package Inline::CLIPS;

use strict;
use warnings;

use Carp qw(croak);
use File::Spec;
use File::Temp qw(tempfile);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

our $VERSION = '0.002';

sub new {
  my ($class, %args) = @_;
  my $self = bless {
    executable => $args{executable},
    library    => $args{library},
  }, $class;
  return $self;
}

sub executable {
  my ($self) = @_;
  return $self->{executable} if defined $self->{executable};

  $self->{executable} = $ENV{INLINE_CLIPS_EXECUTABLE}
    || _path_executable('clips')
    || _alien_executable()
    || q{};

  return $self->{executable};
}

sub library {
  my ($self) = @_;
  return $self->{library} if defined $self->{library};

  $self->{library} = $ENV{INLINE_CLIPS_LIB}
    || _alien_library()
    || q{};

  return $self->{library};
}

sub run_program {
  my ($self, $program, @commands) = @_;
  croak 'program text is required' if !defined $program;

  my ($fh, $tmp) = tempfile('inline-clips-XXXX', SUFFIX => '.clp', UNLINK => 1);
  print {$fh} "(clear)\n";
  print {$fh} $program;
  print {$fh} "\n" if $program !~ /\n\z/;
  print {$fh} "(reset)\n";
  print {$fh} "$_\n" for @commands;
  print {$fh} "(exit)\n";
  close $fh;

  return $self->run_file($tmp);
}

sub run_file {
  my ($self, $file) = @_;
  croak 'file path is required' if !defined $file || $file eq q{};
  croak "CLIPS file not found: $file" if !-f $file;

  my $exe = $self->executable;
  croak 'CLIPS executable is not available; set INLINE_CLIPS_EXECUTABLE or install CLIPS/Alien::CLIPS'
    if !$exe;

  my $err = gensym;
  my $pid = open3(my $in, my $out, $err, $exe, '-f2', $file);
  close $in;

  local $/ = undef;
  my $stdout = <$out> // q{};
  my $stderr = <$err> // q{};
  waitpid($pid, 0);
  my $status = $? >> 8;

  return {
    status => $status,
    stdout => $stdout,
    stderr => $stderr,
  };
}

sub _path_executable {
  my ($name) = @_;
  for my $dir (File::Spec->path) {
    my $candidate = File::Spec->catfile($dir, $name);
    return $candidate if -x $candidate;
  }
  return;
}

sub _alien_executable {
  my $alien = _load_alien() or return;
  my @bins = $alien->can('bin_dir') ? $alien->bin_dir : ();
  for my $dir (@bins) {
    my $candidate = File::Spec->catfile($dir, 'clips');
    return $candidate if -x $candidate;
  }
  return;
}

sub _alien_library {
  my $alien = _load_alien() or return;
  my @libs = $alien->can('dynamic_libs') ? $alien->dynamic_libs : ();
  return $libs[0] if @libs;
  return;
}

sub _load_alien {
  my $ok = eval {
    require Alien::CLIPS;
    Alien::CLIPS->import();
    1;
  };
  return if !$ok;
  return 'Alien::CLIPS';
}

1;

__END__

=encoding UTF-8

=head1 NAME

Inline::CLIPS - Perl interface to run CLIPS programs

=head1 SYNOPSIS

  use Inline::CLIPS;

  my $clips = Inline::CLIPS->new;
  my $result = $clips->run_program(q{
    (deftemplate animal (slot name) (slot class))
    (deffacts initial (animal (name "penguin") (class bird)))
    (defrule print-animal
      (animal (name ?n) (class ?c))
      =>
      (printout t ?n " is a " ?c crlf))
  }, '(run)');

  print $result->{stdout};
  warn $result->{stderr} if $result->{stderr};
  exit $result->{status};

=head1 DESCRIPTION

C<Inline::CLIPS> provides a small Perl API for executing CLIPS programs by
wrapping a CLIPS executable.  It does not embed a CLIPS engine; instead it
writes a temporary C<.clp> file and invokes the CLIPS interpreter with that
file.  The captured output, errors, and exit status are returned as a plain
hash reference.

