package Alien::CLIPS;

use strict;
use warnings;

our @ISA;

BEGIN {
  my $ok = eval {
    require Alien::Base;
    @ISA = qw(Alien::Base);
    1;
  };
  @ISA = () if !$ok;
}

sub dynamic_libs {
  return grep { defined && length } (
    $ENV{INLINE_CLIPS_LIB},
    $ENV{ALIEN_CLIPS_LIB},
  );
}

sub bin_dir {
  return grep { defined && length } (
    $ENV{INLINE_CLIPS_BIN},
    $ENV{ALIEN_CLIPS_BIN},
  );
}

1;

__END__

=head1 NAME

Alien::CLIPS - Find or build CLIPS using Alien::Build

=head1 SYNOPSIS

  use Alien::CLIPS;

  # Directories / libraries that Alien::CLIPS can discover
  my @bin_dirs = Alien::CLIPS->bin_dir;
  my @libs     = Alien::CLIPS->dynamic_libs;

  print "CLIPS binary dir: @bin_dirs\n";
  print "CLIPS library:    @libs\n";

=head1 DESCRIPTION

C<Alien::CLIPS> is the companion Alien module for L<Inline::CLIPS>.  Its job
is to tell Perl where the CLIPS executable and shared library live.  When the
full L<Alien::Build> infrastructure is available, this module prefers a system
CLIPS installation and can fall back to building CLIPS from the FuzzyCLIPS
source repository.

Even without L<Alien::Build>, the module provides a small standalone
implementation that reads environment variables so that a CLIPS installation
can be located without rebuilding it.

=head1 DISCOVERY ORDER

=head2 Executable (C<bin_dir>)

The binary directory is resolved from, in order:

=over 4

=item 1.

C<INLINE_CLIPS_BIN>

=item 2.

C<ALIEN_CLIPS_BIN>

=item 3.

L<Alien::Base> system probe results (when Alien::Build is active)

=back

The actual C<clips> binary is expected to be inside this directory.

=head2 Library (C<dynamic_libs>)

The shared library path is resolved from, in order:

=over 4

=item 1.

C<INLINE_CLIPS_LIB>

=item 2.

C<ALIEN_CLIPS_LIB>

=item 3.

L<Alien::Base> probe results (when Alien::Build is active)

=back

=head1 INSTALLATION

=head2 Using a system CLIPS

If CLIPS is already installed, make sure the C<clips> binary is on C<$PATH>,
or set one of the environment variables below.  No build step is required.

=head2 Building CLIPS from source

When no system CLIPS is found and L<Alien::Build> is active, the Alien build
will fetch and build CLIPS from:

  L<https://github.com/jtrujil43/FuzzyCLIPS>

This is normally triggered automatically when you install this distribution
with a CPAN client:

  cpanm Inline::CLIPS

=head2 Manual environment-based configuration

You can point both L<Inline::CLIPS> and L<Alien::CLIPS> at a custom CLIPS
installation without rebuilding anything:

  export INLINE_CLIPS_EXECUTABLE=/opt/clips/6.4.2/clips
  export INLINE_CLIPS_BIN=/opt/clips/6.4.2/bin
  export INLINE_CLIPS_LIB=/opt/clips/6.4.2/lib/libclips.so

If only the C<Alien::CLIPS> form is needed, use the C<ALIEN_> prefixes:

  export ALIEN_CLIPS_BIN=/opt/clips/6.4.2/bin
  export ALIEN_CLIPS_LIB=/opt/clips/6.4.2/lib/libclips.so

=head1 METHODS

=head2 C<bin_dir>

Returns the list of directories that may contain the CLIPS binary.  In the
standalone fallback this is either the C<INLINE_CLIPS_BIN> directory or the
C<ALIEN_CLIPS_BIN> directory, whichever is set.

=head2 C<dynamic_libs>

Returns the list of CLIPS shared library paths.  In the standalone fallback
this is either the C<INLINE_CLIPS_LIB> file or the C<ALIEN_CLIPS_LIB> file,
whichever is set.

=head1 SEE ALSO

=over 4

=item L<Inline::CLIPS>

The Perl module that uses C<Alien::CLIPS> to locate CLIPS.

=item CLIPS home page

L<https://www.clipsrules.net/>

=item FuzzyCLIPS source

L<https://github.com/jtrujil43/FuzzyCLIPS>

=back

=head1 AUTHOR

Inline-CLIPS contributors.

=head1 LICENSE

This library is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.
