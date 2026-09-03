package Catalyst::Seal::ClassData;

use strict;
use warnings;

use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

sub _classdata_accessors {
    my ($class) = @_;
    my $meta = Class::MOP::class_of($class) or return ();

    my %found;
    for my $pkg ($meta->linearized_isa) {
        my $pkg_meta = Class::MOP::class_of($pkg) or next;

        my %by_body;
        for my $name ($pkg_meta->get_method_list) {
            my $method = $pkg_meta->get_method($name) or next;
            my $body = eval { $method->body } or next;
            push @{ $by_body{ 0 + $body } }, [$name, $body];
        }

        for my $pair (values %by_body) {
            next unless @$pair == 2;
            my ($plain) = grep { $_->[0] !~ /\A_.+_accessor\z/ } @$pair;
            my ($alias) = grep { $_->[0] =~ /\A_.+_accessor\z/ } @$pair;
            next unless $plain && $alias;
            next unless $alias->[0] eq "_$plain->[0]_accessor";
            # A nearer class in the ISA wins, which is the order we are walking.
            $found{ $plain->[0] } ||= $plain->[1];
        }
    }
    return %found;
}

sub _classes_for {
    my ($app) = @_;
    my @classes = ($app);
    my $components = eval { $app->components } || {};
    push @classes, map { ref $_ || $_ } values %$components;

    my %seen;
    return grep { !$seen{$_}++ } grep { defined && length } @classes;
}

sub _seal_class {
    my ($class) = @_;

    my %accessors = _classdata_accessors($class);
    my $sealed = 0;

    for my $name (sort keys %accessors) {
        # Resolve exactly the way a read would, through the accessor itself.
        my $value = eval { $class->$name };
        if ($@) {
            Catalyst::Seal::note("$class\::$name croaked while resolving, not sealed: $@");
            next;
        }

        my $ok = eval {
            no warnings 'redefine';
            Catalyst::Seal::_install_const($class, $name, $value, $accessors{$name});
            1;
        };
        unless ($ok) {
            Catalyst::Seal::note("could not seal $class\::$name: $@");
            next;
        }
        $sealed++;
    }

    return $sealed;
}

sub _component_config {
    my $self = shift;
    my $config = $self->_config || {};
    if (@_) {
        my $newconfig = { %{@_ > 1 ? {@_} : $_[0]} };
        $self->_config(
            $self->merge_config_hashes( $config, $newconfig )
        );
    } else {
        my $class = Scalar::Util::blessed($self) || $self;
        no strict 'refs';
        unless ( ${"${class}::_config"} ) {
            $self->_config( Catalyst::Utils::merge_hashes($config, {}) );
        }
    }
    return $self->_config;
}

my $CONFIG_PATCHED = 0;

Catalyst::Seal::register_step('classdata' => sub {
    my ($app) = @_;
    require Class::MOP;

    eval { $app->context_class( ref $app || $app ) unless $app->context_class };

    my $sealed = 0;
    $sealed += _seal_class($_) for _classes_for($app);

    unless ($CONFIG_PATCHED++) {
        Catalyst::Seal::Guard::replace(
            'Catalyst::Component::config' => \&_component_config);
    }

    Catalyst::Seal::note("sealed $sealed class data accessor(s)")
        if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::ClassData - constant accessors for class data that stopped changing

=head1 DESCRIPTION

C<Catalyst::ClassData::mk_classdata> generates an accessor that calls
C<Moose::Util::find_meta($pkg)> on every read, then walks C<linearized_isa> if
the package's own scalar slot is empty. C<$meta> is computed unconditionally
even though only the write path and the inheritance walk use it, and the common
case, a defined value in the package's own slot, needs neither.

On a bare application that is 84 C<find_meta> calls, 84 C<class_of> calls and 21
C<Class::MOP::Class::initialize> calls per request, all to read values that have
not changed since C<setup_finalize>. The callers are C<_dispatcher>, C<_engine>,
C<_log>, C<_components>, C<_stats_class>, C<__composed_request_class>,
C<__composed_response_class> and the rest of Catalyst's class data.

=head2 How they are found

C<mk_classdata> installs two methods per attribute, C<$name> and
C<_${name}_accessor>, sharing one closure. Nothing else in the tree has that
shape, so a pair of methods in one package whose bodies are the same coderef and
whose names differ by exactly that pattern is a class data accessor. Recognising
them structurally rather than by a hardcoded list means a plugin's own
C<mk_classdata> attributes are sealed too.

The accessors live in the base classes, C<Catalyst>, C<Catalyst::Component>,
C<Catalyst::Controller>, and are shared by every application in the process, so
the constant cannot be installed over them. It is installed into each concrete
class instead, where it shadows the inherited closure for that class only.

=head2 What stays correct

=over 4

=item * A write unseals. The original accessor goes back into both globs, the
write proceeds through it, and that attribute is never sealed again. This is not
optional: C<Catalyst::prepare> writes C<context_class> and
C<_finalized_psgi_app> writes C<_psgi_app>, both after setup.

=item * C<context_class> is pre-warmed at seal time with the same assignment
C<prepare> would make, so the one attribute Catalyst writes on every first
request is already settled and stays sealed.

=item * A subclass created after sealing inherits the XSUB but not the answer.
The accessor compares the invocant against the class the value was resolved for
and delegates to the original when they differ, so a subclass with class data of
its own still gets its own.

=back

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

