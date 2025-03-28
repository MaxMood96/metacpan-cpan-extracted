package Module::ScanDeps;
use 5.008001;
use strict;
use warnings;
use vars qw( $VERSION @EXPORT @EXPORT_OK @ISA $CurrentPackage @IncludeLibs $ScanFileRE );

$VERSION   = '1.37';
@EXPORT    = qw( scan_deps scan_deps_runtime );
@EXPORT_OK = qw( scan_line scan_chunk add_deps scan_deps_runtime path_to_inc_name );

use Config;
require Exporter;
our @ISA = qw(Exporter);

use version;
use File::Path ();
use File::Temp ();
use FileHandle;
use Module::Metadata;
use List::Util qw ( any first );

# NOTE: Keep the following imports exactly as specified, even if the Module::ScanDeps source
# doesn't reference some of them. See '"use lib" idioms' for the reason.
use Cwd (qw(abs_path));
use File::Spec;
use File::Spec::Functions;
use File::Basename;

use constant is_insensitive_fs => File::Spec->case_tolerant();

$ScanFileRE = qr/(?:^|\\|\/)(?:[^.]*|.*\.(?i:p[ml]|t|al))$/;

my %_glob_cache;
my %_file_cache;
my $_cached_inc = "";

=head1 NAME

Module::ScanDeps - Recursively scan Perl code for dependencies

=head1 SYNOPSIS

Via the command-line program L<scandeps.pl>:

    % scandeps.pl *.pm          # Print PREREQ_PM section for *.pm
    % scandeps.pl -e "use utf8" # Read script from command line
    % scandeps.pl -B *.pm       # Include core modules
    % scandeps.pl -V *.pm       # Show autoload/shared/data files

Used in a program;

    use Module::ScanDeps;

    # standard usage
    my $hash_ref = scan_deps(
        files   => [ 'a.pl', 'b.pl' ],
        recurse => 1,
    );

    # shorthand; assume recurse == 1
    my $hash_ref = scan_deps( 'a.pl', 'b.pl' );

    # App::Packer::Frontend compatible interface
    # see App::Packer::Frontend for the structure returned by get_files
    my $scan = Module::ScanDeps->new;
    $scan->set_file( 'a.pl' );
    $scan->set_options( add_modules => [ 'Test::More' ] );
    $scan->calculate_info;
    my $files = $scan->get_files;

=head1 DESCRIPTION

This module scans potential modules used by perl programs, and returns a
hash reference; its keys are the module names as appears in C<%INC>
(e.g. C<Test/More.pm>); the values are hash references with this structure:

    {
        file    => '/usr/local/lib/perl5/5.8.0/Test/More.pm',
        key     => 'Test/More.pm',
        type    => 'module',    # or 'autoload', 'data', 'shared'
        used_by => [ 'Test/Simple.pm', ... ],
        uses    => [ 'Test/Other.pm', ... ],
    }

One function, C<scan_deps>, is exported by default.  Other
functions such as (C<scan_line>, C<scan_chunk>, C<add_deps>, C<path_to_inc_name>)
are exported upon request.

Users of B<App::Packer> may also use this module as the dependency-checking
frontend, by tweaking their F<p2e.pl> like below:

    use Module::ScanDeps;
    ...
    my $packer = App::Packer->new( frontend => 'Module::ScanDeps' );
    ...

Please see L<App::Packer::Frontend> for detailed explanation on
the structure returned by C<get_files>.

=head2 B<scan_deps>

    $rv_ref = scan_deps(
        files      => \@files,     recurse => $recurse,
        rv         => \%rv,        skip    => \%skip,
        compile    => $compile,    execute => $execute,
    );
    $rv_ref = scan_deps(@files); # shorthand, with recurse => 1

This function scans each file in C<@files>, registering their
dependencies into C<%rv>, and returns a reference to the updated
C<%rv>.  The meaning of keys and values are explained above.

If C<$recurse> is true, C<scan_deps> will call itself recursively,
to perform a breadth-first search on text files (as defined by the
-T operator) found in C<%rv>.

If the C<\%skip> is specified, files that exists as its keys are
skipped.  This is used internally to avoid infinite recursion.

If C<$compile> or C<$execute> is true, runs C<files> in either
compile-only or normal mode, then inspects their C<%INC> after
termination to determine additional runtime dependencies.

If C<$execute> is an array reference, passes C<@$execute>
as arguments to each file in C<@files> when it is run.

If performance of the scanning process is a concern, C<cache_file> can be
set to a filename. The scanning results will be cached and written to the
file. This will speed up the scanning process on subsequent runs.

Additionally, an option C<warn_missing> is recognized. If set to true,
C<scan_deps> issues a warning to STDERR for every module file that the
scanned code depends but that wasn't found. Please note that this may
also report numerous false positives. That is why by default, the heuristic
silently drops all dependencies it cannot find.

=head2 B<scan_deps_runtime>

Like B<scan_deps>, but skips the static scanning part.

=head2 B<scan_line>

    @modules = scan_line($line);

Splits a line into chunks (currently with the semicolon characters), and
return the union of C<scan_chunk> calls of them.

If the line is C<__END__> or C<__DATA__>, a single C<__END__> element is
returned to signify the end of the program.

Similarly, it returns a single C<__POD__> if the line matches C</^=\w/>;
the caller is responsible for skipping appropriate number of lines
until C<=cut>, before calling C<scan_line> again.

=head2 B<scan_chunk>

    $module = scan_chunk($chunk);
    @modules = scan_chunk($chunk);

Apply various heuristics to C<$chunk> to find and return the module
name(s) it contains.  In scalar context, returns only the first module
or C<undef>.

=head2 B<add_deps>

    $rv_ref = add_deps( rv => \%rv, modules => \@modules );
    $rv_ref = add_deps( @modules ); # shorthand, without rv

Resolves a list of module names to its actual on-disk location, by
finding in C<@INC> and C<@Module::ScanDeps::IncludeLibs>;
modules that cannot be found are skipped.

This function populates the C<%rv> hash with module/filename pairs, and
returns a reference to it.

=head2 B<path_to_inc_name>

    $perl_name = path_to_inc_name($path, $warn)

Assumes C<$path> refers to a perl file and does it's best to return the
name as it would appear in %INC. Returns undef if no match was found
and a prints a warning to STDERR if C<$warn> is true.

E.g. if C<$path> = perl/site/lib/Module/ScanDeps.pm then C<$perl_name>
will be Module/ScanDeps.pm.

=head1 NOTES

=head2 B<@Module::ScanDeps::IncludeLibs>

You can set this global variable to specify additional directories in
which to search modules without modifying C<@INC> itself.

=head2 B<$Module::ScanDeps::ScanFileRE>

You can set this global variable to specify a regular expression to
identify what files to scan. By default it includes all files of
the following types: .pm, .pl, .t and .al. Additionally, all files
without a suffix are considered.

For instance, if you want to scan all files then use the following:

C<$Module::ScanDeps::ScanFileRE = qr/./>

=head1 CAVEATS

This module intentionally ignores the B<BSDPAN> hack on FreeBSD -- the
additional directory is removed from C<@INC> altogether.

The static-scanning heuristic is not likely to be 100% accurate, especially
on modules that dynamically load other modules.

Chunks that span multiple lines are not handled correctly.  For example,
this one works:

    use base 'Foo::Bar';

But this one does not:

    use base
        'Foo::Bar';

=cut

my $SeenTk;
my %SeenRuntimeLoader;

# match "use LOADER LIST" chunks; sets $1 to LOADER and $2 to LIST
my $LoaderRE =
    qr/^ use \s+
      ( asa
      | base
      | parent
      | prefork
      | POE
      | encoding
      | maybe
      | only::matching
      | Mojo::Base
      | Catalyst
      )(?!\:) \b \s* (.*)
      /sx;

