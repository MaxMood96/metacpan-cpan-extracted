# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

RT::Extension::JSGantt - Gantt charts for your tickets

=head1 DESCRIPTION

This extension uses the Starts and Due dates, along with ticket
dependencies, to produce Gantt charts.

=head1 RT VERSION

Works with RT 6.0 and 5.0

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt6/etc/RT_SiteConfig.pm>

Add this line to your F</opt/rt6/etc/RT_SiteConfig.pm>:

    Plugin('RT::Extension::JSGantt');

=item Clear your mason cache

    rm -rf /opt/rt6/var/mason_data/obj

=item Restart your webserver

=back

=head1 CONFIGURATION

    Set(
        %JSGanttOptions,
        DefaultFormat => 'day', # or week or month or quarter
        ShowOwner     => 1,
        ShowProgress  => 1,
        ShowDuration  => 1,

        # Configurable JSGantt options
        # https://code.google.com/p/jsgantt/wiki/Documentation#4._Instantiate_JSGantt_using_()
        # CaptionType       => 'Resource',
        # ShowStartDate     => 1,
        # ShowEndDate       => 1,
        # DateInputFormat   => 'mm/dd/yyyy',
        # DateDisplayFormat => 'mm/dd/yyyy',
        # FormatArr         => q|'day','week','month','quarter'|,

        # define your own color scheme:
        # ColorScheme => ['ff0000', 'ffff00', 'ff00ff', '00ff00', '00ffff', '0000ff'],

        # we color owners consistently by default, you can disable it via:
        # ColorSchemeByOwner => 0,

        # you can specify colors to use, unspecified owners will be
        # assigned to some color automatically:
        # ColorSchemeByOwner => { root => 'ff0000', foo => '00ff00' },

        # if can't find both start and end dates, use this color
        NullDatesColor => 333,

        # to calculate day length
        WorkingHoursPerDay => 8,

        # used to set start/end if one exists but the other does not
        DefaultDays => 7,
    );

=head1 METHODS

=cut

package RT::Extension::JSGantt;

our $VERSION = '1.09';

use warnings;
use strict;
use List::MoreUtils 'insert_after', 'uniq';

# JS contains mason, and as such cannot use RT->AddJavaScript
RT->AddStyleSheets('jsgantt.css');

=head2 AllRelatedTickets

Given a ticket, return all the relative tickets, including the original ticket.

=cut

sub AllRelatedTickets {
    my $class = shift;
    my %args = ( Ticket => undef, CurrentUser => undef, @_ );

    my @tickets;
    my @to_be_checked;
    my $ticket = RT::Ticket->new( $args{CurrentUser} );
    $ticket->Load( $args{Ticket} );
    if ( $ticket->id ) {

        # find the highest ancestors to make chart pretty
        my @parents = _RelatedTickets( $ticket, 'MemberOf' );
        @parents = $ticket unless @parents;
        my $depth = 0;
        while (@parents ) {
            my @ancestors;
            for my $parent (@parents) {
                unshift @ancestors, _RelatedTickets( $parent, 'MemberOf' );
            }

            if (@ancestors && $depth++ < 10 ) {
                @parents = @ancestors;
            }
            else {
                @to_be_checked = @parents;
                undef @parents;
            }
        }

        @tickets = _GetOrderedTickets( @to_be_checked );
    }
    return @tickets;
}

=head2 TicketsInfo

Given tickets, resolve useful info for jsgantt.js
Returns a 2 elements array, 1st is the ids arrayref, 2nd is the info hashref.

=cut

