package File::Remove;
$File::Remove::VERSION = '1.61';
use 5.008;
use strict;
use warnings;

use vars qw{ @ISA @EXPORT_OK };
use vars qw{ $DEBUG $unlink $rmdir    };

BEGIN
{
    @ISA       = qw{ Exporter };
    @EXPORT_OK = qw{ remove rm clear trash };
}

use File::Path ();
use File::Glob ();
use File::Spec 3.29 ();
use Cwd 3.29        ();

# $debug variable must be set before loading File::Remove.
# Convert to a constant to allow debugging code to be pruned out.
use constant DEBUG => !!$DEBUG;

# Are we on VMS?
# If so copy File::Path and assume VMS::Filespec is loaded
use constant IS_VMS => !!( $^O eq 'VMS' );

# Are we on Mac?
# If so we'll need to do some special trash work
use constant IS_MAC => !!( $^O eq 'darwin' );

# Are we on Win32?
# If so write permissions does not imply deletion permissions
use constant IS_WIN32 => !!( $^O =~ /^MSWin/ or $^O eq 'cygwin' );

# If we ever need a Mac::Glue object we will want to cache it.
my $glue;

#####################################################################
# Main Functions

my @CLEANUP = ();

## no critic
sub clear (@)
{
    my @files = expand(@_);

    # Do the initial deletion
    foreach my $file (@files)
    {
        next unless -e $file;
        remove( \1, $file );
    }

    # Delete again at END-time.
    # Save the current PID so that forked children
    # won't delete things that the parent expects to
    # live until their end-time.
    push @CLEANUP, map { [ $$, $_ ] } @files;
}
## use critic

END
{
    foreach my $file (@CLEANUP)
    {
        next unless $file->[0] == $$;
        next unless -e $file->[1];
        remove( \1, $file->[1] );
    }
}

# Acts like unlink would until given a directory as an argument, then
# it acts like rm -rf ;) unless the recursive arg is zero which it is by
# default
## no critic
sub remove (@)
{
    ## use critic
    my $recursive = ( ref $_[0] eq 'SCALAR' ) ? shift : \0;
    my $opts      = ( ref $_[0] eq 'HASH' )   ? shift : { glob => 1 };
    my @files     = _expand_with_opts( $opts, @_ );

    # Iterate over the files
    my @removes;
    foreach my $path (@files)
    {
        # need to check for symlink first
        # could be pointing to nonexisting/non-readable destination
        if ( -l $path )
        {
            print "link: $path\n" if DEBUG;
            if ( $unlink ? $unlink->($path) : unlink($path) )
            {
                push @removes, $path;
            }
            next;
        }
        unless ( -e $path )
        {
            print "missing: $path\n" if DEBUG;
            push @removes, $path;    # Say we deleted it
            next;
        }
        my $can_delete;
        if (IS_VMS)
        {
            $can_delete = VMS::Filespec::candelete($path);
        }
        elsif (IS_WIN32)
        {
            # Assume we can delete it for the moment
            $can_delete = 1;
        }
        elsif ( -w $path )
        {
            # We have write permissions already
            $can_delete = 1;
        }
        elsif ( $< == 0 )
        {
            # Unixy and root
            $can_delete = 1;
        }
        elsif ( ( lstat($path) )[4] == $< )
        {
            # I own the file
            $can_delete = 1;
        }
        else
        {
            # I don't think we can delete it
            $can_delete = 0;
        }
        unless ($can_delete)
        {
            print "nowrite: $path\n" if DEBUG;
            next;
        }

        if ( -f $path )
        {
            print "file: $path\n" if DEBUG;
            unless ( -w $path )
            {
                # Make the file writable (implementation from File::Path)
                ( undef, undef, my $rp ) = lstat $path or next;
                $rp &= 07777;    # Don't forget setuid, setgid, sticky bits
                $rp |= 0600;     # Turn on user read/write
                chmod $rp, $path;
            }
            if ( $unlink ? $unlink->($path) : unlink($path) )
            {
                # Failed to delete the file
                next if -e $path;
                push @removes, $path;
            }

        }
        elsif ( -d $path )
        {
            print "dir: $path\n" if DEBUG;
            my $dir = File::Spec->canonpath($path);

            # Do we need to move our cwd out of the location
            # we are planning to delete?
            my $chdir = _moveto($dir);
            if ( length $chdir )
            {
                chdir($chdir) or next;
            }

            if ($$recursive)
            {
                if ( File::Path::rmtree( [$dir], DEBUG, 0 ) )
                {
                    # Failed to delete the directory
                    next if -e $path;
                    push @removes, $path;
                }

            }
            else
            {
                my ($save_mode) = ( stat $dir )[2];
                chmod $save_mode & 0777,
                    $dir;    # just in case we cannot remove it.
                if ( $rmdir ? $rmdir->($dir) : rmdir($dir) )
                {
                    # Failed to delete the directory
                    next if -e $path;
                    push @removes, $path;
                }
            }

        }
        else
        {
            print "???: $path\n" if DEBUG;
        }
    }

    return @removes;
}

