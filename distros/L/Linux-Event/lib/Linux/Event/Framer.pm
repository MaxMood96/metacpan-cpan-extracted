package Linux::Event::Framer;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.103';

use Carp qw(croak);

sub import ($class, $keyword = undef, @args) {
    my $target = caller;
    croak "use $class requires a built-in framer name"
        if !defined($keyword) || $keyword eq '';
    croak "invalid framer name '$keyword'"
        if $keyword !~ /\A[A-Za-z_][A-Za-z0-9_]*\z/;
    croak "$target must inherit from Linux::Event::Stream before declaring a framer"
        if !$target->isa('Linux::Event::Stream');

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
    Linux::Event::Stream->_declare_framer($target, $definition);
    return;
}

1;

__END__

=head1 NAME

Linux::Event::Framer - declare native framing for a Stream subclass

=head1 SYNOPSIS

  package LineStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_message ($stream, $message) {
      $stream->send($message);
  }

=head1 DESCRIPTION

The import declares one built-in native framing rule for the calling Stream
subclass. The first argument is the exact final component of a package below
C<Linux::Event::Framer>. Linux::Event constructs that package name,
loads it, validates its definition, and incorporates it into the subclass's
cached native descriptor.

There is deliberately no central keyword table and no per-connection framer
object. A Stream subclass describes one protocol type; every instance keeps
only its changing parser state.

=head1 DECLARATIONS

  use Linux::Event::Framer 'Delimiter', "\r\n", # required delimiter
      max_frame => 1_048_576;                    # optional

  use Linux::Event::Framer 'Fixed',
      size => 32; # required

  use Linux::Event::Framer 'LengthPrefix',
      bytes     => 2,         # optional; default 4
      endian    => 'big',     # default
      max_frame => 1_048_576; # optional

  use Linux::Event::Framer 'U32BE',
      max_frame => 16 * 1024 * 1024; # optional

  use Linux::Event::Framer 'Netstring',
      max_frame => 1_048_576; # optional

  use Linux::Event::Framer 'Varint',
      max_frame => 1_048_576; # optional

  use Linux::Event::Framer 'DecimalLength',
      separator => ' ',       # default
      max_frame => 1_048_576; # optional

=head1 RAW STREAMS

A subclass that does not import a framer is a raw Stream type and must define
C<on_data>. A framed subclass must define C<on_message>. See
L<Linux::Event::Stream> and F<docs/FRAMING.md>.

=head1 EXTENDING THE BUILT-IN FAMILY

The declaration loader derives the implementation package from the final name
instead of maintaining a duplicate keyword registry. New native framing
semantics still require corresponding XS parser support; arbitrary Perl
C<next_frame> objects are not accepted. Applications with unusual protocols
should use a raw Stream's C<on_data>, while generally useful framing families
can be added to Linux::Event as native built-ins.

=cut
