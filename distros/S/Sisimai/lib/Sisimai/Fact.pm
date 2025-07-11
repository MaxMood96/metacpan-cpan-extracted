package Sisimai::Fact;
use v5.26;
use strict;
use warnings;
use Sisimai::Message;
use Sisimai::RFC791;
use Sisimai::RFC1123;
use Sisimai::RFC1894;
use Sisimai::RFC5322;
use Sisimai::Reason;
use Sisimai::Address;
use Sisimai::DateTime;
use Sisimai::Time;
use Sisimai::SMTP::Command;
use Sisimai::SMTP::Failure;
use Sisimai::String;
use Sisimai::Rhost;
use Sisimai::LDA;
use Class::Accessor::Lite ('new' => 0, 'rw' => [
    'action',           # [String] The value of Action: header
    'addresser',        # [Sisimai::Address] From address
    'alias',            # [String] Alias of the recipient address
    'catch',            # [?] Results generated by hook method
    'command',          # [String] The last SMTP command
    'decodedby',        # [String] MTA Module name since v5.2.0
    'deliverystatus',   # [String] Delivery Status(DSN)
    'destination',      # [String] The domain part of the "recipient"
    'diagnosticcode',   # [String] Diagnostic-Code: Header
    'diagnostictype',   # [String] The 1st part of Diagnostic-Code: Header
    'feedbackid',       # [String] The value of Feedback-ID: header of the original message
    'feedbacktype',     # [String] Feedback Type
    'hardbounce',       # [Integer] 1 = Hard bounce, 0 = Is not a hard bounce
    'lhost',            # [String] local host name/Local MTA
    'listid',           # [String] List-Id header of each ML
    'messageid',        # [String] Message-Id: header
    'origin',           # [String] Email path as a data source
    'reason',           # [String] Bounce reason
    'recipient',        # [Sisimai::Address] Recipient address which bounced
    'replycode',        # [String] SMTP Reply Code
    'rhost',            # [String] Remote host name/Remote MTA
    'senderdomain',     # [String] The domain part of the "addresser"
    'subject',          # [String] UTF-8 Subject text
    'timestamp',        # [Sisimai::Time] Date: header in the original message
    'timezoneoffset',   # [Integer] Time zone offset(seconds)
    'token',            # [String] Message token/MD5 Hex digest value
]);

