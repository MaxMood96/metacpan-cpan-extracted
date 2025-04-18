=license

	Dot - The beginning of a Perl universe
	Copyright © 2018 Yang Bo

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.

=cut
# We need ok at compile time for the scalar context of the first argument.
use Dot 'sane', iautoload => [qw'Scalar::Util Carp', [qw'Test::More 0ok']];
# Class of individual attribute.
sub mod0 {
	my ($o, $c) = @_;
	Dot::mod($o);
	my $v;
	$o->{add}(#
		  store => sub {
			  my $a = shift;
			  if ($c->{ro} and not $c->{init}) {
				  confess('Attempt to write readonly attribute.');
			  } else {
				  confess('Wrong type.') if $c->{type} and not $c->{type}($a);
				  $v = $a;
			  }
		  },
		  fetch => sub {
			  $v;
		  });
	$o;
}
sub TIESCALAR {
	bless mod0({}, pop), shift;
}
for my $n (qw/store fetch/) {
	no strict 'refs';
	*{uc $n} = sub {
		goto &{shift->{$n}};
	};
}
# Class for the ability to add attribute.
sub mod1 {
	Dot::mod(my $o = shift);
	$o->{weaken}($o);
	$o->{add}(#
		  attr => sub {
			  my $attr = shift;
			  # It's nasty here that we can't use each.
			  for my $k (keys %$attr) {
				  my ($v, $t, $f) = $attr->{$k};
				  if (exists $o->{$k})		{ $t = delete $o->{$k} }
				  elsif (exists $v->{default})	{ $t = $v->{default} }
				  elsif ($v->{defcref})		{ $t = $v->{defcref}() }
				  elsif ($v->{required})	{ confess("Attribute $k is required.") }
				  else				{ $f = 1 }
				  tie $o->{$k}, 'main', $v;
				  unless ($f) {
					  local $v->{init} = 1;
					  $o->{$k} = $t;
				  }
			  }
		  });
	$o;
}
sub class {
	state $attr = {foo => {ro => 1,
			       required => 1,
			       type => \&looks_like_number},
		       bar => {rw => 1,
			       default => 'baz',
			       type => sub { shift =~ /\w+/ }},
		       baz => {rw => 1,
			       defcref => \&CORE::rand,
			       type => sub { my $v = shift;
					     $v >= 0 and $v < 1 }},
		       qux => {rw => 1,
			       type => \&isvstring}};
	mod1(my $o = shift);
	$o->{attr}($attr);
	$o;
}
my $o;
eval { class($o = {}) };
ok($@ =~ /^Attribute foo is required./,
   'Will croak if an attribute is required but there is no way to provide it.');

eval { class($o = {foo => 'bar'}) };
ok($@ =~ /^Wrong type./, 'Type check during initialization.');

class($o = {foo => 2});
is($o->{bar}, 'baz', 'Default static value.');
ok($o->{baz}, 'Default value by subroutine.');
is($o->{qux}, undef,
   'An attribute should be undefined if we did not provide it a value or default.');

eval { $o->{foo} = 3 };
ok($@ =~ /^Attempt to write readonly attribute./,
   'Cannot write readonly attribute.');

ok(not(eval { $o->{bar} = '-' } ||
       eval { $o->{baz} = 1 } ||
       eval { $o->{qux} = 1.1 }),
   'Type check after initialization.');

$o->{bar} = 'qux', $o->{baz} = 0.414, $o->{qux} = 1.1.1;
pass('Type check after initialization.');

done_testing();
