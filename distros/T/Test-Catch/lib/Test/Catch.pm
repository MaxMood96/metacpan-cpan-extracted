package Test::Catch;
use 5.012;
use Test::More();
use XS::libcatch();
use Test::Builder();

our $VERSION = '2.0.2';

XS::Loader::load();

sub import {
    shift;
    if (@_) {
        run(@_);
        Test::More::done_testing();
    }

    my $pkg = caller();
    no strict 'refs';
    *{"${pkg}::catch_run"} = \&run;
}

sub run {
    my @args = @_;
    my $ctx    = Test::Builder->new->ctx;
    my $hub    = $ctx->hub;
    my $count  = $hub->count;
    my $failed = $hub->failed;
    my $depth  = $hub->nested;
    my $ret = _run($count, $failed, $depth, @args);
    $hub->set_count($count);
    $hub->set_failed($failed);
    $ctx->release;
    return $ret;
}

1;
