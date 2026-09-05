package Linux::Event::Framer;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use Carp qw(croak);
use Linux::Event::_ByteStream::Descriptor ();

sub _byte_stream_base ($target) {
    return 'Linux::Event::_ByteStream'
        if $target->isa('Linux::Event::_ByteStream');
    return undef;
}

sub import ($class, $keyword = undef, @args) {
    return if !defined($keyword) && !@args;

    my $target = caller;
    croak "use $class requires a built-in framer name"
        if !defined($keyword) || $keyword eq '';
    croak "invalid framer name '$keyword'"
        if $keyword !~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;

    my $base = _byte_stream_base($target);
    croak "$target must be a Linux::Event byte-stream subclass before declaring a framer"
        if !defined $base;

    my $package = "${class}::${keyword}";
    (my $file = "$package.pm") =~ s{::}{/}g;
    eval { require $file; 1 } or do {
        my $error = $@ || "unable to load $package";
        $error =~ s/\s+\z//;
        croak "cannot declare framer '$keyword': $error";
    };

    my $builder = $package->can('_build_definition')
        or croak "$package is not a Linux::Event built-in framer";
    my $definition = $builder->($package, @args);
    croak "$package returned an invalid framer definition"
        if ref($definition) ne 'HASH'
        || ref($definition->{native}) ne 'HASH'
        || ref($definition->{frame}) ne 'CODE';

    $definition->{package} = $package;
    Linux::Event::_ByteStream::Descriptor::declare_framer(
        $base, $target, $definition,
    );
    return;
}

sub declare_native_consumer ($class, $target, $definition) {
    croak 'declare_native_consumer(): must be called as a class method'
        if ref $class;
    croak 'declare_native_consumer(): target class is required'
        if !defined($target) || ref($target) || $target eq '';

    my $base = _byte_stream_base($target);
    croak "$target must be a Linux::Event byte-stream subclass before declaring a native consumer"
        if !defined $base;

    Linux::Event::_ByteStream::Descriptor::declare_consumer(
        $base, $target, $definition,
    );
    return;
}

1;

__END__

=head1 NAME

Linux::Event::Framer - native framing for ordered-byte I/O

=head1 SYNOPSIS

  package LineSocket;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($stream, $message) {
      $stream->send($message);
  }

=head1 DESCRIPTION

C<Linux::Event::Framer> declares native framing policy for an ordered-byte
Linux::Event subclass. Pipes, TTYs, and C<SOCK_STREAM> connections share the
same framing engine. The declaration is resolved once per concrete subclass;
there is no per-connection framer object.

=head1 BUILT-IN FRAMERS

Supported declarations include C<Delimiter>, C<Fixed>, C<LengthPrefix>,
C<U32BE>, C<Netstring>, C<Varint>, and C<DecimalLength>. Each framer accepts
its own framing options; see F<docs/FRAMING.md> and the corresponding framer
module POD.

Readable classes without a framer use C<on_data>. Framed classes normally use
C<on_message>, or C<on_messages> when explicit message batching is enabled.

=head1 NATIVE CONSUMERS

External XS extensions may consume complete framed messages without routing
them through a Perl C<on_message> callback:

  Linux::Event::Framer->declare_native_consumer(
      'My::FramedConnection',
      {
          provider           => $provider_lifetime_token,
          abi_version        => $abi_version,
          operations_address => $native_table_address,
      },
  );

This is an extension boundary for high-performance integrations such as
coroutine or awaitable layers. It is independent of the public Perl class
names and must not depend on retired implementation packages.

See F<docs/ORDERED-BYTE-CONSUMER-ABI.md>.

=cut
