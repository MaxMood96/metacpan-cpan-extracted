package Sisimai::Mail;
use v5.26;
use strict;
use warnings;
use Class::Accessor::Lite (
    'new' => 0,
    'ro'  => [
        'path', # [String] path to mbox or Maildir/
        'kind', # [String] Data type: mailbox, maildir, stdin, or memory
    ],
    'rw'  => [
        'data', # [Sisimai::Mail::[Mbox,Maildir,Memory,STDIO] Object
    ]
);

sub new {
    # Constructor of Sisimai::Mail
    # @param    [String] argv1  Path to mbox or Maildir/
    # @return   [Sisimai::Mail] Object
    #           [Undef]         The argument is wrong
    my $class = shift;
    my $argv1 = shift;
    my $klass = undef;
    my $loads = 'Sisimai/Mail/';
    my $param = {'kind' => '', 'data' => undef, 'path' => $argv1};

    # The argumenet is a mailbox or a Maildir/.
    if( -f $argv1 ) {
        # The argument is a file, it is an mbox or email file in Maildir/
        $klass  = __PACKAGE__.'::Mbox';
        $loads .= 'Mbox.pm';
        $param->{'kind'} = 'mailbox';
        $param->{'path'} = $argv1;

    } elsif( -d $argv1 ) {
        # The agument is not a file, it is a Maildir/
        $klass  = __PACKAGE__.'::Maildir';
        $loads .= 'Maildir.pm';
        $param->{'kind'} = 'maildir';

    } else {
        # The argumen1 neither a mailbox nor a Maildir/.
        if( ref($argv1) eq 'GLOB' || $argv1 eq 'STDIN' ) {
            # Read from STDIN
            $klass  = __PACKAGE__.'::STDIN';
            $loads .= 'STDIN.pm';
            $param->{'kind'} = 'stdin';

        } elsif( ref($argv1) eq 'SCALAR' ) {
            # Read from a variable as a scalar reference
            $klass  = __PACKAGE__.'::Memory';
            $loads .= 'Memory.pm';
            $param->{'kind'} = 'memory';
            $param->{'path'} = 'MEMORY';
        }
    }
    return undef unless $klass;

    require $loads;
    $param->{'data'} = $klass->new($argv1);

    return bless($param, __PACKAGE__);
}

sub read {
    # Alias method of Sisimai::Mail::*->read()
    # @return   [String] Contents of mbox/Maildir
    my $self = shift;
    return "" unless ref $self->{'data'};
    return $self->{'data'}->read;
}

1;
__END__

=encoding utf-8

=head1 NAME

Sisimai::Mail - Handler of Mbox/Maildir for reading each mail.

=head1 SYNOPSIS

    use Sisimai::Mail;
    my $mailbox = Sisimai::Mail->new('/var/mail/root');
    while( my $r = $mailbox->read ) {
        print $r;
    }

    my $maildir = Sisimai::Mail->new('/home/neko/Maildir/cur');
    while( my $r = $maildir->read ) {
        print $r;
    }

    my $mailtxt = 'From Mailer-Daemon ...';
    my $mailobj = Sisimai::Mail->new(\$mailtxt);
    while( my $r = $mailobj->read ) {
        print $r;
    }

=head1 DESCRIPTION

C<Sisimai::Mail> is a handler for reading a UNIX mbox, a Maildir, or any email message input from
C<STDIN> variable. It is a wrapper class of the following child classes:

    * Sisimai::Mail::Mbox
    * Sisimai::Mail::Maildir
    * Sisimai::Mail::STDIN
    * Sisimai::Mail::Memory

=head1 CLASS METHODS

=head2 C<B<new(I<path to mbox|Maildir/>)>>

C<new()> method is a constructor of C<Sisimai::Mail>

    my $mailbox = Sisimai::Mail->new('/var/mail/root');
    my $maildir = Sisimai::Mail->new('/home/nyaa/Maildir/cur');
    my $mailtxt = 'From Mailer-Daemon ...';
    my $mailobj = Sisimai::Mail->new(\$mailtxt);

=head1 INSTANCE METHODS

=head2 C<B<path()>>

C<path()> method returns the path to the mbox or the Maildir.

    print $mailbox->path;   # /var/mail/root

=head2 C<B<kind()>>

C<kind()> method returns the name of the data type

    print $mailbox->kind;   # mailbox or maildir, stdin, or memory.

=head2 C<B<mail()>>

C<mail()> method returns the C<Sisimai::Mail::Mbox> object or the C<Sisimai::Mail::Maildir> object.

    my $o = $mailbox->mail;
    print ref $o;   # Sisimai::Mail::Mbox

=head2 C<B<read()>>

C<read()> method works as an iterator for reading each email in the mbox or the Maildir. It calls
C<Sisimai::Mail::Mbox->read()> or C<Sisimai::Mail::Maildir->read> methods.

    my $mailbox = Sisimai::Mail->new('/var/mail/neko');
    while( my $r = $mailbox->read ) {
        print $r;   # print each email in /var/mail/neko
    }

=head1 AUTHOR

azumakuniyuki

=head1 COPYRIGHT

Copyright (C) 2014-2016,2018-2021,2024,2025 azumakuniyuki, All rights reserved.

=head1 LICENSE

This software is distributed under The BSD 2-Clause License.

=cut