# Pre-loaded module dependencies {{{
my %Preload = (
    'AnyDBM_File.pm'                    => [qw( SDBM_File.pm )],
    'AnyEvent.pm'                       => 'sub',
    'Authen/SASL.pm'                    => 'sub',

    'B/Hooks/EndOfScope.pm'             =>
        [qw( B/Hooks/EndOfScope/PP.pm B/Hooks/EndOfScope/XS.pm )],
    'Bio/AlignIO.pm'                    => 'sub',
    'Bio/Assembly/IO.pm'                => 'sub',
    'Bio/Biblio/IO.pm'                  => 'sub',
    'Bio/ClusterIO.pm'                  => 'sub',
    'Bio/CodonUsage/IO.pm'              => 'sub',
    'Bio/DB/Biblio.pm'                  => 'sub',
    'Bio/DB/Flat.pm'                    => 'sub',
    'Bio/DB/GFF.pm'                     => 'sub',
    'Bio/DB/Taxonomy.pm'                => 'sub',
    'Bio/Graphics/Glyph.pm'             => 'sub',
    'Bio/MapIO.pm'                      => 'sub',
    'Bio/Matrix/IO.pm'                  => 'sub',
    'Bio/Matrix/PSM/IO.pm'              => 'sub',
    'Bio/OntologyIO.pm'                 => 'sub',
    'Bio/PopGen/IO.pm'                  => 'sub',
    'Bio/Restriction/IO.pm'             => 'sub',
    'Bio/Root/IO.pm'                    => 'sub',
    'Bio/SearchIO.pm'                   => 'sub',
    'Bio/SeqIO.pm'                      => 'sub',
    'Bio/Structure/IO.pm'               => 'sub',
    'Bio/TreeIO.pm'                     => 'sub',
    'Bio/LiveSeq/IO.pm'                 => 'sub',
    'Bio/Variation/IO.pm'               => 'sub',

    'Catalyst.pm'                       => sub {
        return ('Catalyst/Runtime.pm',
                'Catalyst/Dispatcher.pm',
                _glob_in_inc('Catalyst/DispatchType', 1));
    },
    'Catalyst/Engine.pm'                => 'sub',
    'CGI/Application/Plugin/Authentication.pm' =>
        [qw( CGI/Application/Plugin/Authentication/Store/Cookie.pm )],
    'CGI/Application/Plugin/AutoRunmode.pm' => [qw( Attribute/Handlers.pm )],
    'charnames.pm'                      => \&_unicore,
    'Class/Load.pm'                     => [qw( Class/Load/PP.pm )],
    'Class/MakeMethods.pm'              => 'sub',
    'Class/MethodMaker.pm'              => 'sub',
    'Class/Plain.pm'                    => [qw( XS/Parse/Keyword.pm )],
    'Config/Any.pm'                     =>'sub',
    'Crypt/Random.pm'                   => sub {
        _glob_in_inc('Crypt/Random/Provider', 1);
    },
    'Crypt/Random/Generator.pm'         => sub {
        _glob_in_inc('Crypt/Random/Provider', 1);
    },

    'Date/Manip.pm'                     =>
        [qw( Date/Manip/DM5.pm Date/Manip/DM6.pm )],
    'Date/Manip/Base.pm'                => sub {
        _glob_in_inc('Date/Manip/Lang', 1);
    },
    'Date/Manip/TZ.pm'                  => sub {
        return (_glob_in_inc('Date/Manip/TZ', 1),
                _glob_in_inc('Date/Manip/Offset', 1));
    },
    'DateTime/Format/Builder/Parser.pm' => 'sub',
    'DateTime/Format/Natural.pm'        => 'sub',
    'DateTime/Locale.pm'                => 'sub',
    'DateTime/TimeZone.pm'              => 'sub',
    'DBI.pm'                            => sub {
        grep !/\bProxy\b/, _glob_in_inc('DBD', 1);
    },
    'DBIx/Class.pm'                     => 'sub',
    'DBIx/SearchBuilder.pm'             => 'sub',
    'DBIx/Perlish.pm'                   => [qw( attributes.pm )],
    'DBIx/ReportBuilder.pm'             => 'sub',
    'Device/ParallelPort.pm'            => 'sub',
    'Device/SerialPort.pm'              =>
        [qw( termios.ph asm/termios.ph sys/termiox.ph sys/termios.ph sys/ttycom.ph )],
    'diagnostics.pm'                    => sub {
        # shamelessly taken and adapted from diagnostics.pm
        use Config;
        my($privlib, $archlib) = @Config{qw(privlibexp archlibexp)};
        if ($^O eq 'VMS') {
            require VMS::Filespec;
            $privlib = VMS::Filespec::unixify($privlib);
            $archlib = VMS::Filespec::unixify($archlib);
        }

        for (
              "pod/perldiag.pod",
              "Pod/perldiag.pod",
              "pod/perldiag-$Config{version}.pod",
              "Pod/perldiag-$Config{version}.pod",
              "pods/perldiag.pod",
              "pods/perldiag-$Config{version}.pod",
        ) {
            return $_ if _find_in_inc($_);
        }

        for (
              "$archlib/pods/perldiag.pod",
              "$privlib/pods/perldiag-$Config{version}.pod",
              "$privlib/pods/perldiag.pod",
        ) {
            return $_ if -f $_;
        }

        return 'pod/perldiag.pod';
    },

    'Email/Send.pm'                     => 'sub',
    'Event.pm'                          => sub {
        map "Event/$_.pm", qw( idle io signal timer var );
    },
    'ExtUtils/MakeMaker.pm'             => sub {
        grep /\bMM_/, _glob_in_inc('ExtUtils', 1);
    },

    'FFI/Platypus.pm'                   => 'sub',
    'File/Basename.pm'                  => [qw( re.pm )],
    'File/BOM.pm'                       => [qw( Encode/Unicode.pm )],
    'File/HomeDir.pm'                   => 'sub',
    'File/Spec.pm'                      => sub {
        require File::Spec;
        map { my $name = $_; $name =~ s!::!/!g; "$name.pm" } @File::Spec::ISA;
    },
    'Future/AsyncAwait.pm'              => [qw( XS/Parse/Keyword.pm )],
    'Future/AsyncAwait/Hooks.pm'        => [qw( XS/Parse/Keyword.pm )],

    'Gtk2.pm'                           => [qw( Cairo.pm )], # Gtk2.pm does: eval "use Cairo;"

    'HTTP/Entity/Parser.pm'             => 'sub',
    'HTTP/Message.pm'                   => [qw( URI/URL.pm URI.pm )],

    'Image/ExifTool.pm'                 => sub {
        return(
          (map $_->{name}, _glob_in_inc('Image/ExifTool', 0)), # also *.pl files
          qw( File/RandomAccess.pm ),
        );
    },
    'Image/Info.pm'                     => sub {
        return(
          _glob_in_inc('Image/Info', 1),
          qw( Image/TIFF.pm ),
        );
    },
    'IO.pm'                             => [qw(
        IO/Handle.pm        IO/Seekable.pm      IO/File.pm
        IO/Pipe.pm          IO/Socket.pm        IO/Dir.pm
    )],
    'IO/Socket.pm'                      => [qw( IO/Socket/UNIX.pm )],
    'IUP.pm'                            => 'sub',

    'JSON.pm'                           => sub {
        # add JSON/PP*.pm, JSON/PP/*.pm
        # and ignore other JSON::* modules (e.g. JSON/Syck.pm, JSON/Any.pm);
        # but accept JSON::XS, too (because JSON.pm might use it if present)
        return( grep /^JSON\/(PP|XS)/, _glob_in_inc('JSON', 1) );
    },
    'JSON/MaybeXS.pm'                   => [qw(
        Cpanel/JSON/XS.pm JSON/XS.pm JSON/PP.pm
    )],

    'List/Keywords.pm'                  => [qw( XS/Parse/Keyword.pm )],
    'List/MoreUtils.pm'                 => 'sub',
    'List/SomeUtils.pm'                 => 'sub',
    'Locale/Maketext/Lexicon.pm'        => 'sub',
    'Locale/Maketext/GutsLoader.pm'     => [qw( Locale/Maketext/Guts.pm )],
    'Log/Any.pm'                        => 'sub',
    'Log/Dispatch.pm'                   => 'sub',
    'Log/Log4perl.pm'                   => 'sub',
    'Log/Report/Dispatcher.pm'          => 'sub',
    'LWP/MediaTypes.pm'                 => [qw( LWP/media.types )],
    'LWP/Parallel.pm'                   => sub {
        _glob_in_inc( 'LWP/Parallel', 1 ),
        qw(
            LWP/ParallelUA.pm       LWP/UserAgent.pm
            LWP/RobotPUA.pm         LWP/RobotUA.pm
        ),
    },
    'LWP/Parallel/UserAgent.pm'         => [qw( LWP/Parallel.pm )],
    'LWP/UserAgent.pm'                  => sub {
        return(
          qw( URI/URL.pm URI/http.pm LWP/Protocol/http.pm ),
          _glob_in_inc("LWP/Authen", 1),
          _glob_in_inc("LWP/Protocol", 1),
        );
    },

    'Mail/Audit.pm'                     => 'sub',
    'Math/BigInt.pm'                    => 'sub',
    'Math/BigFloat.pm'                  => 'sub',
    'Math/Symbolic.pm'                  => 'sub',
    'MIME/Decoder.pm'                   => 'sub',
    'MIME/Types.pm'                     => [qw( MIME/types.db )],
    'Module/Build.pm'                   => 'sub',
    'Module/Pluggable.pm'               => sub {
        _glob_in_inc('$CurrentPackage/Plugin', 1);
    },
    'Moo.pm'                            => [qw( Class/XSAccessor.pm )],
    'Moose.pm'                          => sub {
        _glob_in_inc('Moose', 1),
        _glob_in_inc('Class/MOP', 1),
    },
    'MooseX/AttributeHelpers.pm'        => 'sub',
    'MooseX/POE.pm'                     => sub {
        _glob_in_inc('MooseX/POE', 1),
        _glob_in_inc('MooseX/Async', 1),
    },
    'MooX/HandlesVia.pm'                => sub {
        _glob_in_inc('Data/Perl', 1)
    },
    'Mozilla/CA.pm'                     => [qw( Mozilla/CA/cacert.pem )],
    'MozRepl.pm'                        => sub {
        qw( MozRepl/Log.pm MozRepl/Client.pm Module/Pluggable/Fast.pm ),
        _glob_in_inc('MozRepl/Plugin', 1),
    },
    'Module/Implementation.pm'          => \&_warn_of_runtime_loader,
    'Module/Runtime.pm'                 => \&_warn_of_runtime_loader,
    'Mojo/Util.pm'                      => sub {        # html_entities.txt
        map { $_->{name} } _glob_in_inc('Mojo/resources', 0)
    },
    'Mojo/IOLoop/TLS.pm'                => sub {        # server.{crt,key}
        map { $_->{name} } _glob_in_inc('Mojo/IOLoop/resources', 0)
    },

    'Net/DNS/Resolver.pm'               => 'sub',
    'Net/DNS/RR.pm'                     => 'sub',
    'Net/FTP.pm'                        => 'sub',
    'Net/HTTPS.pm'                      => [qw( IO/Socket/SSL.pm Net/SSL.pm )],
    'Net/Server.pm'                     => 'sub',
    'Net/SSH/Perl.pm'                   => 'sub',

    'Object/Pad.pm'                     => [qw( XS/Parse/Keyword.pm )],
    'Object/Pad/Keyword/Accessor.pm'    => [qw( XS/Parse/Keyword.pm )],

    'Package/Stash.pm'                  => [qw( Package/Stash/PP.pm Package/Stash/XS.pm )],
    'Pango.pm'                          => [qw( Cairo.pm )], # Pango.pm does: eval "use Cairo;"
    'PAR/Repository.pm'                 => 'sub',
    'PAR/Repository/Client.pm'          => 'sub',
    'Params/Validate.pm'                => 'sub',
    'Parse/AFP.pm'                      => 'sub',
    'Parse/Binary.pm'                   => 'sub',
    'PDF/API2/Resource/Font.pm'         => 'sub',
    'PDF/API2/Basic/TTF/Font.pm'        => sub {
        _glob_in_inc('PDF/API2/Basic/TTF', 1);
    },
    'PDF/Writer.pm'                     => 'sub',
    'PDL/NiceSlice.pm'                  => 'sub',
    'Perl/Critic.pm'                    => 'sub', #not only Perl/Critic/Policy
    'PerlIO.pm'                         => [qw( PerlIO/scalar.pm )],
    'Pod/Simple/Transcode.pm'           => [qw( Pod/Simple/TranscodeDumb.pm Pod/Simple/TranscodeSmart.pm )],
    'Pod/Usage.pm'                      => sub {  # from Pod::Usage (as of 1.61)
         $] >= 5.005_58 ? 'Pod/Text.pm' : 'Pod/PlainText.pm'
     },
    'POE.pm'                            => [qw( POE/Kernel.pm POE/Session.pm )],
    'POE/Component/Client/HTTP.pm'      => sub {
        _glob_in_inc('POE/Component/Client/HTTP', 1),
        qw( POE/Filter/HTTPChunk.pm POE/Filter/HTTPHead.pm ),
    },
    'POE/Kernel.pm'                     => sub {
        _glob_in_inc('POE/XS/Resource', 1),
        _glob_in_inc('POE/Resource', 1),
        _glob_in_inc('POE/XS/Loop', 1),
        _glob_in_inc('POE/Loop', 1),
    },
    'POSIX.pm'                          => sub {
        map $_->{name},
          _glob_in_inc('auto/POSIX/SigAction', 0),      # *.al files
          _glob_in_inc('auto/POSIX/SigRt', 0),          # *.al files
    },
    'PPI.pm'                            => 'sub',

    'Regexp/Common.pm'                  => 'sub',
    'RPC/XML/ParserFactory.pm'          => sub {
        _glob_in_inc('RPC/XML/Parser', 1);
    },

    'SerialJunk.pm'                     => [qw(
        termios.ph asm/termios.ph sys/termiox.ph sys/termios.ph sys/ttycom.ph
    )],
    'SOAP/Lite.pm'                      => sub {
        _glob_in_inc('SOAP/Transport', 1),
        _glob_in_inc('SOAP/Lite', 1),
    },
    'Socket/GetAddrInfo.pm'             => 'sub',
    'Specio/PartialDump.pm'             => \&_unicore,
    'SQL/Parser.pm'                     => sub {
        _glob_in_inc('SQL/Dialects', 1);
    },
    'SQL/Translator/Schema.pm'          => sub {
        _glob_in_inc('SQL/Translator', 1);
    },
    'Sub/Exporter/Progressive.pm'       => [qw( Sub/Exporter.pm )],
    'SVK/Command.pm'                    => sub {
        _glob_in_inc('SVK', 1);
    },
    'SVN/Core.pm'                       => sub {
        _glob_in_inc('SVN', 1),
        map { $_->{name} } _glob_in_inc('auto/SVN', 0),    # *.so, *.bs files
    },
    'Syntax/Keyword/Combine/Keys.pm'    => [qw( XS/Parse/Keyword.pm )],
    'Syntax/Keyword/Defer.pm'           => [qw( XS/Parse/Keyword.pm )],
    'Syntax/Keyword/Dynamically.pm'     => [qw( XS/Parse/Keyword.pm )],
    'Syntax/Keyword/Inplace.pm'         => [qw( XS/Parse/Keyword.pm )],
    'Syntax/Keyword/Match.pm'           => [qw( XS/Parse/Keyword.pm )],
    'Syntax/Keyword/Try.pm'             => [qw( XS/Parse/Keyword.pm )],

    'Template.pm'                       => 'sub',
    'Term/ReadLine.pm'                  => 'sub',
    'Test/Deep.pm'                      => 'sub',
    'threads/shared.pm'                 => [qw( attributes.pm )],
    # anybody using threads::shared is likely to declare variables
    # with attribute :shared
    'Tk.pm'                             => sub {
        $SeenTk = 1;
        qw( Tk/FileSelect.pm Encode/Unicode.pm );
    },
    'Tk/Balloon.pm'                     => [qw( Tk/balArrow.xbm )],
    'Tk/BrowseEntry.pm'                 => [qw( Tk/cbxarrow.xbm Tk/arrowdownwin.xbm )],
    'Tk/ColorEditor.pm'                 => [qw( Tk/ColorEdit.xpm )],
    'Tk/DragDrop/Common.pm'             => sub {
        _glob_in_inc('Tk/DragDrop', 1),
    },
    'Tk/FBox.pm'                        => [qw( Tk/folder.xpm Tk/file.xpm )],
    'Tk/Getopt.pm'                      => [qw( Tk/openfolder.xpm Tk/win.xbm )],
    'Tk/Toplevel.pm'                    => [qw( Tk/Wm.pm )],

    'Unicode/Normalize.pm'              => \&_unicore,
    'Unicode/UCD.pm'                    => \&_unicore,
    'URI.pm'                            => sub { grep !/urn/, _glob_in_inc('URI', 1) },
    'utf8_heavy.pl'                     => \&_unicore,

    'Win32/EventLog.pm'                 => [qw( Win32/IPC.pm )],
    'Win32/Exe.pm'                      => 'sub',
    'Win32/TieRegistry.pm'              => [qw( Win32API/Registry.pm )],
    'Win32/SystemInfo.pm'               => [qw( Win32/cpuspd.dll )],
    'Wx.pm'                             => [qw( attributes.pm )],

    'XML/Parser.pm'                     => sub {
        _glob_in_inc('XML/Parser/Style', 1),
        _glob_in_inc('XML/Parser/Encodings', 1),
    },
    'XML/SAX.pm'                        => [qw( XML/SAX/ParserDetails.ini ) ],
    'XML/Twig.pm'                       => [qw( URI.pm )],      # or URI::File or LWP
    'XML/Twig/XPath.pm'                 => [qw( XML/XPathEngine.pm XML/XPath.pm )],
    'XMLRPC/Lite.pm'                    => sub {
        _glob_in_inc('XMLRPC/Transport', 1);
    },
    'XS/Parse/Keyword/FromPerl.pm'      => [qw( XS/Parse/Keyword.pm )],

    'YAML.pm'                           => [qw( YAML/Loader.pm YAML/Dumper.pm )],
    'YAML/Any.pm'                       => sub {
        # try to figure out what YAML::Any would have used
        my $impl = eval "use YAML::Any; YAML::Any->implementation;";
        return _mod2pm($impl) unless $@;

        _glob_in_inc('YAML', 1);        # fallback
    },
);

