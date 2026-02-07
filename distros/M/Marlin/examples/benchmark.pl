use v5.20.0;
use strict;
use warnings;
no warnings 'once';

use Benchmark 'cmpthese';
use FindBin '$Bin';

use constant ITERATIONS => $ENV{PERL_MARLIN_BENCH_ITERATIONS} // -1;
use constant NONOO      => $ENV{PERL_MARLIN_BENCH_NONOO}      //  0;

use lib "$Bin/lib";
use lib "$Bin/../lib";
use lib '/home/tai/src/p5/p5-lexical-accessor/lib';

eval 'require Local::Example::Core;   1' or warn $@;
eval 'require Local::Example::Plain;  1' or warn $@;
eval 'require Local::Example::Marlin; 1' or warn $@;
eval 'require Local::Example::Moo;    1' or warn $@;
eval 'require Local::Example::Moose;  1' or warn $@;
eval 'require Local::Example::Mouse;  1' or warn $@;
eval 'require Local::Example::Tiny;   1' or warn $@;

my (
	%simple_constructors,
	%simple_accessors,
	%simple_combined,
	%constructors,
	%accessors,
	%delegations,
	%combined,
);

for my $i ( @Local::Example::ALL ) {
	
	( my $implementation_name = $i ) =~ s/^Local::Example:://;

	my $person_class  = $i . "::Person";
	my $dev_class     = $i . "::Employee::Developer";
	my $simple_class  = $i . "::Simple";

	$simple_constructors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $o = $simple_class->new( foo => 1, bar => 2 );
		}
	};
	
	$constructors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $o1 = $person_class->new( name => 'Alice', age => $n );
			my $o2 = $dev_class->new( name => 'Carol', employee_id => $n );
		}
	};

	my $dev_object = $dev_class->new( name => 'Bob', employee_id => 1 );
	my $simple_object = $simple_class->new( foo => 1, bar => 2 );
	
	$simple_accessors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			die $implementation_name unless $simple_object->foo == 1;
			die $implementation_name unless $simple_object->bar == 2;
		}
	};
	
	$accessors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $name = $dev_object->name;
			my $id   = $dev_object->employee_id;
			my $lang = $dev_object->get_languages;
		}
	};
	
	$delegations{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			$dev_object->add_language( $_ )
				for qw/ Perl C C++ Ruby Python Haskell SQL Go Rust Java /;
			my @all = $dev_object->all_languages;
			@all == 10 or die $implementation_name;
			$dev_object->clear_languages;
		}
	};
	
	$simple_combined{$implementation_name} = sub {
		for my $n ( 1 .. 25 ) {
			my $o = $simple_class->new( foo => 1, bar => 2 );
			for my $n ( 1 .. 10 ) {
				die $implementation_name unless $o->foo == 1;
				die $implementation_name unless $o->bar == 2;
			}
		}
	};
	
	$combined{$implementation_name} = sub {
		for my $n ( 1 .. 25 ) {
			my $person = $person_class->new( name => 'Alice', age => $n );
			my $dev    = $dev_class->new( name => 'Carol', employee_id => $n, age => 42 );
			for my $n ( 1 .. 4 ) {
				$dev->age == 42 or die $implementation_name;
				$dev->name eq 'Carol' or die $implementation_name;
				$dev->add_language( $_ )
					for qw/ Perl C C++ Ruby Python Haskell SQL Go Rust Java /;
				my @all = $dev->all_languages;
				@all == 10 or die $implementation_name;
				$dev->clear_languages;
			}
		}
	};
}

