package Venus::Path;

use 5.018;

use strict;
use warnings;

use Venus::Class 'base', 'with';

base 'Venus::Kind::Utility';

with 'Venus::Role::Valuable';
with 'Venus::Role::Buildable';
with 'Venus::Role::Accessible';
with 'Venus::Role::Explainable';

use overload (
  '""' => 'explain',
  'eq' => sub{$_[0]->value eq "$_[1]"},
  'ne' => sub{$_[0]->value ne "$_[1]"},
  'qr' => sub{qr/@{[quotemeta($_[0]->value)]}/},
  '~~' => 'explain',
  fallback => 1,
);

# HOOKS

sub _exitcode {
  $? >> 8;
}

# METHODS

sub assertion {
  my ($self) = @_;

  my $assertion = $self->SUPER::assertion;

  $assertion->match('string')->format(sub{
    (ref $self || $self)->new($_)
  });

  return $assertion;
}

sub absolute {
  my ($self) = @_;

  require File::Spec;

  return $self->class->new(File::Spec->rel2abs($self->get));
}

sub basename {
  my ($self) = @_;

  require File::Basename;

  return File::Basename::basename($self->get);
}

sub child {
  my ($self, $path) = @_;

  require File::Spec;

  my @parts = File::Spec->splitdir($path);

  return $self->class->new(File::Spec->catfile($self->get, @parts));
}

sub chmod {
  my ($self, $mode) = @_;

  my $path = $self->get;

  CORE::chmod($mode, $path);

  return $self;
}

sub chown {
  my ($self, @args) = @_;

  my $path = $self->get;

  CORE::chown((map $_||-1, @args[0,1]), $path);

  return $self;
}

sub children {
  my ($self) = @_;

  require File::Spec;

  my @paths = map $self->glob($_), '.??*', '*';

  return wantarray ? (@paths) : \@paths;
}

sub copy {
  my ($self, $path) = @_;

  require File::Copy;

  File::Copy::copy("$self", "$path")
    or $self->error({throw => 'error_on_copy', error => $!, path => $path});

  return $self;
}

sub default {
  require Cwd;

  return Cwd::getcwd();
}

sub directories {
  my ($self) = @_;

  my @paths = grep -d, $self->children;

  return wantarray ? (@paths) : \@paths;
}

sub exists {
  my ($self) = @_;

  return int!!-e $self->get;
}

sub explain {
  my ($self) = @_;

  return $self->get;
}

sub extension {
  my ($self, $value) = @_;

  my $basename = $self->basename;

  my ($filename, $suffix) = $basename =~ /^([^\.]+)\.?(.*)$/;

  return $suffix || undef if !$value;

  return $self->sibling(join '.', $filename, $value);
}

sub find {
  my ($self, $expr) = @_;

  $expr = '.*' if !$expr;

  $expr = qr/$expr/ if ref($expr) ne 'Regexp';

  my @paths;

  push @paths, grep {
    $_ =~ $expr
  } map {
    $_->is_directory ? $_->find($expr) : $_
  }
  $self->children;

  return wantarray ? (@paths) : \@paths;
}

sub files {
  my ($self) = @_;

  my @paths = grep -f, $self->children;

  return wantarray ? (@paths) : \@paths;
}

sub glob {
  my ($self, $expr) = @_;

  require File::Spec;

  $expr ||= '*';

  my @paths = map $self->class->new($_),
    CORE::glob +File::Spec->catfile($self->absolute, $expr);

  return wantarray ? (@paths) : \@paths;
}

sub is_absolute {
  my ($self) = @_;

  require File::Spec;

  return int!!(File::Spec->file_name_is_absolute($self->get));
}

sub is_directory {
  my ($self) = @_;

  my $path = $self->get;

  return int!!(-e $path && -d $path);
}

sub is_file {
  my ($self) = @_;

  my $path = $self->get;

  return int!!(-e $path && !-d $path);
}

sub is_relative {
  my ($self) = @_;

  return int!$self->is_absolute;
}

sub lines {
  my ($self, $separator, $binmode) = @_;

  $separator //= "\n";

  return [split /$separator/, $binmode ? $self->read($binmode) : $self->read];
}

sub lineage {
  my ($self) = @_;

  require File::Spec;

  my @parts = File::Spec->splitdir($self->get);

  my @paths = ((
    reverse map $self->class->new(File::Spec->catfile(@parts[0..$_])), 1..$#parts
    ), $self->class->new($parts[0]));

  return wantarray ? (@paths) : \@paths;
}

sub open {
  my ($self, @args) = @_;

  my $path = $self->get;

  require IO::File;

  my $handle = IO::File->new;

  $handle->open($path, @args)
    or $self->error({throw => 'error_on_open', path => $path, error => $!});

  return $handle;
}