sub rise {
    # Constructor of Sisimai::Fact
    # @param         [Hash]   argvs
    # @options argvs [String]  data         Entire email message
    # @options argvs [Integer] delivered    1 if the result which has "delivered" reason is included
    # @options argvs [Integer] vacation     1 if the result which has "vacation" reason is included
    # @options argvs [Code]    hook         Code reference to callback method
    # @options argvs [String]  origin       Path to the original email file
    # @return        [Array]                Array of Sisimai::Fact objects
    my $class = shift;
    my $argvs = shift || return undef;
    die ' ***error: Sisimai::Fact->rise receives only a HASH reference as an argument' unless ref $argvs eq 'HASH';

    my $email = $argvs->{'data'} || return undef;
    my $args1 = {'data' => $email, 'hook' => $argvs->{'hook'}};
    my $mesg1 = Sisimai::Message->rise($args1) || return undef;

    return undef unless $mesg1->{'ds'};
    return undef unless $mesg1->{'rfc822'};

    state $retryindex = Sisimai::Reason->retry;
    state $rfc822head = Sisimai::RFC5322::HEADERTABLE;
    state $actionlist = {'delayed' => 1, 'delivered' => 1, 'expanded' => 1, 'failed' => 1, 'relayed' => 1};
    my    $rfc822data = $mesg1->{'rfc822'};
    my    $listoffact = [];

    RISEOF: for my $e ( $mesg1->{'ds'}->@* ) {
        # Create parameters
        next if length $e->{'recipient'} < 5;
        next if ! $argvs->{'delivered'} && index($e->{'status'}, '2.') == 0;
        next if ! $argvs->{'vacation'}  && $e->{'reason'} eq 'vacation';

        my $thing = {}; # To be blessed and pushed into the array above at the end of the loop
        my $piece = {
            'action'         => $e->{'action'}       // '',
            'alias'          => $e->{'alias'}        // '',
            'catch'          => $mesg1->{'catch'}    // undef,
            'decodedby'      => $e->{'agent'}        // '',
            'deliverystatus' => $e->{'status'}       // '',
            'diagnosticcode' => $e->{'diagnosis'}    // '',
            'diagnostictype' => $e->{'spec'}         // '',
            'feedbacktype'   => $e->{'feedbacktype'} // '',
            'hardbounce'     => 0,
            'lhost'          => $e->{'lhost'}        // '',
            'origin'         => $argvs->{'origin'}   // '',
            'reason'         => $e->{'reason'}       // '',
            'recipient'      => $e->{'recipient'}    // '',
            'replycode'      => $e->{'replycode'}    // '',
            'rhost'          => $e->{'rhost'}        // '',
            'command'        => $e->{'command'}      // '',
        };

        ADDRESSER: {
            # Detect an email address from message/rfc822 part
            my $j = [];
            for my $f ( $rfc822head->{'addresser'}->@* ) {
                # Check each header in message/rfc822 part
                next unless exists $rfc822data->{ $f };
                next unless $rfc822data->{ $f };

                $j = Sisimai::Address->find($rfc822data->{ $f }) || next;
                $piece->{'addresser'} = shift @$j;
                last ADDRESSER;
            }

            # Fallback: Get the sender address from the header of the bounced email if the address
            # is not set at the loop above.
            $j = Sisimai::Address->find($mesg1->{'header'}->{'to'}) || [];
            $piece->{'addresser'} = shift @$j;
        }
        next RISEOF unless $piece->{'addresser'};

        TIMESTAMP: {
            # Convert from a time stamp or a date string to a machine time.
            my $datestring = undef;
            my $zoneoffset = 0;
            my @datevalues; push @datevalues, $e->{'date'} if $e->{'date'};

            # Date information did not exist in message/delivery-status part,...
            for my $f ( $rfc822head->{'date'}->@* ) {
                # Get the value of Date header or other date related header.
                next unless $rfc822data->{ $f };
                push @datevalues, $rfc822data->{ $f };
            }

            # Set "date" getting from the value of "Date" in the bounce message
            push @datevalues, $mesg1->{'header'}->{'date'} if scalar(@datevalues) < 2;

            while( my $v = shift @datevalues ) {
                # Decode each date value in the array
                $datestring = Sisimai::DateTime->parse($v) || next;

                if( $datestring =~ /\A(.+)[ ]+([-+]\d{4})\z/ ) {
                    # Get the value of timezone offset from $datestring: Wed, 26 Feb 2014 06:05:48 -0500
                    $datestring = $1;
                    $zoneoffset = Sisimai::DateTime->tz2second($2);
                    $piece->{'timezoneoffset'} = $2;
                }
                last if $datestring;
            }

            eval {
                # Convert from the date string to an object then calculate time zone offset.
                my $t = Sisimai::Time->strptime($datestring, '%a, %d %b %Y %T');
                $piece->{'timestamp'} = ($t->epoch - $zoneoffset) // undef;
            };
        }
        next RISEOF unless defined $piece->{'timestamp'};

        RECEIVED: {
            # Scan "Received:" header of the original message
            my $recv = $mesg1->{'header'}->{'received'} || [];
            unless( $piece->{'rhost'} ) {
                # Try to pick a remote hostname from Received: headers of the bounce message
                my $ir = Sisimai::RFC1123->find($e->{'diagnosis'});
                $piece->{'rhost'} = $ir if Sisimai::RFC1123->is_internethost($ir);

                unless( $piece->{'rhost'} ) {
                    # The remote hostname in the error message did not exist or is not a valid
                    # internet hostname
                    for my $re ( reverse @$recv ) {
                        # Check the Received: headers backwards and get a remote hostname
                        last if $piece->{'rhost'};
                        my $cv = Sisimai::RFC5322->received($re)->[0];
                        next unless Sisimai::RFC1123->is_internethost($cv);
                        $piece->{'rhost'} = $cv;
                    }
                }
            }
            $piece->{'lhost'} = '' if $piece->{'lhost'} eq $piece->{'rhost'};

            unless( $piece->{'lhost'} ) {
                # Try to pick a local hostname from Received: headers of the bounce message
                for my $le ( @$recv ) {
                    # Check the Received: headers forwards and get a local hostname
                    my $cv = Sisimai::RFC5322->received($le)->[0];
                    next unless Sisimai::RFC1123->is_internethost($cv);
                    $piece->{'lhost'} = $cv; last;
                }
            }

            for my $v ('rhost', 'lhost') {
                # Check and rewrite each host name
                next unless length $piece->{ $v };
                if( index($piece->{ $v }, '@') > -1 ) {
                    # Use the domain part as a remote/local host when the value is an email address
                    $piece->{ $v } = (split('@', $piece->{ $v }))[-1];
                }
                y/[]()\r//d, s/\A.+=// for $piece->{ $v }; # Remove [], (), \r, and strings before "="

                if( index($piece->{ $v }, ' ') > -1 ) {
                    # Check a space character in each value and get the first hostname
                    my @ee = split(' ', $piece->{ $v });
                    for my $w ( @ee ) {
                        # get a hostname from the string like "127.0.0.1 x109-20.example.com 192.0.2.20"
                        # or "mx.sp.example.jp 192.0.2.135"
                        next if Sisimai::RFC791->is_ipv4address($w);
                        $piece->{ $v } = $w; last;
                    }
                    $piece->{ $v } = $ee[0] if index($piece->{ $v }, ' ') > 0;
                }
                chop $piece->{ $v } if substr($piece->{ $v }, -1, 1) eq '.'; # Remove "." at the end of the value
            }
        }

        ID_HEADERS: {
            # Message-ID:, List-ID: headers of the original message
            my $p0 = 0;
            my $p1 = 0;
            if( Sisimai::String->aligned(\$rfc822data->{'message-id'}, ['<', '@', '>']) ) {
                # https://www.rfc-editor.org/rfc/rfc5322#section-3.6.4
                # Leave only string inside of angle brackets(<>)
                $p0 = index($rfc822data->{'message-id'}, '<') + 1;
                $p1 = index($rfc822data->{'message-id'}, '>');
                $piece->{'messageid'} = substr($rfc822data->{'message-id'}, $p0, $p1 - $p0);

            } else {
                # Invalid value of the Message-Id: field
                $piece->{'messageid'} = '';
            }

            if( Sisimai::String->aligned(\$rfc822data->{'list-id'}, ['<', '.', '>']) ) {
                # https://www.rfc-editor.org/rfc/rfc2919
                # Get the value of List-Id header: "List name <list-id@example.org>"
                $p0 = index($rfc822data->{'list-id'}, '<') + 1;
                $p1 = index($rfc822data->{'list-id'}, '>');
                $piece->{'listid'} = substr($rfc822data->{'list-id'}, $p0, $p1 - $p0);

            } else {
                # Invalid value of the List-Id: field
                $piece->{'listid'} = '';
            }
        }

        DIAGNOSTICCODE: {
            # Cleanup the value of "Diagnostic-Code:" header
            last unless length $piece->{'diagnosticcode'};

            # Get an SMTP Reply Code and an SMTP Enhanced Status Code
            chop $piece->{'diagnosticcode'} if substr($piece->{'diagnosticcode'}, -1, 1) eq "\r";

            my $cs = Sisimai::SMTP::Status->find($piece->{'diagnosticcode'})      || '';
            my $cr = Sisimai::SMTP::Reply->find( $piece->{'diagnosticcode'}, $cs) || '';
            $piece->{'deliverystatus'} = Sisimai::SMTP::Status->prefer($piece->{'deliverystatus'}, $cs, $cr);

            if( length $cr == 3 ) {
                # There is an SMTP reply code in the error message
                $piece->{'replycode'} ||= $cr;

                if( index($piece->{'diagnosticcode'}, $cr.'-') > -1 ) {
                    # 550-5.7.1 [192.0.2.222] Our system has detected that this message is
                    # 550-5.7.1 likely unsolicited mail. To reduce the amount of spam sent to Gmail,
                    # 550-5.7.1 this message has been blocked. Please visit
                    # 550 5.7.1 https://support.google.com/mail/answer/188131 for more information.
                    #
                    # kijitora@example.co.uk
                    #   host c.eu.example.com [192.0.2.3]
                    #   SMTP error from remote mail server after end of data:
                    #   553-SPF (Sender Policy Framework) domain authentication
                    #   553-fail. Refer to the Troubleshooting page at
                    #   553-http://www.symanteccloud.com/troubleshooting for more
                    #   553 information. (#5.7.1)
                    for my $q ('-', ' ') {
                        # Remove strings: "550-5.7.1", and "550 5.7.1" from the error message
                        my $cx = sprintf("%s%s%s", $cr, $q, $cs);
                        my $p0 = index($piece->{'diagnosticcode'}, $cx);
                        while( $p0 > -1 ) {
                            # Remove strings like "550-5.7.1"
                            substr($piece->{'diagnosticcode'}, $p0, length $cx, '');
                            $p0 = index($piece->{'diagnosticcode'}, $cx);
                        }

                        # Remove "553-" and "553 " (SMTP reply code only) from the error message
                        $cx = sprintf("%s%s", $cr, $q);
                        $p0 = index($piece->{'diagnosticcode'}, $cx);
                        while( $p0 > -1 ) {
                            # Remove strings like "553-"
                            substr($piece->{'diagnosticcode'}, $p0, length $cx, '');
                            $p0 = index($piece->{'diagnosticcode'}, $cx);
                        }
                    }

                    if( index($piece->{'diagnosticcode'}, $cr) > 1 ) {
                        # Add "550 5.1.1" into the head of the error message when the error
                        # message does not begin with "550"
                        $piece->{'diagnosticcode'} = sprintf("%s %s %s", $cr, $cs, $piece->{'diagnosticcode'});
                    }
                }
            }

            my $dc = lc $piece->{'diagnosticcode'};
            my $p1 = index($dc, '<html>');
            my $p2 = index($dc, '</html>');
            substr($piece->{'diagnosticcode'}, $p1, $p2 + 7 - $p1, '') if $p1 > 0 && $p2 > 0;
            $piece->{'diagnosticcode'} = Sisimai::String->sweep($piece->{'diagnosticcode'});
        }

        DIAGNOSTICTYPE: {
            # Set the value of "diagnostictype" if it is empty
            $piece->{'diagnostictype'} ||= 'X-UNIX' if $piece->{'reason'} eq 'mailererror';
            $piece->{'diagnostictype'} ||= 'SMTP' unless grep { $piece->{'reason'} eq $_ } ('feedback', 'vacation');
        }

        # Check the SMTP command, the Subject field of the original message
        $piece->{'command'} = '' unless Sisimai::SMTP::Command->test($piece->{'command'});
        $piece->{'subject'} = $rfc822data->{'subject'} // '';
        chop $piece->{'subject'} if substr($piece->{'subject'}, -1, 1) eq "\r";

        CONSTRUCTOR: {
            # Create email address object
            my $as = Sisimai::Address->new($piece->{'addresser'})                || next RISEOF;
            my $ar = Sisimai::Address->new({'address' => $piece->{'recipient'}}) || next RISEOF;
            my @ea = (qw|
                action command decodedby deliverystatus diagnosticcode diagnostictype feedbacktype
                lhost listid messageid origin reason replycode rhost subject
            |);

            $thing = {
                'addresser'    => $as,
                'recipient'    => $ar,
                'senderdomain' => $as->host,
                'destination'  => $ar->host,
                'alias'        => $piece->{'alias'} || $ar->alias,
                'token'        => Sisimai::String->token($as->address, $ar->address, $piece->{'timestamp'}),
            };
            $thing->{ $_ }           ||= $piece->{ $_ }    // '' for @ea;
            $thing->{'catch'}          = $piece->{'catch'} // undef;
            $thing->{"feedbackid"}     = "";
            $thing->{'hardbounce'}     = int $piece->{'hardbounce'};
            $thing->{'replycode'}    ||= Sisimai::SMTP::Reply->find($piece->{'diagnosticcode'}) || '';
            $thing->{'timestamp'}      = Sisimai::Time->new($piece->{'timestamp'});
            $thing->{'timezoneoffset'} = $piece->{'timezoneoffset'} // '+0000';
        }

        ALIAS: {
            # Look up the Envelope-To address from the Received: header in the original message
            # when the recipient address is same with the value of $o->{'alias'}.
            last if length $thing->{'alias'} == 0 || $thing->{'recipient'}->address ne $thing->{'alias'};
            last unless exists $rfc822data->{'received'};
            last unless scalar $rfc822data->{'received'}->@*;

            for my $er ( reverse $rfc822data->{'received'}->@* ) {
                # Search for the string " for " from the Received: header
                next unless index($er, ' for ') > 1;
                my $or = Sisimai::RFC5322->received($er);

                next if scalar(@$or) == 0 || length($or->[5]) == 0;
                next if Sisimai::Address->is_emailaddress($or->[5]) == 0;
                next if $thing->{'recipient'}->address eq $or->[5];

                $thing->{'alias'} = $or->[5];
                last ALIAS;
            }
        }
        $thing->{'alias'} = '' if $thing->{'alias'} eq $thing->{'recipient'}->{'address'};

        REASON: {
            # Decide the reason of the email bounce
            if( $thing->{'reason'} eq '' || exists $retryindex->{ $thing->{'reason'} } ) {
                # The value of "reason" is empty or is needed to check with other values again
                my $re = $thing->{'reason'} || 'undefined';
                my $cr = "Sisimai::Reason";
                my $or = Sisimai::LDA->find($thing);    if( $cr->is_explicit($or) ){ $thing->{'reason'} = $or; last }
                   $or = Sisimai::Rhost->find($thing);  if( $cr->is_explicit($or) ){ $thing->{'reason'} = $or; last }
                   $or = Sisimai::Reason->find($thing); if( $cr->is_explicit($or) ){ $thing->{'reason'} = $or; last }
                $thing->{'reason'} = $thing->{'diagnosticcode'} ? "onhold" : $re;
            }
        }

        HARDBOUNCE: {
            # Set the value of "hardbounce", default value of "bouncebounce" is 0
            if( $thing->{'reason'} eq 'delivered' || $thing->{'reason'} eq 'feedback' || $thing->{'reason'} eq 'vacation' ) {
                # Delete the value of ReplyCode when the Reason is "feedback" or "vacation"
                $thing->{'replycode'} = '' unless $thing->{'reason'} eq 'delivered';

            } else {
                # The reason is not "delivered", or "feedback", or "vacation"
                my $smtperrors = $piece->{'deliverystatus'}.' '.$piece->{'diagnosticcode'};
                   $smtperrors = '' if length $smtperrors < 4;
                $thing->{'hardbounce'} = Sisimai::SMTP::Failure->is_hardbounce($thing->{'reason'}, $smtperrors);
            }
        }

        DELIVERYSTATUS: {
            # Set pseudo status code
            last DELIVERYSTATUS if $thing->{'deliverystatus'};

            my $smtperrors = $thing->{'replycode'}.' '.$piece->{'diagnosticcode'};
               $smtperrors = '' if length $smtperrors < 4;
            my $permanent0 = Sisimai::SMTP::Failure->is_permanent($smtperrors);
            my $temporary0 = Sisimai::SMTP::Failure->is_temporary($smtperrors);
            my $temporary1 = $permanent0.$temporary0 eq "00" ? 0 : $temporary0;
            $thing->{'deliverystatus'} = Sisimai::SMTP::Status->code($thing->{'reason'}, $temporary1);
        }

        REPLYCODE: {
            # Check both of the first digit of "deliverystatus" and "replycode"
            my $cx = [substr($thing->{'deliverystatus'}, 0, 1), substr($thing->{'replycode'}, 0, 1)];
            if( $cx->[0] ne $cx->[1] ) {
                # The class of the "Status:" is defer with the first digit of the reply code
                $cx->[1] = Sisimai::SMTP::Reply->find($piece->{'diagnosticcode'}, $cx->[0]) || '';
                $thing->{'replycode'} = index($cx->[1], $cx->[0]) == 0 ? $cx->[1] : '';
            }

            unless( exists $actionlist->{ $thing->{'action'} } ) {
                # There is an action value which is not described at RFC1894
                if( my $ox = Sisimai::RFC1894->field('Action: '.$thing->{'action'}) ) {
                    # Rewrite the value of "Action:" field to the valid value
                    #
                    #    The syntax for the action-field is:
                    #       action-field = "Action" ":" action-value
                    #       action-value = "failed" / "delayed" / "delivered" / "relayed" / "expanded"
                    $thing->{'action'} = $ox->[2];
                }
            }
            $thing->{'action'}   = 'delivered' if $thing->{'reason'} eq 'delivered';
            $thing->{'action'} ||= 'delayed'   if $thing->{'reason'} eq 'expired';
            $thing->{'action'} ||= 'failed'    if $cx->[0] eq '4' || $cx->[0] eq '5';
            $thing->{'action'} ||= "";
        }

        if( $thing->{'replycode'} ne "" ) {
            # Fill empty values: ["SMTP Command", "DSN", "Reason"]
            my $cv = Sisimai::SMTP::Reply->associatedwith($thing->{'replycode'});
            if( scalar @$cv > 0 ) {
                $thing->{'command'}        = $cv->[0] if $cv->[0] ne "" && $thing->{'command'} eq "";
                $thing->{'deliverystatus'} = $cv->[1] if $cv->[1] ne "" && Sisimai::SMTP::Status->is_explicit($thing->{'deliverystatus'}) == 0;
                $thing->{'reason'}         = $cv->[2] if $cv->[2] ne "" && Sisimai::Reason->is_explicit($thing->{'reason'}) == 0;
            }
        }
        # Feedback-ID: 1.us-west-2.QHuyeCQrGtIIMGKQfVdUhP9hCQR2LglVOrRamBc+Prk=:AmazonSES
        $thing->{'feedbackid'} = $rfc822data->{'feedback-id'} || "";

        push @$listoffact, bless($thing, __PACKAGE__);
    } # End of for(RISEOF)

    return $listoffact;
}