sub TicketsInfo {
    my $class = shift;
    my %args = ( Tickets => [], CurrentUser => undef, @_ );


    my ( @ids, %info );
    my %options = RT->Config->Get('JSGanttOptions') ?
        RT->Config->Get('JSGanttOptions') : ();

    my @colors;
    if ( $options{ColorScheme} ) {
        @colors = @{$options{ColorScheme}};
    }
    else {
        @colors = (
            '66cc66', 'ff6666', 'ffcc66', '663399', '3333cc', '339933',
            '993333', '996633', '33cc33', 'cc3333', 'cc9933', '6633cc'
        );
    }
    my $i;

    my ( $min_start, $min_start_obj );

    my %color_map;
    $options{ColorSchemeByOwner} = 1 unless exists $options{ColorSchemeByOwner};
    if ( $options{ColorSchemeByOwner} ) {
        my @owner_names = uniq map { $_->OwnerObj->Name } @{ $args{Tickets} };
        @color_map{@owner_names} =
          (@colors) x ( ( @owner_names ? int @colors / @owner_names : 0 ) + 1 );
        if (   ref $options{ColorSchemeByOwner}
            && ref $options{ColorSchemeByOwner} eq 'HASH' )
        {
            %color_map = ( %color_map, %{ $options{ColorSchemeByOwner} } );
        }
    }

    for my $Ticket (@{$args{Tickets}}) {
        my $progress = 0;
        my $subject = $Ticket->Subject;

        my $parent = _ParentTicket( $Ticket, $args{Tickets} );
        $parent = $parent ? $parent->id : 0;

        # find start/end
        my ( $start_obj, $start, $end_obj, $end ) = _GetTimeRange( $Ticket, %args );

        if ( $start_obj
            && ( !$min_start_obj || $min_start_obj->Unix > $start_obj->Unix ) )
        {
            $min_start_obj = $start_obj;
            $min_start     = $start;
        }

        my $depends = $Ticket->DependsOn;
        my @depends;
        if ( $depends->Count ) {
            while ( my $d = $depends->Next ) {
                # skip the remote links
                next unless $d->TargetObj;
                push @depends, $d->TargetObj->id;
            }
        }

        if ($options{ShowProgress}) {
            my $total_time =
              defined $Ticket->TimeLeft && $Ticket->TimeLeft =~ /\d/
              ? ( $Ticket->TimeWorked + $Ticket->TimeLeft )
              : $Ticket->TimeEstimated;
            if ($total_time && $total_time =~ /\d/ ) {
                if ( $Ticket->TimeWorked ) {
                    $progress = int( 100 * $Ticket->TimeWorked / $total_time );
                }
            }
        }

        push @ids, $Ticket->id;
        $info{ $Ticket->id } = {
            name  => ( $Ticket->id . ': ' . substr $subject, 0, 30 ),
            start => $start,
            end   => $end,
            color => (
                  $options{ColorSchemeByOwner}
                ? $color_map{ $Ticket->OwnerObj->Name }
                : $colors[ $i++ % @colors ]
            ),
            link => (
                    RT->Config->Get('WebPath')
                  . '/Ticket/Display.html?id='
                  . $Ticket->id
            ),
            milestone => 0,
            owner =>
              ( $Ticket->OwnerObj->Name || $Ticket->OwnerObj->EmailAddress ),
            progress    => $progress,
            parent      => $parent,
            open        => 1,
            depends     => ( @depends ? join ',', @depends : 0 )
        };
    }

    {
        my @parents = uniq map { $_->{parent} || () } values %info;
        for my $parent (@parents) {
            next unless $info{$parent};
            $info{$parent}{has_members} = 1;
        }
    }

    #let's tweak our results
    #set to now if all tickets don't have start/end dates
    unless ( $min_start_obj && $min_start_obj->Unix > 0 ) {
        $min_start_obj = RT::Date->new( $args{CurrentUser} );
        $min_start_obj->SetToNow;
        my ( $day, $month, $year ) =
          ( $min_start_obj->Localtime('user') )[ 3, 4, 5 ];
        $min_start = join '/', $month + 1, $day, $year;
    }

    my $no_dates_color = $options{NullDatesColor} || '333';
    for my $id (@ids) {
        $info{$id}{color} = $no_dates_color unless $info{$id}{start};
        $info{$id}{start} ||= $min_start;
        $info{$id}{end}   ||= $min_start;
    }
    return \@ids, \%info;
}


=head2 GetTimeRange

