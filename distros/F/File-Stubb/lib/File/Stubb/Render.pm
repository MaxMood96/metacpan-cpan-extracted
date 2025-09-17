package File::Stubb::Render;
use 5.016;
our $VERSION = '0.04';
use strict;
use warnings;

use File::Basename;
use File::Spec;
use JSON::PP;

# TODO: '?' sigil for '#' and '$' restricted targets
# TODO: Set '$_' in Perl and shell substs to rendered file

my $ILLEGAL_PATH_RX = $^O eq 'MSWin32'
    ? qr/[<>:"\/\\|?*]/
    : qr/\//;

my $PATH_SEP = $^O eq 'MSWin32' ? '\\' : '/';

our $SUBST_TARGET_NAME_RX = qr/[a-zA-Z0-9_]+/;

my $STDOUT_PATH = '-';

my $SUBST_TARGET_RX = qr{
    (?<SIGIL> \\? [\?\$!\#])?
    \^\^
    \s* (?<TARGET> .*?) \s*
    \^\^
}x;

# Path substitution targets only contain basic targets
my $SUBST_TARGET_PATH_RX = qr{
    \^\^
    \s* (?<TARGET> $SUBST_TARGET_NAME_RX) \s*
    \^\^
}x;

sub _dir {

    my ($dir, $hidden) = @_;
    $hidden //= 0;

    opendir my $dh, $dir
        or die "Failed to open $dir as a directory: $!\n";
    my @files =
        sort
        grep { ! /^\.\.?$/ }
        readdir $dh;
    closedir $dh;

    unless ($hidden) {
        @files = grep { ! /^\./ } @files;
    }

    return map { File::Spec->catfile($dir, $_) } @files;

}

sub _read_json {

    my ($self, $file) = @_;

    open my $fh, '<', $file
        or die "Failed to open $file for reading: $!\n";
    my $json = do { local $/ = undef; <$fh> };
    close $fh;

    my $ref = decode_json($json);

    unless (ref $ref eq 'HASH') {
        die "Invalid .stubb.json\n";
    }

    if ($self->{ Defaults } and ref $ref->{ defaults } eq 'HASH') {
        for my $k (keys %{ $ref->{ defaults } }) {
            $self->{ Subst }{ $k } = $ref->{ defaults }{ $k };
        }
    }

    if (exists $ref->{ render_hidden }) {
        $self->{ Hidden } = !! $ref->{ render_hidden };
    }

    if (exists $ref->{ follow_symlinks }) {
        $self->{ FollowLink } = !! $ref->{ follow_symlinks };
    }

    if (exists $ref->{ copy_perms }) {
        $self->{ CopyPerms } = !! $ref->{ copy_perms };
    }

    return 1;

}

sub _pl_subst {

    my ($self, $pl) = @_;

    local %_ = %{ $self->{ Subst } };
    return eval("{ no strict; no warnings; $pl }") // '';

}

sub _qx_subst {

    my ($self, $qx) = @_;

    local %ENV = %ENV;
    for my $k (%{ $self->{ Subst } }) {
        $ENV{ $k } = $self->{ Subst }{ $k };
    }

    my $rt = qx/$qx/;
    chomp $rt;
    return $rt;

}

sub _render_link {

    my ($self, $link, $out) = @_;

    my $to = $self->render_path(readlink $link);

    symlink $to, $out
        or die "Failed to symlink $to to $out: $!\n";

    return $out;

}

sub _render_dir {

    my ($self, $template, $out) = @_;

    if ($out eq $STDOUT_PATH) {
        die "Cannot render directory to stdout\n";
    }

    my @created;

    mkdir $out or die "Failed to mkdir $out: $!\n";
    if ($self->{ CopyPerms }) {
        chmod((stat($template))[2] & 0777, $out);
    }
    push @created, $out;

    for my $f (_dir($template, $self->{ Hidden })) {

        my $bn = basename($f);

        next if $bn eq '.stubb.json';

        my $o = File::Spec->catfile(
            $out,
            $self->render_path($bn)
        );

        my @c;

        eval {
            if (-d $f) {
                @c = $self->_render_dir($f, $o);
            } elsif (!$self->{ FollowLink } and -l $f) {
                @c = $self->_render_link($f, $o);
            } else {
                @c = $self->_render_file($f, $o);
            }
        };

        if ($@ ne '') {
            for my $del (reverse @created) {
                if (-d $del) {
                    rmdir $del or next;
                } elsif (-f $del) {
                    unlink $del or next;
                }
            }
            die $@;
        }

        push @created, @c;

    }

    return @created;

}

sub _render_file {

    my ($self, $template, $out) = @_;

    open my $rh, '<', $template
        or die "Failed to open $template for reading: $!\n";
    binmode $rh;

    my $wh;
    if ($out eq $STDOUT_PATH) {
        $wh = *STDOUT;
    } else {
        open $wh, '>', $out
            or die "Failed to open $out for writing: $!\n";
    }
    binmode $wh;

    while (my $l = readline $rh) {
        $l =~ s{($SUBST_TARGET_RX)}{
            my $m = $1;
            my %c = %+;
            my $repl = '';
            {
                if (defined $c{ SIGIL } and $c{ SIGIL } =~ /^\\/) {
                    # Copy escaped sigil
                    $repl .= substr $c{ SIGIL }, 1, 1;
                    $m = substr $m, length $c{ SIGIL };
                }
                if (not defined $c{ SIGIL } or $c{ SIGIL } =~ /^\\/) {
                    my ($targ, $def) = split /\s*\/\/\s*/, $c{ TARGET };
                    if ($targ !~ /^$SUBST_TARGET_NAME_RX$/) {
                        $repl = $m;
                        last;
                    }
                    $repl .= exists $self->{ Subst }{ $targ }
                        ? $self->{ Subst }{ $targ }
                        : $def // $m;
                } elsif ($c{ SIGIL } eq '?') {
                    if ($c{ TARGET } !~ /^$SUBST_TARGET_NAME_RX$/) {
                        $repl = $m;
                        last;
                    }
                    $repl = exists $self->{ Subst }{ $c{ TARGET } }
                        ? $self->{ Subst }{ $c{ TARGET } }
                        : '';
                } elsif ($c{ SIGIL } eq '$') {
                    $repl = $self->{ Restricted }
                        ? $m
                        : $self->_pl_subst($c{ TARGET });
                } elsif ($c{ SIGIL } eq '#') {
                    $repl = $self->{ Restricted }
                        ? $m
                        : $self->_qx_subst($c{ TARGET });
                } elsif ($c{ SIGIL } eq '!') {
                    $repl = substr $m, 1;
                }
            }
            $repl;
        }ge;
        print { $wh } $l;
    }

    close $rh;
    close $wh unless $out eq $STDOUT_PATH;

    if ($self->{ CopyPerms } and $out ne $STDOUT_PATH) {
        chmod((stat($template))[2] & 0777, $out);
    }

    return $out;

}

sub _path_targets {

    my ($self, $path) = @_;

    my %targ;

    while (my $m = $path =~ m/($SUBST_TARGET_PATH_RX)/g) {
        $targ{ $+{ TARGET } } = 1;
    }

    return sort keys %targ;

}

sub _file_targets {

    my ($self, $template, $targets) = @_;

    open my $fh, '<', $template
        or die "Failed to open $template for reading: $!\n";
    binmode $fh;

    while (my $l = readline $fh) {
        while (my $m = $l =~ m/($SUBST_TARGET_RX)/g) {
            my %c = %+;
            if (not defined $c{ SIGIL } or $c{ SIGIL } eq '?' or $c{ SIGIL } =~ /^\\/) {
                my $t = $c{ TARGET } =~ s/\s*\/\/.*$//r;
                next unless $t =~ /^$SUBST_TARGET_NAME_RX$/;
                $targets->{ basic }{ $t } = 1;
            } elsif ($c{ SIGIL } eq '$' and not $self->{ Restricted }) {
                push @{ $targets->{ perl } }, $c{ TARGET };
            } elsif ($c{ SIGIL } eq '#' and not $self->{ Restricted }) {
                push @{ $targets->{ shell } }, $c{ TARGET };
            }
        }
    }

    close $fh;

    return 1;

}

sub _dir_targets {

    my ($self, $template, $targets) = @_;

    for my $f (_dir($template, $self->{ Hidden })) {

        my $bn = basename($f);

        next if $bn eq '.stubb.json';

        for my $t ($self->_path_targets($bn)) {
            $targets->{ basic }{ $t } = 1;
        }

        if (-l $f and !$self->{ FollowLink }) {
            for my $t ($self->_path_targets(readlink $f)) {
                $targets->{ basic }{ $t } = 1;
            }
        } elsif (-d $f) {
            $self->_dir_targets($f, $targets);
        } else {
            $self->_file_targets($f, $targets);
        }

    }

    return 1;

}

sub new {

    my ($class, %param) = @_;

    my $self = {
        Template   => $param{ template },
        Subst      => {},
        Hidden     => 0,
        FollowLink => 1,
        CopyPerms  => 0,
        Defaults   => 1,
        IgnoreConf => 0,
        Restricted => 0,
    };

    bless $self, $class;

    my $json = File::Spec->catfile($self->{ Template }, '.stubb.json');

    if (defined $param{ ignore_config }) {
        $self->{ IgnoreConf } = !! $param{ ignore_config };
    }

    if (defined $param{ defaults }) {
        $self->{ Defaults } = !! $param{ defaults };
    }

    if (-f $json and !$self->{ IgnoreConf }) {
        $self->_read_json($json);
    }

    if (defined $param{ subst }) {
        $self->{ Subst } = $param{ subst };
    }

    if (defined $param{ render_hidden }) {
        $self->{ Hidden } = !! $param{ render_hidden };
    }

    if (defined $param{ follow_symlinks }) {
        $self->{ FollowLink } = !! $param{ follow_symlinks };
    }

    if (defined $param{ copy_perms }) {
        $self->{ CopyPerms } = !! $param{ copy_perms };
    }

    if (defined $param{ restricted }) {
        $self->{ Restricted } = !! $param{ restricted };
    }

    for my $k (keys %{ $self->{ Subst } }) {
        unless ($k =~ /^$SUBST_TARGET_NAME_RX$/) {
            die "'$k' is not a valid substitution target\n";
        }
    }

    return $self;

}

sub render {

    my ($self, $out) = @_;

    $out = $self->render_path($out);

    my @created = -d $self->{ Template }
        ? $self->_render_dir($self->{ Template }, $out)
        : $self->_render_file($self->{ Template }, $out);

    return @created;

}

sub targets {

    my ($self) = @_;

    my $targets = {
        basic => {},
        perl  => [],
        shell => [],
    };

    if (-d $self->{ Template }) {
        $self->_dir_targets($self->{ Template }, $targets);
    } else {
        $self->_file_targets($self->{ Template }, $targets);
    }

    $targets->{ basic } = [ sort keys %{ $targets->{ basic } } ];

    return $targets;

}

sub render_path {

    my ($self, $path) = @_;

    my @parts = split /\Q$PATH_SEP\E/, $path;

    for (@parts) {
        s{($SUBST_TARGET_PATH_RX)}{
            my $m = $1;
            my %c = %+;
            my $repl = '';
            {
                if (not exists $self->{ Subst }{ $c{ TARGET } }) {
                    $repl = $m;
                    last;
                }
                if ($self->{ Subst }{ $c{ TARGET } } =~ $ILLEGAL_PATH_RX) {
                    die "'$c{ TARGET }' path substitution would contain illegal path characters\n";
                }
                $repl = $self->{ Subst }{ $c{ TARGET } };
            }
            $repl;
        }ge;
    }

    return File::Spec->catfile(@parts);

}

sub template {

    my ($self) = @_;

    return $self->{ Template };

}

sub subst {

    my ($self) = @_;

    return $self->{ Subst };

}

sub set_subst {

    my ($self, $subst) = @_;

    unless (ref $subst eq 'HASH') {
        die "\$subst must be a hash ref";
    }

    $self->{ Subst } = $subst;

}

sub hidden {

    my ($self) = @_;

    return $self->{ Hidden };

}

sub set_hidden {

    my ($self, $hidden) = @_;

    $self->{ Hidden } = !! $hidden;

}

sub follow_symlinks {

    my ($self) = @_;

    return $self->{ FollowLink };

}

sub set_follow_symlinks {

    my ($self, $follow) = @_;

    $self->{ FollowLink } = !! $follow;

}

sub copy_perms {

    my ($self) = @_;

    return $self->{ CopyPerms };

}

sub set_copy_perms {

    my ($self, $copy) = @_;

    $self->{ CopyPerms } = !! $copy;

}

sub restricted {

    my ($self) = @_;

    return $self->{ Restricted };

}

sub set_restricted {

    my ($self, $rest) = @_;

    $self->{ Restricted } = !! $rest;

}

sub defaults {

    my ($self) = @_;

    return $self->{ Defaults };

}

sub ignore_config {

    my ($self) = @_;

    return $self->{ IgnoreConf };

}

1;

=head1 NAME

File::Stubb::Render - Stubb template rendering class

=head1 USAGE

  use File::Stubb::Render;

  my $render = File::Stubb::Render->new(
    template => '/path/to/template',
    subst    => { one => 1, two => 2 },
  );

  my @created = $render->render('/path/to/output');

=head1 DESCRIPTION

B<File::Stubb::Render> is a module that provides an object-oriented interface
to L<stubb>'s template rendering routines. This is a private module for L<stubb>.
For user documentation, consult the L<stubb> manual.

=head1 METHODS

=over 4

=item $render = File::Stubb::Render->new(%params)

Creates a new B<File::Stubb::Render> object from C<%params>. The following are
valid parameters:

=over 4

=item template

Path to template file. Required

=item subst

Hash ref of substitution parameters.

=item render_hidden

Boolean determining whether to render hidden files from a template directory.
Defaults to false.

=item follow_symlinks

Boolean determining whether to render the file symlinks point to, or to copy
the symlinks themselves in template directories. Defaults to true.

=item copy_perms

Boolean determining whether to copy the permissions of a template file when
rendering. Defaults to false.

=item restricted

Boolean determining whether to render files in a "restricted" mode. When
restricted, Perl targets and shell targets will not be rendered and left as-is.

=item defaults

Boolean determining whether to use any default substitution parameters
provided by a template's F<.stubb.json>.

=item ignore_config

Boolean determining whether a template's config file should be ignored during
initialization or not. Defaults to false.

=back

=item @created = $render->render($output)

Render template to C<$output>. Returns a list of created files.

For documentation on how L<stubb> renders files, consult the L<stubb> manual.

=item $targets = $render->targets()

Returns a hash ref list of targets in the object's template. The hash ref will
look something like this:

  {
    basic => [ ... ],
    perl  => [ ... ],
    shell => [ ... ],
  }

=item $new = $render->render_path($path)

Renders C<$path> as a path name.

=item $template = $render->template()

Get the path to C<$render>'s template file.

=item $subst = $render->subst()

=item $render->set_subst($subst)

Getter/setter for C<$render>'s substitution parameter hash ref.

=item $hidden = $render->hidden()

=item $render->set_hidden($hidden)

Getter/setter for C<$render>'s render hidden files flag.

=item $follow = $render->follow_symlinks()

=item $render->set_follow_symlinks($follow)

Getter/setter for C<$render>'s follow symlinks flag.

=item $copy = $render->copy_perms

=item $render->set_copy_perms($copy)

Getter/setter for C<$render>'s copy perms flag.

=item $rest = $render->restricted

=item $render->set_restricted($rest)

Getter/setter for C<$render>'s restricted flag.

=item $def = $render->defaults()

Getter for C<$render>'s defaults flag.

=item $ign = $render->ignore_config()

Getter for C<$render>'s ignore_config flag.

=back

=head1 AUTHOR

Written by Samuel Young, E<lt>samyoung12788@gmail.comE<gt>.

This project's source can be found on its
L<Codeberg page|https://codeberg.org/1-1sam/stubb.git>. Comments and pull
requests are welcome!

=head1 COPYRIGHT

Copyright (C) 2025 Samuel Young

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 SEE ALSO

L<stubb>

=cut

# vim: expandtab shiftwidth=4
