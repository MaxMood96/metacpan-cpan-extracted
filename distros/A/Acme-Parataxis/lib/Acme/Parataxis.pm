use v5.40;
use experimental qw[class try];

package Acme::Parataxis v0.0.10 {
    use Affix;
    use Config;
    use File::Spec;
    use File::Basename qw[dirname];
    use Time::HiRes    qw[usleep];
    use Exporter       qw[import];
    use Carp           qw[croak];
    our %EXPORT_TAGS = (
        all => [
            our @EXPORT_OK
                = qw[
                run spawn yield await stop async fiber
                await_sleep await_read await_write await_core_id
                current_fid tid root maybe_yield
                set_max_threads max_threads
                ]
        ]
    );
    #
    our @IPC_BUFFER;
    my $lib;
    my @SCHEDULER_QUEUE;
    my $IS_RUNNING = 0;

    sub _bind_functions ($l) {
        affix $l, 'init_system',                       [],                             Int;
        affix $l, 'create_fiber',                      [ Pointer [SV], Pointer [SV] ], Int;
        affix $l, 'coro_call',                         [ Int, Pointer [SV] ],          Pointer [SV];
        affix $l, 'coro_transfer',                     [ Int, Pointer [SV] ],          Pointer [SV];
        affix $l, 'coro_yield',                        [ Pointer [SV] ],               Pointer [SV];
        affix $l, 'is_finished',                       [Int],                          Int;
        affix $l, 'destroy_coro',                      [Int],                          Void;
        affix $l, 'force_depth_zero',                  [ Pointer [SV] ],               Void;
        affix $l, 'cleanup',                           [],                             Void;
        affix $l, 'get_os_thread_id_export',           [],                             Int;
        affix $l, 'get_current_parataxis_id',          [],                             Int;
        affix $l, 'submit_c_job',                      [ Int, LongLong, Int ],         Int;
        affix $l, 'check_for_completion',              [],                             Int;
        affix $l, 'get_job_result',                    [Int],                          Pointer [SV];
        affix $l, 'get_job_coro_id',                   [Int],                          Int;
        affix $l, 'free_job_slot',                     [Int],                          Void;
        affix $l, 'get_thread_pool_size',              [],                             Int;
        affix $l, 'get_max_thread_pool_size',          [],                             Int;
        affix $l, 'set_max_threads',                   [Int],                          Void;
        affix $l, 'set_preempt_threshold',             [LongLong],                     Void;
        affix $l, [ 'maybe_yield' => '_maybe_yield' ], [],                             Pointer [SV];
        affix $l, 'get_preempt_count',                 [],                             LongLong;

        # Capture the main interpreter context eagerly
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

        # XXX - Local dir check (This is temporary)
        push @paths, File::Spec->catfile( '.', $lib_name );
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

    # API aliases and wrappers
    sub fiber : prototype(&) ($code) { spawn( 'Acme::Parataxis', $code ) }

    sub async : prototype(&) ($code) {
        my $ret = run($code);
        stop();
        return $ret;
    }

    sub await {
        my $thing = shift;
        if ( builtin::blessed($thing) ) {
            return $thing->await if $thing->can('await');
            return $thing->wait  if $thing->can('wait');
        }
        croak 'await() requires a Future or Fiber object';
    }

    sub yield {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
            $invocant = 'Acme::Parataxis';
        }
        my $result = coro_yield( \@_ );
        return unless defined $result;
        return ( ref $result eq 'ARRAY' ) ? ( wantarray ? @$result : $result->[-1] ) : $result;
    }

    sub spawn {
        my ( $class, $code ) = @_;
        if ( ref $class eq 'CODE' ) {
            $code  = $class;
            $class = 'Acme::Parataxis';
        }
        my $future = Acme::Parataxis::Future->new();
        my $fiber  = Acme::Parataxis->new( code => $code, future => $future );
        push @SCHEDULER_QUEUE, $fiber;
        return $future;
    }

    sub await_sleep {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
        }
        my $ms = shift // 0;
        return 'Queue Full' if submit_c_job( 0, $ms, 0 ) < 0;
        return yield('WAITING');
    }

    sub await_core_id {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
        }
        return 'Queue Full' if submit_c_job( 1, 0, 0 ) < 0;
        return yield('WAITING');
    }

    sub await_read {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
        }
        my ( $fh, $timeout ) = @_;
        $timeout //= 5000;
        my $fileno = fileno($fh);
        die 'Not a valid filehandle' unless defined $fileno;
        my $handle = $^O eq 'MSWin32' ? win32_get_osfhandle($fileno) : $fileno;
        return 'Queue Full' if submit_c_job( 2, $handle, $timeout ) < 0;
        return yield('WAITING');
    }

    sub await_write {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
        }
        my ( $fh, $timeout ) = @_;
        $timeout //= 5000;
        my $fileno = fileno($fh);
        die 'Not a valid filehandle' unless defined $fileno;
        my $handle = $^O eq 'MSWin32' ? win32_get_osfhandle($fileno) : $fileno;
        return 'Queue Full' if submit_c_job( 3, $handle, $timeout ) < 0;
        return yield('WAITING');
    }

    sub maybe_yield {
        my $invocant = shift;
        if ( !defined $invocant || ( ( ref $invocant || $invocant ) ne 'Acme::Parataxis' && !eval { $invocant->isa('Acme::Parataxis') } ) ) {
            unshift @_, $invocant if defined $invocant;
        }
        my $result = Acme::Parataxis::_maybe_yield();
        return unless defined $result;
        return wantarray ? @$result : $result->[-1];
    }
    sub tid            { get_os_thread_id_export() }
    sub current_fid    { get_current_parataxis_id() }
    sub root           { state $root //= Acme::Parataxis::Root->new() }
    sub max_threads () { Acme::Parataxis::get_max_thread_pool_size() }

    # Scheduler internals
    sub _scheduler_enqueue_by_id ($fid) {
        if ( my $fiber = Acme::Parataxis->by_id($fid) ) {
            push @SCHEDULER_QUEUE, $fiber;
        }
    }

    sub poll_io {
        my @ready;
        while (1) {
            my $job_idx = check_for_completion();
            last if $job_idx == -1;
            my $fid = get_job_coro_id($job_idx);
            my $res = get_job_result($job_idx);
            push @ready, [ $fid, $res ];
            free_job_slot($job_idx);
        }
        return @ready;
    }

    sub run ($code) {
        @SCHEDULER_QUEUE = ();
        $IS_RUNNING      = 1;
        my $main_fiber = Acme::Parataxis->new( code => $code );
        push @SCHEDULER_QUEUE, $main_fiber;
        while ($IS_RUNNING) {
            my @ready = poll_io();
            for my $ready (@ready) {
                my ( $fid, $res ) = @$ready;
                my $fiber = Acme::Parataxis->by_id($fid);
                if ($fiber) {
                    my $yield_val = $fiber->call($res);
                    if ( defined $fiber && !$fiber->is_done ) {
                        if ( defined $yield_val && $yield_val eq 'WAITING' ) { }
                        else {
                            push @SCHEDULER_QUEUE, $fiber;
                        }
                    }
                }
            }
            if (@SCHEDULER_QUEUE) {
                my $current = shift @SCHEDULER_QUEUE;
                next unless $current;
                next if $current->is_done;
                my $res = $current->call();
                if ( defined $current && !$current->is_done ) {
                    if ( defined $res && $res eq 'WAITING' ) { }
                    else {
                        push @SCHEDULER_QUEUE, $current;
                    }
                }
            }
            my $active_count = scalar keys %Acme::Parataxis::REGISTRY;
            if ( defined $main_fiber && $main_fiber->is_done && $active_count == 0 && !@SCHEDULER_QUEUE ) {
                $IS_RUNNING = 0;
            }
            if ( $IS_RUNNING && !@SCHEDULER_QUEUE && !@ready ) {
                usleep(1000);
            }
        }
    }
    sub stop () { $IS_RUNNING = 0 }
    class    #
        Acme::Parataxis {
        use Carp qw[croak];
        field $code : reader : param;
        field $is_done = 0;
        field $error  : reader;
        field $result : reader;
        field $fid    : reader;
        field $future : param = undef;

        method set_result ($val) {
            $result = $val;
            $future->set_result($val) if $future;
        }

        method set_error ($err) {
            $error = $err;
            $future->set_error($err) if $future;
        }

        method _clear_result () {
            $result = undef;
            $error  = undef;
        }
        our %REGISTRY;
        ADJUST {
            Acme::Parataxis::force_depth_zero($code);
            $fid = Acme::Parataxis::create_fiber( $code, $self );
            $REGISTRY{$fid} = $self;
            builtin::weaken $REGISTRY{$fid};
        }

        method call (@args) {
            croak 'Cannot call a finished fiber' if $is_done;
            my $rv = Acme::Parataxis::coro_call( $fid, \@args );
            return unless defined $self;
            if ( $self->is_done ) {
                my $err = $error;
                die $err if defined $err;
            }
            return unless defined $rv;
            return ( ref $rv eq 'ARRAY' ) ? ( wantarray ? @$rv : $rv->[-1] ) : $rv;
        }

        method transfer (@args) {
            croak 'Cannot transfer to a finished fiber' if $self->is_done;
            my $rv = Acme::Parataxis::coro_transfer( $fid, \@args );
            if ( $self->is_done ) {
                my $err = $error;
                die $err if defined $err;
            }
            return unless defined $rv;
            return ( ref $rv eq 'ARRAY' ) ? ( wantarray ? @$rv : $rv->[-1] ) : $rv;
        }

        method is_done () {
            return 1 if $is_done;
            if ( defined $fid && $fid >= 0 && Acme::Parataxis::is_finished($fid) ) {
                $is_done = 1;
                my $old_fid = $fid;
                $fid = -1;
                delete $REGISTRY{$old_fid};
                Acme::Parataxis::destroy_coro($old_fid);
                return 1;
            }
            return 0;
        }

        method wait () {
            while ( !$self->is_done ) {
                Acme::Parataxis->yield('WAITING_FOR_CHILD');
            }
            return $self->result;
        }

        method DESTROY {
            return if ${^GLOBAL_PHASE} eq 'DESTRUCT';
            if ( defined $fid && $fid >= 0 ) {
                delete $REGISTRY{$fid};
                Acme::Parataxis::destroy_coro($fid);
                $fid = -1;
            }
        }
        sub by_id ( $class, $fid ) { $REGISTRY{$fid} }
    }
    class    #
        Acme::Parataxis::Root {

        method transfer (@args) {
            my $rv = Acme::Parataxis::coro_transfer( -1, \@args );
            return unless defined $rv;
            return ( ref $rv eq 'ARRAY' ) ? ( wantarray ? @$rv : $rv->[-1] ) : $rv;
        }
        method fid () {-1}
    }
    class    #
        Acme::Parataxis::Future {
        use Carp qw[croak];
        field $is_ready : reader = 0;
        field $result;
        field $error;
        field @callbacks;

        method result () {
            croak 'Future not ready' unless $is_ready;
            return $result;
        }

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

        method clear_result () {
            $result = undef;
            $error  = undef;
        }

        method on_ready ($cb) {
            if   ($is_ready) { $cb->($self) }
            else             { push @callbacks, $cb }
        }

        method await () {
            return $self->result if $is_ready;
            my $fid = Acme::Parataxis->current_fid;
            $self->on_ready(
                sub ($f) {
                    Acme::Parataxis::_scheduler_enqueue_by_id($fid);
                }
            );
            Acme::Parataxis->yield('WAITING');
            $self->result;
        }
    }
    END { cleanup() unless ${^GLOBAL_PHASE} eq 'DESTRUCT' }
}
1;