sub mkcall {
  my ($self, @args) = @_;

  require File::Spec;

  my $path = File::Spec->catfile(File::Spec->splitdir($self->get));

  my $result;

  require Venus::Os;

  my $args = join ' ', map Venus::Os->quote($_), grep defined, @args;

  (defined($result = ($args ? qx($path $args) : qx($path))))
    or $self->error({
      throw => 'error_on_mkcall',
      error => $!,
      exit_code => _exitcode(),
      path => $path,
    });

  chomp $result;

  return wantarray ? ($result, _exitcode()) : $result;
}

sub mkdir {
  my ($self, $mode) = @_;

  my $path = $self->get;

  ($mode ? CORE::mkdir($path, $mode) : CORE::mkdir($path))
    or $self->error({
      throw => 'error_on_mkdir',
      error => $!,
      path => $path,
    });

  return $self;
}

sub mkdirs {
  my ($self, $mode) = @_;

  my @paths;

  for my $path (
    grep !!$_, reverse($self->parents), ($self->is_file ? () : $self)
  )
  {
    if ($path->exists) {
      next;
    }
    else {
      push @paths, $path->mkdir($mode);
    }
  }

  return wantarray ? (@paths) : \@paths;
}

sub mktemp_dir {
  my ($self) = @_;

  require File::Temp;

  return $self->class->new(File::Temp::tempdir());
}

sub mktemp_file {
  my ($self) = @_;

  require File::Temp;

  return $self->class->new((File::Temp::tempfile())[1]);
}

sub mkfile {
  my ($self) = @_;

  my $path = $self->get;

  return $self if $self->exists;

  $self->open('>');

  CORE::utime(undef, undef, $path)
    or $self->error({throw => 'error_on_mkfile', path => $path, error => $!});

  return $self;
}

sub move {
  my ($self, $path) = @_;

  require File::Copy;

  File::Copy::move("$self", "$path")
    or $self->error({throw => 'error_on_move', path => $path, error => $!});

  return $self->class->make($path)->absolute;
}

sub name {
  my ($self) = @_;

  return $self->absolute->get;
}

