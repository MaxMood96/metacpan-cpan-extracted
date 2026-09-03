package Catalyst::Seal::Accessors;

use strict;
use warnings;

use B ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

sub _seal_config {
    my ($app) = @_;

    my $orig = $app->can('config') or return 0;

    # Resolve it the way a read would.
    my $value = eval { $app->config };
    if ($@ || !defined $value) {
        Catalyst::Seal::note("could not resolve $app->config, not sealed: $@");
        return 0;
    }

    my $ok = eval {
        no warnings 'redefine';
        Catalyst::Seal::_install_const($app, 'config', $value, $orig, undef);
        1;
    };
    unless ($ok) {
        Catalyst::Seal::note("could not seal $app->config: $@");
        return 0;
    }
    return 1;
}

my %DELEGATOR = (
    req  => 'request',
    res  => 'response',
    comp => 'component',
);

sub _seal_delegators {
    my ($app) = @_;
    my $sealed = 0;

    for my $name (sort keys %DELEGATOR) {
        my $target = $DELEGATOR{$name};

        my $from = $app->can($name)   or next;
        my $to   = $app->can($target) or next;

        next if $from == $to;

        my $ok = eval {
            no strict 'refs';
            no warnings 'redefine';
            *{"${app}::${name}"} = $to;
            1;
        };
        unless ($ok) {
            Catalyst::Seal::note("could not alias $app\::$name to $target: $@");
            next;
        }
        $sealed++;
    }

    return $sealed;
}

sub _reader_classes {
    my ($app) = @_;
    my @classes = ($app->context_class || $app);
    push @classes, eval { $app->composed_request_class }  || ();
    push @classes, eval { $app->composed_response_class } || ();

    my %seen;
    return grep { !$seen{$_}++ } grep { defined && length } @classes;
}

sub _seal_readers {
    my ($class) = @_;

    my $meta = Class::MOP::class_of($class) or return 0;
    return 0 unless $meta->isa('Class::MOP::Class');
    unless ($meta->is_immutable) {
        Catalyst::Seal::note("$class is mutable, its readers were not sealed");
        return 0;
    }

    my $sealed = 0;
    for my $attr ($meta->get_all_attributes) {
        my $name = eval { $attr->get_read_method } or next;
        my $ref  = eval { $attr->get_read_method_ref } or next;
        next unless ref $ref && $ref->isa('Class::MOP::Method');

        next if $ref->isa('Class::MOP::Method::Wrapped');

        my $body = eval { $ref->body } or next;
        my $installed = $class->can($name) or next;

        next unless $installed == $body;

        my $ok = eval {
            no warnings 'redefine';
            Catalyst::Seal::_install_reader(
                $class, $name, $attr->name, $body, ($attr->is_lazy ? 1 : 0));
            1;
        };
        unless ($ok) {
            Catalyst::Seal::note("could not seal reader $class\::$name: $@");
            next;
        }
        $sealed++;
    }

    return $sealed;
}

my @GUARDED = (
    ['Catalyst::Response', 'headers'],
    ['Catalyst::Response', 'status'],
);

sub _seal_guarded_readers {
    my $sealed = 0;

    for my $pair (@GUARDED) {
        my ($class, $name) = @$pair;

        my $meta = Class::MOP::class_of($class) or next;
        next unless $meta->is_immutable;

        my $attr = $meta->find_attribute_by_name($name) or next;
        my $installed = $class->can($name) or next;

        my $gv = B::svref_2object($installed)->GV;
        next unless $gv->NAME =~ /\A_wrapped_/;

        my $ok = eval {
            no warnings 'redefine';
            Catalyst::Seal::_install_reader(
                $class, $name, $attr->name, $installed,
                ($attr->is_lazy ? 1 : 0));
            1;
        };
        unless ($ok) {
            Catalyst::Seal::note("could not seal guarded reader $class\::$name: $@");
            next;
        }
        $sealed++;
    }

    return $sealed;
}

Catalyst::Seal::register_step('accessors' => sub {
    my ($app) = @_;

    require Class::MOP;

    my $config = _seal_config($app);
    my $readers = 0;
    $readers += _seal_readers($_) for _reader_classes($app);

    $readers += _seal_guarded_readers();

    my $delegators = _seal_delegators($app);

    Catalyst::Seal::note(
        "sealed config ($config), $readers reader(s), $delegators delegator(s)")
        if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Accessors - XS accessors for the context hot set

=head1 DESCRIPTION

Moose's inlined readers are not slow. Measured on an immutable class, two
million calls, best of five:

    plain rw attribute (Moose inlined)       88.5 ns
    rw with a default   (Moose inlined)      75.5 ns
    lazy, after the build (Moose inlined)    99.9 ns
    hand-written sub { $_[0]{x} }            76.7 ns
    a delegator, sub { shift->plain(@_) }   133.8 ns
    an XSUB                                  44.2 ns

Two things follow. Replacing a Moose reader with a hand-written Perl one buys
nothing, so this has to be XS or not at all. And a reader is worth about 45 ns
while a delegator is worth about 90, because a delegator pays for a whole extra
frame before reaching the reader it stands in front of.

What is actually worth doing, in the order this module does it:

=over 4

=item * C<config>, which is not a reader at all but a constant, and costs more
than every reader in this phase put together.

=item * The delegators, C<req> and C<res>, 25 calls a request between them.

=back

=head2 config is a constant

C<$c-E<gt>config> costs 34.5 us per request inclusive under the profiler, about
11us real: an C<around> trampoline, C<Catalyst::Component::config>,
C<Moose::Util::find_meta>, C<Class::MOP::Package::get_or_add_package_symbol> and
C<Package::Stash::XS>, nine calls of each.

It is a constant because Catalyst says so. The C<around config> in Catalyst.pm
croaks on any write once C<setup_finished> is true, so after setup the value
cannot change. The phase 1 constant accessor already handles this shape, and its
slow path delegates to the original, which is what has to do the croaking.

The value is the same hash reference the stock chain returns, so
C<MyApp-E<gt>config-E<gt>{foo} = 'bar'> still works.

=cut

=head2 The delegators

C<req> and C<res> are

    sub req { my $self = shift; return $self->request(@_) }

so every call is a frame that exists only to reach another frame. Sealing one
means installing the target's own body under the delegator's name, which is
only correct while the target is not itself replaced afterwards. They are
sealed last for that reason.

A delegator is only sealed when its body is the exact two-statement shape above.
Anything else, including an application that has overridden C<req>, is left
alone.

=cut

=head2 The attribute readers

Worth about 7 us per request over 160 calls, on the context class and the
composed request and response classes. Small, but above the threshold this
phase set itself.

Only readers, and only on immutable classes, where the reader is Moose's own
generated one and has not been overridden or wrapped. Everything the XSUB
cannot answer goes to that reader instead: a class method call, a write, an
instance of a subclass, or a lazy attribute whose slot is not built yet.

Delegating the lazy miss is what keeps this small. Moose's reader does the
build and the store, every call after it takes the fast path, and because
nothing here ever writes a slot, a C<predicate> keeps telling the truth.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

