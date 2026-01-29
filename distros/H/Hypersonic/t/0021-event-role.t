use strict;
use warnings;
use Test::More;


# Test Hypersonic::Event::Role base class
use_ok('Hypersonic::Event::Role');

# Test that Role defines the interface
subtest 'Interface methods defined' => sub {
    my @required_methods = qw(
        name
        available
        includes
        defines
        event_struct
        extra_cflags
        extra_ldflags
        gen_create
        gen_add
        gen_del
        gen_wait
        gen_get_fd
    );

    for my $method (@required_methods) {
        can_ok('Hypersonic::Event::Role', $method);
    }
};

# Test default implementations
subtest 'Default implementations' => sub {
    # extra_cflags and extra_ldflags should have defaults
    is(Hypersonic::Event::Role->extra_cflags, '', 'extra_cflags defaults to empty');
    is(Hypersonic::Event::Role->extra_ldflags, '', 'extra_ldflags defaults to empty');
};

# Test that abstract methods die appropriately
subtest 'Abstract methods' => sub {
    # These should die or return undef when called on Role directly
    # (they're meant to be overridden)

    my $result = eval { Hypersonic::Event::Role->name };
    ok(!defined($result) || $@, 'name() is abstract or returns undef');

    $result = eval { Hypersonic::Event::Role->available };
    # available() might return false by default
    ok(defined($result) || $@, 'available() returns a value or dies');
};

# Test that all backend modules inherit from Role
subtest 'Backend inheritance' => sub {
    my @backends = qw(
        Hypersonic::Event::Kqueue
        Hypersonic::Event::Epoll
        Hypersonic::Event::Poll
        Hypersonic::Event::Select
        Hypersonic::Event::IOUring
    );

    for my $backend (@backends) {
        eval "require $backend";
        if ($@) {
            note("$backend not loadable: $@");
            next;
        }

        ok($backend->isa('Hypersonic::Event::Role'),
           "$backend inherits from Role");
    }
};

done_testing();
