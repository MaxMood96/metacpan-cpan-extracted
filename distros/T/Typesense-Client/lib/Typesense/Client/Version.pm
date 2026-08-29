package Typesense::Client::Version;
$Typesense::Client::Version::VERSION = '0.001';
use v5.38;
use warnings;
use experimental 'signatures';

use overload '""' => sub { $_[0]->version_string }, fallback => 1;

## The server version, as reported by GET /debug, in a form you can compare.
##
## Typesense is NOT strictly semver: 28.0 reports itself as "28.0", and release
## candidates as "28.0.rc35". So the parse is deliberately lenient - leading
## numeric components are read, missing ones are zero, and anything trailing is
## kept in version_string but ignored for comparison. A client that dies
## because the server named itself in an unexpected way would be worse than
## useless.

sub new ($class, %args) {
    my $string = $args{version_string} // '';
    my @parts  = ( $string =~ /\A(\d+)(?:\.(\d+))?(?:\.(\d+))?/ );

    return bless {
        version_string => $string,
        major          => $parts[0] // 0,
        minor          => $parts[1] // 0,
        patch          => $parts[2] // 0,
    }, $class;
}

sub version_string { $_[0]{version_string} }
sub major          { $_[0]{major} }
sub minor          { $_[0]{minor} }
sub patch          { $_[0]{patch} }

## A zero-padded string, so version comparison is a plain string comparison and
## 28.0 sorts after 9.0 (which it does not do numerically, and does not do at
## all as a plain string).
sub comparator ($self) {
    return sprintf '%03d%03d%03d', $self->{major}, $self->{minor}, $self->{patch};
}

sub is_at_least ($self, $wanted) {
    $wanted = __PACKAGE__->new(version_string => $wanted) unless ref $wanted;
    return $self->comparator ge $wanted->comparator;
}

1;

__END__

=head1 NAME

Typesense::Client::Version - the server version, in a comparable form

=head1 SYNOPSIS

    my $v = $ts->server_version;

    say "$v";                          # 28.0
    say $v->major;                     # 28

    if ( $v->is_at_least('27.0') ) {
        # the analytics API changed shape more than once; gate on the server
    }

=head1 DESCRIPTION

Returned by L<Typesense::Client/server_version>, which reads C<GET /debug>.

Typesense does not report a strict semantic version: 28.0 calls itself
C<28.0>, and release candidates C<28.0.rc35>. This class reads the leading
numeric components, treats the missing ones as zero, and keeps whatever else
was there in L</version_string>. It never dies on an unexpected version
string - a search client that refuses to work because the server named itself
oddly would be worse than one that carries on.

=head1 METHODS

=head2 version_string

The string exactly as the server reported it. The object also stringifies to
this, so C<"$version"> works.

=head2 major, minor, patch

The numeric components, as integers. Missing components are C<0>.

=head2 comparator

    if ( $one->comparator ge $two->comparator ) { ... }

A zero-padded string such as C<028000000>, so that two versions compare
correctly with C<lt> and C<ge>. Numeric comparison would make C<28.0> and
C<28.0.1> equal, and plain string comparison would sort C<28.0> before C<9.0>.

=head2 is_at_least

    if ( $ts->server_version->is_at_least('28.0') ) { ... }

True when this version is the same as, or newer than, the argument. Takes
either a version string or another Typesense::Client::Version.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
