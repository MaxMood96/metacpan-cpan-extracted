=pod

=encoding utf-8

=head1 PURPOSE

Complex checks between Type::Tiny and L<MouseX::Types>.

=head1 DEPENDENCIES

MouseX::Types 0.06; skipped otherwise.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014, 2017-2025 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;

use Test::More;
use Test::Requires { "MouseX::Types" => "0.06" };
use Test::TypeTiny;

use MouseX::Types::Moose qw(Int ArrayRef);
use Types::Standard -all => { -prefix => "My" };

my $union1 = Int | MyArrayRef;
my $union2 = MyArrayRef | Int;

isa_ok($union1, "Mouse::Meta::TypeConstraint");
isa_ok($union1, "Mouse::Meta::TypeConstraint");
isa_ok($union2, "Type::Tiny");

should_pass([], $union1);
should_pass(2, $union1);
should_fail({}, $union1);

should_pass([], $union2);
should_pass(2, $union2);
should_fail({}, $union2);

note explain($union2);

my $param1 = MyArrayRef[Int];
my $param2 = ArrayRef[MyInt];

should_pass([1,2,3], $param1);
should_pass([], $param1);
should_fail({}, $param1);
should_fail(["x"], $param1);

should_pass([1,2,3], $param2);
should_pass([], $param2);
should_fail({}, $param2);
should_fail(["x"], $param2);

my $param_union = MyArrayRef[Int | ArrayRef];

should_pass([], $param_union);
should_pass([1,2,3], $param_union);
should_pass([[],[]], $param_union);
should_pass([11,[]], $param_union);
should_pass([[],11], $param_union);
should_fail([1.111], $param_union);

done_testing;
