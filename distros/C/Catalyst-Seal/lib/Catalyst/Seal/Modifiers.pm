package Catalyst::Seal::Modifiers;

use strict;
use warnings;

use Scalar::Util ();
use Sub::Util 1.40 ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

our @SKIP_CLASS = (qr/\A Catalyst::Log (?: :: | \z ) /x);

my %FLAT;

sub flattened {
    _reap();
    return map { "$_->{class}::$_->{name}" } values %FLAT;
}

sub _installed {
    my ($class, $name) = @_;
    no strict 'refs';
    return *{"${class}::${name}"}{CODE};
}

sub _reap {
    for my $addr (keys %FLAT) {
        my $rec = $FLAT{$addr};
        my $installed = _installed($rec->{class}, $rec->{name});
        next if $installed && Scalar::Util::refaddr($installed) == Scalar::Util::refaddr($rec->{flat});
        delete $FLAT{$addr};
    }
    return;
}

sub _skip_class {
    my ($class) = @_;
    for my $re (@SKIP_CLASS) {
        return 1 if $class =~ $re;
    }
    return 0;
}

sub _candidate_classes {
    my ($app) = @_;

    my @roots = ($app);
    my $components = eval { $app->components } || {};
    push @roots, map { ref $_ || $_ } values %$components;

    for my $acc (qw(request_class response_class context_class
                    dispatcher_class engine_class stats_class)) {
        next unless $app->can($acc);
        my $class = eval { $app->$acc };
        push @roots, $class if defined $class && !ref $class;
    }

    my (%seen, @classes);
    for my $root (@roots) {
        next unless defined $root && length $root;
        my $meta = Class::MOP::class_of($root) or next;
        next unless $meta->isa('Class::MOP::Class');
        for my $class ($meta->linearized_isa) {
            next if $seen{$class}++;
            push @classes, $class;
        }
    }
    return @classes;
}


sub _wrapped_methods {
    my ($meta) = @_;

    my $map = eval { $meta->_method_map };
    unless (ref $map eq 'HASH') {
        Catalyst::Seal::note(
            "no method map on " . $meta->name . ", its modifiers were not flattened");
        return ();
    }

    my @wrapped;
    for my $name (sort keys %$map) {
        my $method = $map->{$name};
        next unless Scalar::Util::blessed($method)
            && $method->isa('Class::MOP::Method::Wrapped');
        push @wrapped, [ $name, $method ];
    }
    return @wrapped;
}

sub _modifier_table {
    my ($method) = @_;
    my $table = $method->{modifier_table};
    return undef unless ref $table eq 'HASH';
    return undef unless ref $table->{cache}  eq 'CODE';
    return undef unless ref $table->{before} eq 'ARRAY';
    return undef unless ref $table->{after}  eq 'ARRAY';
    return undef unless ref $table->{around} eq 'HASH';
    return $table;
}

sub flatten_class {
    my ($class) = @_;

    return 0 if _skip_class($class);

    my $meta = Class::MOP::class_of($class) or return 0;
    return 0 unless $meta->isa('Class::MOP::Class');

    my @wrapped = _wrapped_methods($meta) or return 0;
    unless ($meta->is_immutable) {
        Catalyst::Seal::note(
            "$class is mutable, its " . scalar(@wrapped) . " wrapped method(s) were not flattened");
        return 0;
    }

    my $count = 0;
    $count += _flatten_method($class, @$_) for @wrapped;
    return $count;
}

sub _flatten_method {
    my ($class, $name, $method) = @_;

    return 0 if $FLAT{ Scalar::Util::refaddr $method };

    my $table = _modifier_table($method);
    unless ($table) {
        Catalyst::Seal::note(
            "${class}::${name} has a modifier table this release does not know, not flattened");
        return 0;
    }

    my $installed = _installed($class, $name);
    unless ($installed && Scalar::Util::refaddr($installed) == Scalar::Util::refaddr($method->body)) {
        Catalyst::Seal::note(
            "${class}::${name} is not the body the metaclass has, not flattened");
        return 0;
    }

    my $flat = $table->{cache};

    Sub::Util::set_subname(
        $method->package_name . '::_wrapped_' . $method->name => $flat)
        unless Scalar::Util::refaddr($flat) == Scalar::Util::refaddr($table->{orig});

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${class}::${name}"} = $flat;
    }

    $FLAT{ Scalar::Util::refaddr $method } = {
        class  => $class,
        name   => $name,
        flat   => $flat,
        method => $method,
    };
    _install_unflatten_hook();
    return 1;
}

sub unflatten_method {
    my ($method) = @_;

    return 0 unless Scalar::Util::blessed($method);
    my $rec = $FLAT{ Scalar::Util::refaddr $method } or return 0;
    my ($class, $name) = ($rec->{class}, $rec->{name});

    my $installed = _installed($rec->{class}, $rec->{name});
    if ($installed && Scalar::Util::refaddr($installed) == Scalar::Util::refaddr($rec->{flat})) {
        no strict 'refs';
        no warnings 'redefine';
        *{"${class}::${name}"} = $method->body;
        Catalyst::Seal::note("${class}::${name} un-flattened, a modifier was added after seal");
    }
    else {
        Catalyst::Seal::note(
            "${class}::${name} was replaced after it was flattened, left alone");
    }

    delete $FLAT{ Scalar::Util::refaddr $method };
    return 1;
}

my $HOOKED = 0;

