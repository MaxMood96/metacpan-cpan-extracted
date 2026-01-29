use strict;
use warnings;
use Test::More;


# Load and check availability before planning any tests
require Hypersonic::Event::Kqueue;

# Skip all tests if kqueue is not available
unless (Hypersonic::Event::Kqueue->available) {
    plan skip_all => 'kqueue not available on this platform';
}

# Test Hypersonic::Event::Kqueue backend
use_ok('Hypersonic::Event::Kqueue');

# Test basic properties
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::Kqueue->name, 'kqueue', 'name() returns kqueue');
    ok(Hypersonic::Event::Kqueue->available, 'available() returns true');
};

# Test platform availability
subtest 'Platform availability' => sub {
    if ($^O eq 'darwin') {
        ok(Hypersonic::Event::Kqueue->available, 'Available on macOS');
    } elsif ($^O =~ /^(freebsd|openbsd|netbsd)$/) {
        ok(Hypersonic::Event::Kqueue->available, "Available on $^O");
    } elsif ($^O eq 'linux') {
        ok(!Hypersonic::Event::Kqueue->available, 'Not available on Linux');
    }
};

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::Kqueue->includes;
    ok($includes, 'includes() returns value');
    like($includes, qr/sys\/event\.h/, 'Includes sys/event.h');
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::Kqueue->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_KQUEUE/, 'Defines EV_BACKEND_KQUEUE');
    like($defines, qr/MAX_EVENTS/, 'Defines MAX_EVENTS');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::Kqueue->event_struct, 'kevent', 'event_struct is kevent');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::Kqueue->extra_cflags;
    my $ldflags = Hypersonic::Event::Kqueue->extra_ldflags;

    # kqueue is built into the kernel, no extra flags needed
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
    Hypersonic::Event::Kqueue->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/kqueue/, @code), 'gen_create includes kqueue() call');
    ok(grep(/EV_SET/, @code), 'gen_create includes EV_SET');

    # Test gen_add
    @code = ();
    Hypersonic::Event::Kqueue->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/EV_SET/, @code), 'gen_add includes EV_SET');
    ok(grep(/EV_ADD/, @code), 'gen_add includes EV_ADD');

    # Test gen_del
    @code = ();
    Hypersonic::Event::Kqueue->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    ok(grep(/EV_DELETE/, @code), 'gen_del includes EV_DELETE');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::Kqueue->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/kevent/, @code), 'gen_wait includes kevent() call');
    ok(grep(/timespec/, @code), 'gen_wait includes timespec');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::Kqueue->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/ident/, @code), 'gen_get_fd extracts ident');
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::Kqueue->isa('Hypersonic::Event::Role'),
       'Kqueue inherits from Role');
};

done_testing();