sub damn {
    # Convert from object to hash reference
    # @return   [Hash] Data in Hash reference
    my $self = shift;
    my $data = undef;
    state $stringdata = [qw|
        action alias catch command decodedby deliverystatus destination diagnosticcode diagnostictype
        feedbackid feedbacktype lhost listid messageid origin reason replycode rhost senderdomain
        subject timezoneoffset token
    |];
    eval {
        my $v = {};
        $v->{ $_ }         = $self->$_ // '' for @$stringdata;
        $v->{'hardbounce'} = int $self->hardbounce;
        $v->{'addresser'}  = $self->addresser->address;
        $v->{'recipient'}  = $self->recipient->address;
        $v->{'timestamp'}  = $self->timestamp->epoch;

        # Backward compatibility until v5.5.0
        $v->{"smtpagent"}   = $self->decodedby;
        $v->{"smtpcommand"} = $self->command;
        $data = $v;
    };
    return $data;
}

sub dump {
    # Data dumper
    # @param    [String] type   Data format: json, yaml
    # @return   [String]        Dumped data or an empty string when the argument is neither "json" nor "yaml"
    my $self = shift;
    my $type = shift || 'json'; return "" unless $type =~ /\A(?:json|yaml)\z/;

    my $referclass = 'Sisimai::Fact::'.uc($type);
    my $modulepath = 'Sisimai/Fact/'.uc($type).'.pm';

    require $modulepath;
    return $referclass->dump($self);
}

