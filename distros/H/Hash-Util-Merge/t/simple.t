use Test2::V0;

use Hash::Util::Merge v0.3.0 qw/ mergemap /;

my %a = ( a => 10, b => 15 );
my %b = ( a => 1,  b => 5 );
my %c = ( b => 4 );

{
    my $c = mergemap { $a + $b } \%a, \%b;
    is $c, { a => 11, b => 20 }, 'mergemap';
}

{
    my $c = mergemap { $a - $b } \%a, \%b;
    is $c, { a => 9, b => 10 }, 'mergemap';
}

{
    my $c = mergemap { $a + ($b // 1) } \%a, \%c;
    is $c, { a => 11, b => 19 }, 'mergemap (undef)';
}

{
    my $c = mergemap { $a // $b } \%c, \%a;
    is $c, { a => $a{a}, b => $c{b} }, 'mergemap (undef)';
}

{
    my $c = mergemap { $a + $b } \%a;
    is $c, \%a, 'mergemap (single argument)';
}

{
    my $c = mergemap { $a + $b };
    is $c, { }, 'mergemap (no argument)';
}

{
    my $c = mergemap { $a + $b // 0 } \%a, \%b, { a => 4, b => 7 };
    is $c, { a => 15, b => 27 }, 'mergemap (three args)';
}

{
    my $c = mergemap { $a + ( $b // 0 ) } \%a, \%b, { a => 4, b => 7 }, { a => 0, %c };
    is $c, { a => 15, b => 31 }, 'mergemap (four args)';
}

{
    my @list = ( \%a, \%b );
    my $c    = mergemap { $a + $b } @list;
    is $c, { a => 11, b => 20 }, 'mergemap (list)';
}


done_testing;
