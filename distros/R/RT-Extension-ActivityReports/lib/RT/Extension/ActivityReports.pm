package RT::Extension::ActivityReports;

use Exporter qw( import );
@EXPORT_OK = qw( RelevantTxns );

our $VERSION = '2.00';

RT->AddStyleSheets('activity-reports.css');

=head1 NAME

RT-Extension-ActivityReports - Additional reports to show Activity in RT

=head1 DESCRIPTION

The ActivityReports extension lets you see:

=over

=item * Activity Detail

A table of ticket status per queue, and totals.

=item * Activity Summary

A one-line summary of all updates made.

=item * Resolution Comments

Summary of when tickets were resolved, duration between creation
and (latest) resolution.

=item * Resolution Statistics

For each queue, average duration between creation and (latest)
resolution over the last 30, 60, 90 days, and all time.

=item * Time Worked Statistics

For each user, a table of every queue and how long that user has worked
on tickets that have been resolved in a particular timeframe. For example,
you can see how much time Joe has spent on Basic Support (queue) tickets
that have been resolved the day after they were created.

=back

All of these reports can be filtered by actor, arbitrary search query,
and/or between two dates, so it's quite flexible.

=head1 RT VERSION

Works with RT 6.0. For RT 5.0 install the latest 1.* version.

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt6/etc/RT_SiteConfig.pm>

Add this line:

    Plugin('RT::Extension::ActivityReports');

=item Clear your mason cache

    rm -rf /opt/rt6/var/mason_data/obj

=item Restart your webserver

=item After Installation

The activity reports can be accessed from the URL
http://<path_to_your_RT>/Reports/Activity/index.html

and will also be available as an Activity Reports tab on Search Results
pages.

=back

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 BUGS

All bugs should be reported via email to

    L<bug-RT-Extension-ActivityReports@rt.cpan.org|mailto:bug-RT-Extension-ActivityReports@rt.cpan.org>

or via the web at

    L<rt.cpan.org|http://rt.cpan.org/Public/Dist/Display.html?Name=RT-Extension-ActivityReports>.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2005-2025 by Best Practical Solutions

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut

# RelevantTxns( $ticket, \%args )
#
#Helper routine for the various activity reports, to get the list of
#relevant transactions on each relevant ticket.  Not yet used for
#Resolution* or TimeWorked reports.  Args include:
#
#    start
#    end
#    actor
#    timed
#
#

sub RelevantTxns {
    my( $ticket, %args ) = @_;

    my $txns = $ticket->Transactions;
    $txns->Limit(FIELD => 'Created', OPERATOR => '>=', VALUE => $args{start});
    $txns->Limit(FIELD => 'Created', OPERATOR => '<=', VALUE => $args{end});
    if( $args{timed} ) {
	# Limit to transactions with positive time taken.
        $txns->Limit(FIELD => 'TimeTaken', OPERATOR => '>=', VALUE => 1); 
    } else {
	# Include status changes and ticket creations.
	$txns->Limit(FIELD => 'Type', VALUE => 'Status', ENTRYAGGREGATOR => 'OR');
	$txns->Limit(FIELD => 'Type', VALUE => 'Create', ENTRYAGGREGATOR => 'OR');
    }
    # Comment/correspond type transactions are always relevant.
    $txns->Limit(FIELD => 'Type', VALUE => 'Comment', ENTRYAGGREGATOR => 'OR');
    $txns->Limit(FIELD => 'Type', VALUE => 'Correspond');

    return $txns;
}

1;