sub _install_unflatten_hook {
    return if $HOOKED++;
    for my $kind (qw(before after around)) {
        my $sym  = "Class::MOP::Method::Wrapped::add_${kind}_modifier";
        my $orig = do { no strict 'refs'; \&{$sym} };
        no strict 'refs';
        no warnings 'redefine';
        *{$sym} = sub {
            unflatten_method($_[0]);
            goto &$orig;
        };
    }
    return;
}

my @GUARDED_SETTERS = qw(status headers content_encoding content_length content_type);

my %GUARD_DONE;

sub _short_circuit_guard {
    my ($key, $names, $args) = @_;

    return 0 if $GUARD_DONE{$key}++;

    my $meta = Class::MOP::class_of('Catalyst::Response') or return 0;

    my (@lists, %count);
    for my $name (@$names) {
        my $method = eval { $meta->get_method($name) };
        unless (Scalar::Util::blessed($method) && $method->isa('Class::MOP::Method::Wrapped')) {
            Catalyst::Seal::note("Catalyst::Response::$name is not wrapped, guard not patched");
            return 0;
        }
        my $table = _modifier_table($method) or do {
            Catalyst::Seal::note("Catalyst::Response::$name has an unknown modifier table, guard not patched");
            return 0;
        };
        my $before = $table->{before};
        unless (@$before == 1) {
            Catalyst::Seal::note(sprintf
                "Catalyst::Response::%s has %d before modifiers, not the one this patch was written against",
                $name, scalar @$before);
            return 0;
        }
        push @lists, $before;
        $count{ Scalar::Util::refaddr $before->[0] }++;
    }

    unless (keys(%count) == 1) {
        Catalyst::Seal::note(
            "the Catalyst::Response guard is not one modifier shared by @$names, not patched");
        return 0;
    }

    my $stock = $lists[0][0];
    my $fast  = sub { return unless @_ > $args; goto &$stock };
    $_->[0] = $fast for @lists;
    return 1;
}

Catalyst::Seal::register_step('response-guard' => sub {
    require Class::MOP;
    require Catalyst::Response;

    _short_circuit_guard('Catalyst::Response::setter_guard',
        \@GUARDED_SETTERS, 1);
    _short_circuit_guard('Catalyst::Response::header_guard',
        ['header'], 2);
    return;
});

Catalyst::Seal::register_step('modifiers' => sub {
    my ($app) = @_;
    require Class::MOP;
    require Class::MOP::Method::Wrapped;
    _reap();
    my $count = 0;
    $count += flatten_class($_) for _candidate_classes($app);
    Catalyst::Seal::note("flattened $count wrapped method(s)") if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Modifiers - install the composed body of a wrapped method directly

=head1 DESCRIPTION

A method carrying a C<before>, C<after> or C<around> modifier is a
L<Class::MOP::Method::Wrapped>, and what gets installed in the symbol table is
not the composed body but a trampoline:

    sub {
        my $wrapped
            = set_subname( "${pkg_name}::_wrapped_${method_name}" =>
                $modifier_table->{cache} );
        return $wrapped->(@_) ;
    }

C<cache> is the composed body, rebuilt by Class::MOP whenever a modifier is
added. The trampoline exists so that a call always reaches the current one, and
it pays for that with one extra subroutine call and one C<set_subname> on every
invocation of every wrapped method, for the life of the process, to attach a
name that has been constant since C<wrap> returned.

A bare Catalyst application has twenty-three of them, and the ten that are on
the request path, among them C<Catalyst::Response::status>,
C<Catalyst::Response::headers>, C<Catalyst::Request::parameters> and three
C<BUILD> methods, make 36 C<set_subname> calls per request between them.

After C<setup_finalize> the modifier lists are final, so this step takes
C<cache>, names it once, and installs it in the glob. The trampoline is gone
and nothing else changes: the sub that runs is the same sub that the
trampoline would have called.

=head2 When a modifier does arrive late

A plugin that applies a role at first request adds to a modifier table this
step has already read, and Class::MOP rebuilds C<cache> without knowing that
the old one is now installed under the method's own name. So every entry point
that rebuilds it, C<add_before_modifier>, C<add_after_modifier> and
C<add_around_modifier>, is wrapped: the method un-flattens back to the stock
trampoline before the modifier is added, and stays that way.

=cut

=head2 flattened

    my @names = Catalyst::Seal::Modifiers::flattened();

The C<Class::Name::method> of every method currently flattened, in no
particular order.

=cut

=head2 flatten_class

    my $count = Catalyst::Seal::Modifiers::flatten_class('Catalyst::Response');

Flattens every wrapped method the class declares itself, and returns how many.
A class that is still mutable is left alone: mutable is the state a class is in
while it is still being built, and a method installed here would be replaced by
the next thing that touched it.

=cut

=head2 unflatten_method

    Catalyst::Seal::Modifiers::unflatten_method($wrapped);

Puts the stock trampoline back for one L<Class::MOP::Method::Wrapped>, so that
modifiers added from here on are seen. Returns true if it did anything. Called
for you when a modifier is added to a method this step flattened.

=cut

=head2 The response header guard

L<Catalyst::Response> carries a C<before> modifier on C<status>, C<headers>,
C<content_encoding>, C<content_length> and C<content_type> that warns when one
of them is used as a setter after the headers have been finalised, and a second
one on C<header> that does the same. Both conditions end in C<&& @_>, so on a
read the warning cannot fire, but the terms before it are evaluated first and
each one is an accessor call. That is 40 calls per request asking whether a
response that has not been finalised has been finalised.

This step replaces the modifier with one that returns immediately unless it was
called as a setter, and otherwise calls the stock guard with the arguments it
was given. Reordering a condition whose last term already decides it is not a
behaviour change, and the warning itself is the original.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