Given a ticket, resolve it's start/end.
Returns an array like ( $start_obj, $start, $end_obj, $end )
$start and $end are strings like 3/21/2011

=cut

sub _GetTimeRange {
    my ( $Ticket, %args ) = @_;
    my %options = RT->Config->Get('JSGanttOptions') ?
        RT->Config->Get('JSGanttOptions') : ();

    # the, uh, long way
    my ( $start_obj, $start ) = _GetDate( $Ticket, 'Starts', 'Started' );
    my ( $end_obj, $end ) = _GetDate( $Ticket, 'Due' );

    if ( !$start ) {
        my $Transactions = $Ticket->Transactions;
        while ( my $Transaction = $Transactions->Next ) {
            next
              unless $Transaction->TimeTaken
                  || (   $Transaction->Type eq 'Set'
                      && $Transaction->Field eq 'TimeWorked'
                      && $Transaction->NewValue > $Transaction->OldValue );
            $start_obj = $Transaction->CreatedObj;
            my ( $day, $month, $year ) =
              ( $start_obj->Localtime('user') )[ 3, 4, 5 ];
            $start = join '/', $month + 1, $day, $year;
            last;
        }
    }

    # if $start or $end is empty still
    unless ( $start && $end ) {
        my $hours_per_day = $options{WorkingHoursPerDay} || 8;
        my $total_time =
          defined $Ticket->TimeLeft && $Ticket->TimeLeft =~ /\d/
          ? ( $Ticket->TimeWorked + $Ticket->TimeLeft )
          : $Ticket->TimeEstimated;
        my $days;
        if ( $total_time ) {
            $days = $total_time / ( 60 * $hours_per_day );
        }
        else {
            $days = $options{'DefaultDays'} || 7;
        }

        # since we only use date without time, let's make days inclusive
        # ( i.e. 5/12/2010 minus 3 days is 5/10/2010. 10,11,12, 3 days! )
        $days = $days =~ /\./ ? int $days : $days - 1;
        $days = 0 if $days < 0;

        if ( $start && !$end ) {
            $end_obj = RT::Date->new( $args{CurrentUser} );
            $end_obj->Set( Value => $start_obj->Unix );
            $end_obj->AddDays($days) if $days;
            my ( $day, $month, $year ) =
              ( $end_obj->Localtime('user') )[ 3, 4, 5 ];
            $end = join '/', $month + 1, $day, $year;
        }

        if ( $end && !$start ) {
            $start_obj = RT::Date->new( $args{CurrentUser} );
            $start_obj->Set( Value => $end_obj->Unix );
            $start_obj->AddDays( -1 * $days ) if $days;
            my ( $day, $month, $year ) =
              ( $start_obj->Localtime('user') )[ 3, 4, 5 ];
            $start = join '/', $month + 1, $day, $year;
        }
    }

    if ( !$start ) {
        $RT::Logger->warning( "Ticket "
              . $Ticket->id
              . " doesn't have Starts/Started defined, and we can't figure it out either"
        );
        $start = $end if $end;
    }

    if ( !$end ) {
        $RT::Logger->warning( "Ticket "
              . $Ticket->id
              . " doesn't have Due defined, and we can't figure it out either"
        );
        $end = $start if $start;
    }

    return ( $start_obj, $start, $end_obj, $end );
}

sub _RelatedTickets {
    my $ticket = shift;
    my @types = @_;
    return unless $ticket;
    my @tickets;
    for my $type ( @types ) {
        my $links = $ticket->$type->ItemsArrayRef;
        my $target_or_base =
          $type =~ /DependsOn|MemberOf|RefersTo/ ? 'TargetObj' : 'BaseObj';
        for my $link (@$links) {
            my $obj = $link->$target_or_base;
            if ( $obj && $obj->isa('RT::Ticket') ) {
                push @tickets, $obj;
            }
        }
    }
    return @tickets;
}


