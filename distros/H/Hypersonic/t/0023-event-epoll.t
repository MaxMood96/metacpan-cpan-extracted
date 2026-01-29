use strict;
use warnings;
use Test::More;


# Load and check availability before planning any tests
require Hypersonic::Event::Epoll;

# Skip all tests if epoll is not available
unless (Hypersonic::Event::Epoll->available) {
    plan skip_all => 'epoll not available on this platform';
}

# Test Hypersonic::Event::Epoll backend
use_ok('Hypersonic::Event::Epoll');

# Test basic properties
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::Epoll->name, 'epoll', 'name() returns epoll');
    ok(Hypersonic::Event::Epoll->available, 'available() returns true');
};

# Test platform availability
subtest 'Platform availability' => sub {
    if ($^O eq 'linux') {
        ok(Hypersonic::Event::Epoll->available, 'Available on Linux');
    } else {
        ok(!Hypersonic::Event::Epoll->available, "Not available on $^O");
    }
};

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::Epoll->includes;
    ok($includes, 'includes() returns value');
    like($includes, qr/sys\/epoll\.h/, 'Includes sys/epoll.h');
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::Epoll->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_EPOLL/, 'Defines EV_BACKEND_EPOLL');
    like($defines, qr/MAX_EVENTS/, 'Defines MAX_EVENTS');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::Epoll->event_struct, 'epoll_event', 'event_struct is epoll_event');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::Epoll->extra_cflags;
    my $ldflags = Hypersonic::Event::Epoll->extra_ldflags;

    # epoll is built into glibc, no extra flags needed
    is($cflags, '', 'No extra cflags needed');
    is($ldflags, '', 'No extra ldflags needed');
};

# Test code generation methods with mock builder
subtest 'Code generation methods' => sub {
    # Create a simple mock builder
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
    Hypersonic::Event::Epoll->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/epoll_create/, @code), 'gen_create includes epoll_create');
    ok(grep(/epoll_ctl/, @code), 'gen_create includes epoll_ctl');
    ok(grep(/EPOLL_CTL_ADD/, @code), 'gen_create includes EPOLL_CTL_ADD');

    # Test gen_add
    @code = ();
    Hypersonic::Event::Epoll->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/epoll_ctl/, @code), 'gen_add includes epoll_ctl');
    ok(grep(/EPOLL_CTL_ADD/, @code), 'gen_add includes EPOLL_CTL_ADD');
    ok(grep(/EPOLLIN/, @code), 'gen_add includes EPOLLIN');

    # Test gen_del
    @code = ();
    Hypersonic::Event::Epoll->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    ok(grep(/epoll_ctl/, @code), 'gen_del includes epoll_ctl');
    ok(grep(/EPOLL_CTL_DEL/, @code), 'gen_del includes EPOLL_CTL_DEL');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::Epoll->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/epoll_wait/, @code), 'gen_wait includes epoll_wait');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::Epoll->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/data\.fd/, @code), 'gen_get_fd extracts data.fd');
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::Epoll->isa('Hypersonic::Event::Role'),
       'Epoll inherits from Role');
};

done_testing();
