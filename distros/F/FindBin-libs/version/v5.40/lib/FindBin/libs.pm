########################################################################
# housekeeping
########################################################################

package FindBin::libs   v4.0.4;
use v5.40;

use File::Basename;

use Carp        qw( croak                   );
use List::Util  qw( uniq first              );
use Symbol      qw( qualify qualify_to_ref  );

use File::Spec::Functions
qw
(
    splitpath
    splitdir
    catpath
    catdir
    rel2abs
);

use FindBin::Bin        qw( $Bin        );
use FindBin::Parents    qw( dir_paths   );

########################################################################
# package variables
########################################################################

my %defaultz =
(
    base    => 'lib'
  , use     => undef
  , blib    => undef   # prefer ./blib at the first level

  , subdir  => ''      # add this subdir also if found.
  , subonly => undef   # leave out lib's, use only subdir.
  , export  => undef   # push variable into caller's space.
  , append  => undef   # push onto existing array (vs. overwrite)
  , verbose => undef   # boolean: print inputs, results.
  , debug   => undef   # boolean: set internal breakpoints.

  , print   => 1       # display the results

  , p5lib   => undef   # prefix PERL5LIB with the results

  , ignore => q{,usr} # dir's to skip looking for ./lib
);

# saves passing this between import and $handle_args.

my %argz    = ();
my $verbose = '';
my $empty   = q{};

########################################################################
# utility subs
########################################################################

# HAK ALERT: $Bin is an absolute path, there are cases
# where splitdir does not add the leading '' onto the
# directory path for it on VMS. Fix is to unshift a leading
# '' into @dirpath where the leading entry is true.

my $append_subdir
= sub( $path, @subz )
{
    my ( $vol, $dir )   = splitpath $path, 1;

    catpath
    (
        $vol
      , catdir( $dir => @subz )
      , ''
    )
};