sub rm (@)
{
    goto &remove;
}

sub trash (@)
{
    local $unlink = $unlink;
    local $rmdir  = $rmdir;

    if ( ref $_[0] eq 'HASH' )
    {
        my %options = %{ +shift @_ };
        $unlink = $options{unlink};
        $rmdir  = $options{rmdir};

    }
    elsif (IS_WIN32)
    {
        local $@;
        eval 'use Win32::FileOp ();';
        die "Can't load Win32::FileOp to support the Recycle Bin: \$@ = $@"
            if length $@;
        $unlink = \&Win32::FileOp::Recycle;
        $rmdir  = \&Win32::FileOp::Recycle;

    }
    elsif (IS_MAC)
    {
        unless ($glue)
        {
            local $@;
            eval 'use Mac::Glue ();';
            die
"Can't load Mac::Glue::Finder to support the Trash Can: \$@ = $@"
                if length $@;
            $glue = Mac::Glue->new('Finder');
        }
        my $code = sub {
            my @files =
                map { Mac::Glue::param_type( Mac::Glue::typeAlias() => $_ ) }
                @_;
            $glue->delete( \@files );
        };
        $unlink = $code;
        $rmdir  = $code;
    }
    else
    {
        die
"Support for trash() on platform '$^O' not available at this time.\n";
    }

    remove(@_);
}

sub undelete (@)
{
    goto &trash;
}

######################################################################
# Support Functions

sub _expand_with_opts
{
    my $opts = shift;
    return ( $opts->{glob} ? expand(@_) : @_ );
}

sub expand (@)
{
    map { -e $_ ? $_ : File::Glob::bsd_glob($_) } @_;
}

