package Statocles::Types;
our $VERSION = '0.098';
# ABSTRACT: Type constraints and coercions for Statocles

use strict;
use warnings;
use feature qw( :5.10 );
use Type::Library -base, -declare => qw(
    StoreType ThemeType LinkType LinkArray LinkHash LinkTree LinkTreeArray
    DateTimeObj DateStr DateTimeStr
    PersonType
    PagePath
);
use Type::Utils -all;
use Types::Standard -types;
use DateTime::Moonpig;
use Mojo::Path;

class_type StoreType, { class => "Statocles::Store" };
coerce StoreType, from Str, via { Statocles::Store->new( path => $_ ) };
coerce StoreType, from InstanceOf['Path::Tiny'], via { Statocles::Store->new( path => $_ ) };

class_type ThemeType, { class => "Statocles::Theme" };
coerce ThemeType, from Str, via { require Statocles::Theme; Statocles::Theme->new( store => $_ ) };
coerce ThemeType, from InstanceOf['Path::Tiny'], via { require Statocles::Theme; Statocles::Theme->new( store => $_ ) };

class_type LinkType, { class => "Statocles::Link" };
coerce LinkType, from HashRef, via { Statocles::Link->new( $_ ) };
coerce LinkType, from Str, via { Statocles::Link->new( href => $_ ) };

class_type LinkTree, { class => "Statocles::Link::Tree" };
coerce LinkTree, from HashRef, via { Statocles::Link::Tree->new( $_ ) };
coerce LinkTree, from Str, via { Statocles::Link::Tree->new( href => $_ ) };

class_type PersonType, { class => 'Statocles::Person' };
coerce PersonType, from HashRef, via { Statocles::Person->new( $_ ) };
coerce PersonType, from Str, via { Statocles::Person->new( $_ ) };

declare LinkArray, as ArrayRef[LinkType], coerce => 1;
coerce LinkArray, from ArrayRef[HashRef|Str],
    via {
        [ map { ref $_ eq 'HASH' && exists $_->{children} ? LinkTree->coerce($_) : LinkType->coerce( $_ ) } @$_ ];
    };

declare LinkHash, as HashRef[LinkArray], coerce => 1;
# We need the parens in this "from" type union to fix an issue in Perl
# < 5.14 and Type::Tiny 1.000005
# (https://github.com/tobyink/p5-type-tiny/issues/29)
coerce LinkHash, from HashRef[(ArrayRef[HashRef|Str]|HashRef)|Str],
    via {
        my %hash = %$_;
        my $out = {
            ( map {; $_ => LinkArray->coerce( ref $hash{ $_ } ne 'ARRAY' ? [ $hash{ $_ } ] : $hash{ $_ }  ) } keys %hash ),
        };
        return $out;
    };

declare LinkTreeArray, as ArrayRef[LinkTree], coerce => 1;
coerce LinkTreeArray, from ArrayRef[HashRef|Str],
    via {
        [ map { LinkTree->coerce( $_ ) } @$_ ];
    };

class_type DateTimeObj, { class => 'DateTime::Moonpig' };
declare DateStr, as Str, where { m{^\d{4}-?\d{2}-?\d{2}$} };
declare DateTimeStr, as Str, where { m{^\d{4}-?\d{2}-?\d{2}[T ]\d{2}:?\d{2}:?\d{2}} };
coerce DateTimeObj, from DateStr, via {
    my ( $y, $m, $d ) = $_ =~ /^(\d{4})[-]?(\d{2})[-]?(\d{2})$/;
    DateTime::Moonpig->new(
        year => $y,
        month => $m,
        day => $d,
    );
};
coerce DateTimeObj, from DateTimeStr, via {
    my ( $y, $m, $d, $h, $n, $s ) = $_ =~ /^(\d{4})[-]?(\d{2})[-]?(\d{2})[T ]?(\d{2}):?(\d{2}):?(\d{2})/;
    DateTime::Moonpig->new(
        year => $y,
        month => $m,
        day => $d,
        hour => $h,
        minute => $n,
        second => $s,
    );
};

class_type PagePath, { class => "Mojo::Path" };
coerce PagePath, from Str, via { Mojo::Path->new( $_ ) };

sub DateTime::Moonpig::tzoffset {
    my ( $self ) = @_;
    warn "The tzoffset shim method will be removed in Statocles version 2.0. See Statocles::Help::Upgrading for instructions to remove this warning.\n";
    return $self->offset * 100;
}

# Down here to resolve circular dependencies
require Statocles::Store;
require Statocles::Link;
require Statocles::Link::Tree;
require Statocles::Person;
require Statocles::Image;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Statocles::Types - Type constraints and coercions for Statocles

=head1 VERSION

version 0.098

=head1 SYNOPSIS

    use Statocles::Class;
    use Statocles::Types qw( :all );

    has store => (
        isa => Store,
        coerce => Store->coercion,
    );

    has theme => (
        isa => Theme,
        coerce => Theme->coercion,
    );

    has link => (
        isa => LinkType,
        coerce => LinkType->coercion,
    );
    has links => (
        isa => LinkArray,
        coerce => LinkArray->coercion,
    );
    has nav => (
        isa => LinkHash,
        coerce => LinkHash->coercion,
    );

    has date => (
        isa => DateTimeObj,
        coerce => DateTimeObj->coercion,
    );

    has path => (
        isa => PagePath,
        coerce => PagePath->coercion,
    );

=head1 DESCRIPTION

This is a L<type library|Type::Tiny::Manual::Library> for common Statocles types.

=head1 TYPES

=head2 Store

A L<Statocles::Store> object.

This can be coerced from any L<Path::Tiny> object or any String, which will be
used as the filesystem path to the store's documents (the L<path
attribute|Statocles::Store/path>). The coercion creates a
L<Statocles::Store> object.

=head2 Theme

A L<Statocles::Theme> object.

This can be coerced from any L<Path::Tiny> object or any String, which will be
used as the L<store attribute|Statocles::Theme/store> (which will then be given
to the Store's path attribute).

=head2 LinkType

A L<Statocles::Link> object.

This can be coerced from any HashRef.

=head2 LinkArray

An arrayref of L<Statocles::Link> objects.

This can be coerced from any ArrayRef of HashRefs.

=head2 LinkHash

A hashref of arrayrefs of L<Statocles::Link> objects. Useful for the named links like
L<site navigation|Statocles::Site/nav>.

This can be coerced from any HashRef of ArrayRef of HashRefs.

=head2 DateTimeObj

A L<DateTime::Moonpig> object representing a date/time. This can be coerced from a
C<YYYY-MM-DD> string or a C<YYYY-MM-DD HH:MM:SS> string.

=head2 PagePath

A L<Mojo::Path> object representing the path portion of a URL. It can
be coerced from a suitable string.

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