The module discovers the CLIPS executable in the following order:

=over 4

=item 1.

The C<executable> argument passed to C<new>.

=item 2.

The C<INLINE_CLIPS_EXECUTABLE> environment variable.

=item 3.

A command named C<clips> found in C<$PATH>.

=item 4.

The binary directory reported by C<Alien::CLIPS>, if installed.

=back

=head1 INSTALLATION

=head2 Installing the Perl module

The distribution follows the standard L<ExtUtils::MakeMaker> build process:

  perl Makefile.PL
  make
  make test
  make install

=head2 Making CLIPS available to Perl

C<Inline::CLIPS> needs a working CLIPS executable.  You can make one
available in any of these ways.

=head3 Option 1: Use a system CLIPS on C<$PATH>

Install CLIPS from your operating system package manager, or build CLIPS from
source and copy the C<clips> binary into a directory on your C<$PATH>.  Once
C<clips> is executable and discoverable, C<Inline::CLIPS> will find it
automatically.

  # Verify CLIPS is visible
  which clips
  clips -v

=head3 Option 2: Set C<INLINE_CLIPS_EXECUTABLE>

If CLIPS is installed in a non-standard location, set the environment variable
to the absolute path of the executable:

  export INLINE_CLIPS_EXECUTABLE=/opt/clips/6.4.2/clips
  perl my_script.pl

You can also set this in your Perl code before constructing the object:

  $ENV{INLINE_CLIPS_EXECUTABLE} = '/opt/clips/6.4.2/clips';
  my $clips = Inline::CLIPS->new;

=head3 Option 3: Use C<Alien::CLIPS>

If this distribution is installed with its companion module C<Alien::CLIPS>,
the module will fall back to a CLIPS binary discovered through the Alien
infrastructure.  C<Alien::CLIPS> can locate a system CLIPS installation or,
when no system copy is found, build CLIPS from the FuzzyCLIPS source
repository:

  L<https://github.com/jtrujil43/FuzzyCLIPS>

=head3 Verifying the installation

  use Inline::CLIPS;

  my $clips = Inline::CLIPS->new;
  die "CLIPS executable not found\n" unless $clips->executable;

  my $result = $clips->run_program(q{
    (printout t "CLIPS is available" crlf)
  }, '(exit)');

  print $result->{stdout};

=head1 METHODS

=head2 C<new(%args)>

Constructor.  Accepts the following optional arguments:

=over 4

=item C<executable>

Path to the CLIPS executable.  If omitted, the executable is discovered using
the rules in L</"INSTALLATION">.

=item C<library>

Path to the CLIPS shared library.  This is exposed for callers that need to
know where CLIPS libraries live; it is not used directly by the executable
wrapper.

=back

  my $clips = Inline::CLIPS->new(
    executable => '/usr/local/bin/clips',
  );

=head2 C<executable>

Returns the resolved path to the CLIPS executable, or the empty string if none
was found.

  my $path = $clips->executable;

=head2 C<library>

Returns the resolved path to the CLIPS shared library, or the empty string if
none was found.  The library is resolved from the C<library> constructor
argument, the C<INLINE_CLIPS_LIB> environment variable, or C<Alien::CLIPS>.

  my $lib = $clips->library;

=head2 C<run_program($program, @commands)>

Executes an inline CLIPS program.  The C<$program> string is written to a
temporary C<.clp> file followed by C<(reset)>, each command in C<@commands>,
and finally C<(exit)>.  Returns a hash reference:

  {
    status => 0,          # CLIPS exit status
    stdout => "...",      # everything printed to STDOUT
    stderr => "...",      # everything printed to STDERR
  }

  my $result = $clips->run_program(q{
    (deffacts numbers (number 1) (number 2) (number 3))
    (defrule sum-numbers
      (number ?n)
      =>
      (printout t "number: " ?n crlf))
  }, '(reset)', '(run)');