sub smtpagent   { warn " ***warning: Sisimai::Fact->smtpagent will be removed at v5.5.0"; return shift->decodedby }
sub smtpcommand { warn " ***warning: Sisimai::Fact->smtpcommand will be removed at v5.5.0"; return shift->command }

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Fact - Decoded data object

=head1 SYNOPSIS

    use Sisimai::Fact;
    my $args = {'data' => 'entire-email-text-including-all-the-headers'};
    my $fact = Sisimai::Fact->rise($args);
    for my $e ( @$fact ) {
        print $e->reason;               # userunknown, mailboxfull, and so on.
        print $e->recipient->address;   # (Sisimai::Address) envelope recipient address
        print $e->bonced->ymd           # (Sisimai::Time) Date of bounce
    }

=head1 DESCRIPTION

C<Sisimai::Fact> generates a decoded bounce email data structure from C<Sisimai::Message> object.

=head1 CLASS METHODS

=head2 C<B<rise(I<Hash>)>>

C<rise()> method generate decoded data and returns an array reference which are including
C<Sisimai::Fact> objects.

    my $mail = Sisimai::Mail->new('/var/mail/root');
    while( my $r = $mail->read ) {
        my $fact = Sisimai::Fact->make('data' => $r);
        for my $e ( @$fact ) {
            print $e->reason;               # userunknown, mailboxfull, and so on.
            print $e->recipient->address;   # (Sisimai::Address) envelope recipient address
            print $e->timestamp->ymd        # (Sisimai::Time) Date of the email bounce
        }
    }

