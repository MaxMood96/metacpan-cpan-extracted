package Catalyst::Seal::Construct;

use strict;
use warnings;

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

my %EMPTY;
my %DECIDED;

sub _clear { %EMPTY = (); %DECIDED = (); return }
sub empty_classes { scalar keys %EMPTY }

sub _stock_controller_build {
    my $orig = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::Controller::BUILD'};
    return $orig;
}

sub _controller_build {
    my ($self, $args) = @_;

    my $class = ref $self;
    my $plain = !exists $args->{action} && !exists $args->{actions};

    if ($plain && $EMPTY{$class}) {
        # Fresh containers, not the remembered ones. See the note above.
        $self->{actions}                 = {};
        $self->{_all_actions_attributes} = {};
        $self->{_action_roles}           = [];
        return;
    }

    my $orig = _stock_controller_build() or return;
    $orig->($self, $args);

    return unless $plain;
    return if $DECIDED{$class}++;

    my $actions = $self->{actions};
    my $attrs   = $self->{_all_actions_attributes};
    my $roles   = $self->{_action_roles};

    $EMPTY{$class} = 1
        if ref $actions eq 'HASH'  && !keys %$actions
        && ref $attrs   eq 'HASH'  && !keys %$attrs
        && ref $roles   eq 'ARRAY' && !@$roles;

    return;
}

our %LAZY_STATS;

my %STATS_ORIG;

sub _make_stats_reader {
    my ($class) = @_;
    my $orig = $class->can('stats') or return;
    $STATS_ORIG{$class} = $orig;

    return sub {
        my $self = shift;
        return $orig->($self, @_) if @_;

        my $v = $self->{stats};
        return $v if defined $v;

        my $stats = $self->stats_class->new;
        $stats->enable($self->use_stats);
        return $self->{stats} = $stats;
    };
}

my $PATCHED = 0;

Catalyst::Seal::register_step('construct' => sub {
    my ($app) = @_;

    my $build = 0;
    unless ($PATCHED++) {
        $build = Catalyst::Seal::Guard::replace(
            'Catalyst::Controller::BUILD' => \&_controller_build);
    }

    # The context class only. Nothing else is constructed per request.
    my $ctx = $app->context_class || $app;
    my $stats = 0;
    if (my $reader = _make_stats_reader($ctx)) {
        my $ok = eval {
            no strict 'refs';
            no warnings 'redefine';
            *{"${ctx}::stats"} = $reader;
            1;
        };
        if ($ok) {
            $LAZY_STATS{$ctx} = 1;
            $stats = 1;
        }
        else {
            Catalyst::Seal::note("could not install a lazy stats reader on $ctx: $@");
        }
    }

    Catalyst::Seal::note("construct: controller-build=$build stats-lazy=$stats")
        if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Construct - two things built per request that need not be

=head1 DESCRIPTION

=head2 A controller's BUILD on the context object

The application class's linearized ISA is

    MyApp, Catalyst, Catalyst::Component, Moose::Object, Catalyst::Controller

so the per-request context object inherits C<Catalyst::Controller::BUILD>, and
C<BUILDALL> runs it on a throwaway object every request:

    my $attr_value = $self->merge_config_hashes($actions, $action);
    $self->_controller_actions($attr_value);
    $self->_all_actions_attributes;   # trigger lazy builder
    $self->_action_roles;             # trigger lazy builder

Two lazy builders fired to compute values derived from class data that stopped
changing at C<setup_finalize>. 17.5 us per request inclusive.

The memo here is deliberately narrow. It runs the stock body once per class, and
remembers the class only when all three results came out empty, which is the
case for a context object built with no arguments. Then it stores *fresh* empty
containers into each new instance rather than sharing the remembered ones: a
shared C<actions> hash that something wrote to would leak between requests, and
C<_build__all_actions_attributes> deletes a key from that hash as it goes.

Anything else, including a real controller being configured at setup with
C<action> or C<actions> arguments, takes the stock body.

=head2 A Stats object built when stats are off

C<prepare> does

    $c->stats($class->stats_class->new)->enable($c->use_stats);

unconditionally, and C<Catalyst::Stats> has C<tree> as a required, non-lazy
attribute defaulting to C<Tree::Simple-E<gt>new({t =E<gt> [gettimeofday]})>. So
a tree is built and the clock read on every request for an object that, with
stats disabled, nothing reads again.

With stats enabled this changes nothing: the object is constructed eagerly, at
the same point, because the timestamp in that default is the request start and
deferring it would move the elapsed time that gets reported.

With stats disabled the construction is deferred to the first read of
C<$c-E<gt>stats>, which usually never comes. It is not shared between requests:
a request calling C<$c-E<gt>stats-E<gt>enable(1)> would otherwise profile into a
tree that outlives it and grows for the life of the worker.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