if ( NONOO ) {
	my $implementation_name = 'NonOO';

	$simple_constructors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $href = { foo => 1, bar => 2 };
		}
	};
	
	$constructors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $href1 = { name => 'Alice', age => $n };
			my $href2 = { name => 'Carol', employee_id => $n };
		}
	};

	my $dev_href = { name => 'Bob', employee_id => 1 };
	my $simple_href = { foo => 1, bar => 2 };
	
	$simple_accessors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			die $implementation_name unless $simple_href->{foo} == 1;
			die $implementation_name unless $simple_href->{bar} == 2;
		}
	};
	
	$accessors{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			my $name = $dev_href->{name};
			my $id   = $dev_href->{employee_id};
			my $lang = $dev_href->{languages};
		}
	};
	
	$delegations{$implementation_name} = sub {
		for my $n ( 1 .. 100 ) {
			push @{ $dev_href->{languages} //= [] }, $_
				for qw/ Perl C C++ Ruby Python Haskell SQL Go Rust Java /;
			my @all = @{ $dev_href->{languages} };
			@all == 10 or die $implementation_name;
			delete $dev_href->{languages};
		}
	};
	
	$simple_combined{$implementation_name} = sub {
		for my $n ( 1 .. 25 ) {
			my $href = { foo => 1, bar => 2 };
			for my $n ( 1 .. 10 ) {
				die $implementation_name unless $href->{foo} == 1;
				die $implementation_name unless $href->{bar} == 2;
			}
		}
	};
	
	$combined{$implementation_name} = sub {
		for my $n ( 1 .. 25 ) {
			my $person_hr = { name => 'Alice', age => $n };
			my $dev_hr    = { name => 'Carol', employee_id => $n, age => 42 };
			for my $n ( 1 .. 4 ) {
				$dev_hr->{age} == 42 or die $implementation_name;
				$dev_hr->{name} eq 'Carol' or die $implementation_name;
				push @{ $dev_hr->{languages} //= [] }, $_
					for qw/ Perl C C++ Ruby Python Haskell SQL Go Rust Java /;
				my @all = @{ $dev_hr->{languages} };
				@all == 10 or die $implementation_name;
				delete $dev_hr->{languages};
			}
		}
	};
}

#say "[[ SIMPLE CONSTRUCTORS ]]";
#cmpthese( ITERATIONS, \%simple_constructors );
#say "";

#say "[[ SIMPLE ACCESSORS ]]";
#cmpthese( ITERATIONS, \%simple_accessors );
#say "";

#say "[[ SIMPLE COMBINED ]]";
#cmpthese( ITERATIONS, \%simple_combined );
#say "";

say "[[ COMPLEX CONSTRUCTORS ]]";
cmpthese( ITERATIONS, \%constructors );
say "";

say "[[ COMPLEX ACCESSORS ]]";
cmpthese( ITERATIONS, \%accessors );
say "";

say "[[ COMPLEX DELEGATIONS ]]";
cmpthese( ITERATIONS, \%delegations );
say "";

say "[[ COMPLEX COMBINED ]]";
cmpthese( ITERATIONS, \%combined );
say "";

__END__
[[ SIMPLE CONSTRUCTORS ]]
          Rate   Tiny    Moo  Moose  Plain  Mouse Marlin
Tiny    2567/s     --   -37%   -43%   -68%   -75%   -79%
Moo     4094/s    59%     --    -9%   -50%   -60%   -67%
Moose   4479/s    74%     9%     --   -45%   -56%   -64%
Plain   8145/s   217%    99%    82%     --   -20%   -34%
Mouse  10192/s   297%   149%   128%    25%     --   -17%
Marlin 12281/s   378%   200%   174%    51%    20%     --

[[ SIMPLE ACCESSORS ]]
          Rate  Moose   Tiny  Plain    Moo  Mouse Marlin
Moose  25048/s     --    -6%   -24%   -44%   -50%   -54%
Tiny   26613/s     6%     --   -19%   -41%   -47%   -51%
Plain  32844/s    31%    23%     --   -27%   -34%   -39%
Moo    44776/s    79%    68%    36%     --   -10%   -17%
Mouse  49778/s    99%    87%    52%    11%     --    -8%
Marlin 54234/s   117%   104%    65%    21%     9%     --

[[ SIMPLE COMBINED ]]
          Rate   Tiny  Moose  Plain  Mouse    Moo Marlin
Tiny    3796/s     --   -40%   -52%   -66%   -67%   -74%
Moose   6343/s    67%     --   -20%   -43%   -44%   -57%
Plain   7905/s   108%    25%     --   -29%   -31%   -46%
Mouse  11108/s   193%    75%    41%     --    -3%   -24%
Moo    11395/s   200%    80%    44%     3%     --   -22%
Marlin 14602/s   285%   130%    85%    31%    28%     --

[[ COMPLEX CONSTRUCTORS ]]
         Rate  Plain   Tiny    Moo  Moose Marlin  Mouse
Plain   867/s     --    -3%   -30%   -44%   -73%   -78%
Tiny    895/s     3%     --   -28%   -42%   -73%   -78%
Moo    1245/s    44%    39%     --   -20%   -62%   -69%
Moose  1550/s    79%    73%    24%     --   -52%   -61%
Marlin 3258/s   276%   264%   162%   110%     --   -19%
Mouse  4021/s   364%   349%   223%   160%    23%     --

[[ COMPLEX ACCESSORS ]]
          Rate   Tiny  Plain  Moose    Moo Marlin  Mouse
Tiny   12822/s     --    -6%   -16%   -42%   -51%   -59%
Plain  13608/s     6%     --   -11%   -39%   -48%   -56%
Moose  15335/s    20%    13%     --   -31%   -42%   -51%
Moo    22191/s    73%    63%    45%     --   -15%   -28%
Marlin 26256/s   105%    93%    71%    18%     --   -15%
Mouse  31030/s   142%   128%   102%    40%    18%     --

[[ COMPLEX DELEGATIONS ]]
         Rate   Tiny  Mouse Marlin    Moo  Plain  Moose
Tiny    549/s     --   -11%   -42%   -50%   -53%   -57%
Mouse   617/s    12%     --   -35%   -44%   -47%   -51%
Marlin  946/s    72%    53%     --   -14%   -18%   -25%
Moo    1100/s   101%    78%    16%     --    -5%   -13%
Plain  1159/s   111%    88%    23%     5%     --    -8%
Moose  1266/s   131%   105%    34%    15%     9%     --

[[ COMPLEX COMBINED ]]
        Rate   Tiny  Mouse  Moose  Plain    Moo Marlin
Tiny   430/s     --   -37%   -45%   -50%   -50%   -54%
Mouse  686/s    60%     --   -13%   -20%   -20%   -27%
Moose  789/s    83%    15%     --    -8%    -8%   -16%
Plain  856/s    99%    25%     9%     --    -0%    -9%
Moo    858/s   100%    25%     9%     0%     --    -9%
Marlin 939/s   118%    37%    19%    10%     9%     --