If you want to get bounce records which reason is C<"delivered">, set C<delivered> option to C<rise()>
method like the following:

    my $fact = Sisimai::Fact->rise('data' => $r, 'delivered' => 1);

=head1 INSTANCE METHODS

=head2 C<B<damn()>>

C<damn> method converts the object to a hash reference.

    my $hash = $self->damn;
    print $hash->{'recipient'}; # user@example.jp
    print $hash->{'timestamp'}; # 1393940000

=head1 PROPERTIES

C<Sisimai::Fact> have the following properties:

=head2 C<action> (I<String>)

C<action> is the value of C<Action:> field in a bounce email message such as C<failed> or C<delayed>.

    Action: failed

=head2 C<addresser> (I<Sisimai::Address)>

C<addressser> is L<Sisimai::Address> object generated from the sender address. When C<Sisimai::Fact>
object is dumped as JSON, this value converted to an email address. C<Sisimai::Address> object have
the following accessors:

=over

=item - C<user()> - the local part of the address

=item - C<host()> - the domain part of the address

=item - C<address()> - email address

=item - C<verp()> - variable envelope return path

=item - C<alias()> - alias of the address

=back

    From: "Kijitora Cat" <kijitora@example.org>

=head2 C<alias> (I<String>)

C<alias> is an alias address of the recipient. When the C<Original-Recipient:> field or
C<expanded from "address"> string did not exist in a bounce message, this value is empty.

    Original-Recipient: rfc822;kijitora@example.org

    "|IFS=' ' && exec /usr/local/bin/procmail -f- || exit 75 #kijitora"
        (expanded from: <kijitora@neko.example.edu>)

