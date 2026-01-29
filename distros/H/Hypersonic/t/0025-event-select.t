use strict;
use warnings;
use Test::More;


# Test Hypersonic::Event::Select backend
use_ok('Hypersonic::Event::Select');

# Select should always be available (universal)
ok(Hypersonic::Event::Select->available, 'select is universally available');

# Test basic properties
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::Select->name, 'select', 'name() returns select');
    ok(Hypersonic::Event::Select->available, 'available() returns true');
};

# Test platform availability
subtest 'Platform availability' => sub {
    # select() is available everywhere including Windows
    ok(Hypersonic::Event::Select->available, "Available on $^O");

    # Even on Windows
    if ($^O eq 'MSWin32') {
        ok(Hypersonic::Event::Select->available, 'Available on Windows');
    }
};

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::Select->includes;
    ok($includes, 'includes() returns value');

    if ($^O eq 'MSWin32') {
        like($includes, qr/winsock2\.h/, 'Windows includes winsock2.h');
    } else {
        like($includes, qr/sys\/select\.h/, 'Unix includes sys/select.h');
    }
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::Select->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_SELECT/, 'Defines EV_BACKEND_SELECT');
    like($defines, qr/FD_SETSIZE/, 'References FD_SETSIZE');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::Select->event_struct, 'fd_set', 'event_struct is fd_set');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::Select->extra_cflags;
    my $ldflags = Hypersonic::Event::Select->extra_ldflags;

    is($cflags, '', 'No extra cflags needed');

    if ($^O eq 'MSWin32') {
        like($ldflags, qr/ws2_32/, 'Windows needs ws2_32 library');
    } else {
        is($ldflags, '', 'Unix needs no extra ldflags');
    }
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
    Hypersonic::Event::Select->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/FD_ZERO/, @code), 'gen_create includes FD_ZERO');
    ok(grep(/FD_SET/, @code), 'gen_create includes FD_SET');
    ok(grep(/max_fd/, @code), 'gen_create tracks max_fd');

    # Test gen_add
    @code = ();
    Hypersonic::Event::Select->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/FD_SET/, @code), 'gen_add includes FD_SET');

    # Test gen_del
    @code = ();
    Hypersonic::Event::Select->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    ok(grep(/FD_CLR/, @code), 'gen_del includes FD_CLR');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::Select->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/select\s*\(/, @code), 'gen_wait includes select() call');
    ok(grep(/timeval/, @code), 'gen_wait uses timeval for timeout');
    # select modifies fd_set, so we need to copy it
    ok(grep(/master|read_fds/, @code), 'gen_wait copies fd_set (select modifies it)');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::Select->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/FD_ISSET/, @code), 'gen_get_fd uses FD_ISSET');
};

# Test FD_SETSIZE limitation awareness
subtest 'FD_SETSIZE limitation' => sub {
    my $defines = Hypersonic::Event::Select->defines;

    # Should define or reference FD_SETSIZE
    like($defines, qr/FD_SETSIZE/, 'Defines mention FD_SETSIZE');

    # Default is typically 1024 on Unix, 64 on Windows
    pass('select() is limited by FD_SETSIZE (typically 1024 on Unix, 64 on Windows)');
};

# Test Windows-specific code
subtest 'Windows support' => sub {
    if ($^O eq 'MSWin32') {
        # Check for WSAStartup/WSACleanup
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

        Hypersonic::Event::Select->gen_create($mock_builder, 'listen_fd');
        ok(grep(/WSAStartup/, @code), 'Windows version calls WSAStartup');

        if (Hypersonic::Event::Select->can('gen_cleanup')) {
            @code = ();
            Hypersonic::Event::Select->gen_cleanup($mock_builder);
            ok(grep(/WSACleanup/, @code), 'Windows cleanup calls WSACleanup');
        }
    } else {
        pass('Windows-specific tests skipped on Unix');
    }
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::Select->isa('Hypersonic::Event::Role'),
       'Select inherits from Role');
};

done_testing();
