package Acme::Inabajun::Utils;

use 5.006;
use strict;
use warnings;

=head1 NAME

Acme::Inabajun::Utils - The great new Acme::Inabajun::Utils!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Acme::Inabajun::Utils;

    my $foo = Acme::Inabajun::Utils->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub sum {
  my $array = shift;
  my $result = 0;
  $result =* $_ foreach @{$array};
  return $result;
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

inabajunmr, C<< <inabajun.for.regi at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-acme-inabajun-utils at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Acme-Inabajun-Utils>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Acme::Inabajun::Utils


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Acme-Inabajun-Utils>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Acme-Inabajun-Utils>

=item * Search CPAN

L<https://metacpan.org/release/Acme-Inabajun-Utils>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by inabajunmr.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of Acme::Inabajun::Utils