=head2 C<command> (I<String>)

C<command> is a SMTP command name picked from the error message or the value of C<Diagnostic-Code:>
field in a bounce message. When there is no SMTP command in the bounce message, this value will be
empty. The list of values is C<HELO>, C<EHLO>, C<MAIL>, C<RCPT>, C<DATA>, and C<CONN>.
Until v5.2.0, this accessor name was C<smtpcommand>.

    <kijitora@example.go.jp>: host mx1.example.go.jp[192.0.2.127] said: 550 5.1.6 recipient
        no longer on server: kijitora@example.go.jp (in reply to RCPT TO command)

=head2 C<decodedby> (I<String>)

C<decodedby> is a module name to be used for decoding a bounce message. For example, when the value
is C<Sendmail>, Sisimai used L<Sisimai::Lhost::Sendmail> to decode the bounce message, to find the
recipient address, and collect error messages for deciding a bounce reason.
Until v5.2.0, this accessor name was C<smtpagent>.

=head2 C<deliverystatus> (I<String>)

C<deliverystatus> is the value of C<Status:> field in a bounce message. When the message has no
C<Status:> field, Sisimai set pseudo value like C<5.0.9XX> to this value. The range of values only
C<4.x.x> or C<5.x.x>.

    Status: 5.0.0 (permanent failure)

