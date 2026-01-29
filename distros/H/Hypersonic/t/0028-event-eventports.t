use strict;
use warnings;
use Test::More;


# Load and check availability before planning any tests
require Hypersonic::Event::EventPorts;

# Skip all tests if event ports are not available
unless (Hypersonic::Event::EventPorts->available) {
    plan skip_all => 'Event Ports not available on this platform (Solaris/illumos only)';
}

# Test Hypersonic::Event::EventPorts backend
use_ok('Hypersonic::Event::EventPorts');

# Test basic properties
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::EventPorts->name, 'event_ports', 'name() returns event_ports');
    ok(Hypersonic::Event::EventPorts->available, 'available() returns true');
};

# Test platform availability
subtest 'Platform availability' => sub {
    if ($^O eq 'solaris') {
        ok(Hypersonic::Event::EventPorts->available, 'Available on Solaris');
    } else {
        ok(!Hypersonic::Event::EventPorts->available, "Not available on $^O");
    }
};

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::EventPorts->includes;
    ok($includes, 'includes() returns value');
    like($includes, qr/port\.h/, 'Includes port.h');
    like($includes, qr/poll\.h/, 'Includes poll.h (for POLLIN)');
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::EventPorts->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_EVENT_PORTS/, 'Defines EV_BACKEND_EVENT_PORTS');
    like($defines, qr/MAX_EVENTS/, 'Defines MAX_EVENTS');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::EventPorts->event_struct, 'port_event_t',
       'event_struct is port_event_t');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::EventPorts->extra_cflags;
    my $ldflags = Hypersonic::Event::EventPorts->extra_ldflags;

    # Event ports are in libc on Solaris, no extra flags
    is($cflags, '', 'No extra cflags needed');
    is($ldflags, '', 'No extra ldflags needed (event ports are in libc)');
};

# Test code generation methods with mock builder
subtest 'Code generation methods' => sub {
    my @code;
    my $mock_builder = bless {}, 'MockBuilder';

    {
        no strict 'refs';
        for my $method (qw(line comment blank if endif else elsif while endwhile)) {
            *{"MockBuilder::$method"} = sub {
                my ($self, $code) = @_;
                push @code, $code if defined $code;
                return $self;
            };
        }
    }

    # Test gen_create
    @code = ();
    Hypersonic::Event::EventPorts->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/port_create/, @code), 'gen_create includes port_create()');
    ok(grep(/port_associate/, @code), 'gen_create includes port_associate()');
    ok(grep(/PORT_SOURCE_FD/, @code), 'gen_create uses PORT_SOURCE_FD');

    # Test gen_add
    @code = ();
    Hypersonic::Event::EventPorts->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/port_associate/, @code), 'gen_add includes port_associate()');
    ok(grep(/POLLIN/, @code), 'gen_add registers for POLLIN');

    # Test gen_del
    @code = ();
    Hypersonic::Event::EventPorts->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    ok(grep(/port_dissociate/, @code), 'gen_del includes port_dissociate()');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::EventPorts->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/port_getn/, @code), 'gen_wait includes port_getn()');
    ok(grep(/timespec/, @code), 'gen_wait uses timespec');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::EventPorts->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/portev_object/, @code), 'gen_get_fd extracts portev_object');
    ok(grep(/port_associate/, @code), 'gen_get_fd re-associates (one-shot semantics)');
};

# Test one-shot semantics documentation
subtest 'One-shot semantics' => sub {
    # Event ports are one-shot - verify gen_get_fd re-associates
    my @code;
    my $mock_builder = bless {}, 'MockBuilder2';

    {
        no strict 'refs';
        for my $method (qw(line comment blank if endif else elsif while endwhile)) {
            *{"MockBuilder2::$method"} = sub {
                my ($self, $code) = @_;
                push @code, $code if defined $code;
                return $self;
            };
        }
    }

    Hypersonic::Event::EventPorts->gen_get_fd($mock_builder, 'events', 'i', 'fd');

    # Must re-associate after receiving event
    my $reassoc_count = grep(/port_associate/, @code);
    ok($reassoc_count >= 1, 'gen_get_fd re-associates fd (one-shot requires this)');
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::EventPorts->isa('Hypersonic::Event::Role'),
       'EventPorts inherits from Role');
};

done_testing();