# }}}

sub path_to_inc_name($$) {
    my $path = shift;
    my $warn = shift;
    my $inc_name;

    if ($path =~ m/\.pm$/io) {
        die "$path doesn't exist" unless (-f $path);
        my $module_info = Module::Metadata->new_from_file($path);
        die "Module::Metadata error: $!" unless defined($module_info);
        $inc_name = $module_info->name();
        if (defined($inc_name)) {
            $inc_name =~ s|\:\:|\/|og;
            $inc_name .= '.pm';
        } else {
            warn "# Couldn't find include name for $path\n" if $warn;
        }
    } else {
        # Bad solution!
        (my $vol, my $dir, $inc_name) = File::Spec->splitpath($path);
    }

    return $inc_name;
}

my $Keys = 'files|keys|recurse|rv|skip|first|execute|compile|warn_missing|cache_cb|cache_file';
sub scan_deps {
    my %args = (
        rv => {},
        (@_ and $_[0] =~ /^(?:$Keys)$/o) ? @_ : (files => [@_], recurse => 1)
    );

    if (!defined($args{keys})) {
        $args{keys} = [map {path_to_inc_name($_, $args{warn_missing})} @{$args{files}}];
    }
    my $cache_file = $args{cache_file};
    my $using_cache;
    if ($cache_file) {
        require Module::ScanDeps::Cache;
        $using_cache = Module::ScanDeps::Cache::init_from_file($cache_file);
        if( $using_cache ){
            $args{cache_cb} = Module::ScanDeps::Cache::get_cache_cb();
        }else{
            my @missing = Module::ScanDeps::Cache::prereq_missing();
            warn join(' ',
                      "Can not use cache_file: Needs Modules [",
                      @missing,
                      "]\n",);
        }
    }
    my ($type, $path);
    foreach my $input_file (@{$args{files}}) {
        if ($input_file !~ $ScanFileRE)  {
            warn "Skipping input file $input_file"
                 . " because it doesn't match \$Module::ScanDeps::ScanFileRE\n"
                    if $args{warn_missing};
            next;
        }

        $type = _gettype($input_file);
        $path = $input_file;
        if ($type eq 'module') {
            # necessary because add_deps does the search for shared libraries and such
            add_deps(
                used_by => undef,
                rv => $args{rv},
                modules => [path_to_inc_name($path, $args{warn_missing})],
                skip => undef,
                warn_missing => $args{warn_missing},
            );
        }
        else {
            _add_info(
                rv      => $args{rv},
                module  => path_to_inc_name($path, $args{warn_missing}),
                file    => $path,
                used_by => undef,
                type    => $type,
            );
        }
    }

    {
        ## "use lib" idioms
        #
        # We want to correctly interprete stuff like
        #
        #   use FindBin;
        #   use lib "$FindBin/../lib";
        #
        # Find out what $FindBin::Bin etc would have been if "use FindBin" had been
        # called in the first file to analyze.
        #
        # Notes:
        # (1) We don't want to reimplement FindBin, hence fake $0 locally (as the path of the
        #     first file analyzed) and call FindBin::again().
        # (2) If the caller of scan_deps() itself uses FindBin, we don't want to overwrite
        #     the value of "their" $FindBin::Bin.
        #
        # Other idioms seen sometimes:
        #
        # use lib "$ENV{FOO}/path";
        # use lib File::Spec->catdir($FindBin::Bin, qw[.. qqlib] );
        # use lib catdir(dirname($0), "perl");
        # use lib dirname(abs_path($0));
        #
        # In order to correctly interprete these, the modules referenced have to be imported.


        require FindBin;

        local $FindBin::Bin;
        #local $FindBin::RealBin;
        #local $FindBin::Script;
        #local $FindBin::RealScript;

        my $_0 = $args{files}[0];
        local *0 = \$_0;
        FindBin->again();

        scan_deps_static(\%args);
    }

    if ($args{execute} or $args{compile}) {
        scan_deps_runtime(
            rv      => $args{rv},
            files   => $args{files},
            execute => $args{execute},
            compile => $args{compile},
            skip    => $args{skip}
        );
    }

    if ( $using_cache ){
        Module::ScanDeps::Cache::store_cache();
    }

    # do not include the input files themselves as dependencies!
    delete $args{rv}{$_} foreach @{$args{files}};

    return ($args{rv});
}