=head2 C<destination> (I<String>)

C<destination> is the domain part of the recipient address. This value is the same as the return
value from C<host()> method of C<recipient> accessor.

=head2 C<diagnosticcode> (I<String>)

C<diagnosticcode> is an error message picked from C<Diagnostic-Code:> field or message body in a
bounce message. This value and the value of C<diagnostictype>, C<action>, C<deliverystatus>, C<replycode>,
and C<command> will be referred by L<Sisimai::Reason> to decide the bounce reason.

    Diagnostic-Code: SMTP; 554 5.4.6 Too many hops

=head2 C<diagnostictype> (C<String>)

C<diagnostictype> is a type like C<SMTP> or C<X-Unix> picked from C<Diagnostic-Code:> field in a
bounce message. When there is no C<Diagnostic-Code:> field in the bounce message, this value will
be empty.

    Diagnostic-Code: X-Unix; 255

=head2 C<feedbacktype> (I<String>)

C<feedbacktype> is the value of C<Feedback-Type:> field like C<abuse>, C<fraud>, C<opt-out> in a
bounce message. When the message is not ARF format or the value of C<reason> is not C<feedback>,
this value will be empty.

    Content-Type: message/feedback-report

    Feedback-Type: abuse
    User-Agent: SMP-FBL

=head2 C<hardbounce> (I<Integer>)

The value of C<hardbounce> indicates whether the reason of the bounce is a hard bounce or not. This
accessor has added in Sisimai 5.0.0. The range of the values are the followings:

=over

=item C<1> = Hard bounce

=item C<0> = Not a hard bounce

=back

=head2 C<lhost> (I<String>)

C<lhost> is a local MTA name to be used as a gateway for sending email message or the value of
C<Reporting-MTA:> field in a bounce message. When there is no C<Reporting-MTA:> field in a bounce
message, Sisimai try to get the value from C<Received:> headers.

    Reporting-MTA: dns; mx4.smtp.example.co.jp