=head2 C<run_file($file)>

Executes an existing CLIPS source file.  The file must exist and be readable.
The CLIPS interpreter is invoked as C<clips -f2 $file>.

  my $result = $clips->run_file('src/main.clp');

This is useful for projects that already keep their rules, templates, and
facts in separate C<.clp> files.  See L</"Running a real process-flow-check
project"> for a complete example.

=head1 ENVIRONMENT

=over 4

=item C<INLINE_CLIPS_EXECUTABLE>

Full path to the CLIPS executable.  Overrides the C<$PATH> search and the
C<Alien::CLIPS> fallback.

=item C<INLINE_CLIPS_LIB>

Full path to the CLIPS shared library.  Used by C<library()>.

=item C<INLINE_CLIPS_BIN>

Directory containing the CLIPS binary.  Consulted by C<Alien::CLIPS> when no
system executable is found.

=item C<ALIEN_CLIPS_LIB>, C<ALIEN_CLIPS_BIN>

Fallback variables read by C<Alien::CLIPS>.

=back

=head1 EXAMPLES

=head2 Basic inline program

  use Inline::CLIPS;

  my $clips = Inline::CLIPS->new;
  my $result = $clips->run_program(q{
    (deftemplate animal (slot name) (slot class))
    (deffacts seed
      (animal (name "penguin") (class bird))
      (animal (name "salmon") (class fish)))
    (defrule describe-animal
      (animal (name ?n) (class ?c))
      =>
      (printout t ?n " is a " ?c crlf))
  }, '(run)');

  print $result->{stdout};

=head2 Running a real process-flow-check project