# Do we need to move to a different directory to delete a directory,
# and if so which.
sub _moveto
{
    my $remove = File::Spec->rel2abs(shift);
    my $cwd    = @_ ? shift : Cwd::cwd();

    # Do everything in absolute terms
    $remove = Cwd::abs_path($remove);
    $cwd    = Cwd::abs_path($cwd);

    # If we are on a different volume we don't need to move
    my ( $cv, $cd ) = File::Spec->splitpath( $cwd,    1 );
    my ( $rv, $rd ) = File::Spec->splitpath( $remove, 1 );
    return '' unless $cv eq $rv;

    # If we have to move, it's to one level above the deletion
    my @cd = File::Spec->splitdir($cd);
    my @rd = File::Spec->splitdir($rd);

    # Is the current directory the same as or inside the remove directory?
    unless ( @cd >= @rd )
    {
        return '';
    }
    foreach ( 0 .. $#rd )
    {
        $cd[$_] eq $rd[$_] or return '';
    }

    # Confirmed, the current working dir is in the removal dir
    pop @rd;
    return File::Spec->catpath( $rv, File::Spec->catdir(@rd), '' );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

File::Remove - Remove files and directories

=head1 VERSION

version 1.61

=head1 SYNOPSIS

    use File::Remove 'remove';

    # removes (without recursion) several files
    remove( '*.c', '*.pl' );

    # removes (with recursion) several directories
    remove( \1, qw{directory1 directory2} );

    # removes (with recursion) several files and directories
    remove( \1, qw{file1 file2 directory1 *~} );

    # removes without globbing:
    remove( \1, {glob => 0}, '*');

    # trashes (with support for undeleting later) several files
    trash( '*~' );

=head1 DESCRIPTION

B<File::Remove::remove> removes files and directories.  It acts like
B</bin/rm>, for the most part.  Although C<unlink> can be given a list
of files, it will not remove directories; this module remedies that.
It also accepts wildcards, * and ?, as arguments for filenames.

B<File::Remove::trash> accepts the same arguments as B<remove>, with
the addition of an optional, infrequently used "other platforms"
hashref.

=head1 SUBROUTINES

=head2 remove

Removes files and directories.  Directories are removed recursively like
in B<rm -rf> if the first argument is a reference to a scalar that
evaluates to true.  If the first argument is a reference to a scalar,
then it is used as the value of the recursive flag.  By default it's
false so only pass \1 to it.

If the next argument is a hash reference then it is a key/values of options.
Currently, there is one supported option of C<<< 'glob' => 0 >>> which prevents
globbing. E.g:

    remove(\1, {glob => 0}, '*');

Will not remove files globbed by '*' and will only remove the file
called asterisk if it exists.

In list context it returns a list of files/directories removed, in
scalar context it returns the number of files/directories removed.  The
list/number should match what was passed in if everything went well.

=head2 rm

Just calls B<remove>.  It's there for people who get tired of typing
B<remove>.

=head2 clear

The C<clear> function is a version of C<remove> designed for
use in test scripts. It takes a list of paths that it will both
initially delete during the current test run, and then further
flag for deletion at END-time as a convenience for the next test
run.

=head2 trash

Removes files and directories, with support for undeleting later.
Accepts an optional "other platforms" hashref, passing the remaining
arguments to B<remove>.

=over 4

=item Win32

Requires L<Win32::FileOp>.

Installation not actually enforced on Win32 yet, since L<Win32::FileOp>
has badly failing dependencies at time of writing.

=item OS X

Requires L<Mac::Glue>.

=item Other platforms

The first argument to trash() must be a hashref with two keys,
'rmdir' and 'unlink', each referencing a coderef.  The coderefs
will be called with the filenames that are to be deleted.

=back

=head2 expand

B<DO NOT USE.> Kept for legacy.

=head2 undelete

B<DO NOT USE.> Kept for legacy.

=head1 SUPPORT

Bugs should always be submitted via the CPAN bug tracker

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=File-Remove>

For other issues, contact the maintainer.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Taken over by Shlomi Fish (L<http://www.shlomifish.org/>) while disclaiming
all rights and placing his modifications under
CC0/public-domain/MIT/any-other-licence.

Some parts copyright 2006 - 2012 Adam Kennedy.

Taken over by Adam Kennedy E<lt>adamk@cpan.orgE<gt> to fix the
"deep readonly files" bug, and do some package cleaning.

Some parts copyright 2004 - 2005 Richard Soderberg.

Taken over by Richard Soderberg E<lt>perl@crystalflame.netE<gt> to
port it to L<File::Spec> and add tests.

Original copyright: 1998 by Gabor Egressy, E<lt>gabor@vmunix.comE<gt>.

This program is free software; you can redistribute and/or modify it under
the same terms as Perl itself.

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/File-Remove>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=File-Remove>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/File-Remove>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/F/File-Remove>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=File-Remove>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=File::Remove>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-file-remove at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=File-Remove>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/File-Remove>

  git clone git://github.com/shlomif/File-Remove.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-Remove> or by email to
L<bug-file-remove@rt.cpan.org|mailto:bug-file-remove@rt.cpan.org>.

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 1998 by Gabor Egressy.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
