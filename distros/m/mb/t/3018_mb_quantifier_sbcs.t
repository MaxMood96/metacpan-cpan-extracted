# This file is encoded in Shift_JIS.
die "This file is not encoded in Shift_JIS.\n" if '��' ne "\x82\xA0";
die "This script is for perl only. You are using $^X.\n" if $^X =~ /jperl/i;

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use mb;
mb::set_script_encoding('sjis');
use vars qw(@test);

BEGIN {
    $SIG{__WARN__} = sub {
        local($_) = @_;
        /\A\(\)\+ matches null string many times before HERE mark in / ? return :
        /\A\(\)\* matches null string many times before HERE mark in / ? return :
        /\A\(\)\+ matches null string many times in regex; marked by / ? return :
        /\A\(\)\* matches null string many times in regex; marked by / ? return :
        warn $_[0];
    };
}

@test = (

# 1
    sub { mb::parse(<<'END1'); },
'AB' =~ /(AB)/; 'ABBBABAB' =~ /($1?)/; $& eq 'AB'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /(AB)/; 'ABBBABAB' =~ /($1+)/; $& eq 'ABBB'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /(AB)/; 'ABBBABAB' =~ /($1*)/; $& eq 'ABBB'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /(AB)/; 'ABABAB' =~ /(($1)?)/; $& eq 'AB'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /(AB)/; 'ABABAB' =~ /(($1)+)/; $& eq 'ABABAB'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /(AB)/; 'ABABAB' =~ /(($1)*)/; $& eq 'ABABAB'
END1
    sub {1},
    sub {1},
    sub {1},
    sub {1},

# 11
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A$1?)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A$1+)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A$1*)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A($1)?)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A($1)+)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AB' =~ /AB(C?)/; 'AAA' =~ /(A($1)*)/; $& eq 'A'
END1
    sub {1},
    sub {1},
    sub {1},
    sub {1},

# 21
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)\2?)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)\2+)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)\2*)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)(\2)?)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)(\2)+)/; $& eq 'AAA'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(A?)(\2)*)/; $& eq 'AAA'
END1
    sub {1},
    sub {1},
    sub {1},
    sub {1},

# 31
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)\2?)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)\2+)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)\2*)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)(\2)?)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)(\2)+)/; $& eq 'A'
END1
    sub { mb::eval(<<'END1'); },
'AAA' =~ /(A(B?)(\2)*)/; $& eq 'A'
END1
    sub {1},
    sub {1},
    sub {1},
    sub {1},
);

$|=1; print "1..",scalar(@test),"\n"; my $testno=1; sub ok { print $_[0]?'ok ':'not ok ',$testno++,$_[1]?" - $_[1]\n":"\n" } ok($_->()) for @test;

__END__