sub _GetDate {
    my $ticket = shift;
    my $depth;
    if ( $_[0] =~ /^\d+$/ ) {
        $depth = shift;
    }
    else {
        $depth = 0;
    }

    my @fields = @_;
    my ( $date_obj, $date );
    for my $field (@fields) {
        my $obj = $field . 'Obj';
        if ( $ticket->$obj->Unix > 0 ) {
            $date_obj = $ticket->$obj;
            my ( $day, $month, $year ) =
              ( $date_obj->Localtime('user') )[ 3, 4, 5 ];
            $date = join '/', $month + 1, $day, $year;
        }
    }

    if ($date || $depth++ > 10 ) {
        return ( $date_obj, $date );
    }

    # inherit from parents
    for my $member_of ( @{ $ticket->MemberOf->ItemsArrayRef } ) {
        my $parent = $member_of->TargetObj;
        return _GetDate( $parent, $depth, @fields );
    }
}

sub _GetOrderedTickets {
    my @tickets;
    my @to_be_checked = @_;

    my %map;
    __GetOrderedTickets( \@tickets, \@to_be_checked, {}, 'Members' );
    __GetOrderedTickets( \@tickets, [@tickets], {}, );
    return @tickets;
}

sub __GetOrderedTickets {
    my $tickets       = shift;
    my $to_be_checked = shift;
    my $checked       = shift;
    my $type          = shift;


    if ( $type && $type eq 'Members' ) {
        while ( my $ticket = shift @$to_be_checked ) {
            unless ( grep { $ticket->id eq $_->id } @$tickets ) {
                my $parent = _ParentTicket($ticket, $tickets);

                if ( !$parent || !insert_after { $_->id == $parent->id } $ticket,
                    @$tickets )
                {
                    push @$tickets, $ticket;
                }
            }

            next if $checked->{ $ticket->id }++;

            for my $member ( grep { !$checked->{ $_->id } }
                sort { $b->id <=> $a->id } _RelatedTickets( $ticket, 'Members' ) )
            {
                push @$to_be_checked, $member;
                __GetOrderedTickets( $tickets, $to_be_checked, $checked,
                    'Members' );
            }
        }
    }
    else {
        while ( my $ticket = shift @$to_be_checked ) {
            push @$tickets, $ticket
              unless grep { $ticket->id eq $_->id } @$tickets;
            next if $checked->{ $ticket->id }++;

            for my $related (
                grep { !$checked->{ $_->id } } _RelatedTickets(
                    $ticket,    'MemberOf', 'DependsOn', 'DependedOnBy',
                    'RefersTo', 'ReferredToBy'
                )
              )
            {
                push @$to_be_checked, $related;
                __GetOrderedTickets( $tickets, $to_be_checked, $checked );
            }
        }

    }
}

sub _ParentTicket {
    my $ticket = shift;
    my $candidates = shift || [];
    my @parents = _RelatedTickets( $ticket, 'MemberOf' );
    if (@parents) {
        for my $candidate (@$candidates) {
            if ( grep { $_->id == $candidate->id } @parents ) {
                return $candidate;
            }
        }
        return $parents[0];
    }
    return;
}

if ( RT->Config->can('RegisterPluginConfig') ) {
    RT->Config->RegisterPluginConfig(
        Plugin  => 'JSGantt',
        Content => [
            {
                Name => 'JSGanttOptions',
                Help => 'https://metacpan.org/pod/RT::Extension::JSGantt#CONFIGURATION',
            },
        ],
        Meta    => {
            JSGanttOptions => {
                Type => 'HASH',
            },
        }
    );
}

=head1 UPGRADING

=head2 DateDayBeforeMonth

Prior to version 1.02, there was an undocumented RT config option
C<DateDayBeforeMonth>. If you have DateDayBeforeMonth set in your RT, you can
make JSGantt do the same thing by setting C<DateDisplayFormat> in
RT_SiteConfig.pm:

    Set(
        %JSGanttOptions,
        ...
        # DateDisplayFormat => 'dd/mm/yyyy',
        ...
    );

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-JSGantt@rt.cpan.org|mailto:bug-RT-Extension-JSGantt@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-JSGantt>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2014-2025 by Best Practical Solutions

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

1;
