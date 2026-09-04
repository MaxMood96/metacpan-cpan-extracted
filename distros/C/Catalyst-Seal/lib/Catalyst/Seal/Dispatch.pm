package Catalyst::Seal::Dispatch;

use strict;
use warnings;

use Encode ();
use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

my %PATH;       # "$base\0$rel_path" => [ $action, \@extra_args ]
my %ACTIONS;    # "$name\0$namespace" => [ @actions ]

our $MAX_KEYS = 2048;
my $CAPPED = 0;

sub capped { $CAPPED }

sub _clear {
    %PATH    = ();
    %ACTIONS = ();
    $CAPPED  = 0;
    return;
}

sub memo_sizes { return (scalar keys %PATH, scalar keys %ACTIONS) }

sub _invoke_as_path {
    my ( $self, $c, $rel_path, $args ) = @_;

    my $base = '';
    if ($rel_path !~ m{\A/}) {
        my $top = $c->stack->[-1];
        $base = $top ? $top->namespace : '';
        $base = '' unless defined $base;
    }

    my $key = "$base\0$rel_path";
    my $hit = $PATH{$key};

    unless ($hit) {
        my (@extra_args, $found);
        my $path = $self->_action_rel2abs( $c, $rel_path );

        my $tail;
        while ( ( $path, $tail ) = ( $path =~ m#^(?:(.*)/)?(\w+)?$# ) ) {
            if ( my $action = $c->get_action( $tail, $path ) ) {
                $found = $action;
                last;
            }
            else {
                # A failed match on the global namespace fails the whole
                # lookup, and the stock code returns without touching @$args.
                last unless $path;
            }
            unshift @extra_args, $tail;
        }

        $hit = [ $found, \@extra_args ];
        if (keys %PATH < $MAX_KEYS) {
            $PATH{$key} = $hit;
        }
        elsif (!$CAPPED++) {
            Catalyst::Seal::note(
                "dispatch path memo reached $MAX_KEYS keys, no longer caching");
        }
    }

    my ($action, $extra) = @$hit;
    return unless $action;
    push @$args, @$extra if @$extra;
    return $action;
}

sub _get_actions {
    my ( $self, $c, $action, $namespace ) = @_;
    return [] unless $action;

    my $key = "$action\0" . (defined $namespace ? $namespace : '');
    my $hit = $ACTIONS{$key};

    unless ($hit) {
        my $ns = join( "/", grep { length } split '/', $namespace || "" );
        my @match = $self->get_containers($ns);
        $hit = [ map { $_->get_action($action) } @match ];
        $ACTIONS{$key} = $hit if keys %ACTIONS < $MAX_KEYS;
    }

    return @$hit;
}

my %PLAN;        # "_DISPATCH namespace" => { steps => [...], end => $action }
my %DISPATCH;    # action namespace      => the _DISPATCH action, or 0

sub _clear_chain { %PLAN = (); %DISPATCH = (); return }

sub _run {
    my ($c, $action) = @_;

    my @args = @{ $c->request->arguments };
    local $c->request->{arguments} = \@args;
    no warnings 'recursion';
    $action->dispatch($c);

    $c->state(0) if @{ $c->error };
    return $c->state;
}

sub _dispatch {
    my ($self, $c) = @_;

    my $action = $c->action;
    my $stock  = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::Dispatcher::dispatch'};

    return $stock ? $stock->($self, $c) : () unless $action;

    my $ns = $action->namespace;
    $ns = '' unless defined $ns;

    my $disp = $DISPATCH{$ns};
    unless (defined $disp) {
        $disp = $DISPATCH{$ns} = $c->get_action('_DISPATCH', $ns) || 0;
    }
    return $stock ? $stock->($self, $c) : () unless $disp;

    _run($c, $disp);
    return;
}

sub _state_one    { $_[0]->state(1); return 1 }
sub _state_or_one { my $c = shift; $c->state($c->state || 1); return 1 }

sub _build_plan {
    my ($c, $self, $ns) = @_;

    # What _BEGIN and _AUTO would find. Fixed for a namespace after setup.
    my $begin = ( $c->get_actions('begin', $ns) )[-1];
    my @autos = $c->get_actions('auto', $ns);
    my $end   = ( $c->get_actions('end',  $ns) )[-1];

    my %noop = (
        _BEGIN => ($begin ? undef : \&_state_one),
        _AUTO  => (@autos ? undef : \&_state_or_one),
    );

    my @steps;
    for my $name (@{ $self->_dispatch_steps }) {
        if ($noop{$name}) {
            push @steps, $noop{$name};
            next;
        }
        my $a = $c->get_action($name, $ns) or return 0;
        push @steps, $a;
    }

    my $end_step;
    if ($end) {
        $end_step = $c->get_action('_END', $ns) or return 0;
    }
    else {
        $end_step = \&_state_one;
    }

    return { steps => \@steps, end => $end_step };
}

sub _controller_dispatch {
    my ($self, $c) = @_;

    my $top = $c->stack->[-1];
    my $ns  = $top ? $top->namespace : '';
    $ns = '' unless defined $ns;

    my $plan = $PLAN{$ns};
    $plan = $PLAN{$ns} = _build_plan($c, $self, $ns) unless defined $plan;

    unless ($plan) {
        my $stock = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::Controller::_DISPATCH'};
        return $stock ? $stock->($self, $c) : ();
    }

    for my $step (@{ $plan->{steps} }) {
        last unless ref $step eq 'CODE' ? $step->($c) : _run($c, $step);
    }
    # _END runs whether or not a step stopped the chain, exactly as stock.
    my $end = $plan->{end};
    ref $end eq 'CODE' ? $end->($c) : _run($c, $end);
    return;
}

my %COMPONENT;

sub _clear_components { %COMPONENT = (); return }

# ------------------------------------------------------------ route lookup
#
# ------------------------------------------------------------ route lookup
#
# There is deliberately no route memo here. 0.02 had one, keyed on the request
# path, and it was CVE-2026-85491.
#
# The premise it rested on was that "which level matched, which dispatch type
# matched it, and what ended up in the arguments are a pure function of the
# path once the action table is frozen". That is false.
# Catalyst::ActionRole::HTTPMethods, ConsumesContent, Scheme and QueryMatching
# each wrap match() with a test on request state that is not the path, so the
# same path matches a different action, or none, depending on the method, the
# content type, the scheme or the query.
#
# Two things followed. A request that legitimately failed to match wrote a
# negative entry, and replaying it returned without consulting any dispatch
# type, so $c->action was never set: one unauthenticated GET of a
# :Method('POST') path disabled that path for the life of the worker. And a
# positive entry recorded the level an earlier request had descended to, so a
# GET that fell past a deep POST-only action onto a shallow any-method one
# would route a later POST to the shallow action, with whatever guarded the
# deep one never running.
#
# It cannot be repaired by widening the key. match() is wrapped by whatever
# roles an application applies, so what the decision depends on is not
# knowable from here, and there is no reliable way to detect that an action is
# matched on the path alone. Anything remembered about a routing decision has
# to key on all of the request state or not be remembered.
#
# The memos that remain in this file do not have this problem: get_action and
# get_containers are lookups in _action_hash and _container_hash, and consult
# no request state at all. t/61-dispatch-method.t is the regression.

sub _component {
    my ($c, $name, @args) = @_;

    if (defined $name && !ref $name && !@args) {
        my $hit = $COMPONENT{$name};
        return $hit->[0] if $hit;
    }

    my $stock = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::component'};
    my @out = $stock ? $stock->($c, $name, @args) : ();

    if (defined $name && !ref $name && !@args && @out == 1) {
        my $comps = eval { $c->components } || {};
        my $raw   = $comps->{$name};
        # Only an exact-name hit on a blessed component with no ACCEPT_CONTEXT.
        # A coderef entry is built lazily, and ACCEPT_CONTEXT is per request.
        if (defined $raw && Scalar::Util::blessed($raw)
            && !$raw->can('ACCEPT_CONTEXT')
            && Scalar::Util::blessed($out[0])
            && Scalar::Util::refaddr($out[0]) == Scalar::Util::refaddr($raw)) {
            $COMPONENT{$name} = [ $out[0] ] if keys %COMPONENT < $MAX_KEYS;
        }
    }

    return wantarray ? @out : $out[0];
}

sub _rewire_dispatch_actions {
    my ($app) = @_;

    my $stock = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::Controller::_DISPATCH'}
        or return 0;

    my $hash = eval { $app->dispatcher->_action_hash } or return 0;
    my $done = 0;

    for my $action (values %$hash) {
        next unless $action && $action->name eq '_DISPATCH';
        my $code = $action->{code} or next;
        next unless Scalar::Util::refaddr($code) == Scalar::Util::refaddr($stock);
        $action->{code} = \&_controller_dispatch;
        $done++;
    }

    Catalyst::Seal::note("rewired $done _DISPATCH action(s)")
        if $Catalyst::Seal::DEBUG;
    return $done;
}

my $PATCHED = 0;

Catalyst::Seal::register_step('dispatch' => sub {
    my ($app) = @_;

    return if $PATCHED++;

    my $path = Catalyst::Seal::Guard::replace(
        'Catalyst::Dispatcher::_invoke_as_path' => \&_invoke_as_path);
    my $actions = Catalyst::Seal::Guard::replace(
        'Catalyst::Dispatcher::get_actions' => \&_get_actions);

    unless ($path || $actions) {
        Catalyst::Seal::note('neither dispatch lookup was memoised');
        return;
    }

    Catalyst::Seal::Guard::replace(
        'Catalyst::Dispatcher::dispatch'    => \&_dispatch);
    Catalyst::Seal::Guard::replace(
        'Catalyst::Controller::_DISPATCH'   => \&_controller_dispatch);
    _rewire_dispatch_actions($app);
    Catalyst::Seal::Guard::replace(
        'Catalyst::component'               => \&_component);

    
    my $register = Catalyst::Dispatcher->can('register');
    if ($register) {
        no warnings 'redefine';
        *Catalyst::Dispatcher::register = sub {
            _clear();
            _clear_chain();
            _clear_components();
            return $register->(@_);
        };
    }
    else {
        Catalyst::Seal::note(
            'no Catalyst::Dispatcher::register to hook, memos cannot be invalidated');
        Catalyst::Seal::Guard::restore('Catalyst::Dispatcher::_invoke_as_path');
        Catalyst::Seal::Guard::restore('Catalyst::Dispatcher::get_actions');
        return;
    }

    Catalyst::Seal::note("memoised dispatch lookups (path=$path actions=$actions)")
        if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Dispatch - memoise the action lookups that stopped changing

=head1 DESCRIPTION

One action costs five forwards and six executes:

    dispatch      -> forward('/<ns>/_DISPATCH')
    _DISPATCH     -> forward each of _dispatch_steps, stopping on false
        _BEGIN    -> get_actions('begin', $ns), dispatch the last
        _AUTO     -> get_actions('auto', $ns),  dispatch each
        _ACTION   -> $c->action->dispatch($c)          <- the application's
    _DISPATCH     -> forward('_END') unconditionally
        _END      -> get_actions('end', $ns),   dispatch the last

Each forward turns a string like C<'/steps/_BEGIN'> into an action object, every
request, for the life of the process: C<_command2action>, C<_invoke_as_path>,
C<_action_rel2abs>, C<get_action>, C<get_action_by_path>. The action table those
walk is frozen at C<setup_finalize>, so the answer is the same every time.

This module memoises the two lookups and nothing else.

=head2 Why the chain itself is not flattened

The plan for this phase was to compile the route table into C and run the chain
as a flat loop. Measured, that is the wrong target twice over.

The lookup is not where the time is. C<prepare_action> and
C<DispatchType::Path::match> are about 11 us per request; the chain walk is
about 29. A trie would make an already cheap hash lookup marginally cheaper.

And the chain cannot be flattened without reimplementing C<execute>. The private
steps go on C<$c-E<gt>stack>, and that stack is load bearing:
C<$c-E<gt>depth> is C<scalar @{$c-E<gt>stack}>,
C<Catalyst::Exception::Detach> rethrows only C<if $c-E<gt>depth E<gt> 1>, C<Go>
only C<if $c-E<gt>depth E<gt> 0>, and an uncaught error names
C<$last-E<gt>class> and C<$last-E<gt>name> off it. A flat chain that skips the
pushes turns a depth of 3 into a depth of 1, and a C<detach> from an action
stops rethrowing. Preserving the stack means doing C<execute>'s push, pop, depth
guard, stats check, eval and error handling five times over, in this
distribution, which leaves about 5 us of C<forward> and C<_do_forward> as the
entire prize.

Memoising the lookups gets most of the recoverable time for none of that risk,
so that is what this does. The arithmetic is in
F<plan_catalyst_seal/phase_5_TODO.md>.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

