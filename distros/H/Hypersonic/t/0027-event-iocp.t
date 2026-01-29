use strict;
use warnings;
use Test::More;


# Load and check availability before planning any tests
require Hypersonic::Event::IOCP;

# Skip all tests if IOCP is not available
unless (Hypersonic::Event::IOCP->available) {
    plan skip_all => 'IOCP not available on this platform (Windows only)';
}

# Test Hypersonic::Event::IOCP backend
use_ok('Hypersonic::Event::IOCP');

# Test basic properties
subtest 'Basic properties' => sub {
    is(Hypersonic::Event::IOCP->name, 'iocp', 'name() returns iocp');
    ok(Hypersonic::Event::IOCP->available, 'available() returns true');
};

# Test platform availability
subtest 'Platform availability' => sub {
    if ($^O eq 'MSWin32') {
        ok(Hypersonic::Event::IOCP->available, 'Available on Windows');
    } else {
        ok(!Hypersonic::Event::IOCP->available, "Not available on $^O");
    }
};

# Test includes
subtest 'C includes' => sub {
    my $includes = Hypersonic::Event::IOCP->includes;
    ok($includes, 'includes() returns value');
    like($includes, qr/winsock2\.h/, 'Includes winsock2.h');
    like($includes, qr/mswsock\.h/, 'Includes mswsock.h');
};

# Test defines
subtest 'C defines' => sub {
    my $defines = Hypersonic::Event::IOCP->defines;
    ok($defines, 'defines() returns value');
    like($defines, qr/EV_BACKEND_IOCP/, 'Defines EV_BACKEND_IOCP');
    like($defines, qr/OP_ACCEPT/, 'Defines OP_ACCEPT');
    like($defines, qr/OP_READ/, 'Defines OP_READ');
    like($defines, qr/OP_WRITE/, 'Defines OP_WRITE');
    like($defines, qr/PER_IO_DATA/, 'Defines PER_IO_DATA structure');
};

# Test event_struct
subtest 'Event struct' => sub {
    is(Hypersonic::Event::IOCP->event_struct, 'OVERLAPPED_ENTRY',
       'event_struct is OVERLAPPED_ENTRY');
};

# Test extra flags
subtest 'Extra compiler flags' => sub {
    my $cflags = Hypersonic::Event::IOCP->extra_cflags;
    my $ldflags = Hypersonic::Event::IOCP->extra_ldflags;

    is($cflags, '', 'No extra cflags needed');
    like($ldflags, qr/ws2_32/, 'Requires ws2_32 library');
    like($ldflags, qr/mswsock/, 'Requires mswsock library');
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
    Hypersonic::Event::IOCP->gen_create($mock_builder, 'listen_fd');
    ok(scalar @code > 0, 'gen_create generates code');
    ok(grep(/WSAStartup/, @code), 'gen_create includes WSAStartup');
    ok(grep(/CreateIoCompletionPort/, @code), 'gen_create includes CreateIoCompletionPort');
    ok(grep(/AcceptEx/, @code), 'gen_create loads AcceptEx');

    # Test gen_add
    @code = ();
    Hypersonic::Event::IOCP->gen_add($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_add generates code');
    ok(grep(/CreateIoCompletionPort/, @code), 'gen_add associates socket with IOCP');
    ok(grep(/WSARecv/, @code), 'gen_add posts read operation');

    # Test gen_del
    @code = ();
    Hypersonic::Event::IOCP->gen_del($mock_builder, 'ev_fd', 'client_fd');
    ok(scalar @code > 0, 'gen_del generates code');
    ok(grep(/CancelIo/, @code), 'gen_del cancels pending I/O');
    ok(grep(/closesocket/, @code), 'gen_del closes socket');

    # Test gen_wait
    @code = ();
    Hypersonic::Event::IOCP->gen_wait($mock_builder, 'ev_fd', 'events', 'n', '1000');
    ok(scalar @code > 0, 'gen_wait generates code');
    ok(grep(/GetQueuedCompletionStatusEx/, @code), 'gen_wait uses GetQueuedCompletionStatusEx');

    # Test gen_get_fd
    @code = ();
    Hypersonic::Event::IOCP->gen_get_fd($mock_builder, 'events', 'i', 'fd');
    ok(scalar @code > 0, 'gen_get_fd generates code');
    ok(grep(/CONTAINING_RECORD/, @code), 'gen_get_fd extracts PER_IO_DATA');
    ok(grep(/op_type/, @code), 'gen_get_fd checks operation type');
};

# Test cleanup method
subtest 'Cleanup' => sub {
    if (Hypersonic::Event::IOCP->can('gen_cleanup')) {
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

        Hypersonic::Event::IOCP->gen_cleanup($mock_builder);
        ok(grep(/CloseHandle/, @code), 'Cleanup closes IOCP handle');
        ok(grep(/WSACleanup/, @code), 'Cleanup calls WSACleanup');
    } else {
        pass('gen_cleanup not implemented (optional)');
    }
};

# Test inheritance
subtest 'Inheritance' => sub {
    require Hypersonic::Event::Role;
    ok(Hypersonic::Event::IOCP->isa('Hypersonic::Event::Role'),
       'IOCP inherits from Role');
};

done_testing();