sub scan_deps_static {
    my ($args) = @_;
    my ($files,  $keys, $recurse, $rv,
        $skip,  $first, $execute, $compile,
        $cache_cb, $_skip)
        = @$args{qw( files keys  recurse rv
                     skip  first execute compile
                     cache_cb _skip )};

    $rv   ||= {};
    $_skip ||= { %{$skip || {}} };

    foreach my $file (@{$files}) {
        my $key = shift @{$keys};
        next if $_skip->{$file}++;
        next if is_insensitive_fs()
          and $file ne lc($file) and $_skip->{lc($file)}++;
        next unless $file =~ $ScanFileRE;

        my @pm;
        my $found_in_cache;
        if ($cache_cb){
            my $pm_aref;
            # cache_cb populates \@pm on success
            $found_in_cache = $cache_cb->(action => 'read',
                                          key    => $key,
                                          file   => $file,
                                          modules => \@pm,
                                      );
            unless( $found_in_cache ){
                @pm = scan_file($file);
                $cache_cb->(action => 'write',
                            key    => $key,
                            file   => $file,
                            modules => \@pm,
                        );
            }
        }else{ # no caching callback given
            @pm = scan_file($file);
        }

        foreach my $pm (@pm){
            add_deps(
                     used_by => $key,
                     rv      => $args->{rv},
                     modules => [$pm],
                     skip    => $args->{skip},
                     warn_missing => $args->{warn_missing},
                 );

            my @preload = _get_preload($pm) or next;

            add_deps(
                     used_by => $key,
                     rv      => $args->{rv},
                     modules => \@preload,
                     skip    => $args->{skip},
                     warn_missing => $args->{warn_missing},
                 );
        }
    }

    # Top-level recursion handling {{{

    # prevent utf8.pm from being scanned
    $_skip->{$rv->{"utf8.pm"}{file}}++ if $rv->{"utf8.pm"};

    while ($recurse) {
        my $count = keys %$rv;
        my @files = sort grep { defined $_->{file} && -T $_->{file} } values %$rv;
        scan_deps_static({
            files    => [ map $_->{file}, @files ],
            keys     => [ map $_->{key},  @files ],
            rv       => $rv,
            skip     => $skip,
            recurse  => 0,
            cache_cb => $cache_cb,
            _skip    => $_skip,
        });
        last if $count == keys %$rv;
    }

    # }}}

    return $rv;
}