my $find_libs
= sub
{
    my $base    = basename ( shift // $argz{ base } );
    my $subdir  = $argz{ subdir } // '';
    my $subonly = defined $argz{ subonly } || defined $argz{ scalar };
    my @found   = ();
    my $ignorz  = $argz{ ignore };

    say STDERR "\nSearching $Bin for '$base' ($subdir)..."
    if $verbose;

    my @search
    = do
    {
        my @dirz    = dir_paths $Bin, 1;

        say STDERR join "\n\t" => 'Parent Dirs:', @dirz
        if $verbose;;

        my ( $vol ) = splitpath $dirz[0];
        my %skipz
        = map
        {
            (
                catpath( $vol => $_, '' ) => 1
            )
        }
        $ignorz->@*;

        my @subz
        = grep
        {
            ! exists $skipz{ $_ }
        }
        map
        {
            $_->$append_subdir( $base )
        }
        @dirz;

        say STDERR join "\n\t" => 'Search Subs:', @subz
        if $verbose;;

        if( $subdir )
        {
            map
            {
                my $sub = $_->$append_subdir( $subdir );

                $subonly
                ? $sub
                : [ $sub => $_ ]
            }
            @subz
        }
        else
        {
            $subonly    = 1;
            @subz
        }
    };

    if( $argz{ scalar } )
    {
        # return at most one item.

        first
        {
            -e
        }
        @search
    }
    elsif( $subonly )
    {
        # grab all the extant items on the list.

        grep
        {
            -e
        }
        @search
    }
    else
    {
        # if the subdir exists then return it and the subdir.

        map
        {
            -e $_->[0]
            ? $_->@*
            : ()
        }
        @search
    }
};

my $handle_args
= sub
{
    # discard the module, rest are arguments.

    shift;

    # anything after the module are options with arguments
    # assigned via '='.

    %argz
    = map
    {
        my $use_undef
        = do
        {
            my %a   = ();
            @a{ qw( export ignore ) } = ();
            \%a
        };

        my ( $k, $v ) = split '=', $_, 2;

        exists $use_undef->{ $k }
        or $v //= 1;

        # "no" inverts the sense of the test.

        $k =~ s{^no}{}
        and $v  = ! $v;

        ( $k => $v )
    }
    @_;

    # exporting a subdir as a scalar requires stopping at
    # the subdir, ignoring its parent.

    $argz{ subonly }
    ||= $argz{ export } && $argz{ subdir } && $argz{ scalar };

    # stuff "debug=1" into your arguments and perl -d will stop here.

    $DB::single = 1 if defined $argz{ debug };

    # default if nothing is supplied is to use the result;
    # otherwise, without use supplied either of export or
    # p5lib will turn off use.

    if( exists $argz{ use } )
    {
        # nothing further to do
    }
    elsif( defined $argz{ export } || defined $argz{ p5lib } )
    {
        $argz{ use      } = undef;
    }
    else
    {
        $argz{ use } = 1;
    }

    # now apply the defaults, then sanity check the result.
    # base is a special case since it always has to exist.
    #
    # if $argz{ export } is defined but false then it takes
    # its default from $argz{ base }.

    while( my($k,$v) = each %defaultz )
    {
        # //= doesn't work here since undef may be a
        # legit default.

        exists $argz{ $k }
        or
        $argz{ $k } = $v;
    }

    exists $argz{ base } && $argz{ base }
    or croak "Bogus FindBin::libs: missing/false base argument, should be 'base=NAME'";

    $argz{ export } //= $argz{ base }
    if exists $argz{ export };

    $argz{ ignore } =
    [
        uniq split /\s*,\s*/, $argz{ ignore }
    ];

    $verbose = defined $argz{ verbose };
};

########################################################################
# interface
########################################################################

sub import
{
    &$handle_args;

    my @libz
    = map
    {
        # HAK ALERT: the regex does nothing for security,
        # just dodges -T.
        #
        # undef happens when nothing matches and the list
        # returned is empty. this just leaves @libz empty.

        defined
        ? m{ (.+) }xs
        : ()
    }
    $find_libs->();

    say join "\n\t" => 'Found Libs:', @libz
    if $verbose;

    my $caller = caller;

    if( $verbose || defined $argz{ print } )
    {
        local $\ = "\n";
        local $, = "\n\t";

        say STDERR "Found */$argz{ base }:", @libz
        if $verbose;
    }

    if( $argz{ export } )
    {
        # this has to run in order to install variables that
        # the caller is expecting to exist at runtime -- even
        # if they are empty/undef at the end of it.

        my $ref     = qualify_to_ref $argz{ export }, $caller;

        if( $verbose )
        {
            my $dest    = qualify $argz{ export }, $caller;

            $argz{ scalar }
            ? say STDERR "\nExporting: \$$dest"
            : say STDERR "\nExporting: \@$dest"
            ;
        }

        if( $argz{ scalar } )
        {
            *$ref
            = @libz
            ? \$libz[0]
            : \( my $a = '' )
            ;
        }
        elsif
        (
            $argz{ append }
            and
            my $ary = *{ $ref }{ ARRAY }
        )
        {
            push @$ary, @libz;
        }
        else
        {
            *$ref = \@libz
        }
    }

    # no 'else', these are not exclusive

    if( @libz )
    {
        if( defined $argz{ p5lib } )
        {
            # stuff the lib's found at the front of $ENV{ PERL5LIB }
            # yes, virginia, substr is an lvalue -- and saner than
            # dealing with \Q and a regex on arbitrary paths.

            ( substr $ENV{ PERL5LIB }, 0, 0 ) = join ':', @libz, '';

            say STDERR "\nUpdated PERL5LIB:\t$ENV{ PERL5LIB }"
            if $verbose;
        }

        if( $argz{ use } )
        {
            # this obviously won't work if lib ever depends
            # on the caller's package.
            #
            # it does avoids issues with -T blowing up on the
            # old eval technique.

            require lib;

            lib->import( @libz );
        }
    }

    0
}

# keep require happy

1

__END__

=head1 NAME

FindBin::libs - locate and a 'use lib' or export
directories based on $FindBin::Bin.

=head1 SYNOPSIS

    # search up $FindBin::Bin looking for ./lib directories
    # and "use lib" them.

    use FindBin::libs;

    # same as above with explicit defaults.

    use FindBin::libs qw( base=lib use=1 noexport noprint );

    # print the lib dir's before using them.

    use FindBin::libs qw( print );

    # find and use lib "altlib" dir's

    use FindBin::libs qw( base=altlib );

    # move starting point from $FindBin::Bin to '/tmp'

    use FindBin::libs qw( Bin=/tmp base=altlib );

    # skip "use lib", export "@altlib" instead.

    use FindBin::libs qw( base=altlib export );

    # find altlib directories, use lib them and export @mylibs

    use FindBin::libs qw( base=altlib export=mylibs use );

    # "export" defaults to "nouse", these two are identical:

    use FindBin::libs qw( export nouse );
    use FindBin::libs qw( export       );

    # use and export are not exclusive:

    use FindBin::libs qw( use export            ); # do both
    use FindBin::libs qw( nouse noexport print  ); # print only
    use FindBin::libs qw( nouse noexport        ); # do nothting at all

    # print a few interesting messages about the
    # items found.

    use FindBinlibs qw( verbose );

    # turn on a breakpoint after the args are prcoessed, before
    # any search/export/use lib is handled.

    use FindBin::libs qw( debug );

    # prefix PERL5LIB with the lib's found.

    use FindBin::libs qw( perl5lib );

    # find a subdir of the lib's looked for.
    # the first example will use both ../lib and
    # ../lib/perl5; the second ../lib/perl5/frobnicate
    # (if they exist). it can also be used with export
    # and base to locate special configuration dir's.
    #
    # subonly with a base is useful for locating config
    # files. this finds any "./config/mypackage" dir's
    # without including any ./config dir's. the result
    # ends up in @config (see also "export=", above).

    use FindBin::libs qw( subdir=perl5 );

    use FindBin::libs qw( subdir=perl5/frobnicate );

    use FindBin::libs qw( base=config subdir=mypackage subonly export );

    # base and subonly are also useful if your
    # project is stored in multiple git
    # repositories.
    #
    # say you need libs under api_foo/lib from api_bar: a
    # base of the git repository directory with subdir of
    # lib and subonly will pull in those lib dirs.

    use FindBin::libs qw( base=api_foo subdir=lib subonly );

    # no harm in using this multiple times to use
    # or export multple layers of libs.

    use FindBin::libs qw( export                                            );
    use FindBin::libs qw( export=found base=lib                             );
    use FindBin::libs qw( export=binz  base=bin            ignore=/foo,/bar );
    use FindBin::libs qw( export=junk  base=frobnicatorium                  );
    use FindBin::libs qw( export       base=foobar                          );

=head1 DESCRIPTION

=head2 General Use

This module will locate directories along the path to $FindBin::Bin
and "use lib" or export an array of the directories found. The default
is to locate "lib" directories and "use lib" them without printing
the list.

Options controll whether the lib's found are exported into the caller's
space, exported to PERL5LIB, or printed. Exporting or setting perl5lib
will turn off the default of "use lib" so that:

    use FindBin::libs qw( export );
    use FindBin::libs qw( p5lib  );

are equivalent to

    use FindBin::libs qw( export nouse );
    use FindBin::libs qw( p5lib  nouse );

Combining export with use or p5lib may be useful, p5lib and
use are probably not all that useful together.

=head3 Alternate directory name: 'base'

The basename searched for can be changed via 'base=name' so
that

    use FindBin::libs qw( base=altlib );

will search for directories named "altlib" and "use lib" them.

=head3 Exporting a variable: "export", "scalar", "append"

=over 4

=item "export"

This installs the results of locating directories into the caller's
space. Without any argument, export pushes out a variable named after
the located [sub]dir; an argument can be supplied to give the variable
name. Without the "scalar" option, the exported variable will be an
array in increasing order of "distance" (i.e., "up" the file tree);
with the "scalar" option only the first (i.e., "nearest") path is
exported.

If "export" is given then "nouse" is assumed; using both leaves the
variable exported and its contents handed to "use lib".

For example:

    use FindBin::libs qw( export );

will find "lib" directories and export @lib with the
list of directories found.

    use FindBin::libs qw( export=mylibs );

will find "lib" directories and export them as "@mylibs" to
the caller.

If "export" only is given then the "use" option defaults to
false. So:

    use FindBin::libs qw( export );
    use FindBin::libs qw( export nouse );

are equivalent. This is mainly for use when looking for data
directories with the "base=" argument.

If base is used with export the default array name is the base
directory value:

    use FindBin::libs qw( export base=meta );

exports @meta while

    use FindBin::libs qw( export=metadirs base=meta );

exports @metadirs as a list of paths ending in "/meta".

The use and export switches are not exclusive:

    use FindBin::libs qw( use export=mylibs );

will locate "lib" directories, use lib them, and export
@mylibs into the caller's package.

=item "scalar"

Only searches for the first directory, which is exported (or
overwritten) as a scalar rather than array. For example, if
a project directory has ./bin and ./etc dir's then #! code in
bin with

    use FindBin::libs qw( export scalar base=etc );

will have an $etc variable with the absolute path to ./bin/../etc.
For configuration varibles this is usually what you want and allows
for "$etc/Foo.conf" rather than "$etc[0]/Foo.conf".

=item "append"

Sometimes it's simpler to accumulate multiple searches into a
single array. Say for ./etc dir's in collection of standard
locations.

In that case:

    use FindBin::libs qw( export=etc base=foo subdir=etc );
    use FindBin::libs qw( export=etc base=bar subdir=etc append );

produces something like

    (
        /path/to/foo/etc
        /path/to/bar/etc
    )

without append @etc will have only ./bar/etc since the array would
be overwritten with each call to import.

=back

=head3 Subdirectories

The "subdir" and "subonly" settings will add or
exclusively use subdir's. This is useful if some
of your lib's are in ../lib/perl5 along with
../lib or all of the lib's are in ../lib/perl5.

These could be handled with:

    use FindBin::libs;
    use FindBin::libs qw( subdir=perl5 subonly );

which uses the "lib" dir's along with any lib/perl5 dirs.

This can also be handy for locating subdir's used
for configuring packages:

    use FindBin::libs qw( export base=config subonly=mypackage );

Will leave @config containing any mypackage dir's found up
the tree, nearest to closest.

The array format is convienent for locating configuration files
shared between projects in separate, sibling directories. For
example given:

    ./proj/Foo/etc
    ./proj/etc

with

    use FindBin::libs qw( export subdir=etc subonly )

will export @etc with qw( ../proj/Foo/etc ../proj/etc ) in lexical
order by distance from the #! code. At that point

    use List::Util qw( first );

    my $path = first { -e "$_/Global.config" } @etc;

will locate the nearest "Global.confg" file. Note that this is
not the same as using "scalar" since that will export
$etc with only ./Foo/etc.

=head3 Setting PERL5LIB: p5lib

For cases where the environment is more useful for setting
up library paths "p5lib" can be used to preload this variable.
This is mainly useful for automatically including directories
outside of the parent tree of $FindBin::bin.

For example, using:

    $ export PERL5LIB="/usr/local/foo:/usr/local/bar";

    $ myprog;

or simply

    $ PERL5LIB="/usr/local/lib/foo:/usr/lib/bar" myprog;

(depending on your shell) with #! code including:

    use FindBin::libs qw( p5lib );

will not "use lib" any dir's found but will update PERL5LIB
to something like:

    /home/me/sandbox/branches/lib:/usr/local/lib/foo:/usr/lib/bar

This can make controlling the paths used simpler and avoid
the use of symlinks for some testing (see examples below).

=head2 Skipping directories

By default, lib directories under / and /usr are
sliently ignored. This normally means that /lib, /usr/lib, and
'/usr/local/lib' are skipped. The "ignore" parameter provides
a comma-separated list of directories to ignore:

    use FindBin::libs qw( ignore=/skip/this,/and/this/also );

will replace the standard list and thus skip "/skip/this/lib"
and "/and/this/also/lib". It will search "/lib" and "/usr/lib"
since the argument ignore list replaces the original one.

=head2 Homegrown Library Management

An all-too-common occurrance managing perly projects is
being unable to install new modules becuse "it might
break things", and being unable to test them because
you can't install them. The usual outcome of this is a
collection of hard-coded

    use lib qw( /usr/local/projectX ... )

code at the top of each #! file that has to be updated by
hand for each new project.

To get away from this you'll often see relative paths
for the lib's, which require running the code from one
specific place. All this does is push the hard-coding
into cron, shell wrappers, and begin blocks.

With FindBin::libs you need suffer no more.

Automatically finding libraries in and above the executable
means you can put your modules into cvs/svn and check them
out with the project, have multiple copies shared by developers,
or easily move a module up the directory tree in a testbed
to regression test the module with existing code. All without
having to modify a single line of code.

=over 4

=item Code-speicfic modules.

Say your sandbox is in ./sandbox and you are currently
working in ./sandbox/projects/package/bin on a perl
executable. You may have some number of modules that
are specific -- or customized -- for this pacakge,
share some modules within the project, and may want
to use company-wide modules that are managed out of
./sandbox in development. All of this lives under a
./qc tree on the test boxes and under ./production
on production servers.

For simplicity, say that your sandbox lives in your
home direcotry, /home/jowbloe, as a directory or a
symlink.

If your #! uses FindBin::libs in it then it will
effectively

    use lib
    qw(
        /home/jowbloe/sandbox/lib
        /home/jowbloe/sandbox/project/lib
        /home/jowbloe/sandbox/project/package/lib
    );

if you run /home/jowbloe/sandbox/project/package/bin/foobar.
This will happen the same way if you use a relative or
absolute path, perl -d the thing, or if any of the lib
directories are symlinks outside of your sandbox.

This means that the most specific module directories
("closest" to your executable) will be picked up first.

If you have a version of Frobnicate.pm in your ./package/lib
for modifications fine: you'll use it before the one in
./project or ./sandbox.

Using the "p5lib" argument can help in case where some of
the code lives outside of the sandbox. To test a sandbox
version of some other module:

    use FindBin::libs qw( p5lib );

and

    $ PERL5LIB=/other/sandbox/module foobar;

=item Regression Testing

Everntually, however, you'll need to regression test
Frobnicate.pm with other modules.

Fine: move, copy, or symlink it into ./project/lib and
you can merrily run ./project/*/bin/* with it and see
if there are any problems. In fact, so can the nice
folks in QC.

If you want to install and test a new module just
prefix it into, say, ./sandbox/lib and all the code
that has FindBin::libs will simply use it first.

=item Testing with Symlinks

$FindBin::Bin is relative to where an executable is started from.
This allows a symlink to change the location of directories used
by FindBin::libs. Full regression testing of an executable can be
accomplished with a symlink:

    ./sandbox
        ./lib -> /homegrown/dir/lib
        ./lib/What/Ever.pm

        ./pre-change
            ./bin/foobar

        ./post-change
            ./lib/What/Ever.pm
            ./bin/foobar -> ../../pre-last-change/bin/foobar

Running foobar symlinked into the post-change directory will
test it with whatever collection of modules is in the post-change
directory. A large regression test on some collection of
changed modules can be performed with a few symlinks into a
sandbox area.

=item Managing Configuration and Meta-data Files

The "base" option alters FindBin::libs standard base directory.
This allows for a heirarchical set of metadata directories:

    ./sandbox
        ./meta
        ./project/
            ./meta

        ./project/package
            ./bin
            ./meta

with

    use FindBin::libs qw( base=meta export );

    sub read_meta
    {
        my $base = shift;

        for my $dir ( @meta )
        {
            # open the first one and return
            ...
        }

        # caller gets back empty list if nothing was read.

        ()
    }

=item using "prove" with local modules.

Modules that are not intended for CPAN will not usually have
a Makefile.PL or Build setup. This makes it harder to check
the code via "make test". Instead of hacking a one-time
Makefile, FindBin::libs can be used to locate modules in
a "lib" directory adjacent to the "t: directory. The setup
for this module would look like:


    ./t/01.t
    ./t/02.t
    ...

    ./lib/FindBin/libs.pm

since the *.t files use FindBin::libs they can locate the
most recent version of code without it having to be copied
into a ./blib directory (usually via make) before being
processed. If the module did not have a Makefile this would
allow:

    prove t/*.t;

to check the code.

=back

=head1 Notes

=head2 Alternatives

FindBin::libs was developed to avoid pitfalls with
the items listed below. As of FindBin::libs-1.20,
this is also mutli-platform, where other techniques
may be limited to *NIX or at least less portable.

=over 4

=item PERL5LIBS

PERL5LIB can be used to accomplish the same directory
lookups as FindBin::libs.  The problem is PERL5LIB often
contains absolte paths and does not automatically change
depending on where tests are run. This can leave you
modifying a file, changing directory to see if it works
with some other code and testing an unmodified version of
the code via PERL5LIB. FindBin::libs avoids this by using
$FindBin::bin to reference where the code is running from.

The same is true of trying to use almost any environmental
solution, with Perl's built in mechanism or one based on
$ENV{ PWD } or qx( pwd ).

Aside: Combining an existing PERL5LIB for
out-of-tree lookups with the "p5lib" option
works well for most development situations.

=item use lib qw( ../../../../Lib );

This works, but how many dots do you need to get all
the working lib's into a module or #! code? Class
distrubuted among several levels subdirectories may
have qw( ../../../lib ) vs. qw( ../../../../lib )
or various combinations of them. Validating these by
hand (let alone correcting them) leaves me crosseyed
after only a short session.

=item Anchor on a fixed lib directory.

Given a standard directory, it is possible to use
something like:

    BEGIN
    {
        my ( $libdir ) = $0 =~ m{ ^( .+? )/SOMEDIR/ }x;

        eval "use lib qw( $libdir )";
    }

This looks for a standard location (e.g., /path/to/Mylib)
in the executable path (or cwd) and uses that.

The main problem here is that if the anchor ever changes
(e.g., when moving code between projects or relocating
directories now that SVN supports it) the path often has
to change in multiple files. The regex also may have to
support multiple platforms, or be broken into more complicated
File::Spec code that probably looks pretty much like what

    use FindBin::libs qw( base=Mylib )

does anyway.

=back

=head2 FindBin::libs-1.2+ uses File::Spec

In order to accmodate a wider range of filesystems,
the code has been re-written to use File::Spec for
all directory and volume manglement.

=head1 See Also

=over 4

=item File::Spec

This is used for portability in dis- and re-assembling
directory paths based on $FindBin::Bin.

=item Older code.

FindBin::libs_5_8.pm is installed if $^V indicates
that the running perl is prior to v5.10. See the
./versions dir in the distro for list of Perl version
increments.

=back

=head1 BUGS

=over 4

=item

In order to avoid including junk, FindBin::libs
uses '-d' to test the items before including
them on the library list.

abs_path causes too many issues where symlinks
are useful, at this point I've given up trying
to make it work. This may leave multiple paths
to the same location in multiple points of the
directory stack. So be it.

This also means I've had to replace FindBin as
the source of the execution directory. I've used
a mirror of the Raku code for FindBin and
FindBin::Parent here as seprate modules. These
depend only on File::Spec and do not use abs_path.

=item

File::Spec 3.16 and prior have a bug in VMS of
not returning an absolute paths in splitdir for
dir's without a leading '.'. Fix for this is to
unshift '', @dirpath if $dirpath[0]. While not a
bug, this is obviously a somewhat kludgy workaround
and should be removed (with an added test for a
working version) once the File::Spec is fixed.

=item

The hack for prior-to-5.12 versions of perl is
messy, but is the only I've found that works for
the moment on *NIX, VMS, and MSW. I am not sure
whether any of these systems are normally configured
to share perl modules between versions. If the
moduels are not shared on multiple platforms then
I can make this work by managing the installation
rather than checking this every time at startup.

For the moment, at least, this seems to work.

=back

=head1 AUTHOR

Steven Lembark, Workhorse Computing <lembark@wrkhors.com>

=head1 COPYRIGHT

Copyright (C) 2003-2024, Steven Lembark, Workhorse Computing.

=head1 LICENSE

This code is released under the same terms as Perl-5.40
or any later version of Perl.
