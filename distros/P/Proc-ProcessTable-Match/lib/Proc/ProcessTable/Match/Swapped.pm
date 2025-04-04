package Proc::ProcessTable::Match::Swapped;

use 5.006;
use strict;
use warnings;

=head1 NAME

Proc::ProcessTable::Match::Swapped - Check if the process is swapped out.

=head1 VERSION

Version 0.0.0

=cut

our $VERSION = '0.0.0';


=head1 SYNOPSIS

    use Proc::ProcessTable::Match::Swapped;
    
    my $checker=Proc::ProcessTable::Match::Swapped->new(;
    
    if ( $checker->match( $proc ) ){
        print "It matches.\n";
    }

=head1 METHODS

=head2 new

This intiates the object.

    my $checker=Proc::ProcessTable::Match::Swapped->new;

=cut

sub new{
    my $self = {
				};
    bless $self;

	return $self;
}

=head2 match

Checks if a single Proc::ProcessTable::Process object matches.

One argument is taken and that is a Proc::ProcessTable::Process object.

The returned value is a boolean.

    if ( $checker->match( $proc ) ){
        print "The connection matches.\n";
    }

=cut

sub match{
	my $self=$_[0];
	my $object=$_[1];

	if ( !defined( $object ) ){
		return 0;
	}

	if ( ref( $object ) ne 'Proc::ProcessTable::Process' ){
		return 0;
	}

	my $proc_state;
	eval{
		$proc_state=$object->state;
	};

	# don't bother proceeding, the object won't match ever
	# as it does not have a fname
	if ( ! defined( $proc_state ) ){
		return 0;
	}

	# will have a 0 rss, but is not swapped
	if ( $proc_state =~ /^zombie$/ ){
		return 0;
	}

	my $proc_rss;
	eval{
		$proc_rss=$object->rss;
	};

	# don't bother proceeding, the object won't match ever
	# as it does not have a fname
	if ( ! defined( $proc_rss ) ){
		return 0;
	}

	# if the rss 0, it is swapped out
	if ( $proc_rss == 0 ){
		return 1;
	}

	return 0;
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Proc-ProcessTable-Match at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Proc-ProcessTable-Match>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Proc::ProcessTable::Match


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Proc-ProcessTable-Match>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Proc-ProcessTable-Match>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Proc-ProcessTable-Match>

=item * Search CPAN

L<https://metacpan.org/release/Proc-ProcessTable-Match>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2019 Zane C. Bowers-Hadley.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Proc::ProcessTable::Match