sub scan_deps_runtime {
    my %args = (
        rv   => {},
        (@_ and $_[0] =~ /^(?:$Keys)$/o) ? @_ : (files => [@_], recurse => 1)
    );
    my ($files, $rv, $execute, $compile) =
      @args{qw( files rv execute compile )};

    $files = (ref($files)) ? $files : [$files];

    if ($compile) {
        foreach my $file (@$files) {
            next unless $file =~ $ScanFileRE;

            _merge_rv(_info2rv(_compile_or_execute($file)), $rv);
        }
    }
    elsif ($execute) {
        foreach my $file (@$files) {
            $execute = [] unless ref $execute;  # make sure it's an array ref

            _merge_rv(_info2rv(_compile_or_execute($file, $execute)), $rv);
        }
    }

    return ($rv);
}

sub scan_file{
    my $file = shift;
    my %found;
    open my $fh, "<", $file or die "Cannot open $file: $!";

    $SeenTk = 0;
    # Line-by-line scanning
  LINE:
    while (my $line = <$fh>) {
        chomp($line);
        foreach my $pm (scan_line($line)) {
            last LINE if $pm eq '__END__';

            if ($pm eq '__POD__') {
                while ($line = <$fh>) {
                    next LINE if $line =~ /^=cut/;
                }
            }

            # Skip Tk hits from Term::ReadLine and Tcl::Tk
            my $pathsep = qr/\/|\\|::/;
            if ($pm =~ /^Tk\b/) {
                next if $file =~ /(?:^|${pathsep})Term${pathsep}ReadLine\.pm$/;
                next if $file =~ /(?:^|${pathsep})Tcl${pathsep}Tk\W/;
            }
            $SeenTk ||= $pm =~ /Tk\.pm$/;

            $found{$pm}++;
        }
    }
    close $fh or die "Cannot close $file: $!";
    return keys %found;
}

sub scan_line {
    my $line = shift;
    my %found;

    return '__END__' if $line =~ /^__(?:END|DATA)__$/;
    return '__POD__' if $line =~ /^=\w/;

    $line =~ s/\s*#.*$//;

  CHUNK:
    foreach (split(/;/, $line)) {
        s/^\s*//;
        s/^\w+:\s*//;           # remove LABEL:
        s/^(?:do\s*)?\{\s*//;   # handle single line blocks like 'do { package foo; use xx; }'
        s/\s*\}$//;

        if (/^package\s+(\w+)/) {
            $CurrentPackage = $1;
            $CurrentPackage =~ s{::}{/}g;
            next CHUNK;
        }
        # use VERSION:
        if (/^(?:use|require)\s+v?(\d[\d\._]*)/) {
          # include feature.pm if we have 5.9.5 or better
          if (version->new($1) >= version->new("5.9.5")) {
            # seems to catch 5.9, too (but not 5.9.4)
            $found{"feature.pm"}++;
          }
          next CHUNK;
        }

        if (my ($pragma, $args) = /^(?:use|no) \s+ (autouse|if) \s+ (.+)/x)
        {
            # NOTE: There are different ways the MODULE may
            # be specified for the "autouse" and "if" pragmas, e.g.
            #   use autouse Module => qw(func1 func2);
            #   use autouse "Module", qw(func1);
            my $module;
            if ($pragma eq "autouse") {
                ($module) = _parse_module_list($args);
            }
            else {
                # The syntax of the "if" pragma is
                #   use if COND, MODULE => ARGUMENTS
                # NOTE: This works only for simple conditions.
                $args =~ s/.*? (?:,|=>) \s*//x;
                ($module) = _parse_module_list($args);
            }
            $found{_mod2pm($pragma)}++;
            $found{_mod2pm($module)}++ if $module;
            next CHUNK;
        }

        if (my ($how, $libs) = /^(use \s+ lib \s+ | (?:unshift|push) \s+ \@INC \s*,\s*) (.+)/x)
        {
            my $archname = defined($Config{archname}) ? $Config{archname} : '';
            my $ver = defined($Config{version}) ? $Config{version} : '';
            while ((my $dir, $libs) = _parse_libs($libs))
            {
                next unless defined $dir;
                my @dirs = $dir;
                push @dirs, "$dir/$ver", "$dir/$archname", "$dir/$ver/$archname"
                    if $how =~ /lib/;
                foreach (@dirs) {
                    unshift(@INC, $_) if -d $_;
                }
            }
            next CHUNK;
        }

        $found{$_}++ for scan_chunk($_);
    }

    return sort keys %found;
}


# convert module name to file name
sub _mod2pm {
    my $mod = shift;
    $mod =~ s!::!/!g;
    return "$mod.pm";
}

# parse a comma-separated list of module names (as string literals or qw() lists)
sub _parse_module_list {
    my $list = shift;

    # split $list on anything that's not a word character or ":"
    # and ignore "q", "qq" and "qw"
    return grep { length and !/^:|^q[qw]?$/ } split(/[^\w:]+/, $list);
}