=head2 C<listid> (I<String>)

C<listid> is the value of C<List-Id:> header of the original message. When there is no C<List-Id:>
field in the original message or the bounce message did not include the original message, this value
will be empty.

    List-Id: Mailman mailing list management users

=head2 C<messageid> (I<String>)

C<messageid> is the value of C<Message-Id:> header of the original message. When the original message
did not include C<Message-Id:> header or the bounce message did not include the original message,
this value will be empty.

    Message-Id: <201310160515.r9G5FZh9018575@smtpgw.example.jp>

=head2 C<origin> (I<Path to the original email file>)

C<origin> is the path to the original email file of the decoded results. When the original email data
were input from STDIN, the value is C<<STDIN>>, were input from a variable, the value is C<<MEMORY>>.
This accessor method has been implemented at v4.25.6.

=head2 C<recipient> (I<Sisimai::Address)>

C<recipient> is L<Sisimai::Address> object generated from the recipient address.  When C<Sisimai::Fact>
object is dumped as JSON, this value converted to an email address. C<Sisimai::Address> object have
the following accessors:

=over

=item - C<user()> - the local part of the address

=item - C<host()> - the domain part of the address

=item - C<address()> - email address

=item - C<verp()> - variable envelope return path

=item - C<alias()> - alias of the address

=back

    Final-Recipient: RFC822; shironeko@example.ne.jp
    X-Failed-Recipients: kijitora@example.ed.jp

=head2 C<reason> (I<String>)

C<reason> is the value of bounce reason Sisimai detected. When this value is C<undefined> or C<onhold>,
it means that Sisimai could not decide the reason. All the reasons Sisimai can detect are available
at L<Sisimai::Reason> or web site L<https://libsisimai.org/en/reason/>.

=head2 C<replycode> (I<Integer>)

C<replycode> is the value of SMTP reply code picked from the error message or the value of C<Diagnostic-Code:>
field in a bounce message. The range of values is only C<4xx> or C<5xx>.

       ----- The following addresses had permanent fatal errors -----
    <userunknown@libsisimai.org>
        (reason: 550 5.1.1 <userunknown@libsisimai.org>... User Unknown)

=head2 C<rhost> (I<String>)

C<rhost> is a remote MTA name which has rejected the message you sent or the value of C<Remote-MTA:>
field in a bounce message. When there is no C<Remote-MTA:> field in the bounce message, Sisimai try
to get the value from C<Received:> headers.

    Remote-MTA: DNS; g5.example.net

=head2 C<senderdomain> (I<String>)

C<senderdomain> is the domain part of the sender address. This value is the same as the return value
from C<host()> method of addresser accessor.

=head2 C<subject> (I<String>)

C<subject> is the value of C<Subject:> header of the original message. When the original message which
is included in a bounce email contains no C<Subject:> header (removed by remote MTA), this value will
be empty. If the value of C<Subject:> header of the original message contain any multibyte character
(non-ASCII character), such as MIME encoded Japanese or German and so on, the value of C<"subject">
in decoded data is encoded with UTF-8 again.

=head2 C<token> (I<String>)

C<token> is an identifier of each email-bounce. The token string is created from the sender email
address (C<addresser>) and the recipient email address (C<recipient>) and the machine time of the
date in a bounce message as an MD5 hash value. The token value is generated at C<token()> method of
L<Sisimai::String> class.

If you want to get the same token string at command line, try to run the following command:

    % printf "\x02%s\x1e%s\x1e%d\x03" sender@example.jp recipient@example.org `date '+%s'` | md5
    714d72dfd972242ad04f8053267e7365

=head2 C<timestamp> (I<Sisimai::Time>)

C<timestamp> is the date which email has bounced as a L<Sisima::Time> (Child class of C<Time::Piece>)
object. When C<Sisimai::Fact> object is dumped as JSON, this value will be converted to an UNIX machine
time (32 bits integer).

    Arrival-Date: Thu, 29 Apr 2009 23:45:33 +0900

=head2 C<timezomeoffset> (I<String>)

C<timezoneoffset> is a time zone offset of a bounce email which its email has bounced. The format of
this value is String like C<+0900>, C<-0200>.  If Sisimai has failed to get a value of time zone
offset, this value will be set as C<+0000>.

=head1 SEE ALSO

L<https://libsisimai.org/en/data/>

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