sub parent {
  my ($self) = @_;

  require File::Spec;

  my @parts = File::Spec->splitdir($self->get);

  my $path = File::Spec->catfile(@parts[0..$#parts-1]);

  return defined $path ? $self->class->new($path) : undef;
}

sub parents {
  my ($self) = @_;

  my @paths = $self->lineage;

  @paths = @paths[1..$#paths] if @paths;

  return wantarray ? (@paths) : \@paths;
}

sub parts {
  my ($self) = @_;

  require File::Spec;

  return [File::Spec->splitdir($self->get)];
}

sub read {
  my ($self, $binmode) = @_;

  my $path = $self->get;

  CORE::open(my $handle, '<', $path)
    or $self->error({throw => 'error_on_read_open', path => $path, error => $!});

  CORE::binmode($handle, $binmode) or do {
    $self->error({
      throw => 'error_on_read_binmode',
      path => $path,
      error => $!,
      binmode => $binmode,
    });
  } if defined($binmode);

  my $result = my $content = '';

  while ($result = $handle->sysread(my $buffer, 131072, 0)) {
    $content .= $buffer;
  }

  $self->error({throw => 'error_on_read_error', path => $path, error => $!}) if !defined $result;

  require Venus::Os;
  $content =~ s/\015\012/\012/g if Venus::Os->is_win;

  return $content;
}

sub relative {
  my ($self, $path) = @_;

  require File::Spec;

  $path ||= $self->default;

  return $self->class->new(File::Spec->abs2rel($self->get, $path));
}

sub rename {
  my ($self, $path) = @_;

  $path = $self->class->make($path);

  $path = $self->sibling("$path") if $path->is_relative;

  return $self->move($path);
}

sub rmdir {
  my ($self) = @_;

  my $path = $self->get;

  CORE::rmdir($path)
    or $self->error({throw => 'error_on_rmdir', path => $path, error => $!});

  return $self;
}

sub rmdirs {
  my ($self) = @_;

  my @paths;

  for my $path ($self->children) {
    if ($path->is_file) {
      push @paths, $path->unlink;
    }
    else {
      push @paths, $path->rmdirs;
    }
  }

  push @paths, $self->rmdir;

  return wantarray ? (@paths) : \@paths;
}

sub rmfiles {
  my ($self) = @_;

  my @paths;

  for my $path ($self->children) {
    if ($path->is_file) {
      push @paths, $path->unlink;
    }
    else {
      push @paths, $path->rmfiles;
    }
  }

  return wantarray ? (@paths) : \@paths;
}

sub root {
  my ($self, $spec, $base) = @_;

  my @paths;

  for my $path ($self->absolute->lineage) {
    if ($path->child($base)->test($spec)) {
      push @paths, $path;
      last;
    }
  }

  return @paths ? (-f $paths[0] ? $paths[0]->parent : $paths[0]) : undef;
}

sub seek {
  my ($self, $spec, $base) = @_;

  if ((my $path = $self->child($base))->test($spec)) {
    return $path;
  }
  else {
    for my $path ($self->directories) {
      my $sought = $path->seek($spec, $base);
      return $sought if $sought;
    }
    return undef;
  }
}

sub sibling {
  my ($self, $path) = @_;

  require File::Basename;
  require File::Spec;

  return $self->class->new(File::Spec->catfile(
    File::Basename::dirname($self->get), $path));
}

sub siblings {
  my ($self) = @_;

  my @paths = map $self->parent->glob($_), '.??*', '*';

  my %seen = ($self->absolute, 1);

  @paths = grep !$seen{$_}++, @paths;

  return wantarray ? (@paths) : \@paths;
}

sub test {
  my ($self, $spec) = @_;

  return eval(
    join(' ', map("-$_", grep(/^[a-zA-Z]$/, split(//, $spec || 'e'))), '$self')
  );
}

sub unlink {
  my ($self) = @_;

  my $path = $self->get;

  CORE::unlink($path)
    or $self->error({throw => 'error_on_unlink', path => $path, error => $!});

  return $self;
}

sub write {
  my ($self, $data, $binmode) = @_;

  my $path = $self->get;

  CORE::open(my $handle, '>', $path)
    or $self->error({throw => 'error_on_write_open', path => $path, error => $!});

  CORE::binmode($handle, $binmode) or do {
    $self->error({
      throw => 'error_on_write_binmode',
      path => $path,
      error => $!,
      binmode => $binmode,
    });
  } if defined($binmode);

  (($handle->syswrite($data) // -1) == length($data))
    or $self->error({throw => 'error_on_write_error', path => $path, error => $!});

  return $self;
}

# ERRORS

sub error_on_copy {
  my ($self, $data) = @_;

  my $message = 'Can\'t copy "{{self}}" to "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
    self => $self,
  };

  my $result = {
    name => 'on.copy',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_mkcall {
  my ($self, $data) = @_;

  my $error = $data->{error};
  my $exit_code = $data->{exit_code} || 0;

  my $message = ("Can't make system call to \"{{path}}\": "
    . ($error ? "$error" : sprintf("exit code (%s)", $exit_code)));

  my $stash = {
    error => $error,
    exit_code => $exit_code,
    path => $data->{path},
  };

  my $result = {
    name => 'on.mkcall',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_mkdir {
  my ($self, $data) = @_;

  my $message = 'Can\'t make directory "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.mkdir',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_mkfile {
  my ($self, $data) = @_;

  my $message = 'Can\'t make file "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.mkfile',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_move {
  my ($self, $data) = @_;

  my $message = 'Can\'t move "{{self}}" to "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
    self => $self,
  };

  my $result = {
    name => 'on.move',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_open {
  my ($self, $data) = @_;

  my $message = 'Can\'t open "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.open',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_read_binmode {
  my ($self, $data) = @_;

  my $message = 'Can\'t binmode "{{path}}": {{error}}';

  my $stash = {
    binmode => $data->{binmode},
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.read.binmode',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_read_error {
  my ($self, $data) = @_;

  my $message = 'Can\'t read from file "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.read.error',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_read_open {
  my ($self, $data) = @_;

  my $message = 'Can\'t read "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.read.open',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_rmdir {
  my ($self, $data) = @_;

  my $message = 'Can\'t rmdir "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.rmdir',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_write_binmode {
  my ($self, $data) = @_;

  my $message = 'Can\'t binmode "{{path}}": {{error}}';

  my $stash = {
    binmode => $data->{binmode},
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.write.binmode',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_write_error {
  my ($self, $data) = @_;

  my $message = 'Can\'t write to file "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.write.error',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_write_open {
  my ($self, $data) = @_;

  my $message = 'Can\'t write "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.write.open',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

sub error_on_unlink {
  my ($self, $data) = @_;

  my $message = 'Can\'t unlink "{{path}}": {{error}}';

  my $stash = {
    error => $data->{error},
    path => $data->{path},
  };

  my $result = {
    name => 'on.unlink',
    raise => true,
    stash => $stash,
    message => $message,
  };

  return $result;
}

1;



=head1 NAME

Venus::Path - Path Class

=cut

=head1 ABSTRACT

Path Class for Perl 5

=cut

=head1 SYNOPSIS

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/planets');

  # my $planets = $path->files;
  # my $mercury = $path->child('mercury');
  # my $content = $mercury->read;

=cut

=head1 DESCRIPTION

This package provides methods for working with file system paths.

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Venus::Kind::Utility>

=cut

=head1 INTEGRATES

This package integrates behaviors from:

L<Venus::Role::Accessible>

L<Venus::Role::Buildable>

L<Venus::Role::Explainable>

L<Venus::Role::Valuable>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 absolute

  absolute() (Venus::Path)

The absolute method returns a path object where the value (path) is absolute.

I<Since C<0.01>>

=over 4

=item absolute example 1

  # given: synopsis;

  $path = $path->absolute;

  # bless({ value => "/path/to/t/data/planets" }, "Venus::Path")

=back

=cut

=head2 basename

  basename() (string)

The basename method returns the path base name.

I<Since C<0.01>>

=over 4

=item basename example 1

  # given: synopsis;

  my $basename = $path->basename;

  # planets

=back

=cut

=head2 child

  child(string $path) (Venus::Path)

The child method returns a path object representing the child path provided.

I<Since C<0.01>>

=over 4

=item child example 1

  # given: synopsis;

  $path = $path->child('earth');

  # bless({ value => "t/data/planets/earth" }, "Venus::Path")

=back

=cut

=head2 children

  children() (within[arrayref, Venus::Path])

The children method returns the files and directories under the path. This
method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item children example 1

  # given: synopsis;

  my $children = $path->children;

  # [
  #   bless({ value => "t/data/planets/ceres" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/earth" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/eris" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/haumea" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/jupiter" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/makemake" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mars" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mercury" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/neptune" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/planet9" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/pluto" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/saturn" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/uranus" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/venus" }, "Venus::Path"),
  # ]

=back

=cut

=head2 chmod

  chmod(string $mode) (Venus::Path)

The chmod method changes the file permissions of the file or directory.

I<Since C<0.01>>

=over 4

=item chmod example 1

  # given: synopsis;

  $path = $path->chmod(0755);

  # bless({ value => "t/data/planets" }, "Venus::Path")

=back

=cut

=head2 chown

  chown(string @args) (Venus::Path)

The chown method changes the group and/or owner or the file or directory.

I<Since C<0.01>>

=over 4

=item chown example 1

  # given: synopsis;

  $path = $path->chown(-1, -1);

  # bless({ value => "t/data/planets" }, "Venus::Path")

=back

=cut

=head2 copy

  copy(string | Venus::Path $path) (Venus::Path)

The copy method uses L<File::Copy/copy> to copy the file represented by the
invocant to the path provided and returns the invocant.

I<Since C<2.80>>

=over 4

=item copy example 1

  # given: synopsis

  package main;

  my $copy = $path->child('mercury')->copy($path->child('yrucrem'));

  # bless({...}, 'Venus::Path')

=back

=cut

=head2 default

  default() (string)

The default method returns the default value, i.e. C<$ENV{PWD}>.

I<Since C<0.01>>

=over 4

=item default example 1

  # given: synopsis;

  my $default = $path->default;

  # $ENV{PWD}

=back

=cut

=head2 directories

  directories() (within[arrayref, Venus::Path])

The directories method returns a list of children under the path which are
directories. This method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item directories example 1

  # given: synopsis;

  my $directories = $path->directories;

  # []

=back

=cut

=head2 exists

  exists() (boolean)

The exists method returns truthy or falsy if the path exists.

I<Since C<0.01>>

=over 4

=item exists example 1

  # given: synopsis;

  my $exists = $path->exists;

  # 1

=back

=over 4

=item exists example 2

  # given: synopsis;

  my $exists = $path->child('random')->exists;

  # 0

=back

=cut

=head2 explain

  explain() (string)

The explain method returns the path string and is used in stringification
operations.

I<Since C<0.01>>

=over 4

=item explain example 1

  # given: synopsis;

  my $explain = $path->explain;

  # t/data/planets

=back

=cut

=head2 extension

  extension(string $name) (string | Venus::Path)

The extension method returns a new path object using the extension name
provided. If no argument is provided this method returns the extension for the
path represented by the invocant, otherwise returns undefined.

I<Since C<2.55>>

=over 4

=item extension example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/Venus_Path.t');

  my $extension = $path->extension;

  # "t"

=back

=over 4

=item extension example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/mercury');

  my $extension = $path->extension('txt');

  # bless({ value => "t/data/mercury.txt"}, "Venus::Path")

=back

=over 4

=item extension example 3

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data');

  my $extension = $path->extension;

  # undef

=back

=over 4

=item extension example 4

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data');

  my $extension = $path->extension('txt');

  # bless({ value => "t/data.txt"}, "Venus::Path")

=back

=cut

=head2 files

  files() (within[arrayref, Venus::Path])

The files method returns a list of children under the path which are files.
This method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item files example 1

  # given: synopsis;

  my $files = $path->files;

  # [
  #   bless({ value => "t/data/planets/ceres" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/earth" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/eris" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/haumea" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/jupiter" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/makemake" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mars" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mercury" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/neptune" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/planet9" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/pluto" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/saturn" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/uranus" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/venus" }, "Venus::Path"),
  # ]

=back

=cut

=head2 find

  find(string | regexp $expr) (within[arrayref, Venus::Path])

The find method does a recursive depth-first search and returns a list of paths
found, matching the expression provided, which defaults to C<*>. This method
can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item find example 1

  # given: synopsis;

  my $find = $path->find;

  # [
  #   bless({ value => "t/data/planets/ceres" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/earth" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/eris" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/haumea" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/jupiter" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/makemake" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mars" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mercury" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/neptune" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/planet9" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/pluto" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/saturn" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/uranus" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/venus" }, "Venus::Path"),
  # ]

=back

=over 4

=item find example 2

  # given: synopsis;

  my $find = $path->find('[:\/\\\.]+m[^:\/\\\.]*$');

  # [
  #   bless({ value => "t/data/planets/makemake" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mars" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mercury" }, "Venus::Path"),
  # ]

=back

=over 4

=item find example 3

  # given: synopsis;

  my $find = $path->find('earth');

  # [
  #   bless({ value => "t/data/planets/earth" }, "Venus::Path"),
  # ]

=back

=cut

=head2 glob

  glob(string | regexp $expr) (within[arrayref, Venus::Path])

The glob method returns the files and directories under the path matching the
expression provided, which defaults to C<*>. This method can return a list of
values in list-context.

I<Since C<0.01>>

=over 4

=item glob example 1

  # given: synopsis;

  my $glob = $path->glob;

  # [
  #   bless({ value => "t/data/planets/ceres" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/earth" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/eris" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/haumea" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/jupiter" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/makemake" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mars" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/mercury" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/neptune" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/planet9" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/pluto" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/saturn" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/uranus" }, "Venus::Path"),
  #   bless({ value => "t/data/planets/venus" }, "Venus::Path"),
  # ]

=back

=cut

=head2 is_absolute

  is_absolute() (boolean)

The is_absolute method returns truthy or falsy is the path is absolute.

I<Since C<0.01>>

=over 4

=item is_absolute example 1

  # given: synopsis;

  my $is_absolute = $path->is_absolute;

  # 0

=back

=cut

=head2 is_directory

  is_directory() (boolean)

The is_directory method returns truthy or falsy is the path is a directory.

I<Since C<0.01>>

=over 4

=item is_directory example 1

  # given: synopsis;

  my $is_directory = $path->is_directory;

  # 1

=back

=cut

=head2 is_file

  is_file() (boolean)

The is_file method returns truthy or falsy is the path is a file.

I<Since C<0.01>>

=over 4

=item is_file example 1

  # given: synopsis;

  my $is_file = $path->is_file;

  # 0

=back

=cut

=head2 is_relative

  is_relative() (boolean)

The is_relative method returns truthy or falsy is the path is relative.

I<Since C<0.01>>

=over 4

=item is_relative example 1

  # given: synopsis;

  my $is_relative = $path->is_relative;

  # 1

=back

=cut

=head2 lineage

  lineage() (within[arrayref, Venus::Path])

The lineage method returns the list of parent paths up to the root path. This
method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item lineage example 1

  # given: synopsis;

  my $lineage = $path->lineage;

  # [
  #   bless({ value => "t/data/planets" }, "Venus::Path"),
  #   bless({ value => "t/data" }, "Venus::Path"),
  #   bless({ value => "t" }, "Venus::Path"),
  # ]

=back

=cut

=head2 lines

  lines(string | regexp $separator, string $binmode) (within[arrayref, string])

The lines method returns the list of lines from the underlying file. By default
the file contents are separated by newline.

I<Since C<1.23>>

=over 4

=item lines example 1

  # given: synopsis;

  my $lines = $path->child('mercury')->lines;

  # ['mercury']

=back

=over 4

=item lines example 2

  # given: synopsis;

  my $lines = $path->child('planet9')->lines($^O =~ /win32/i ? "\n" : "\r\n");

  # ['planet', 'nine']

=back

=cut

=head2 mkcall

  mkcall(any @data) (any)

The mkcall method returns the result of executing the path as an executable. In
list context returns the call output and exit code.

I<Since C<0.01>>

=over 4

=item mkcall example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new($^X);

  my $output = $path->mkcall('--help');

  # Usage: perl ...

=back

=over 4

=item mkcall example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new($^X);

  my ($call_output, $exit_code) = $path->mkcall('t/data/sun', '--heat-death');

  # ("", 1)

=back

=over 4

=item mkcall example 3

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('.help');

  my $output = $path->mkcall;

  # Exception! (isa Venus::Path::Error) (see error_on_mkcall)

=back

=cut

=head2 mkdir

  mkdir(maybe[string] $mode) (Venus::Path)

The mkdir method makes the path as a directory.

I<Since C<0.01>>

=over 4

=item mkdir example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/systems');

  $path = $path->mkdir;

  # bless({ value => "t/data/systems" }, "Venus::Path")

=back

=over 4

=item mkdir example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  $path = $path->mkdir;

  # Exception! (isa Venus::Path::Error) (see error_on_mkdir)

=back

=cut

=head2 mkdirs

  mkdirs(maybe[string] $mode) (within[arrayref, Venus::Path])

The mkdirs method creates parent directories and returns the list of created
directories. This method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item mkdirs example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/systems');

  my $mkdirs = $path->mkdirs;

  # [
  #   bless({ value => "t/data/systems" }, "Venus::Path")
  # ]

=back

=over 4

=item mkdirs example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/systems/solar');

  my $mkdirs = $path->mkdirs;

  # [
  #   bless({ value => "t/data/systems" }, "Venus::Path"),
  #   bless({ value => "t/data/systems/solar" }, "Venus::Path"),
  # ]

=back

=cut

=head2 mkfile

  mkfile() (Venus::Path)

The mkfile method makes the path as an empty file.

I<Since C<0.01>>

=over 4

=item mkfile example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/moon');

  $path = $path->mkfile;

  # bless({ value => "t/data/moon" }, "Venus::Path")

=back

=over 4

=item mkfile example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  $path = $path->mkfile;

  # Exception! (isa Venus::Path::Error) (see error_on_mkfile)

=back

=cut

=head2 mktemp_dir

  mktemp_dir() (Venus::Path)

The mktemp_dir method uses L<File::Temp/tempdir> to create a temporary
directory which isn't automatically removed and returns a new path object.

I<Since C<2.80>>

=over 4

=item mktemp_dir example 1

  # given: synopsis

  package main;

  my $mktemp_dir = $path->mktemp_dir;

  # bless({value => "/tmp/ZnKTxBpuBE"}, "Venus::Path")

=back

=cut

=head2 mktemp_file

  mktemp_file() (Venus::Path)

The mktemp_file method uses L<File::Temp/tempfile> to create a temporary file
which isn't automatically removed and returns a new path object.

I<Since C<2.80>>

=over 4

=item mktemp_file example 1

  # given: synopsis

  package main;

  my $mktemp_file = $path->mktemp_file;

  # bless({value => "/tmp/y5MvliBQ2F"}, "Venus::Path")

=back

=cut

=head2 move

  move(string | Venus::Path $path) (Venus::Path)

The move method uses L<File::Copy/move> to move the file represented by the
invocant to the path provided and returns the invocant.

I<Since C<2.80>>

=over 4

=item move example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data');

  my $unknown = $path->child('unknown')->mkfile->move($path->child('titan'));

  # bless({value => 't/data/titan'}, 'Venus::Path')

=back

=cut

=head2 name

  name() (string)

The name method returns the path as an absolute path.

I<Since C<0.01>>

=over 4

=item name example 1

  # given: synopsis;

  my $name = $path->name;

  # /path/to/t/data/planets

=back

=cut

=head2 open

  open(any @data) (FileHandle)

The open method creates and returns an open filehandle.

I<Since C<0.01>>

=over 4

=item open example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/planets/earth');

  my $fh = $path->open;

  # bless(..., "IO::File");

=back

=over 4

=item open example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/planets/earth');

  my $fh = $path->open('<');

  # bless(..., "IO::File");

=back

=over 4

=item open example 3

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/planets/earth');

  my $fh = $path->open('>');

  # bless(..., "IO::File");

=back

=over 4

=item open example 4

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  my $fh = $path->open('>');

  # Exception! (isa Venus::Path::Error) (see error_on_open)

=back

=cut

=head2 parent

  parent() (Venus::Path)

The parent method returns a path object representing the parent directory.

I<Since C<0.01>>

=over 4

=item parent example 1

  # given: synopsis;

  my $parent = $path->parent;

  # bless({ value => "t/data" }, "Venus::Path")

=back

=cut

=head2 parents

  parents() (within[arrayref, Venus::Path])

The parents method returns is a list of parent directories. This method can
return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item parents example 1

  # given: synopsis;

  my $parents = $path->parents;

  # [
  #   bless({ value => "t/data" }, "Venus::Path"),
  #   bless({ value => "t" }, "Venus::Path"),
  # ]

=back

=cut

=head2 parts

  parts() (within[arrayref, string])

The parts method returns an arrayref of path parts.

I<Since C<0.01>>

=over 4

=item parts example 1

  # given: synopsis;

  my $parts = $path->parts;

  # ["t", "data", "planets"]

=back

=cut

=head2 read

  read(string $binmode) (string)

The read method reads the file and returns its contents.

I<Since C<0.01>>

=over 4

=item read example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/planets/mars');

  my $content = $path->read;

=back

=over 4

=item read example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  my $content = $path->read;

  # Exception! (isa Venus::Path::Error) (see error_on_read_open)

=back

=cut

=head2 relative

  relative(string $root) (Venus::Path)

The relative method returns a path object representing a relative path
(relative to the path provided).

I<Since C<0.01>>

=over 4

=item relative example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/t/data/planets/mars');

  my $relative = $path->relative('/path');

  # bless({ value => "to/t/data/planets/mars" }, "Venus::Path")

=back

=over 4

=item relative example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/t/data/planets/mars');

  my $relative = $path->relative('/path/to/t');

  # bless({ value => "data/planets/mars" }, "Venus::Path")

=back

=cut

=head2 rename

  rename(string | Venus::Path $path) (Venus::Path)

The rename method performs a L</move> unless the path provided is only a file
name, in which case it attempts a rename under the directory of the invocant.

I<Since C<2.91>>

=over 4

=item rename example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/path/001');

  my $rename = $path->rename('002');

  # bless({value => 't/path/002'}, 'Venus::Path')

=back

=cut

=head2 rmdir

  rmdir() (Venus::Path)

The rmdir method removes the directory and returns a path object representing
the deleted directory.

I<Since C<0.01>>

=over 4

=item rmdir example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/stars');

  my $rmdir = $path->mkdir->rmdir;

  # bless({ value => "t/data/stars" }, "Venus::Path")

=back

=over 4

=item rmdir example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  my $rmdir = $path->mkdir->rmdir;

  # Exception! (isa Venus::Path::Error) (see error_on_rmdir)

=back

=cut

=head2 rmdirs

  rmdirs() (within[arrayref, Venus::Path])

The rmdirs method removes that path and its child files and directories and
returns all paths removed. This method can return a list of values in
list-context.

I<Since C<0.01>>

=over 4

=item rmdirs example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/stars');

  $path->child('dwarfs')->mkdirs;

  my $rmdirs = $path->rmdirs;

  # [
  #   bless({ value => "t/data/stars/dwarfs" }, "Venus::Path"),
  #   bless({ value => "t/data/stars" }, "Venus::Path"),
  # ]

=back

=cut

=head2 rmfiles

  rmfiles() (within[arrayref, Venus::Path])

The rmfiles method recursively removes files under the path and returns the
paths removed. This method does not remove the directories found. This method
can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item rmfiles example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/stars')->mkdir;

  $path->child('sirius')->mkfile;
  $path->child('canopus')->mkfile;
  $path->child('arcturus')->mkfile;
  $path->child('vega')->mkfile;
  $path->child('capella')->mkfile;

  my $rmfiles = $path->rmfiles;

  # [
  #   bless({ value => "t/data/stars/arcturus" }, "Venus::Path"),
  #   bless({ value => "t/data/stars/canopus" }, "Venus::Path"),
  #   bless({ value => "t/data/stars/capella" }, "Venus::Path"),
  #   bless({ value => "t/data/stars/sirius" }, "Venus::Path"),
  #   bless({ value => "t/data/stars/vega" }, "Venus::Path"),
  # ]

=back

=cut

=head2 root

  root(string $spec, string $base) (maybe[Venus::Path])

The root method performs a search up the file system heirarchy returns the
first path (i.e. absolute path) matching the file test specification and base
path expression provided. The file test specification is the same passed to
L</test>. If no path matches are found this method returns underfined.

I<Since C<2.32>>

=over 4

=item root example 1

  # given: synopsis;

  my $root = $path->root('d', 't');

  # bless({ value => "/path/to/t/../" }, "Venus::Path")

=back

=over 4

=item root example 2

  # given: synopsis;

  my $root = $path->root('f', 't');

  # undef

=back

=cut

=head2 seek

  seek(string $spec, string $base) (maybe[Venus::Path])

The seek method performs a search down the file system heirarchy returns the
first path (i.e. absolute path) matching the file test specification and base
path expression provided. The file test specification is the same passed to
L</test>. If no path matches are found this method returns underfined.

I<Since C<2.32>>

=over 4

=item seek example 1

  # given: synopsis;

  $path = Venus::Path->new('t');

  my $seek = $path->seek('f', 'earth');

  # bless({ value => "/path/to/t/data/planets/earth" }, "Venus::Path")

=back

=over 4

=item seek example 2

  # given: synopsis;

  $path = Venus::Path->new('t');

  my $seek = $path->seek('f', 'europa');

  # undef

=back

=cut

=head2 sibling

  sibling(string $path) (Venus::Path)

The sibling method returns a path object representing the sibling path provided.

I<Since C<0.01>>

=over 4

=item sibling example 1

  # given: synopsis;

  my $sibling = $path->sibling('galaxies');

  # bless({ value => "t/data/galaxies" }, "Venus::Path")

=back

=cut

=head2 siblings

  siblings() (within[arrayref, Venus::Path])

The siblings method returns all sibling files and directories for the current
path. This method can return a list of values in list-context.

I<Since C<0.01>>

=over 4

=item siblings example 1

  # given: synopsis;

  my $siblings = $path->siblings;

  # [
  #   bless({ value => "t/data/moon" }, "Venus::Path"),
  #   bless({ value => "t/data/sun" }, "Venus::Path"),
  # ]

=back

=cut

=head2 test

  test(string $expr) (boolean)

The test method evaluates the current path against the stackable file test
operators provided.

I<Since C<0.01>>

=over 4

=item test example 1

  # given: synopsis;

  my $test = $path->test;

  # -e $path

  # 1

=back

=over 4

=item test example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/sun');

  my $test = $path->test('efs');

  # -e -f -s $path

  # 1

=back

=cut

=head2 unlink

  unlink() (Venus::Path)

The unlink method removes the file and returns a path object representing the
removed file.

I<Since C<0.01>>

=over 4

=item unlink example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/asteroid')->mkfile;

  my $unlink = $path->unlink;

  # bless({ value => "t/data/asteroid" }, "Venus::Path")

=back

=over 4

=item unlink example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  my $unlink = $path->unlink;

  # Exception! (isa Venus::Path::Error) (see error_on_unlink)

=back

=cut

=head2 write

  write(string $data, string $binmode) (Venus::Path)

The write method write the data provided to the file.

I<Since C<0.01>>

=over 4

=item write example 1

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('t/data/asteroid');

  my $write = $path->write('asteroid');

=back

=over 4

=item write example 2

  package main;

  use Venus::Path;

  my $path = Venus::Path->new('/path/to/xyz');

  my $write = $path->write('nothing');

  # Exception! (isa Venus::Path::Error) (see error_on_write_open)

=back

=cut

=head1 ERRORS

This package may raise the following errors:

=cut

=over 4

=item error: C<error_on_copy>

This package may raise an error_on_copy exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_copy',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_copy"

  # my $message = $error->render;

  # "Can't copy \"t\/data\/planets\" to \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

  # my $self = $error->stash('self');

  # bless({...}, 'Venus::Path')

=back

=over 4

=item error: C<error_on_mkcall>

This package may raise an error_on_mkcall exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_mkcall',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_mkcall"

  # my $message = $error->render;

  # "Can't make system call to \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_mkdir>

This package may raise an error_on_mkdir exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_mkdir',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_mkdir"

  # my $message = $error->render;

  # "Can't make directory \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_mkfile>

This package may raise an error_on_mkfile exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_mkfile',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_mkfile"

  # my $message = $error->render;

  # "Can't make file \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_move>

This package may raise an error_on_move exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_move',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_move"

  # my $message = $error->render;

  # "Can't copy \"t\/data\/planets\" to \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

  # my $self = $error->stash('self');

  # bless({...}, 'Venus::Path')

=back

=over 4

=item error: C<error_on_open>

This package may raise an error_on_open exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_open',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_open"

  # my $message = $error->render;

  # "Can't open \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_read_binmode>

This package may raise an error_on_read_binmode exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_read_binmode',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_read_binmode"

  # my $message = $error->render;

  # "Can't binmode \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_read_error>

This package may raise an error_on_read_error exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_read_error',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_read_error"

  # my $message = $error->render;

  # "Can't read from file \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_read_open>

This package may raise an error_on_read_open exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_read_open',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_read_open"

  # my $message = $error->render;

  # "Can't read \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_rmdir>

This package may raise an error_on_rmdir exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_rmdir',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_rmdir"

  # my $message = $error->render;

  # "Can't rmdir \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_unlink>

This package may raise an error_on_unlink exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_unlink',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_unlink"

  # my $message = $error->render;

  # "Can't unlink \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_write_binmode>

This package may raise an error_on_write_binmode exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_write_binmode',
    error => $!,
    path => '/nowhere',
    binmode => ':utf8',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_write_binmode"

  # my $message = $error->render;

  # "Can't binmode \"/nowhere\": $!"

  # my $binmode = $error->stash('binmode');

  # ":utf8"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_write_error>

This package may raise an error_on_write_error exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_write_error',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_write_error"

  # my $message = $error->render;

  # "Can't write to file \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=over 4

=item error: C<error_on_write_open>

This package may raise an error_on_write_open exception.

B<example 1>

  # given: synopsis;

  my $input = {
    throw => 'error_on_write_open',
    error => $!,
    path => '/nowhere',
  };

  my $error = $path->catch('error', $input);

  # my $name = $error->name;

  # "on_write_open"

  # my $message = $error->render;

  # "Can't write \"/nowhere\": $!"

  # my $path = $error->stash('path');

  # "/nowhere"

=back

=head1 OPERATORS

This package overloads the following operators:

=cut

=over 4

=item operation: C<("")>

This package overloads the C<""> operator.

B<example 1>

  # given: synopsis;

  my $result = "$path";

  # "t/data/planets"

B<example 2>

  # given: synopsis;

  my $mercury = $path->child('mercury');

  my $result = "$path, $path";

  # "t/data/planets, t/data/planets"

=back

=over 4

=item operation: C<(.)>

This package overloads the C<.> operator.

B<example 1>

  # given: synopsis;

  my $result = $path . '/earth';

  # "t/data/planets/earth"

=back

=over 4

=item operation: C<(eq)>

This package overloads the C<eq> operator.

B<example 1>

  # given: synopsis;

  my $result = $path eq 't/data/planets';

  # 1

=back

=over 4

=item operation: C<(ne)>

This package overloads the C<ne> operator.

B<example 1>

  # given: synopsis;

  my $result = $path ne 't/data/planets/';

  # 1

=back

=over 4

=item operation: C<(qr)>

This package overloads the C<qr> operator.

B<example 1>

  # given: synopsis;

  my $result = 't/data/planets' =~ $path;

  # 1

=back

=over 4

=item operation: C<(~~)>

This package overloads the C<~~> operator.

B<example 1>

  # given: synopsis;

  my $result = $path ~~ 't/data/planets';

  # 1

=back

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut

=head1 LICENSE

Copyright (C) 2022, Awncorp, C<awncorp@cpan.org>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Apache license version 2.0.

=cut