# incrementally parse a comma separated list library paths:
# returning a pair: the contents of the first strings literal and the remainder of the string
# - for "string", 'string', q/string/, qq/string/ also unescape \\ and \<delimiter>)
# - for qw(foo bar quux) return ("foo", qw(bar quux))
# - otherwise skip over the first comma and return (undef, "remainder")
# - return () if the string is exhausted
# - as a special case, if the string starts with $FindBin::Bin, replace it with our $Bin
sub _parse_libs {
    local $_ = shift;

    s/^[\s,()]*//;
    return if $_ eq "";

    if (s/^(['"]) ((?:\\.|.)*?) \1//x) {
        return (_unescape($1, $2), $_);
    }
    if (s/^qq? \s* (\W)//x) {
        my $opening_delim = $1;
        (my $closing_delim = $opening_delim) =~ tr:([{<:)]}>:;
        s/^((?:\\.|.)*?) \Q$closing_delim\E//x;
        return (_unescape($opening_delim, $1), $_);
    }

    if (s/^qw \s* (\W)//x) {
        my $opening_delim = $1;
        (my $closing_delim = $opening_delim) =~ tr:([{<:)]}>:;
        s/^((?:\\.|.)*?) \Q$closing_delim\E//x;
        my $contents = $1;
        my @list = split(" ", $contents);
        return (undef, $_) unless @list;
        my $first = shift @list;
        return (_unescape($opening_delim, $first),
                @list ? "qw${opening_delim}@list${closing_delim}$_" : $_);
    }

    # nothing recognizable in the first list item, skip to the next
    if (s/^.*? ,//x) {
        return (undef, $_);
    }
    return;     # list exhausted
}


sub _unescape {
    my ($delim, $str) = @_;
    $str =~ s/\\([\\\Q$delim\E])/$1/g;
    $str =~ s/^\$FindBin::Bin\b/$FindBin::Bin/;

    return $str;
}



sub scan_chunk {
    my $chunk = shift;

    # Module name extraction heuristics {{{
    my $module = eval {
        local $_ = $chunk;
        s/^\s*//;

        # "if", "while" etc: analyze the expression
        s/^(?:if|elsif|unless|while|until) \s* \( \s*//x;

        # "eval" with a block: analyze the block
        s/^eval \s* \{ \s*//x;

        # "eval" with an expression that's a string literal:
        # analyze the string
        s/^eval \s+ (?:['"]|qq?\s*\W) \s*//x;

        # "use LOADER LIST"
        # TODO: There's many more of these "loader" type modules on CPAN!
        if (my ($loader, $list) = $_ =~ $LoaderRE) {
            my @mods = _parse_module_list($list);

            if ($loader eq "Catalyst") {
                # "use Catalyst 'Foo'" looks for "Catalyst::Plugin::Foo",
                # but "use Catalyst +Foo" looks for "Foo"
                @mods = map {
                    ($list =~ /([+-])\Q$_\E(?:$|[^\w:])/)
                        ? ($1 eq "-"
                            ? ()   # "-Foo": it's a flag, eg. "-Debug", skip it
                            : $_)  # "+Foo": look for "Foo"
                        : "Catalyst::Plugin::$_"
                                   # "Foo": look for "Catalyst::Plugin::Foo"
                } @mods;
            }
            return [ map { _mod2pm($_) } $loader, @mods ];
        }

        if (/^use \s+ Class::Autouse \b \s* (.*)/sx
            or /^Class::Autouse \s* -> \s* autouse \s* (.*)/sx) {
          return [ map { _mod2pm($_) } "Class::Autouse", _parse_module_list($1) ];
        }

        # generic "use ..."
        if (s/^(?:use|no) \s+//x) {
            my ($mod) = _parse_module_list($_);                # just the first word
            return _mod2pm($mod);
        }

        if (s/^(require|do) [\s(]+//x) {
            return ($1 eq "require" && /^([\w:]+)/)
                ? _mod2pm($1)                           # bareword ("require" only)
                : $_;                                   # maybe string literal?
        }

        if (/(<[^>]*[^\$\w>][^>]*>)/) {
            my $diamond = $1;
            return "File/Glob.pm" if $diamond =~ /[*?\[\]{}~\\]/;
        }

        return "DBD/$1.pm"    if /\bdbi:(\w+):/i;

        # Moose/Moo/Mouse style inheritance or composition
        if (s/^(with|extends)\s+//) {
            return [ map { _mod2pm($_) } _parse_module_list($_) ];
        }

        # check for stuff like
        #   decode("klingon", ...)
        #   open FH, "<:encoding(klingon)", ...
        if (my ($args) = /\b(?:open|binmode)\b(.*)/) {
            my @mods;
            push @mods, qw( PerlIO.pm PerlIO/encoding.pm Encode.pm ), _find_encoding($1)
                if $args =~ /:encoding\((.*?)\)/;
            while ($args =~ /:(\w+)(?:\((.*?)\))?/g) {
                push @mods, "PerlIO/$1.pm";
                push @mods, "Encode.pm", _find_encoding($2) if $1 eq "encoding";
            }
            push @mods, "PerlIO.pm" if @mods;
            return \@mods if @mods;
        }
        if (/\b(?:en|de)code\(\s*['"]?([-\w]+)/) {
            return [qw( Encode.pm ), _find_encoding($1)];
        }

        if ($SeenTk) {
            my @modules;
            while (/->\s*([A-Z]\w+)/g) {
                push @modules, "Tk/$1.pm";
            }
            while (/->\s*Scrolled\W+([A-Z]\w+)/g) {
                push @modules, "Tk/$1.pm";
                push @modules, "Tk/Scrollbar.pm";
            }
            if (/->\s*setPalette/g) {
                push @modules,
                  map { "Tk/$_.pm" }
                  qw( Button Canvas Checkbutton Entry
                      Frame Label Labelframe Listbox
                      Menubutton Menu Message Radiobutton
                      Scale Scrollbar Spinbox Text );
            }
            return \@modules;
        }

        # Module::Runtime
        return $_ if s/^(?:require_module|use_module|use_package_optimistically) \s* \( \s*//x;

        # Test::More
        return $_ if s/^(?:require_ok|use_ok) \s* \( \s*//x;

        return;
    };

    # }}}

    return unless defined($module);
    return wantarray ? @$module : $module->[0] if ref($module);

    # extract contents from string literals
    if ($module =~ /^(['"]) (.*?) \1/x) {
        $module = $2;
    }
    elsif ($module =~ s/^qq? \s* (\W)//x) {
        (my $closing = $1) =~  tr:([{<:)]}>:;
        $module =~ s/\Q$closing\E.*//;
    }

    $module =~ s/::/\//g;
    return if $module =~ /^(?:[\d\._]+|'.*[^']|".*[^"])$/;

    $module .= ".pm" unless $module =~ /\./;
    return $module;
}

sub _find_encoding {
    my ($enc) = @_;
    return unless $] >= 5.008 and eval { require Encode; %Encode::ExtModule };

    my $mod = eval { $Encode::ExtModule{ Encode::find_encoding($enc)->name } } or return;
    return _mod2pm($mod);
}

sub _add_info {
    my %args = @_;
    my ($rv, $module, $file, $used_by, $type) = @args{qw/rv module file used_by type/};

    return unless defined($module) and defined($file);

    # Ensure file is always absolute
    $file = File::Spec->rel2abs($file);
    $file =~ s|\\|\/|go;

    # Avoid duplicates that can arise due to case differences that don't actually
    # matter on a case tolerant system
    if (is_insensitive_fs) {
        if (!exists $rv->{$module}) {
            my $lc_module  = lc $module;
            my $key = first {lc($_) eq $lc_module} keys %$rv;
            if (defined $key) {
                $module = $key
            };
        }
        if (defined($used_by)) {
            if (lc($used_by) eq lc($module)) {
                $used_by = $module;
            } else {
                if (!exists $rv->{$used_by}) {
                    my $lc_used_by = lc $used_by;
                    my $key = first {lc($_) eq $lc_used_by} keys %$rv;
                    if (defined $key) {
                        $used_by = $key
                    };
                }
            }
        }
    }

    $rv->{$module} ||= {
        file => $file,
        key  => $module,
        type => $type,
    };

    if (defined($used_by) and $used_by ne $module) {
        if (is_insensitive_fs) {
            my $lc_used_by = lc $used_by;
            my $lc_module  = lc $module;
            push @{ $rv->{$module}{used_by} }, $used_by
                if !any { lc($_) eq $lc_used_by } @{ $rv->{$module}{used_by} };
            # We assume here that another _add_info will be called to provide the other parts of $rv->{$used_by}
            push @{ $rv->{$used_by}{uses} }, $module
                if !any { lc($_) eq $lc_module } @{ $rv->{$used_by}{uses} };
        }
        else {
            push @{ $rv->{$module}{used_by} }, $used_by
                if !any { $_ eq $used_by } @{ $rv->{$module}{used_by} };
            # We assume here that another _add_info will be called to provide the other parts of $rv->{$used_by}
            push @{ $rv->{$used_by}{uses} }, $module
                if !any { $_ eq $module } @{ $rv->{$used_by}{uses} };
        }
    }
}

# This subroutine relies on not being called for modules that have already been visited
sub add_deps {
    my %args =
      ((@_ and $_[0] =~ /^(?:modules|rv|used_by|warn_missing)$/)
        ? @_
        : (rv => (ref($_[0]) ? shift(@_) : undef), modules => [@_]));

    my $rv = $args{rv}   || {};
    my $skip = $args{skip} || {};
    my $used_by = $args{used_by};

    foreach my $module (@{ $args{modules} }) {
        my $file = _find_in_inc($module)
          or _warn_of_missing_module($module, $args{warn_missing}), next;
        next if $skip->{$file};

        if (exists $rv->{$module}) {
            _add_info( rv     => $rv,      module  => $module,
                       file   => $file,    used_by => $used_by,
                       type   => undef );
            next;
        }

        _add_info( rv     => $rv,   module  => $module,
                   file   => $file, used_by => $used_by,
                   type   => _gettype($file) );

        if ((my $path = $module) =~ s/\.p[mh]$//i) {

            foreach (_glob_in_inc("auto/$path")) {
                next if $_->{name} =~ m{^auto/$path/.*/};  # weed out subdirs
                next if $_->{name} =~ m{/(?:\.exists|\.packlist)$|\Q$Config{lib_ext}\E$};

                _add_info( rv     => $rv,        module  => $_->{name},
                           file   => $_->{file}, used_by => $module,
                           type   => _gettype($_->{name}) );
            }

            ### Now, handle module and distribution share dirs
            # convert 'Module/Name' to 'Module-Name'
            my $modname = $path;
            $modname =~ s|/|-|g;
            # TODO: get real distribution name related to module name
            my $distname = $modname;
            foreach (_glob_in_inc("auto/share/module/$modname")) {
                _add_info( rv     => $rv,        module  => $_->{name},
                           file   => $_->{file}, used_by => $module,
                           type   => 'data' );
            }
            foreach (_glob_in_inc("auto/share/dist/$distname")) {
                _add_info( rv     => $rv,        module  => $_->{name},
                           file   => $_->{file}, used_by => $module,
                           type   => 'data' );
            }
        }
    } # end for modules
    return $rv;
}

# invalidate %_file_cache and %_glob_cache in case @INC changes
sub _validate_cached_inc
{
    my $inc = join("\0", @INC, @IncludeLibs);
    return if $inc eq $_cached_inc;

    # blow away the caches
    %_file_cache = ();
    %_glob_cache = ();
    $_cached_inc = $inc;
}

sub _find_in_inc {
    my $file = shift;
    return unless defined $file;

    _validate_cached_inc();
    my $cached_val = $_file_cache{$file};
    return $cached_val if $cached_val;

    foreach my $dir (grep !/\bBSDPAN\b/, @INC, @IncludeLibs) {
        if (-f "$dir/$file") {
            $_file_cache{$file} = "$dir/$file";
            return "$dir/$file"
        };
    }

    # absolute file names
    return $file if -f $file;

    return;
}

sub _glob_in_inc {
    my ($subdir, $pm_only) = @_;

    require File::Find;

    $subdir =~ s/\$CurrentPackage/$CurrentPackage/;

    _validate_cached_inc();
    my $cached_val = $_glob_cache{$subdir};
    return @$cached_val if $cached_val;

    my @files;
    foreach my $inc (grep !/\bBSDPAN\b/, @INC, @IncludeLibs) {
        my $dir = "$inc/$subdir";
        next unless -d $dir;

        # canonicalize $inc (ie. use "/" as filename separator exclusively)
        # as newer versions of File::Find return a canonicalized $File::Find::name
        (my $canon = $inc) =~ s|\\|/|g;
        File::Find::find(
            sub {
                return unless -f $_;
                return if $pm_only and !/\.p[mh]$/i;
                (my $file = $File::Find::name) =~ s|\\|/|g;
                (my $name = $file) =~ s|^\Q$canon\E/||;
                push @files, $pm_only ? $name
                                      : { file => $file, name => $name };
            },
            $dir
        );
    }

    $_glob_cache{$subdir} = \@files;

    return @files;
}

# like _glob_in_inc, but looks only at the first level
# (i.e. the children of $subdir)
# NOTE: File::Find has no public notion of the depth of the traversal
# in its "wanted" callback, so it's not helpful
sub _glob_in_inc_1 {
    my ($subdir, $pm_only) = @_;

    $subdir =~ s/\$CurrentPackage/$CurrentPackage/;

    my @files;
    foreach my $inc (grep !/\bBSDPAN\b/, @INC, @IncludeLibs) {
        my $dir = "$inc/$subdir";
        next unless -d $dir;

        opendir(my $dh, $dir) or next;
        my @names = map { "$subdir/$_" } grep { -f "$dir/$_" } readdir $dh;
        closedir $dh;

        push @files, $pm_only ? ( grep { /\.p[mh]$/i } @names )
                              : ( map { { file => "$inc/$_", name => $_ } } @names );
    }

    return @files;
}

my $unicore_stuff;
sub _unicore {
    $unicore_stuff ||= [ 'utf8_heavy.pl', map $_->{name}, _glob_in_inc('unicore', 0) ];
    return @$unicore_stuff;
}

# App::Packer compatibility functions

sub new {
    my ($class, $self) = @_;
    return bless($self ||= {}, $class);
}

sub set_file {
    my $self = shift;
    my $script = shift;

    my ($vol, $dir, $file) = File::Spec->splitpath($script);
    $self->{main} = {
        key  => $file,
        file => $script,
    };
}

sub set_options {
    my $self = shift;
    my %args = @_;
    foreach my $module (@{ $args{add_modules} }) {
        $module = _mod2pm($module) unless $module =~ /\.p[mh]$/i;
        my $file = _find_in_inc($module)
          or _warn_of_missing_module($module, $args{warn_missing}), next;
        $self->{files}{$module} = $file;
    }
}

sub calculate_info {
    my $self = shift;
    my $rv   = scan_deps(
        'keys' => [ $self->{main}{key}, sort keys %{ $self->{files} }, ],
        files  => [ $self->{main}{file},
            map { $self->{files}{$_} } sort keys %{ $self->{files} },
        ],
        recurse => 1,
    );

    my $info = {
        main => {  file     => $self->{main}{file},
                   store_as => $self->{main}{key},
        },
    };

    my %cache = ($self->{main}{key} => $info->{main});
    foreach my $key (sort keys %{ $self->{files} }) {
        my $file = $self->{files}{$key};

        $cache{$key} = $info->{modules}{$key} = {
            file     => $file,
            store_as => $key,
            used_by  => [ $self->{main}{key} ],
        };
    }

    foreach my $key (sort keys %{$rv}) {
        my $val = $rv->{$key};
        if ($cache{ $val->{key} }) {
            defined($val->{used_by}) or next;
            push @{ $info->{ $val->{type} }->{ $val->{key} }->{used_by} },
              @{ $val->{used_by} };
        }
        else {
            $cache{ $val->{key} } = $info->{ $val->{type} }->{ $val->{key} } =
              {        file     => $val->{file},
                store_as => $val->{key},
                used_by  => $val->{used_by},
              };
        }
    }

    $self->{info} = { main => $info->{main} };

    foreach my $type (sort keys %{$info}) {
        next if $type eq 'main';

        my @val;
        if (UNIVERSAL::isa($info->{$type}, 'HASH')) {
            foreach my $val (sort values %{ $info->{$type} }) {
                @{ $val->{used_by} } = map $cache{$_} || "!!$_!!",
                  @{ $val->{used_by} };
                push @val, $val;
            }
        }

        $type = 'modules' if $type eq 'module';
        $self->{info}{$type} = \@val;
    }
}

sub get_files {
    my $self = shift;
    return $self->{info};
}

sub add_preload_rule {
    my ($pm, $rule) = @_;
    die qq[a preload rule for "$pm" already exists] if $Preload{$pm};
    $Preload{$pm} = $rule;
}

# scan_deps_runtime utility functions

# compile $file if $execute is undef,
# otherwise execute $file with arguments @$execute
sub _compile_or_execute {
    my ($file, $execute) = @_;

    local $ENV{MSD_ORIGINAL_FILE} = $file;

    my ($ih, $instrumented_file) = File::Temp::tempfile(UNLINK => 1);

    my (undef, $data_file) = File::Temp::tempfile(UNLINK => 1);
    local $ENV{MSD_DATA_FILE} = $data_file;

    # spoof $0 (to $file) so that FindBin works as expected
    # NOTE: We don't directly assign to $0 as it has magic (i.e.
    # assigning has side effects and may actually fail, cf. perlvar(1)).
    # Instead we alias *0 to a package variable holding the correct value.
    print $ih <<'...';
BEGIN { my $_0 = $ENV{MSD_ORIGINAL_FILE}; *0 = \$_0; }
...

    # NOTE: When compiling the block will run as the last CHECK block;
    # when executing the block will run as the first END block and
    # the programs continues.
    print $ih
        $execute ? "END\n" : "CHECK\n",
        <<'...';
{
    require DynaLoader;
    my @_dl_shared_objects = @DynaLoader::dl_shared_objects;
    my @_dl_modules = @DynaLoader::dl_modules;

    # save %INC etc so that requires below don't pollute them
    my %_INC = %INC;
    my @_INC = @INC;

    require Cwd;
    require Data::Dumper;
    require Config;
    my $dlext = $Config::Config{dlext};

    foreach my $k (keys %_INC)
    {
        # NOTES:
        # (1) An unsuccessful "require" may store an undefined value into %INC.
        # (2) If a key in %INC was located via a CODE or ARRAY ref or
        #     blessed object in @INC the corresponding value in %INC contains
        #     the ref from @INC.
        # (3) Some modules (e.g. Moose) fake entries in %INC, e.g.
        #     "Class/MOP/Class/Immutable/Moose/Meta/Class.pm" => "(set by Moose)"
        #     On some architectures (e.g. Windows) Cwd::abs_path() will throw
        #     an exception for such a pathname.

        my $v = $_INC{$k};
        if (defined $v && !ref $v && -e $v)
        {
            $_INC{$k} = Cwd::abs_path($v);
        }
        else
        {
            delete $_INC{$k};
        }
    }

    # drop refs from @_INC
    @_INC = grep { !ref $_ } @_INC;

    my @dlls = grep { defined $_ && -e $_ } Module::ScanDeps::DataFeed::_dl_shared_objects();
    my @shared_objects = @dlls;
    push @shared_objects, grep { -e $_ } map { (my $bs = $_) =~ s/\.\Q$dlext\E$/.bs/; $bs } @dlls;

    # write data file
    my $data_file = $ENV{MSD_DATA_FILE};
    open my $fh, ">", $data_file
        or die "Couldn't open $data_file: $!\n";
    print $fh Data::Dumper::Dumper(
    {
        '%INC'            => \%_INC,
        '@INC'            => \@_INC,
        dl_shared_objects => \@shared_objects,
    });
    close $fh;

    sub Module::ScanDeps::DataFeed::_dl_shared_objects {
        if (@_dl_shared_objects) {
            return @_dl_shared_objects;
        }
        elsif (@_dl_modules) {
            return map { Module::ScanDeps::DataFeed::_dl_mod2filename($_) } @_dl_modules;
        }
        return;
    }

    sub Module::ScanDeps::DataFeed::_dl_mod2filename {
        my $mod = shift;

        return if $mod eq 'B';
        return unless defined &{"$mod\::bootstrap"};


        # cf. DynaLoader.pm
        my @modparts = split(/::/, $mod);
        my $modfname = defined &DynaLoader::mod2fname ? DynaLoader::mod2fname(\@modparts) : $modparts[-1];
        my $modpname = join('/', @modparts);

        foreach my $dir (@_INC) {
            my $file = "$dir/auto/$modpname/$modfname.$dlext";
            return $file if -e $file;
        }
        return;
    }
} # END or CHECK
...

    # append the file to compile or execute
    {
        open my $fh, "<", $file or die "Couldn't open $file: $!";
        print $ih qq[#line 1 "$file"\n], <$fh>;
        close $fh;
    }
    close $ih;

    # run the instrumented file
    my $rc = system(
        $^X,
        $execute ? () : ("-c"),
        (map { "-I$_" } @IncludeLibs),
        $instrumented_file,
        $execute ? @$execute : ());

    die $execute
        ? "SYSTEM ERROR in executing $file @$execute: $rc"
        : "SYSTEM ERROR in compiling $file: $rc"
        unless $rc == 0;

    my $info = do $data_file
        or die "error extracting info from -c/-x file: ", ($@ || "can't read $data_file: $!");

    return $info;
}

# create a new hashref, applying fixups
sub _info2rv {
    my ($info) = @_;

    my $rv = {};

    my $incs = join('|', sort { length($b) <=> length($a) }
                              map { s|\\|/|g; s|/+$||; quotemeta($_) }
                                  @{ $info->{'@INC'} });
    my $i = is_insensitive_fs() ? "i" : "";
    my $strip_inc_prefix = qr{^(?$i:$incs)/};

    require File::Spec;

    foreach my $key (keys %{ $info->{'%INC'} }) {
        (my $path = $info->{'%INC'}{$key}) =~ s|\\|/|g;

        # NOTE: %INC may contain (as keys) absolute pathnames,
        # e.g. for autosplit .ix and .al files. In the latter case,
        # the key may also start with "./" if found via a relative path in @INC.
        $key =~ s|\\|/|g;
        $key =~ s|^\./||;
        $key =~ s/$strip_inc_prefix//;

        $rv->{$key} = {
            'used_by' => [],
            'file'    => $path,
            'type'    => _gettype($path),
            'key'     => $key
        };
    }

    foreach my $path (@{ $info->{dl_shared_objects} }) {
        $path =~ s|\\|/|g;
        (my $key = $path) =~ s/$strip_inc_prefix//;

        $rv->{$key} = {
            'used_by' => [],
            'file'    => $path,
            'type'    => 'shared',
            'key'     => $key
        };
    }

    return $rv;
}

sub _gettype {
    my $name = shift;

    return 'autoload' if $name =~ /\.(?:ix|al|bs)$/i;
    return 'module'   if $name =~ /\.p[mh]$/i;
    return 'shared'   if $name =~ /\.\Q$Config{dlext}\E$/i;
    return 'data';
}

# merge all keys from $rv_sub into the $rv mega-ref
sub _merge_rv {
    my ($rv_sub, $rv) = @_;

    my $key;
    foreach $key (keys(%$rv_sub)) {
        my %mark;
        if ($rv->{$key} and _not_dup($key, $rv, $rv_sub)) {
            warn "Different modules for file '$key' were found.\n"
                . " -> Using '" . abs_path($rv_sub->{$key}{file}) . "'.\n"
                . " -> Ignoring '" . abs_path($rv->{$key}{file}) . "'.\n";
            $rv->{$key}{used_by} = [
                grep (!$mark{$_}++,
                    @{ $rv->{$key}{used_by} },
                    @{ $rv_sub->{$key}{used_by} })
            ];
            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
            $rv->{$key}{file} = $rv_sub->{$key}{file};
        }
        elsif ($rv->{$key}) {
            $rv->{$key}{used_by} = [
                grep (!$mark{$_}++,
                    @{ $rv->{$key}{used_by} },
                    @{ $rv_sub->{$key}{used_by} })
            ];
            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
        }
        else {
            $rv->{$key} = {
                used_by => [ @{ $rv_sub->{$key}{used_by} } ],
                file    => $rv_sub->{$key}{file},
                key     => $rv_sub->{$key}{key},
                type    => $rv_sub->{$key}{type}
            };

            @{ $rv->{$key}{used_by} } = grep length, @{ $rv->{$key}{used_by} };
        }
    }
}

sub _not_dup {
    my ($key, $rv1, $rv2) = @_;
    if (is_insensitive_fs) {
        return lc(abs_path($rv1->{$key}{file})) ne lc(abs_path($rv2->{$key}{file}));
    }
    else {
        return abs_path($rv1->{$key}{file}) ne abs_path($rv2->{$key}{file});
    }
}

sub _warn_of_runtime_loader {
    my $module = shift;
    return if $SeenRuntimeLoader{$module}++;
    $module =~ s/\.pm$//;
    $module =~ s|/|::|g;
    warn "# Use of runtime loader module $module detected.  Results of static scanning may be incomplete.\n";
    return;
}

sub _warn_of_missing_module {
    my $module = shift;
    my $warn = shift;
    return if not $warn;
    return if not $module =~ /\.p[ml]$/;
    warn "# Could not find source file '$module' in \@INC or \@IncludeLibs. Skipping it.\n"
      if not -f $module;
}

sub _get_preload1 {
    my $pm = shift;
    my $preload = $Preload{$pm} or return();
    if ($preload eq 'sub') {
        $pm =~ s/\.p[mh]$//i;
        return  _glob_in_inc($pm, 1);
    }
    elsif (UNIVERSAL::isa($preload, 'CODE')) {
        return $preload->($pm);
    }
    return @$preload;
}

sub _get_preload {
    my ($pm, $seen) = @_;
    $seen ||= {};
    $seen->{$pm}++;
    my @preload;

    foreach $pm (_get_preload1($pm))
    {
        next if $seen->{$pm};
        $seen->{$pm}++;
        push @preload, $pm, _get_preload($pm, $seen);
    }
    return @preload;
}

1;
__END__

=head1 SEE ALSO

L<scandeps.pl> is a bundled utility that writes C<PREREQ_PM> section
for a number of files.

An application of B<Module::ScanDeps> is to generate executables from
scripts that contains prerequisite modules; this module supports two
such projects, L<PAR> and L<App::Packer>.  Please see their respective
documentations on CPAN for further information.

Other modules which accomplish the same goal with different approach:
L<Module::ExtractUse>, L<Perl::PrereqScanner>, L<Perl::PrereqScanner::Lite>,
L<Perl::PrereqScanner::NotQuiteLite>.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

To a lesser degree: Steffen Mueller E<lt>smueller@cpan.orgE<gt>

Parts of heuristics were deduced from:

=over 4

=item *

B<PerlApp> by ActiveState Tools Corp L<http://www.activestate.com/>

=item *

B<Perl2Exe> by IndigoStar, Inc L<http://www.indigostar.com/>

=back

The B<scan_deps_runtime> function is contributed by Edward S. Peschko.

You can write to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty
mail to E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.
Archives of the mailing list are available at
E<lt>https://www.mail-archive.com/par@perl.org/E<gt> or E<lt>https://groups.google.com/g/perl.parE<gt>.

Please submit bug reports to E<lt>https://github.com/rschupp/Module-ScanDeps/issuesE<gt>.

=head1 COPYRIGHT

Copyright 2002-2008 by
Audrey Tang E<lt>cpan@audreyt.orgE<gt>;
2005-2010 by Steffen Mueller E<lt>smueller@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
