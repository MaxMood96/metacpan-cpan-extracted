#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use object;

# Define test classes
object::define('LeakClone',
    'name:Str:required',
    'age:Int:default(0)',
    'tags:ArrayRef:default([])',
);

object::define('LeakSimple', 'foo', 'bar', 'baz');

object::define('LeakTyped',
    'str_val:Str',
    'int_val:Int:default(42)',
    'readonly_val:Str:readonly',
);

# Warmup
for (1..10) {
    my $obj = new LeakClone name => 'Warmup';
    my $clone = object::clone($obj);
    my @props = object::properties('LeakClone');
    my $info = object::slot_info('LeakClone', 'name');
}

# ==== clone() leak tests ====

subtest 'clone basic no leak' => sub {
    my $obj = new LeakClone name => 'Original', age => 30;
    no_leaks_ok {
        for (1..500) {
            my $clone = object::clone($obj);
        }
    } 'clone basic no leak';
};

subtest 'clone with array default no leak' => sub {
    my $obj = new LeakClone name => 'WithTags', age => 25;
    push @{$obj->tags}, 'tag1', 'tag2';
    no_leaks_ok {
        for (1..500) {
            my $clone = object::clone($obj);
        }
    } 'clone with array no leak';
};

subtest 'clone frozen object no leak' => sub {
    my $obj = new LeakClone name => 'Frozen', age => 40;
    object::freeze($obj);
    no_leaks_ok {
        for (1..500) {
            my $clone = object::clone($obj);
        }
    } 'clone frozen no leak';
};

subtest 'clone locked object no leak' => sub {
    my $obj = new LeakClone name => 'Locked', age => 35;
    object::lock($obj);
    no_leaks_ok {
        for (1..500) {
            my $clone = object::clone($obj);
        }
    } 'clone locked no leak';
};

subtest 'clone and modify no leak' => sub {
    my $obj = new LeakClone name => 'Source', age => 20;
    no_leaks_ok {
        for (1..500) {
            my $clone = object::clone($obj);
            $clone->name('Modified');
            $clone->age(99);
        }
    } 'clone and modify no leak';
};

# ==== properties() leak tests ====

subtest 'properties list context no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my @props = object::properties('LeakClone');
        }
    } 'properties list no leak';
};

subtest 'properties scalar context no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $count = object::properties('LeakClone');
        }
    } 'properties scalar no leak';
};

subtest 'properties simple class no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my @props = object::properties('LeakSimple');
        }
    } 'properties simple no leak';
};

subtest 'properties nonexistent class no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my @props = object::properties('NonExistent');
            my $count = object::properties('NonExistent');
        }
    } 'properties nonexistent no leak';
};

# ==== slot_info() leak tests ====

subtest 'slot_info typed property no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakClone', 'name');
        }
    } 'slot_info typed no leak';
};

subtest 'slot_info with default no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakClone', 'age');
        }
    } 'slot_info default no leak';
};

subtest 'slot_info array default no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakClone', 'tags');
        }
    } 'slot_info array no leak';
};

subtest 'slot_info untyped property no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakSimple', 'foo');
        }
    } 'slot_info untyped no leak';
};

subtest 'slot_info readonly property no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakTyped', 'readonly_val');
        }
    } 'slot_info readonly no leak';
};

subtest 'slot_info nonexistent property no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('LeakClone', 'nonexistent');
        }
    } 'slot_info nonexistent no leak';
};

subtest 'slot_info nonexistent class no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            my $info = object::slot_info('NonExistent', 'prop');
        }
    } 'slot_info missing class no leak';
};

subtest 'slot_info access all fields no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $info = object::slot_info('LeakClone', 'name');
            my $n = $info->{name};
            my $i = $info->{index};
            my $t = $info->{type};
            my $r = $info->{is_required};
            my $ro = $info->{is_readonly};
        }
    } 'slot_info field access no leak';
};

# ==== Combined operations ====

subtest 'introspection combined no leak' => sub {
    my $obj = new LeakClone name => 'Test', age => 25;
    no_leaks_ok {
        for (1..300) {
            my $clone = object::clone($obj);
            my @props = object::properties('LeakClone');
            for my $prop (@props) {
                my $info = object::slot_info('LeakClone', $prop);
            }
        }
    } 'combined introspection no leak';
};

done_testing;
