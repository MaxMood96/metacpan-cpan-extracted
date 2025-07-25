use v5.14.0;

package JMAP::Tester::Result::Failure 0.104;
# ABSTRACT: what you get when your JMAP request utterly fails

use Moo;
with 'JMAP::Tester::Role::HTTPResult';

use namespace::clean;

#pod =head1 OVERVIEW
#pod
#pod This is the sort of worthless object you get back when your JMAP request fails.
#pod This class should be replaced, in most cases, by more useful classes in the
#pod future.
#pod
#pod It's got an C<is_success> method.  It returns false. It also has:
#pod
#pod =method ident
#pod
#pod An error identifier. May or may not be defined.
#pod
#pod =cut

sub is_success { 0 }

has ident => (is => 'ro', predicate => 'has_ident');

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

JMAP::Tester::Result::Failure - what you get when your JMAP request utterly fails

=head1 VERSION

version 0.104

=head1 OVERVIEW

This is the sort of worthless object you get back when your JMAP request fails.
This class should be replaced, in most cases, by more useful classes in the
future.

It's got an C<is_success> method.  It returns false. It also has:

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should
work on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to
lower the minimum required perl.

=head1 METHODS

=head2 ident

An error identifier. May or may not be defined.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Fastmail Pty. Ltd.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
