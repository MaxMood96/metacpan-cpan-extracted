use strict;
use warnings;
use Test::More;


# Test Hypersonic::Event::IOUring backend
use_ok('Hypersonic::Event::IOUring');

# Test basic properties (even if not available)
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::IOUring->name, 'io_uring', 'name() returns io_uring');
};

# Test platform availability
subtest 'Platform availability' => sub {
    if ($^O ne 'linux') {
        ok(!Hypersonic::Event::IOUring->available, "Not available on $^O (Linux only)");
        note('io_uring is Linux-specific, skipping detailed tests');
    } else {
        # On Linux, check kernel version and liburing
        my $available = Hypersonic::Event::IOUring->available;
        if ($available) {
            pass('io_uring available on this Linux system');
        } else {
            note('io_uring not available (requires Linux 5.1+ and liburing)');
            pass('io_uring correctly reports unavailable');
        }
    }
};

# Skip remaining tests if not available
if (!Hypersonic::Event::IOUring->available) {
    done_testing();
    exit;
}

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::IOUring->includes;
    ok($includes, 'includes() returns value');
    like($includes, qr/liburing\.h/, 'Includes liburing.h');
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::IOUring->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_IO_URING/, 'Defines EV_BACKEND_IO_URING');
    like($defines, qr/URING_ENTRIES/, 'Defines URING_ENTRIES');

    # io_uring uses user data encoding
    like($defines, qr/UD_ACCEPT/, 'Defines UD_ACCEPT for user data encoding');
    like($defines, qr/UD_READ/, 'Defines UD_READ for user data encoding');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::IOUring->event_struct, 'io_uring_cqe',
       'event_struct is io_uring_cqe');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::IOUring->extra_cflags;
    my $ldflags = Hypersonic::Event::IOUring->extra_ldflags;

    is($cflags, '', 'No extra cflags needed');
    like($ldflags, qr/-luring/, 'Requires -luring linker flag');
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
    Hypersonic::Event::IOUring->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/io_uring_queue_init/, @code), 'gen_create includes io_uring_queue_init');
    ok(grep(/io_uring_get_sqe/, @code), 'gen_create includes io_uring_get_sqe');
    ok(grep(/io_uring_prep_accept/, @code), 'gen_create prepares initial accept');

    # Test gen_add
    @code = ();
    Hypersonic::Event::IOUring->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/io_uring_get_sqe/, @code), 'gen_add gets sqe');
    ok(grep(/io_uring_prep_recv/, @code), 'gen_add prepares recv');
    ok(grep(/io_uring_submit/, @code), 'gen_add submits');

    # Test gen_del
    @code = ();
    Hypersonic::Event::IOUring->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    # io_uring closes fd, pending ops complete with error
    ok(grep(/close/, @code), 'gen_del closes fd');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::IOUring->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/io_uring_wait_cqe/, @code), 'gen_wait waits for cqe');
    ok(grep(/kernel_timespec|__kernel_timespec/, @code), 'gen_wait uses kernel timespec');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::IOUring->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/io_uring_cqe_get_data/, @code), 'gen_get_fd extracts user data');
    ok(grep(/io_uring_cqe_seen/, @code), 'gen_get_fd marks cqe as seen');
};

# Test io_uring specific features
subtest 'io_uring specific features' => sub {
    my $defines = Hypersonic::Event::IOUring->defines;

    # User data encoding for operation types
    like($defines, qr/UD_ACCEPT.*0x[0-9a-fA-F]+/, 'UD_ACCEPT has hex value');
    like($defines, qr/UD_READ.*0x[0-9a-fA-F]+/, 'UD_READ has hex value');
    like($defines, qr/UD_WRITE.*0x[0-9a-fA-F]+/, 'UD_WRITE has hex value');
    like($defines, qr/UD_FD_MASK/, 'UD_FD_MASK defined for extracting fd');
};

# Test cleanup method if present
subtest 'Cleanup' => sub {
    if (Hypersonic::Event::IOUring->can('gen_cleanup')) {
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

        Hypersonic::Event::IOUring->gen_cleanup($mock_builder);
        ok(grep(/io_uring_queue_exit/, @code), 'Cleanup calls io_uring_queue_exit');
    } else {
        pass('gen_cleanup not implemented (optional)');
    }
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::IOUring->isa('Hypersonic::Event::Role'),
       'IOUring inherits from Role');
};

done_testing();
