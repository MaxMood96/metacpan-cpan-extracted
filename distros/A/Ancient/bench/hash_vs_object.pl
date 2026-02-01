#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);
use lib 'blib/lib', 'blib/arch';

use object;

# Define class in BEGIN so call checkers work
BEGIN {
    object::define('Thing', qw(key));
    object::import_accessors('Thing');
}

print "=" x 60, "\n";
print "Hash vs Object Benchmark: \$hash->{key} vs key(\$obj)\n";
print "=" x 60, "\n\n";

# Pre-create test objects
my $hash = { key => 'okay' };
my $obj  = new Thing key => 'okay';

print "Test: Getter (1_000_000 reads)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    '$hash->{key}' => sub {
        my $x = $hash->{key} for 1..1_000_000;
    },
    'key($obj)' => sub {
        my $x = key($obj) for 1..1_000_000;
    },
    '$obj->key' => sub {
        my $x = $obj->key for 1..1_000_000;
    },
});

print "\n\nTest: Setter (1_000_000 writes)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    '$hash->{key} =' => sub {
        $hash->{key} = 'value' for 1..1_000_000;
    },
    'key($obj, val)' => sub {
        key($obj, 'value') for 1..1_000_000;
    },
    '$obj->key(val)' => sub {
        $obj->key('value') for 1..1_000_000;
    },
});

print "\n\nTest: Get + Set cycle (500_000 each)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'hash' => sub {
        for (1..500_000) {
            $hash->{key} = 'new';
            my $x = $hash->{key};
        }
    },
    'object func' => sub {
        for (1..500_000) {
            key($obj, 'new');
            my $x = key($obj);
        }
    },
    'object OO' => sub {
        for (1..500_000) {
            $obj->key('new');
            my $x = $obj->key;
        }
    },
});

print "\n\nTest: Create + access + discard (100_000 objects)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'hash' => sub {
        for (1..100_000) {
            my $h = { key => 'okay' };
            $h->{key} = 'changed';
            my $x = $h->{key};
        }
    },
    'object named' => sub {
        for (1..100_000) {
            my $o = new Thing key => 'okay';
            key($o, 'changed');
            my $x = key($o);
        }
    },
    'object positional' => sub {
        for (1..100_000) {
            my $o = new Thing 'okay';  # positional - faster
            key($o, 'changed');
            my $x = key($o);
        }
    },
});

print "\n", "=" x 60, "\n";
print "Summary:\n";
print "- \$hash->{key}: Raw Perl hash access\n";
print "- key(\$obj): XS object with function-style accessor\n";
print "- \$obj->key: XS object with OO-style accessor\n";
print "=" x 60, "\n";