Suppose you have the C<process-flow-check> CLIPS project at
F</home/jovan/devel/Clips_code/process-flow-check>.  It defines templates for
C<flow-step>, C<tool-capability>, and C<violation>, loads rules from
F<src/core/*.clp>, and provides a C<check-flow> deffunction in
F<src/io/run-validation.clp>.  You can drive that project from Perl with
C<run_file> or with a self-contained inline program.

=head3 Using C<run_file> with the project loader

  use Inline::CLIPS;

  my $clips = Inline::CLIPS->new;
  my $project_dir = '/home/jovan/devel/Clips_code/process-flow-check';

  # CLIPS file paths are relative to its current directory, so run from there.
  chdir $project_dir or die "Cannot chdir: $!";

  my $result = $clips->run_file('src/main.clp');
  print $result->{stdout};
  warn $result->{stderr} if $result->{stderr};

=head3 Using an inline copy of the same rules

The project checks semiconductor-style process flows.  The CLIPS snippet
below is a self-contained, simplified version of the real rules that validates
a short photolithography and poly-etch flow.

  use Inline::CLIPS;

  my $clips = Inline::CLIPS->new;
  my $result = $clips->run_program(
    q{
      (deftemplate flow-step
        (slot step-id (type INTEGER))
        (slot step-name)
        (slot layer)
        (slot tool-id)
        (slot recipe-id)
        (slot queue-time-min (type INTEGER))
        (slot max-wait-min (type INTEGER))
        (slot rework-allowed (allowed-values TRUE FALSE))
        (slot prev-step-id (type INTEGER) (default -1)))

      (deftemplate tool-capability
        (slot tool-id)
        (slot allowed-layers)
        (multislot allowed-recipes))

      (deftemplate violation
        (slot code)
        (slot message)
        (slot step-id)
        (slot severity (allowed-values info warning error)))

      (deffacts reference-capabilities
        (tool-capability (tool-id CT-01)  (allowed-layers PHOTO)
                         (allowed-recipes CT-PR-193))
        (tool-capability (tool-id EX-05)  (allowed-layers PHOTO)
                         (allowed-recipes EX-193-NA13))
        (tool-capability (tool-id DEV-02) (allowed-layers PHOTO)
                         (allowed-recipes DEV-TMAH))
        (tool-capability (tool-id INS-01) (allowed-layers PHOTO)
                         (allowed-recipes INS-BF))
        (tool-capability (tool-id ETCH-07) (allowed-layers POLY)
                         (allowed-recipes ETCH-Cl2-BCl3)))

      (defrule check-tool-layer
        (flow-step (step-id ?id) (layer ?layer) (tool-id ?tool))
        (tool-capability (tool-id ?tool) (allowed-layers ?allowed))
        (test (neq ?layer ?allowed))
        =>
        (assert (violation (code CONS-001)
                           (message "Tool not qualified for layer")
                           (step-id ?id)
                           (severity error))))

      (defrule check-queue-time
        (flow-step (step-id ?id) (queue-time-min ?q) (max-wait-min ?m))
        (test (> ?q ?m))
        =>
        (assert (violation (code TIME-001)
                           (message "Queue time exceeds maximum wait")
                           (step-id ?id)
                           (severity error))))

      (deffunction print-report ()
        (bind ?errs (find-all-facts ((?v violation)) TRUE))
        (if (eq (length$ ?errs) 0)
          then
            (printout t "No violations found." crlf)
          else
            (printout t "Violations:" crlf)
            (foreach ?vf ?errs
              (printout t "[" (fact-slot-value ?vf code) "] @ step "
                        (fact-slot-value ?vf step-id) " — "
                        (fact-slot-value ?vf message) crlf))))

      (deffacts current-flow
        (flow-step (step-id 10) (step-name Coat)    (layer PHOTO)
                   (tool-id CT-01)  (recipe-id CT-PR-193)
                   (queue-time-min 10) (max-wait-min 60)  (rework-allowed FALSE)
                   (prev-step-id -1))
        (flow-step (step-id 20) (step-name Expose)  (layer PHOTO)
                   (tool-id EX-05)  (recipe-id EX-193-NA13)
                   (queue-time-min 12) (max-wait-min 60)  (rework-allowed FALSE)
                   (prev-step-id 10))
        (flow-step (step-id 30) (step-name Develop) (layer PHOTO)
                   (tool-id DEV-02) (recipe-id DEV-TMAH)
                   (queue-time-min 8)  (max-wait-min 45)  (rework-allowed FALSE)
                   (prev-step-id 20))
        (flow-step (step-id 40) (step-name Inspect) (layer PHOTO)
                   (tool-id INS-01) (recipe-id INS-BF)
                   (queue-time-min 5)  (max-wait-min 30)  (rework-allowed TRUE)
                   (prev-step-id 30))
        (flow-step (step-id 50) (step-name Etch)    (layer POLY)
                   (tool-id ETCH-07) (recipe-id ETCH-Cl2-BCl3)
                   (queue-time-min 15) (max-wait-min 120) (rework-allowed FALSE)
                   (prev-step-id 40)))
    },
    '(reset)',
    '(run)',
    '(print-report)',
  );

  print $result->{stdout};
  warn $result->{stderr} if $result->{stderr};
  exit $result->{status};

=head1 DIAGNOSTICS

=over 4

=item C<CLIPS executable is not available; set INLINE_CLIPS_EXECUTABLE or install CLIPS/Alien::CLIPS>

Thrown by C<run_file> and C<run_program> when no CLIPS executable could be
discovered.  Follow the steps in L</"INSTALLATION">.

=item C<program text is required>

C<run_program> was called without a program string.

=item C<file path is required> / C<CLIPS file not found: ...>

C<run_file> was called with a missing, empty, or non-existent file path.

=back

=head1 SEE ALSO

=over 4

=item L<Alien::CLIPS>

Companion Alien module that can locate or build CLIPS.

=item CLIPS home page

L<https://www.clipsrules.net/>

=item FuzzyCLIPS source used by the Alien fallback

L<https://github.com/jtrujil43/FuzzyCLIPS>

=back

=head1 AUTHOR

Inline-CLIPS contributors.

=head1 LICENSE

This library is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

