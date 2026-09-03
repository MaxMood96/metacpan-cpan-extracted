package Catalyst::Seal::Immutable;

use strict;
use warnings;

use Catalyst::Seal ();

our $VERSION = '0.01';

sub _classes_for {
    my ($app) = @_;
    my @classes = ($app);

    my $components = eval { $app->components } || {};
    for my $comp (values %$components) {
        push @classes, ref $comp || $comp;
    }

    my %seen;
    return grep { !$seen{$_}++ } grep { defined && length } @classes;
}

sub _seal_class {
    my ($class) = @_;

    my $meta = Class::MOP::class_of($class);
    unless ($meta) {
        Catalyst::Seal::note("$class has no metaclass, not made immutable");
        return 0;
    }
    unless ($meta->isa('Class::MOP::Class')) {
        Catalyst::Seal::note("$class metaclass is not a Class::MOP::Class, not made immutable");
        return 0;
    }
    return 0 if $meta->is_immutable;

    my %opts = eval { $meta->immutable_options };
    %opts = () unless %opts;

    my $ok = eval { $meta->make_immutable(%opts); 1 };
    unless ($ok) {
        Catalyst::Seal::note("could not make $class immutable: $@");
        return 0;
    }
    return 1;
}

Catalyst::Seal::register_step('immutable' => sub {
    my ($app) = @_;
    require Class::MOP;

    my $done = 0;
    for my $class (_classes_for($app)) {
        $done += _seal_class($class);
    }
    Catalyst::Seal::note("made $done class(es) immutable") if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Immutable - make the application class and its components immutable

=head1 DESCRIPTION

C<catalyst.pl> generates C<__PACKAGE__-E<gt>meta-E<gt>make_immutable> into
controllers but not into F<MyApp.pm>, and the application class is also the
per-request context class: C<Catalyst::prepare> builds one with
C<$class-E<gt>context_class-E<gt>new>. A mutable application class means every
request is constructed through C<Class::MOP::Class::_construct_instance>, with
one C<initialize_instance_slot> call per attribute, plus C<BUILDALL> and
C<find_all_methods_by_name>.

On a bare application with eighteen attributes that is 283us against 231us per
request, measured with C<bench/dispatch.pl> from the Punk distribution.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

