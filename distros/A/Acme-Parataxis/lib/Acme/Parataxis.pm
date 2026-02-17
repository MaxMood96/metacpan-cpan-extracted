package Acme::Parataxis v0.0.2 {
    use v5.40;
    use experimental qw[class try];
    use Affix;
    use Config;
    use File::Spec;
    use File::Basename qw[dirname];
    #
    our @IPC_BUFFER;
    my $lib;

    sub _bind_functions ($l) {
        affix $l, 'init_system',                       [],                             Int;
        affix $l, 'create_coro_ptr',                   [ Pointer [SV], Pointer [SV] ], Int;
        affix $l, 'coro_call',                         [ Int, Pointer [SV] ],          Pointer [SV];
        affix $l, 'coro_transfer',                     [ Int, Pointer [SV] ],          Pointer [SV];
        affix $l, 'coro_yield',                        [ Pointer [SV] ],               Pointer [SV];
        affix $l, 'is_finished',                       [Int],                          Int;
        affix $l, 'destroy_coro',                      [Int],                          Void;
        affix $l, 'force_depth_zero',                  [ Pointer [SV] ],               Void;
        affix $l, 'cleanup',                           [],                             Void;
        affix $l, 'get_os_thread_id_export',           [],                             Int;
        affix $l, 'get_current_parataxis_id',          [],                             Int;
        affix $l, 'submit_c_job',                      [ Int, LongLong ],              Int;
        affix $l, 'check_for_completion',              [],                             Int;
        affix $l, 'get_job_result',                    [Int],                          Pointer [SV];
        affix $l, 'get_job_coro_id',                   [Int],                          Int;
        affix $l, 'free_job_slot',                     [Int],                          Void;
        affix $l, 'get_thread_pool_size',              [],                             Int;
        affix $l, 'set_preempt_threshold',             [LongLong],                     Void;
        affix $l, [ 'maybe_yield' => '_maybe_yield' ], [],                             Pointer [SV];
        affix $l, 'get_preempt_count',                 [],                             LongLong;
        init_system();

        if ( $^O eq 'MSWin32' ) {
            my $perl_dll = $Config{libperl};
            $perl_dll =~ s/^lib//;
            $perl_dll =~ s/\.a$//;
            $perl_dll .= '.' . $Config{so};
            my $p = Affix::load_library($perl_dll);
            affix $p, 'win32_get_osfhandle', [Int], LongLong;
        }
    }

    BEGIN {
        my $lib_name = ( $^O eq 'MSWin32' ? '' : 'lib' ) . 'parataxis.' . $Config{so};
        my @paths;
        push @paths, File::Spec->catfile( dirname(__FILE__), $lib_name );
        push @paths, File::Spec->catfile( dirname(__FILE__), '..',   'arch', 'auto',      'Acme', 'Parataxis', $lib_name );
        push @paths, File::Spec->catfile( dirname(__FILE__), '..',   '..',   'arch',      'auto', 'Acme', 'Parataxis', $lib_name );
        push @paths, File::Spec->catfile( dirname(__FILE__), 'auto', 'Acme', 'Parataxis', $lib_name );
        for my $inc (@INC) {
            next if ref $inc;
            push @paths, File::Spec->catfile( $inc, 'auto', 'Acme', 'Parataxis', $lib_name );
        }
        for my $path (@paths) {
            if ( -e $path ) {
                $lib = Affix::load_library($path);
                last if $lib;
            }
        }
        die 'Could not find or load ' . $lib_name unless $lib;
        _bind_functions($lib);
    }

    class #
    Acme::Parataxis {
        use Carp         qw[croak];
        use Scalar::Util qw[weaken];
        field $code : reader : param;
        field $is_done = 0;
        field $error  : reader;
        field $result : reader;
        field $id     : reader;
        field $future : param = undef;

        method set_result ($val) {
            $result = $val;
            $future->set_result($val) if $future;
        }

        method set_error ($err) {
            $error = $err;
            $future->set_error($err) if $future;
        }

        # Registry to track active coroutines
        our %REGISTRY;
        our $SEQ = 0;
        ADJUST {
            $id = create_coro_ptr( $code, $self );
            $REGISTRY{$id} = $self;
        }

        method call (@args) {
            croak 'Cannot call a finished parataxis' if $self->is_done;
            $result = coro_call( $id, \@args );
            die $error if $self->is_done && defined $error;
            return unless $result;
            ref $result ? $result->[-1] : $result;
        }

        method transfer (@args) {
            croak 'Cannot transfer to a finished parataxis' if $self->is_done;
            $result = coro_transfer( $id, \@args );
            $self->is_done;
            return unless $result;
            ref $result ? $result->[-1] : $result;
        }

        method is_done () {
            return 1 if $is_done;
            return 0 if $id < 0;
            return 0 unless is_finished($id);
            $is_done = 1;
            my $old_id = $id;
            $id = -1;
            my $self_ref = delete $REGISTRY{$old_id};
            destroy_coro($old_id) if $old_id >= 0;
            return 1;
        }

        method await () {
            while ( !$self->is_done ) {
                Acme::Parataxis->yield('WAITING_FOR_CHILD');
            }
            return $self->result;
        }

        method DESTROY {
            return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
            if ( defined $id && $id >= 0 ) {
                delete $REGISTRY{$id};
                destroy_coro($id);
                $id = -1;
            }
        }
        sub by_id ( $class, $id ) { $REGISTRY{$id} }
    }
    class    #
        Acme::Parataxis::Root {

        method transfer (@args) {
            my $rv  = Acme::Parataxis::coro_transfer( -1, \@args );
            my @ret = @$rv;
            return wantarray ? @ret : $ret[-1];
        }
        method id () {-1}
    }
    class    #
        Acme::Parataxis::Future {
        field $is_ready = 0;
        field $result;
        field $error;
        field @callbacks;
        method is_ready () {$is_ready}

        method set_result ($val) {
            die 'Future already ready' if $is_ready;
            $result   = $val;
            $is_ready = 1;
            $_->($self) for @callbacks;
        }

        method set_error ($err) {
            die 'Future already ready' if $is_ready;
            $error    = $err;
            $is_ready = 1;
            $_->($self) for @callbacks;
        }

        method result () {
            die $error if defined $error;
            return $result;
        }

        method on_ready ($cb) {
            if   ($is_ready) { $cb->($self) }
            else             { push @callbacks, $cb }
        }

        method await () {
            return $self->result if $is_ready;
            my $fid = Acme::Parataxis->fid;
            $self->on_ready(
                sub ($f) {
                    Acme::Parataxis::_scheduler_enqueue_by_id($fid);
                }
            );
            Acme::Parataxis->yield('WAITING');
            $self->result;
        }
    }
    package    #
        Acme::Parataxis {
        use Time::HiRes qw[usleep];
        my @SCHEDULER_QUEUE;
        my $IS_RUNNING = 0;
        sub root { state $root //= Acme::Parataxis::Root->new() }

        sub yield ( $self, @args ) {
            my $result = coro_yield( \@args );
            return unless defined $result;
            return wantarray ? @$result : $result->[-1];
        }

        sub maybe_yield ($class) {
            my $result = Acme::Parataxis::_maybe_yield();
            return unless defined $result;
            return wantarray ? @$result : $result->[-1];
        }
        sub tid { get_os_thread_id_export() }
        sub fid { get_current_parataxis_id() }
        sub await_sleep   ( $class, $ms ) { submit_c_job( 0, $ms ) < 0 ? 'Queue Full' : $class->yield('WAITING') }
        sub await_core_id ($class)        { submit_c_job( 1, 0 ) < 0   ? 'Queue Full' : $class->yield('WAITING') }

        sub await_read ( $class, $fh ) {
            my $fileno = fileno($fh);
            die 'Not a valid filehandle' unless defined $fileno;
            my $handle = $^O eq 'MSWin32' ? win32_get_osfhandle($fileno) : $fileno;
            submit_c_job( 2, $handle ) < 0 ? 'Queue Full' : $class->yield('WAITING');
        }

        sub await_write ( $class, $fh ) {
            my $fileno = fileno($fh);
            die 'Not a valid filehandle' unless defined $fileno;
            my $handle = $^O eq 'MSWin32' ? win32_get_osfhandle($fileno) : $fileno;
            submit_c_job( 3, $handle ) < 0 ? 'Queue Full' : $class->yield('WAITING');
        }

        sub poll_io {
            my @ready;
            while (1) {
                my $job_idx = check_for_completion();
                last if $job_idx == -1;
                my $id  = get_job_coro_id($job_idx);
                my $res = get_job_result($job_idx);
                push @ready, [ $id, $res ];
                free_job_slot($job_idx);
            }
            return @ready;
        }

        sub spawn ( $class, $code ) {
            my $future = Acme::Parataxis::Future->new();
            my $coro   = Acme::Parataxis->new( code => $code, future => $future );
            push @SCHEDULER_QUEUE, $coro;
            return $future;
        }

        sub _scheduler_enqueue_by_id ($id) {
            if ( my $coro = Acme::Parataxis->by_id($id) ) {
                push @SCHEDULER_QUEUE, $coro;
            }
        }

        sub run ($code) {
            @SCHEDULER_QUEUE = ();
            $IS_RUNNING      = 1;
            my $main_coro = Acme::Parataxis->new( code => $code );
            push @SCHEDULER_QUEUE, $main_coro;
            while ($IS_RUNNING) {
                my @ready = poll_io();
                for my $ready (@ready) {
                    my ( $id, $res ) = @$ready;
                    my $coro = Acme::Parataxis->by_id($id);
                    if ($coro) {
                        my $yield_val = $coro->call($res);
                        if ( !$coro->is_done ) {
                            if ( defined $yield_val && $yield_val eq 'WAITING' ) {

                                # Waiting
                            }
                            else {
                                push @SCHEDULER_QUEUE, $coro;
                            }
                        }
                    }
                }
                if (@SCHEDULER_QUEUE) {
                    my $current = shift @SCHEDULER_QUEUE;
                    next if $current->is_done;
                    my $res = $current->call();
                    if ( !$current->is_done ) {
                        if ( defined $res && $res eq 'WAITING' ) {

                            # Waiting
                        }
                        else {
                            push @SCHEDULER_QUEUE, $current;
                        }
                    }
                }
                my $active_count = scalar keys %Acme::Parataxis::REGISTRY;
                if ( $main_coro->is_done && $active_count == 0 && !@SCHEDULER_QUEUE ) {
                    $IS_RUNNING = 0;
                }
                if ( $IS_RUNNING && !@SCHEDULER_QUEUE ) {
                    usleep(1000);
                }
            }
        }
        sub stop () { $IS_RUNNING = 0 }
        END { cleanup() unless ${^GLOBAL_PHASE} eq 'DESTRUCT' }
    }
};
1;
