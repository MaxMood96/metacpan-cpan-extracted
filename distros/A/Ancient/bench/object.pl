#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);
use lib 'blib/lib', 'blib/arch';

use object;

# Define classes in BEGIN so call checkers work
BEGIN {
    # object (XS) - no types
    object::define('Person', qw(name age score));

    # object (XS) - with types
    object::define('TypedPerson', 'name:Str', 'age:Int', 'score:Num');

    # Import function-style accessors
    object::import_accessors('Person');
}

print "=" x 60, "\n";
print "Object Benchmark: object (XS) vs Pure Perl OO\n";
print "=" x 60, "\n\n";

# Pure Perl hashref-based OO (baseline)
package PureHash {
    sub new {
        my ($class, %args) = @_;
        return bless { name => $args{name}, age => $args{age}, score => $args{score} }, $class;
    }
    sub name  { @_ > 1 ? $_[0]->{name}  = $_[1] : $_[0]->{name}  }
    sub age   { @_ > 1 ? $_[0]->{age}   = $_[1] : $_[0]->{age}   }
    sub score { @_ > 1 ? $_[0]->{score} = $_[1] : $_[0]->{score} }
}

# Pure Perl arrayref-based OO (faster than hash)
package PureArray {
    use constant { NAME => 0, AGE => 1, SCORE => 2 };
    sub new {
        my ($class, %args) = @_;
        return bless [ $args{name}, $args{age}, $args{score} ], $class;
    }
    sub name  { @_ > 1 ? $_[0]->[NAME]  = $_[1] : $_[0]->[NAME]  }
    sub age   { @_ > 1 ? $_[0]->[AGE]   = $_[1] : $_[0]->[AGE]   }
    sub score { @_ > 1 ? $_[0]->[SCORE] = $_[1] : $_[0]->[SCORE] }
}

package main;

print "Test: Object construction (10000 objects)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Raw Hash' => sub {
        my $h = { name => 'Alice', age => 30, score => 95.5 } for 1..10000;
    },
    'Pure Hash OO' => sub {
        PureHash->new(name => 'Alice', age => 30, score => 95.5) for 1..10000;
    },
    'object (XS)' => sub {
        (new Person name => 'Alice', age => 30, score => 95.5) for 1..10000;
    },
    'object typed' => sub {
        (new TypedPerson name => 'Alice', age => 30, score => 95.5) for 1..10000;
    },
});

print "\n\nTest: Getter (100000 reads)\n";
print "-" x 40, "\n";

my $pure_hash  = PureHash->new(name => 'Bob', age => 25, score => 88.0);
my $pure_array = PureArray->new(name => 'Bob', age => 25, score => 88.0);
my $obj_xs     = new Person name => 'Bob', age => 25, score => 88.0;
my $obj_typed  = new TypedPerson name => 'Bob', age => 25, score => 88.0;

cmpthese(-2, {
    'Pure Hash' => sub {
        my $x = $pure_hash->name for 1..100000;
    },
    'Pure Array' => sub {
        my $x = $pure_array->name for 1..100000;
    },
    'object (XS OO)' => sub {
        my $x = $obj_xs->name for 1..100000;
    },
    'object (XS func)' => sub {
        my $x = name($obj_xs) for 1..100000;
    },
    'object typed' => sub {
        my $x = $obj_typed->name for 1..100000;
    },
});

print "\n\nTest: Setter (100000 writes)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Pure Hash' => sub {
        $pure_hash->name('Alice') for 1..100000;
    },
    'Pure Array' => sub {
        $pure_array->name('Alice') for 1..100000;
    },
    'object (XS OO)' => sub {
        $obj_xs->name('Alice') for 1..100000;
    },
    'object (XS func)' => sub {
        name($obj_xs, 'Alice') for 1..100000;
    },
    'object typed' => sub {
        $obj_typed->name('Alice') for 1..100000;
    },
});

print "\n\nTest: Mixed get/set (50000 each)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Pure Hash' => sub {
        for (1..50000) {
            $pure_hash->age(31);
            my $x = $pure_hash->age;
        }
    },
    'Pure Array' => sub {
        for (1..50000) {
            $pure_array->age(31);
            my $x = $pure_array->age;
        }
    },
    'object (XS OO)' => sub {
        for (1..50000) {
            $obj_xs->age(31);
            my $x = $obj_xs->age;
        }
    },
    'object (XS func)' => sub {
        for (1..50000) {
            age($obj_xs, 31);
            my $x = age($obj_xs);
        }
    },
    'object typed' => sub {
        for (1..50000) {
            $obj_typed->age(31);
            my $x = $obj_typed->age;
        }
    },
});

print "\n\nTest: Create + access + destroy cycle (5000 objects)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Pure Hash' => sub {
        for (1..5000) {
            my $o = PureHash->new(name => 'Test', age => 20, score => 100);
            $o->name('Changed');
            my $n = $o->name;
            my $a = $o->age;
        }
    },
    'Pure Array' => sub {
        for (1..5000) {
            my $o = PureArray->new(name => 'Test', age => 20, score => 100);
            $o->name('Changed');
            my $n = $o->name;
            my $a = $o->age;
        }
    },
    'object (XS)' => sub {
        for (1..5000) {
            my $o = new Person name => 'Test', age => 20, score => 100;
            $o->name('Changed');
            my $n = $o->name;
            my $a = $o->age;
        }
    },
    'object typed' => sub {
        for (1..5000) {
            my $o = new TypedPerson name => 'Test', age => 20, score => 100;
            $o->name('Changed');
            my $n = $o->name;
            my $a = $o->age;
        }
    },
});

print "\n\nTest: Multiple attribute access (all 3 attrs x 10000)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Pure Hash' => sub {
        for (1..10000) {
            my $n = $pure_hash->name;
            my $a = $pure_hash->age;
            my $s = $pure_hash->score;
        }
    },
    'Pure Array' => sub {
        for (1..10000) {
            my $n = $pure_array->name;
            my $a = $pure_array->age;
            my $s = $pure_array->score;
        }
    },
    'object (XS OO)' => sub {
        for (1..10000) {
            my $n = $obj_xs->name;
            my $a = $obj_xs->age;
            my $s = $obj_xs->score;
        }
    },
    'object (XS func)' => sub {
        for (1..10000) {
            my $n = name($obj_xs);
            my $a = age($obj_xs);
            my $s = score($obj_xs);
        }
    },
    'object typed' => sub {
        for (1..10000) {
            my $n = $obj_typed->name;
            my $a = $obj_typed->age;
            my $s = $obj_typed->score;
        }
    },
});

print "\n", "=" x 60, "\n";
print "Summary:\n";
print "- Pure Hash: Standard blessed hashref (baseline)\n";
print "- Pure Array: Blessed arrayref with constants (faster baseline)\n";
print "- object (XS OO): XS with custom ops, OO style (\$obj->name)\n";
print "- object (XS func): XS with custom ops, function style (name \$obj)\n";
print "- object typed: XS with inline type checking (Str, Int, Num)\n";
print "=" x 60, "\n";
