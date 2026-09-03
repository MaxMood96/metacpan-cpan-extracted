#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Storable ();

# The whole correctness argument for phase 0: the same application, driven
# through the same request table, must produce the same bytes sealed and
# unsealed.
#
# Each side runs in its own child from a clean interpreter, because the patches
# on Catalyst.pm are process-global and immutability cannot be undone. The
# parent only compares.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require SealTest;

sub run_in_child {
    my ($sealed) = @_;
    pipe my $r, my $w or die "pipe: $!";
    my $pid = fork;
    defined $pid or die "fork: $!";

    if (!$pid) {
        # The child inherits the TAP pipe. Anything it prints on STDOUT is
        # read as test output by the harness, so it says nothing there.
        close $r;
        open STDOUT, '>', '/dev/null' or die $!;
        open STDERR, '>', '/dev/null' or die $!;
        $ENV{CATALYST_SEAL} = $sealed ? 1 : 0;
        my $out = eval {
            require TestApp;
            my $data = SealTest::drive(TestApp->psgi_app);
            # Reported back so the parent can prove the two sides really were
            # different. A sealed child that silently sealed nothing would make
            # every comparison below pass for the wrong reason.
            $data->{'__STATE__'} = join ',',
                'handle_request=' . (Catalyst->can('handle_request')
                    == \&Catalyst::Seal::Exceptions::_handle_request ? 'patched' : 'stock'),
                'prepare=' . (Catalyst->can('prepare')
                    == \&Catalyst::Seal::Exceptions::_prepare ? 'patched' : 'stock'),
                'app_immutable=' . (Class::MOP::class_of('TestApp')->is_immutable ? 1 : 0),
                'classdata=' . (Catalyst::Seal::_is_sealed(TestApp->can('dispatcher')) ? 'sealed' : 'stock'),
                'modifiers=' . (Catalyst::Response->can('status')
                    == Class::MOP::class_of('Catalyst::Response')->get_method('status')->body
                        ? 'stock' : 'flat'),
                'config=' . (Catalyst::Seal::_is_sealed(TestApp->can('config')) ? 'sealed' : 'stock'),
                'readers=' . (Catalyst::Seal::_is_sealed(TestApp->can('stack')) ? 'sealed' : 'stock'),
                'delegators=' . (TestApp->can('req') == TestApp->can('request')
                    ? 'aliased' : 'stock'),
                'dispatch=' . (Catalyst::Dispatcher->can('_invoke_as_path')
                    == \&Catalyst::Seal::Dispatch::_invoke_as_path ? 'memo' : 'stock'),
                'encoding=' . (Catalyst->can('finalize_encoding')
                    == \&Catalyst::Seal::Finalize::_finalize_encoding ? 'memo' : 'stock'),
                'prepare_path=' . (Catalyst::Engine->can('prepare_path')
                    == \&Catalyst::Seal::Prepare::_prepare_path ? 'patched' : 'stock'),
                'prepare_headers=' . (Catalyst::Request->can('prepare_headers')
                    == \&Catalyst::Seal::Prepare::_prepare_headers ? 'patched' : 'stock'),
                'decoder=' . (Catalyst->can('_handle_param_unicode_decoding')
                    == \&Catalyst::Seal::Prepare::_handle_param_unicode_decoding ? 'patched' : 'stock'),
                'destroy=' . (Catalyst::Response->can('DESTROY')
                    == \&Catalyst::Seal::Finalize::_response_destroy ? 'eval' : 'stock'),
                'construct=' . (Catalyst::Controller->can('BUILD')
                    == \&Catalyst::Seal::Construct::_controller_build ? 'memo' : 'stock');
            Storable::nfreeze($data);
        };
        $out = Storable::nfreeze({ FATAL => "$@" }) if $@;
        syswrite $w, $out;
        close $w;
        # Leave without running the END blocks Test::More installed in the
        # parent, which the child inherited and would otherwise report twice.
        require POSIX;
        POSIX::_exit(0);
    }

    close $w;
    my $frozen = do { local $/; <$r> };
    close $r;
    waitpid $pid, 0;
    my $status = $?;

    return { error => "child exited $status with no output" }
        unless defined $frozen && length $frozen;
    return Storable::thaw($frozen);
}

my $stock  = run_in_child(0);
my $sealed = run_in_child(1);

# Checked before any test runs: a skip_all after a test has already been
# reported is itself a failure, and a child that could not start is not a
# reason to pass quietly.
if ($stock->{FATAL} || $sealed->{FATAL} || $stock->{error} || $sealed->{error}) {
    plan skip_all => 'a child could not run: '
        . join ' ', grep { defined } $stock->{FATAL}, $sealed->{FATAL},
                                     $stock->{error}, $sealed->{error};
}

ok(!$stock->{FATAL},  'the unsealed child ran');
ok(!$sealed->{FATAL}, 'the sealed child ran');

is_deeply(
    [sort keys %$sealed],
    [sort keys %$stock],
    'both sides answered the same set of requests',
);

is(
    $stock->{'__STATE__'},
    'handle_request=stock,prepare=stock,app_immutable=0,classdata=stock,'
        . 'modifiers=stock,config=stock,readers=stock,delegators=stock,'
        . 'dispatch=stock,encoding=stock,'
        . 'prepare_path=stock,prepare_headers=stock,decoder=stock,destroy=stock,'
        . 'construct=stock',
    'CATALYST_SEAL=0 really did seal nothing',
);
is(
    $sealed->{'__STATE__'},
    'handle_request=patched,prepare=patched,app_immutable=1,classdata=sealed,'
        . 'modifiers=flat,config=sealed,readers=sealed,delegators=aliased,'
        . 'dispatch=memo,encoding=memo,'
        . 'prepare_path=patched,prepare_headers=patched,decoder=patched,destroy=eval,'
        . 'construct=memo',
    'the sealed side really was sealed, so the comparisons below mean something',
);

for my $req (SealTest::requests()) {
    my $name = $req->{name};
    is($sealed->{$name}, $stock->{$name}, "$name is byte identical");
}

done_testing;
