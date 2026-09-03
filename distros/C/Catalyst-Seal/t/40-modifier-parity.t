#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Storable ();

# Every method this phase flattens, called the way the request path calls it and
# the way an application calls it, sealed against unsealed.
#
# Context is the thing that breaks. The composed body a wrapped method installs
# distinguishes list, scalar and void, so every call below is made three times
# and all three answers are compared.
#
# Two children from a clean interpreter, because flattening cannot be undone.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require SealTest;

# A value rendered so that two processes agree on it without agreeing on a
# serialiser, and so that hash order cannot fail the comparison.
sub render {
    my ($v, $depth) = @_;
    $depth ||= 0;
    return '(undef)' unless defined $v;
    return '(deep)' if $depth > 3;
    my $r = ref $v;
    return "$v" unless $r;
    return 'ARRAY[' . join(',', map { render($_, $depth + 1) } @$v) . ']'
        if $r eq 'ARRAY';
    return 'HASH{' . join(',', map { "$_=" . render($v->{$_}, $depth + 1) }
        sort keys %$v) . '}' if $r eq 'HASH';
    return 'CODE' if $r eq 'CODE';
    # A blessed object is compared by class, not by address, which differs
    # between the two children for reasons that are not the thing under test.
    return "OBJ($r)" if Scalar::Util::blessed($v);
    return "REF($r)";
}

sub child {
    my ($sealed) = @_;
    pipe my $r, my $w or die "pipe: $!";
    my $pid = fork;
    defined $pid or die "fork: $!";

    if (!$pid) {
        close $r;
        open STDOUT, '>', '/dev/null' or die $!;
        open STDERR, '>', '/dev/null' or die $!;
        $ENV{CATALYST_SEAL} = $sealed ? 1 : 0;
        my $out = eval {
            require Scalar::Util;
            require TestApp;
            Storable::nfreeze(probe());
        };
        $out = Storable::nfreeze({ FATAL => "$@" }) if $@;
        syswrite $w, $out;
        close $w;
        require POSIX;
        POSIX::_exit(0);
    }

    close $w;
    my $frozen = do { local $/; <$r> };
    close $r;
    waitpid $pid, 0;
    return { error => "child exited $? with no output" }
        unless defined $frozen && length $frozen;
    return Storable::thaw($frozen);
}

# One call in all three contexts. Void is recorded as whether it died, since
# there is nothing else to record, and getting void wrong is how a wrapped
# method loses its return value.
sub three_ways {
    my ($out, $label, $call) = @_;
    my @list   = eval { $call->() };
    $out->{"$label/list"}   = $@ ? "DIED: $@" : render(\@list);
    my $scalar = eval { scalar $call->() };
    $out->{"$label/scalar"} = $@ ? "DIED: $@" : render($scalar);
    eval { $call->(); 1 };
    $out->{"$label/void"}   = $@ ? "DIED: $@" : 'ok';
    return;
}

sub probe {
    my %out;

    # Serve one request first, so that the lazy class-level state every one of
    # these methods reads is built before anything is compared.
    my $app = TestApp->psgi_app;
    $out{'request/root'} = SealTest::flatten($app->(SealTest::env()));

    my $res = TestApp->response_class->new;
    three_ways(\%out, 'response.status.read',     sub { $res->status });
    three_ways(\%out, 'response.status.write',    sub { $res->status(201) });
    three_ways(\%out, 'response.status.reread',   sub { $res->status });
    three_ways(\%out, 'response.headers.read',    sub { $res->headers });
    three_ways(\%out, 'response.ctype.write',     sub { $res->content_type('text/plain') });
    three_ways(\%out, 'response.ctype.read',      sub { $res->content_type });
    three_ways(\%out, 'response.clength.write',   sub { $res->content_length(11) });
    three_ways(\%out, 'response.clength.read',    sub { $res->content_length });
    three_ways(\%out, 'response.cenc.write',      sub { $res->content_encoding('gzip') });
    three_ways(\%out, 'response.cenc.read',       sub { $res->content_encoding });
    three_ways(\%out, 'response.header.read',     sub { $res->header('X-Thing') });
    three_ways(\%out, 'response.header.write',    sub { $res->header('X-Thing' => 'yes') });
    three_ways(\%out, 'response.header.reread',   sub { $res->header('X-Thing') });

    my $req = TestApp->request_class->new(_log => TestApp->log);
    three_ways(\%out, 'request.parameters.read',  sub { $req->parameters });
    three_ways(\%out, 'request.parameters.write', sub { $req->parameters({ a => 1, b => [2, 3] }) });
    three_ways(\%out, 'request.parameters.reread', sub { $req->parameters });

    my $ctrl = TestApp->controller('Root');
    three_ways(\%out, 'controller.name',      sub { $ctrl->catalyst_component_name });
    three_ways(\%out, 'controller.namespace', sub { $ctrl->action_namespace(TestApp()) });
    three_ways(\%out, 'controller.prefix',    sub { $ctrl->path_prefix(TestApp()) });

    my $d = TestApp->dispatcher;
    three_ways(\%out, 'dispatcher.tree',       sub { $d->tree });
    three_ways(\%out, 'dispatcher.action_hash', sub { $d->action_hash });
    three_ways(\%out, 'dispatcher.containers', sub { $d->container_hash });
    three_ways(\%out, 'dispatcher.types',      sub { $d->registered_dispatch_types });
    three_ways(\%out, 'dispatcher.action_class', sub { $d->method_action_class });

    three_ways(\%out, 'app.config', sub { TestApp->config });

    # Proof that the sealed side is the sealed side. Without this every
    # comparison above passes when nothing was flattened at all.
    my $meta = Class::MOP::class_of('Catalyst::Response');
    my $wrapped = $meta->get_method('status');
    $out{'__STATE__'} = 'status='
        . (TestApp->response_class->can('status') == $wrapped->body ? 'trampoline' : 'flat')
        . ',guard=' . (Sub::Util::subname($wrapped->{modifier_table}{before}[0])
            =~ /\ACatalyst::Seal::Modifiers::/ ? 'short' : 'stock');

    return \%out;
}

my $stock  = child(0);
my $sealed = child(1);

if ($stock->{FATAL} || $sealed->{FATAL} || $stock->{error} || $sealed->{error}) {
    plan skip_all => 'a child could not run: '
        . join ' ', grep { defined } $stock->{FATAL}, $sealed->{FATAL},
                                     $stock->{error}, $sealed->{error};
}

is($stock->{'__STATE__'},  'status=trampoline,guard=stock',
    'CATALYST_SEAL=0 left the wrapped methods alone');
is($sealed->{'__STATE__'}, 'status=flat,guard=short',
    'the sealed side really was flattened, so the comparisons below mean something');

is_deeply(
    [sort keys %$sealed],
    [sort keys %$stock],
    'both sides answered the same set of calls',
);

for my $key (sort grep { $_ ne '__STATE__' } keys %$stock) {
    is($sealed->{$key}, $stock->{$key}, "$key is identical");
}

done_testing;
