package Module::AutoInstall;

use strict;
use Cwd                 ();
use File::Spec          ();
use ExtUtils::MakeMaker ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.21';
}

# special map on pre-defined feature sets
my %FeatureMap = (
    ''      => 'Core Features',    # XXX: deprecated
    '-core' => 'Core Features',
);

# various lexical flags
my ( @Missing, @Existing,  %DisabledTests, $UnderCPAN, $InstallDepsTarget, $HasCPANPLUS );
my (
    $Config, $CheckOnly, $SkipInstall, $AcceptDefault, $TestOnly, $AllDeps,
    $UpgradeDeps
);
my ( $PostambleActions, $PostambleActionsNoTest, $PostambleActionsUpgradeDeps,
    $PostambleActionsUpgradeDepsNoTest, $PostambleActionsListDeps,
    $PostambleActionsListAllDeps, $PostambleUsed, $NoTest);

# See if it's a testing or non-interactive session
_accept_default( $ENV{AUTOMATED_TESTING} or ! -t STDIN ); 
_init();

sub _accept_default {
    $AcceptDefault = shift;
}

sub _installdeps_target {
    $InstallDepsTarget = shift;
}

sub missing_modules {
    return @Missing;
}

sub do_install {
    __PACKAGE__->install(
        [
            $Config
            ? ( UNIVERSAL::isa( $Config, 'HASH' ) ? %{$Config} : @{$Config} )
            : ()
        ],
        @Missing,
    );
}

# initialize various flags, and/or perform install
sub _init {
    foreach my $arg (
        @ARGV,
        split(
            /[\s\t]+/,
            $ENV{PERL_AUTOINSTALL} || $ENV{PERL_EXTUTILS_AUTOINSTALL} || ''
        )
      )
    {
        if ( $arg =~ /^--config=(.*)$/ ) {
            $Config = [ split( ',', $1 ) ];
        }
        elsif ( $arg =~ /^--installdeps=(.*)$/ ) {
            __PACKAGE__->install( $Config, @Missing = split( /,/, $1 ) );
            exit 0;
        }
	elsif ( $arg =~ /^--upgradedeps=(.*)$/ ) {
	    $UpgradeDeps = 1;
	    __PACKAGE__->install( $Config, @Missing = split( /,/, $1 ) );
	    exit 0;
	}
        elsif ( $arg =~ /^--default(?:deps)?$/ ) {
            $AcceptDefault = 1;
        }
        elsif ( $arg =~ /^--check(?:deps)?$/ ) {
            $CheckOnly = 1;
        }
        elsif ( $arg =~ /^--skip(?:deps)?$/ ) {
            $SkipInstall = 1;
        }
        elsif ( $arg =~ /^--test(?:only)?$/ ) {
            $TestOnly = 1;
        }
        elsif ( $arg =~ /^--all(?:deps)?$/ ) {
            $AllDeps = 1;
        }
    }
}

# overrides MakeMaker's prompt() to automatically accept the default choice
sub _prompt {
    goto &ExtUtils::MakeMaker::prompt unless $AcceptDefault;

    my ( $prompt, $default ) = @_;
    my $y = ( $default =~ /^[Yy]/ );

    print $prompt, ' [', ( $y ? 'Y' : 'y' ), '/', ( $y ? 'n' : 'N' ), '] ';
    print "$default\n";
    return $default;
}

# the workhorse
sub import {
    my $class = shift;
    my @args  = @_ or return;
    my $core_all;

    print "*** $class version " . $class->VERSION . "\n";
    print "*** Checking for Perl dependencies...\n";

    my $cwd = Cwd::getcwd();

    $Config = [];

    my $maxlen = length(
        (
            sort   { length($b) <=> length($a) }
              grep { /^[^\-]/ }
              map  {
                ref($_)
                  ? ( ( ref($_) eq 'HASH' ) ? keys(%$_) : @{$_} )
                  : ''
              }
              map { +{@args}->{$_} }
              grep { /^[^\-]/ or /^-core$/i } keys %{ +{@args} }
        )[0]
    );

    # We want to know if we're under CPAN early to avoid prompting, but
    # if we aren't going to try and install anything anyway then skip the
    # check entirely since we don't want to have to load (and configure)
    # an old CPAN just for a cosmetic message

    $UnderCPAN = _check_lock(1) unless $SkipInstall || $InstallDepsTarget;

    while ( my ( $feature, $modules ) = splice( @args, 0, 2 ) ) {
        my ( @required, @tests, @skiptests );
        my $default  = 1;
        my $conflict = 0;

        if ( $feature =~ m/^-(\w+)$/ ) {
            my $option = lc($1);

            # check for a newer version of myself
            _update_to( $modules, @_ ) and return if $option eq 'version';

            # sets CPAN configuration options
            $Config = $modules if $option eq 'config';

            # promote every features to core status
            $core_all = ( $modules =~ /^all$/i ) and next
              if $option eq 'core';

            next unless $option eq 'core';
        }

        print "[" . ( $FeatureMap{ lc($feature) } || $feature ) . "]\n";

        $modules = [ %{$modules} ] if UNIVERSAL::isa( $modules, 'HASH' );

        unshift @$modules, -default => &{ shift(@$modules) }
          if ( ref( $modules->[0] ) eq 'CODE' );    # XXX: bugward compatibility

        while ( my ( $mod, $arg ) = splice( @$modules, 0, 2 ) ) {
            if ( $mod =~ m/^-(\w+)$/ ) {
                my $option = lc($1);

                $default   = $arg    if ( $option eq 'default' );
                $conflict  = $arg    if ( $option eq 'conflict' );
                @tests     = @{$arg} if ( $option eq 'tests' );
                @skiptests = @{$arg} if ( $option eq 'skiptests' );

                next;
            }

            printf( "- %-${maxlen}s ...", $mod );

            if ( $arg and $arg =~ /^\D/ ) {
                unshift @$modules, $arg;
                $arg = 0;
            }

            # XXX: check for conflicts and uninstalls(!) them.
            my $cur = _version_of($mod);
            if (_version_cmp ($cur, $arg) >= 0)
            {
                print "loaded. ($cur" . ( $arg ? " >= $arg" : '' ) . ")\n";
                push @Existing, $mod => $arg;
                $DisabledTests{$_} = 1 for map { glob($_) } @skiptests;
            }
            else {
                if (not defined $cur)   # indeed missing
                {
                    print "missing." . ( $arg ? " (would need $arg)" : '' ) . "\n";
                }
                else
                {
                    # no need to check $arg as _version_cmp ($cur, undef) would satisfy >= above
                    print "too old. ($cur < $arg)\n";
                }

                push @required, $mod => $arg;
            }
        }

        next unless @required;

        my $mandatory = ( $feature eq '-core' or $core_all );

        if (
            !$SkipInstall
            and (
                $CheckOnly
                or ($mandatory and $UnderCPAN)
                or $AllDeps
                or $InstallDepsTarget
                or _prompt(
                    qq{==> Auto-install the }
                      . ( @required / 2 )
                      . ( $mandatory ? ' mandatory' : ' optional' )
                      . qq{ module(s) from CPAN?},
                    $default ? 'y' : 'n',
                ) =~ /^[Yy]/
            )
          )
        {
            push( @Missing, @required );
            $DisabledTests{$_} = 1 for map { glob($_) } @skiptests;
        }

        elsif ( !$SkipInstall
            and $default
            and $mandatory
            and
            _prompt( qq{==> The module(s) are mandatory! Really skip?}, 'n', )
            =~ /^[Nn]/ )
        {
            push( @Missing, @required );
            $DisabledTests{$_} = 1 for map { glob($_) } @skiptests;
        }

        else {
            $DisabledTests{$_} = 1 for map { glob($_) } @tests;
        }
    }

    if ( @Missing and not( $CheckOnly or $UnderCPAN) ) {
        require Config;
        my $make = $Config::Config{make};
        if ($InstallDepsTarget) {
            print
"*** To install dependencies type '$make installdeps' or '$make installdeps_notest'.\n";
        }
        else {
            print
"*** Dependencies will be installed the next time you type '$make'.\n";
        }

        # make an educated guess of whether we'll need root permission.
        print "    (You may need to do that as the 'root' user.)\n"
          if eval '$>';
    }
    print "*** $class configuration finished.\n";

    chdir $cwd;

    # import to main::
    no strict 'refs';
    *{'main::WriteMakefile'} = \&Write if caller(0) eq 'main';

    return (@Existing, @Missing);
}

sub _running_under {
    my $thing = shift;
    print <<"END_MESSAGE";
*** Since we're running under ${thing}, I'll just let it take care
    of the dependency's installation later.
END_MESSAGE
    return 1;
}

# Check to see if we are currently running under CPAN.pm and/or CPANPLUS;
# if we are, then we simply let it taking care of our dependencies
sub _check_lock {
    return unless @Missing or @_;

    if ($ENV{PERL5_CPANM_IS_RUNNING}) {
        return _running_under('cpanminus');
    }

    my $cpan_env = $ENV{PERL5_CPAN_IS_RUNNING};

    if ($ENV{PERL5_CPANPLUS_IS_RUNNING}) {
        return _running_under($cpan_env ? 'CPAN' : 'CPANPLUS');
    }

    require CPAN;

    if ($CPAN::VERSION > '1.89') {
        if ($cpan_env) {
            return _running_under('CPAN');
        }
        return; # CPAN.pm new enough, don't need to check further
    }

    # last ditch attempt, this -will- configure CPAN, very sorry

    _load_cpan(1); # force initialize even though it's already loaded

    # Find the CPAN lock-file
    my $lock = MM->catfile( $CPAN::Config->{cpan_home}, ".lock" );
    return unless -f $lock;

    # Check the lock
    local *LOCK;
    return unless open(LOCK, $lock);

    if (
            ( $^O eq 'MSWin32' ? _under_cpan() : <LOCK> == getppid() )
        and ( $CPAN::Config->{prerequisites_policy} || '' ) ne 'ignore'
    ) {
        print <<'END_MESSAGE';

*** Since we're running under CPAN, I'll just let it take care
    of the dependency's installation later.
END_MESSAGE
        return 1;
    }

    close LOCK;
    return;
}

sub install {
    my $class = shift;

    my $i;    # used below to strip leading '-' from config keys
    my @config = ( map { s/^-// if ++$i; $_ } @{ +shift } );

	my ( @modules, @installed, @modules_to_upgrade );
	while (my ($pkg, $ver) = splice(@_, 0, 2)) {

		# grep out those already installed
		if (_version_cmp(_version_of($pkg), $ver) >= 0) {
			push @installed, $pkg;
			if ($UpgradeDeps) {
				push @modules_to_upgrade, $pkg, $ver;
			}
		}
		else {
			push @modules, $pkg, $ver;
		}
	}

	if ($UpgradeDeps) {
		push @modules, @modules_to_upgrade;
		@installed          = ();
		@modules_to_upgrade = ();
	}

    return @installed unless @modules;  # nothing to do
    return @installed if _check_lock(); # defer to the CPAN shell

    print "*** Installing dependencies...\n";

    return unless _connected_to('cpan.org');

    my %args = @config;
    my %failed;
    local *FAILED;
    if ( $args{do_once} and open( FAILED, '.#autoinstall.failed' ) ) {
        while (<FAILED>) { chomp; $failed{$_}++ }
        close FAILED;

        my @newmod;
        while ( my ( $k, $v ) = splice( @modules, 0, 2 ) ) {
            push @newmod, ( $k => $v ) unless $failed{$k};
        }
        @modules = @newmod;
    }

    if ( _has_cpanplus() and not $ENV{PERL_AUTOINSTALL_PREFER_CPAN} ) {
        _install_cpanplus( \@modules, \@config );
    } else {
        _install_cpan( \@modules, \@config );
    }

    print "*** $class installation finished.\n";

    # see if we have successfully installed them
    while ( my ( $pkg, $ver ) = splice( @modules, 0, 2 ) ) {
        if ( _version_cmp( _version_of($pkg), $ver ) >= 0 ) {
            push @installed, $pkg;
        }
        elsif ( $args{do_once} and open( FAILED, '>> .#autoinstall.failed' ) ) {
            print FAILED "$pkg\n";
        }
    }

    close FAILED if $args{do_once};

    return @installed;
}

sub _install_cpanplus {
    my @modules   = @{ +shift };
    my @config    = _cpanplus_config( @{ +shift } );
    my $installed = 0;

    require CPANPLUS::Backend;
    my $cp   = CPANPLUS::Backend->new;
    my $conf = $cp->configure_object;

    return unless $conf->can('conf') # 0.05x+ with "sudo" support
               or _can_write($conf->_get_build('base'));  # 0.04x

    # if we're root, set UNINST=1 to avoid trouble unless user asked for it.
    my $makeflags = $conf->get_conf('makeflags') || '';
    if ( UNIVERSAL::isa( $makeflags, 'HASH' ) ) {
        # 0.03+ uses a hashref here
        $makeflags->{UNINST} = 1 unless exists $makeflags->{UNINST};

    } else {
        # 0.02 and below uses a scalar
        $makeflags = join( ' ', split( ' ', $makeflags ), 'UNINST=1' )
          if ( $makeflags !~ /\bUNINST\b/ and eval qq{ $> eq '0' } );

    }
    $conf->set_conf( makeflags => $makeflags );
    $conf->set_conf( prereqs   => 1 );

    

    while ( my ( $key, $val ) = splice( @config, 0, 2 ) ) {
        $conf->set_conf( $key, $val );
    }

    my $modtree = $cp->module_tree;
    while ( my ( $pkg, $ver ) = splice( @modules, 0, 2 ) ) {
        print "*** Installing $pkg...\n";

        MY::preinstall( $pkg, $ver ) or next if defined &MY::preinstall;

        my $success;
        my $obj = $modtree->{$pkg};

        if ( $obj and _version_cmp( $obj->{version}, $ver ) >= 0 ) {
            my $pathname = $pkg;
            $pathname =~ s/::/\\W/;

            foreach my $inc ( grep { m/$pathname.pm/i } keys(%INC) ) {
                delete $INC{$inc};
            }

            my $rv = $cp->install( modules => [ $obj->{module} ] );

            if ( $rv and ( $rv->{ $obj->{module} } or $rv->{ok} ) ) {
                print "*** $pkg successfully installed.\n";
                $success = 1;
            } else {
                print "*** $pkg installation cancelled.\n";
                $success = 0;
            }

            $installed += $success;
        } else {
            print << ".";
*** Could not find a version $ver or above for $pkg; skipping.
.
        }

        MY::postinstall( $pkg, $ver, $success ) if defined &MY::postinstall;
    }

    return $installed;
}

sub _cpanplus_config {
	my @config = ();
	while ( @_ ) {
		my ($key, $value) = (shift(), shift());
		if ( $key eq 'prerequisites_policy' ) {
			if ( $value eq 'follow' ) {
				$value = CPANPLUS::Internals::Constants::PREREQ_INSTALL();
			} elsif ( $value eq 'ask' ) {
				$value = CPANPLUS::Internals::Constants::PREREQ_ASK();
			} elsif ( $value eq 'ignore' ) {
				$value = CPANPLUS::Internals::Constants::PREREQ_IGNORE();
			} else {
				die "*** Cannot convert option $key = '$value' to CPANPLUS version.\n";
			}
			push @config, 'prereqs', $value;
		} elsif ( $key eq 'force' ) {
		    push @config, $key, $value;
		} elsif ( $key eq 'notest' ) {
		    push @config, 'skiptest', $value;
		} else {
			die "*** Cannot convert option $key to CPANPLUS version.\n";
		}
	}
	return @config;
}

sub _install_cpan {
    my @modules   = @{ +shift };
    my @config    = @{ +shift };
    my $installed = 0;
    my %args;

    _load_cpan();
    require Config;

    if (CPAN->VERSION < 1.80) {
        # no "sudo" support, probe for writableness
        return unless _can_write( MM->catfile( $CPAN::Config->{cpan_home}, 'sources' ) )
                  and _can_write( $Config::Config{sitelib} );
    }

    # if we're root, set UNINST=1 to avoid trouble unless user asked for it.
    my $makeflags = $CPAN::Config->{make_install_arg} || '';
    $CPAN::Config->{make_install_arg} =
      join( ' ', split( ' ', $makeflags ), 'UNINST=1' )
      if ( $makeflags !~ /\bUNINST\b/ and eval qq{ $> eq '0' } );

    # don't show start-up info
    $CPAN::Config->{inhibit_startup_message} = 1;

    # set additional options
    while ( my ( $opt, $arg ) = splice( @config, 0, 2 ) ) {
        ( $args{$opt} = $arg, next )
          if $opt =~ /^(?:force|notest)$/;    # pseudo-option
        $CPAN::Config->{$opt} = $opt eq 'urllist' ? [$arg] : $arg;
    }

    if ($args{notest} && (not CPAN::Shell->can('notest'))) {
	die "Your version of CPAN is too old to support the 'notest' pragma";
    }

    local $CPAN::Config->{prerequisites_policy} = 'follow';

    while ( my ( $pkg, $ver ) = splice( @modules, 0, 2 ) ) {
        MY::preinstall( $pkg, $ver ) or next if defined &MY::preinstall;

        print "*** Installing $pkg...\n";

        my $obj     = CPAN::Shell->expand( Module => $pkg );
        my $success = 0;

        if ( $obj and _version_cmp( $obj->cpan_version, $ver ) >= 0 ) {
            my $pathname = $pkg;
            $pathname =~ s/::/\\W/;

            foreach my $inc ( grep { m/$pathname.pm/i } keys(%INC) ) {
                delete $INC{$inc};
            }

            my $rv = do {
		if ($args{force}) {
		    CPAN::Shell->force( install => $pkg )
		} elsif ($args{notest}) {
		    CPAN::Shell->notest( install => $pkg )
		} else {
		    CPAN::Shell->install($pkg)
		}
	    };

            $rv ||= eval {
                $CPAN::META->instance( 'CPAN::Distribution', $obj->cpan_file, )
                  ->{install}
                  if $CPAN::META;
            };

            if ( $rv eq 'YES' ) {
                print "*** $pkg successfully installed.\n";
                $success = 1;
            }
            else {
                print "*** $pkg installation failed.\n";
                $success = 0;
            }

            $installed += $success;
        }
        else {
            print << ".";
*** Could not find a version $ver or above for $pkg; skipping.
.
        }

        MY::postinstall( $pkg, $ver, $success ) if defined &MY::postinstall;
    }

    return $installed;
}

sub _has_cpanplus {
    return (
        $HasCPANPLUS = (
            $INC{'CPANPLUS/Config.pm'}
              or _load('CPANPLUS::Shell::Default')
        )
    );
}

# make guesses on whether we're under the CPAN installation directory
sub _under_cpan {
    require Cwd;
    require File::Spec;

    my $cwd  = File::Spec->canonpath( Cwd::getcwd() );
    my $cpan = File::Spec->canonpath( $CPAN::Config->{cpan_home} );

    return ( index( $cwd, $cpan ) > -1 );
}

sub _update_to {
    my $class = __PACKAGE__;
    my $ver   = shift;

    return
      if _version_cmp( _version_of($class), $ver ) >= 0;  # no need to upgrade

    if (
        _prompt( "==> A newer version of $class ($ver) is required. Install?",
            'y' ) =~ /^[Nn]/
      )
    {
        die "*** Please install $class $ver manually.\n";
    }

    print << ".";
*** Trying to fetch it from CPAN...
.

    # install ourselves
    _load($class) and return $class->import(@_)
      if $class->install( [], $class, $ver );

    print << '.'; exit 1;

*** Cannot bootstrap myself. :-( Installation terminated.
.
}

# check if we're connected to some host, using inet_aton
sub _connected_to {
    my $site = shift;

    return (
        ( _load('Socket') and Socket::inet_aton($site) ) or _prompt(
            qq(
*** Your host cannot resolve the domain name '$site', which
    probably means the Internet connections are unavailable.
==> Should we try to install the required module(s) anyway?), 'n'
          ) =~ /^[Yy]/
    );
}

# check if a directory is writable; may create it on demand
sub _can_write {
    my $path = shift;
    mkdir( $path, 0755 ) unless -e $path;

    return 1 if -w $path;

    print << ".";
*** You are not allowed to write to the directory '$path';
    the installation may fail due to insufficient permissions.
.

    if (
        eval '$>' and lc(`sudo -V`) =~ /version/ and _prompt(
            qq(
==> Should we try to re-execute the autoinstall process with 'sudo'?),
            ((-t STDIN) ? 'y' : 'n')
        ) =~ /^[Yy]/
      )
    {

        # try to bootstrap ourselves from sudo
        print << ".";
*** Trying to re-execute the autoinstall process with 'sudo'...
.
        my $missing = join( ',', @Missing );
        my $config = join( ',',
            UNIVERSAL::isa( $Config, 'HASH' ) ? %{$Config} : @{$Config} )
          if $Config;

        return
          unless system( 'sudo', $^X, $0, "--config=$config",
            "--installdeps=$missing" );

        print << ".";
*** The 'sudo' command exited with error!  Resuming...
.
    }

    return _prompt(
        qq(
==> Should we try to install the required module(s) anyway?), 'n'
    ) =~ /^[Yy]/;
}

# load a module and return the version it reports
sub _load {
    my $mod  = pop; # method/function doesn't matter
    my $file = $mod;
    $file =~ s|::|/|g;
    $file .= '.pm';
    local $@;
    return eval { require $file; $mod->VERSION } || ( $@ ? undef: 0 );
}

# report version without loading a module
sub _version_of {
    my $mod = pop; # method/function doesn't matter
    my $file = $mod;
    $file =~ s|::|/|g;
    $file .= '.pm';
    foreach my $dir ( @INC ) {
        next if ref $dir;
        my $path = File::Spec->catfile($dir, $file);
        next unless -e $path;
        require ExtUtils::MM_Unix;
        return ExtUtils::MM_Unix->parse_version($path);
    }
    return undef;
}

# Load CPAN.pm and it's configuration
sub _load_cpan {
    return if $CPAN::VERSION and $CPAN::Config and not @_;
    require CPAN;

    # CPAN-1.82+ adds CPAN::Config::AUTOLOAD to redirect to
    #    CPAN::HandleConfig->load. CPAN reports that the redirection
    #    is deprecated in a warning printed at the user.

    # CPAN-1.81 expects CPAN::HandleConfig->load, does not have
    #   $CPAN::HandleConfig::VERSION but cannot handle
    #   CPAN::Config->load

    # Which "versions expect CPAN::Config->load?

    if ( $CPAN::HandleConfig::VERSION
        || CPAN::HandleConfig->can('load')
    ) {
        # Newer versions of CPAN have a HandleConfig module
        CPAN::HandleConfig->load;
    } else {
    	# Older versions had the load method in Config directly
        CPAN::Config->load;
    }
}

# compare two versions, either use Sort::Versions or plain comparison
# return values same as <=>
sub _version_cmp {
    my ( $cur, $min ) = @_;
    return -1 unless defined $cur;  # if 0 keep comparing
    return 1 unless $min;

    $cur =~ s/\s+$//;

    # check for version numbers that are not in decimal format
    if ( ref($cur) or ref($min) or $cur =~ /v|\..*\./ or $min =~ /v|\..*\./ ) {
        if ( ( $version::VERSION or defined( _load('version') )) and
             version->can('new') 
            ) {

            # use version.pm if it is installed.
            return version->new($cur) <=> version->new($min);
        }
        elsif ( $Sort::Versions::VERSION or defined( _load('Sort::Versions') ) )
        {

            # use Sort::Versions as the sorting algorithm for a.b.c versions
            return Sort::Versions::versioncmp( $cur, $min );
        }

        warn "Cannot reliably compare non-decimal formatted versions.\n"
          . "Please install version.pm or Sort::Versions.\n";
    }

    # plain comparison
    local $^W = 0;    # shuts off 'not numeric' bugs
    return $cur <=> $min;
}

# nothing; this usage is deprecated.
sub main::PREREQ_PM { return {}; }

sub _make_args {
    my %args = @_;

    $args{PREREQ_PM} = { %{ $args{PREREQ_PM} || {} }, @Existing, @Missing }
      if $UnderCPAN or $TestOnly;

    if ( $args{EXE_FILES} and -e 'MANIFEST' ) {
        require ExtUtils::Manifest;
        my $manifest = ExtUtils::Manifest::maniread('MANIFEST');

        $args{EXE_FILES} =
          [ grep { exists $manifest->{$_} } @{ $args{EXE_FILES} } ];
    }

    $args{test}{TESTS} ||= 't/*.t';
    $args{test}{TESTS} = join( ' ',
        grep { !exists( $DisabledTests{$_} ) }
          map { glob($_) } split( /\s+/, $args{test}{TESTS} ) );

    my $missing = join( ',', @Missing );
    my $config =
      join( ',', UNIVERSAL::isa( $Config, 'HASH' ) ? %{$Config} : @{$Config} )
      if $Config;

    $PostambleActions = (
        ($missing and not $UnderCPAN)
        ? "\$(PERL) $0 --config=$config --installdeps=$missing"
        : "\$(NOECHO) \$(NOOP)"
    );

    my $deps_list = join( ',', @Missing, @Existing );

    $PostambleActionsUpgradeDeps =
        "\$(PERL) $0 --config=$config --upgradedeps=$deps_list";

    my $config_notest =
      join( ',', (UNIVERSAL::isa( $Config, 'HASH' ) ? %{$Config} : @{$Config}),
	  'notest', 1 )
      if $Config;

    $PostambleActionsNoTest = (
        ($missing and not $UnderCPAN)
        ? "\$(PERL) $0 --config=$config_notest --installdeps=$missing"
        : "\$(NOECHO) \$(NOOP)"
    );

    $PostambleActionsUpgradeDepsNoTest =
        "\$(PERL) $0 --config=$config_notest --upgradedeps=$deps_list";

    $PostambleActionsListDeps =
        '@$(PERL) -le "print for @ARGV" '
            . join(' ', map $Missing[$_], grep $_ % 2 == 0, 0..$#Missing);

    my @all = (@Missing, @Existing);

    $PostambleActionsListAllDeps =
        '@$(PERL) -le "print for @ARGV" '
            . join(' ', map $all[$_], grep $_ % 2 == 0, 0..$#all);

    return %args;
}

# a wrapper to ExtUtils::MakeMaker::WriteMakefile
sub Write {
    require Carp;
    Carp::croak "WriteMakefile: Need even number of args" if @_ % 2;

    if ($CheckOnly) {
        print << ".";
*** Makefile not written in check-only mode.
.
        return;
    }

    my %args = _make_args(@_);

    no strict 'refs';

    $PostambleUsed = 0;
    local *MY::postamble = \&postamble unless defined &MY::postamble;
    ExtUtils::MakeMaker::WriteMakefile(%args);

    print << "." unless $PostambleUsed;
*** WARNING: Makefile written with customized MY::postamble() without
    including contents from Module::AutoInstall::postamble() --
    auto installation features disabled.  Please contact the author.
.

    return 1;
}

sub postamble {
    $PostambleUsed = 1;
    my $fragment;

    $fragment .= <<"AUTO_INSTALL" if !$InstallDepsTarget;

config :: installdeps
\t\$(NOECHO) \$(NOOP)
AUTO_INSTALL

    $fragment .= <<"END_MAKE";

checkdeps ::
\t\$(PERL) $0 --checkdeps

installdeps ::
\t$PostambleActions

installdeps_notest ::
\t$PostambleActionsNoTest

upgradedeps ::
\t$PostambleActionsUpgradeDeps

upgradedeps_notest ::
\t$PostambleActionsUpgradeDepsNoTest

listdeps ::
\t$PostambleActionsListDeps

listalldeps ::
\t$PostambleActionsListAllDeps

END_MAKE

    return $fragment;
}

1;

__END__

=pod

=head1 NAME

Module::AutoInstall - Automatic install of dependencies via CPAN

=head1 SYNOPSIS

In F<Makefile.PL>, with L<Module::Install> available on the author's system:

    use inc::Module::Install;
    
    name        'Joe-Hacker';
    abstract    'Perl Interface to Joe Hacker';
    author      'Joe Hacker <joe@hacker.org>';
    include     'Module::AutoInstall';
    
    requires    'Module0';          # mandatory modules
    
    feature     'Feature1',
        -default    => 0,
        'Module2'   => '0.1';
    
    feature     'Feature2',
        -default    => 0,
        'Module3'   => '1.0';
    
    auto_install(
        make_args   => '--hello',   # option(s) for CPAN::Config
        force       => 1,           # pseudo-option to force install
        do_once     => 1,           # skip previously failed modules
    );
    
    WriteAll;

Invoking the resulting F<Makefile.PL>:

    % perl Makefile.PL                  # interactive behaviour
    % perl Makefile.PL --defaultdeps    # accept default value on prompts
    % perl Makefile.PL --checkdeps      # check only, no Makefile produced
    % perl Makefile.PL --skipdeps       # ignores all dependencies
    % perl Makefile.PL --testonly       # don't write installation targets

Note that the trailing 'deps' of arguments may be omitted, too.

Using C<--defaultdeps> will make F<Makefile.PL> behave similarly to a regular
Makefile.PL file with C<PREREQ_PM> dependencies.

One can use environment variables (see "ENVIRONMENT") below to set a default
behavior instead of specifying it in the command line for every invocation
of F<Makefile.PL>.

Using F<make> (or F<nmake>):

    % make [all|test|install]           # install dependencies first
    % make checkdeps                    # same as the --checkdeps above
    % make installdeps                  # install dependencies only
    % make installdeps_notest           # same without running tests
    % make upgradedeps                  # upgrade all deps, even if installed
    % make upgradedeps_notest           # same without running tests
    % make listdeps                     # print unsatisifed deps, one per line
    % make listalldeps                  # print all deps, one per line

=head1 DESCRIPTION

B<Module::AutoInstall> lets module writers to specify a more
sophisticated form of dependency information than the C<PREREQ_PM>
option offered by B<ExtUtils::MakeMaker>.

This module works best with the B<Module::Install> framework,
a drop-in replacement for MakeMaker.  However, this module also
supports F<Makefile.PL> files based on MakeMaker; see L</EXAMPLES>
for instructions.

Specifying C<installdeps_target;> instead of C<auto_install;> will not try to
install dependencies when running C<make>, but only when running C<make
installdeps>.

=head2 Prerequisites and Features

Prerequisites are grouped into B<features>, and the user could choose
yes/no on each one's dependencies; the module writer may also supply a
boolean value via C<-default> to specify the default choice.

The B<Core Features> marked by the name C<-core> will double-check with
the user, if the user chooses not to install the mandatory modules.
This differs from the pre-0.26 'silent install' behaviour.

Starting from version 0.27, if C<-core> is set to the string C<all>
(case-insensitive), every feature will be considered mandatory.

The dependencies are expressed as pairs of C<Module> => C<version>
inside an array reference.  If the order does not matter, and there
are no C<-default>, C<-tests> or C<-skiptests> directives for that
feature, you may also use a hash reference.

=head2 The Installation Process

Once B<Module::AutoInstall> has determined which module(s) are needed,
it checks whether it's running under the B<CPAN> shell and should
therefore let B<CPAN> handle the dependency.

Finally, the C<WriteMakefile()> is overridden to perform some additional
checks, as well as skips tests associated with disabled features by the
C<-tests> option.

The actual installation happens at the end of the C<make config> target;
both C<make test> and C<make install> will trigger the installation of
required modules.

If it's not running under B<CPAN>, the installer will probe for an
active connection by trying to resolve the domain C<cpan.org>, and check
for the user's permission to use B<CPAN>.  If all went well, a separate
    B<CPAN> instance is created to install the required modules.

If you have the B<CPANPLUS> package installed in your system, it is
preferred by default over B<CPAN>; it also accepts some extra options
(e.g. C<-target =E<gt> 'skiptest', -skiptest =E<gt> 1> to skip testing).

All modules scheduled to be installed will be deleted from C<%INC>
first, so B<ExtUtils::MakeMaker> will check the newly installed modules.

Additionally, you could use the C<make installdeps> target to install
the modules, and the C<make checkdeps> target to check dependencies
without actually installing them; the C<perl Makefile.PL --checkdeps>
command has an equivalent effect.

If the F<Makefile.PL> itself needs to use an independent module (e.g.
B<Acme::KillarApp>, v1.21 or greater), then use something like below:

    BEGIN {
        require Module::AutoInstall;
        # the first argument is an arrayref of the -config flags
        Module::AutoInstall->install([], 'Acme::KillerApp' => 1.21);
    }
    use Acme::KillerApp 1.21;

    Module::AutoInstall->import(
        # ... arguments as usual ...
    );

Note the version test in the use clause; if you are so close to the
cutting edge that B<Acme::KillerApp> 1.20 is the latest version on CPAN,
this will prevent your module from going awry.

=head2 User-Defined Hooks

User-defined I<pre-installation> and I<post-installation> hooks are
available via C<MY::preinstall> and C<MY::postinstall> subroutines,
as shown below:

    # pre-install handler; takes $module_name and $version
    sub MY::preinstall  { return 1; } # return false to skip install

    # post-install handler; takes $module_name, $version, $success
    sub MY::postinstall { return; }   # the return value doesn't matter

Note that since B<Module::AutoInstall> performs installation at the
time of C<use> (i.e. before perl parses the remainder of
F<Makefile.PL>), you have to declare those two handlers I<before> the
C<use> statement for them to take effect.

If the user did not choose to install a module or it already exists on
the system, neither of the handlers is invoked.  Both handlers are invoked
exactly once for each module when installation is attempted.

C<MY::preinstall> takes two arguments, C<$module_name> and C<$version>;
if it returns a false value, installation for that module will be
skipped, and C<MY::postinstall> won't be called at all.

C<MY::postinstall> takes three arguments, C<$module_name>, C<$version>
and C<$success>.  The last one denotes whether the installation
succeeded or not: C<1> means installation completed successfully, C<0>
means failure during install, and C<undef> means that the installation
was not attempted at all, possibly due to connection problems, or that
module does not exist on CPAN at all.

=head2 Customized C<MY::postamble>

Starting from version 0.43, B<Module::AutoInstall> supports modules
that require a C<MY::postamble> subroutine in their F<Makefile.PL>.
The user-defined C<MY::postamble>, if present, is responsible for
calling C<Module::AutoInstall::postamble> and include the output in
its return value.

For example, the B<DBD::*> (database driver) modules for the Perl DBI
are required to include the postamble generated by the function
C<dbd_postamble>, so their F<Makefile.PL> may contain lines like this:

    sub MY::postamble {
        return &Module::AutoInstall::postamble . &dbd_postamble;
    }

Note that the B<Module::AutoInstall> module does not export the
C<postamble> function, so the name should always be fully qualified.

=head1 CAVEATS

B<Module::AutoInstall> will add C<UNINST=1> to your B<make install>
flags if your effective uid is 0 (root), unless you explicitly disable
it by setting B<CPAN>'s C<make_install_arg> configuration option (or the
C<makeflags> option of B<CPANPLUS>) to include C<UNINST=0>.  This I<may>
cause dependency problems if you are using a fine-tuned directory
structure for your site.  Please consult L<CPAN/FAQ> for an explanation
in detail.

If either B<version> or B<Sort::Versions> is available, they will be
used to compare the required version with the existing module's version
and the CPAN module's.  Otherwise it silently falls back to use I<cmp>.
This may cause inconsistent behaviours in pathetic situations.

=head1 ENVIRONMENT

B<Module::AutoInstall> uses a single environment variable,
C<PERL_AUTOINSTALL>.  It is taken as the command line argument
passed to F<Makefile.PL>; you could set it to C<--alldeps>, C<--defaultdeps>
or C<--skipdeps> to avoid all interactive behaviour.

C<--alldeps> will install all features, while
C<--defaultdeps> will only install features for which the default answer is
'y'.

C<--skipdeps> will refrain from loading L<CPAN> and not install anything, unless
you're running under L<CPAN> or L<CPANPLUS>, in which case required dependencies
will be installed.

It is also read from the C<PERL_EXTUTILS_AUTOINSTALL> environment variable if
C<PERL_AUTOINSTALL> is not defined.

You can also set C<PERL_AUTOINSTALL_PREFER_CPAN> to use CPAN to install
dependencies. By default CPANPLUS is used.

=head1 SEE ALSO

L<Module::Install>

L<perlmodlib>, L<ExtUtils::MakeMaker>, L<Sort::Versions>, L<CPAN>,
L<CPANPLUS>

=head1 AUTHORS

Audrey Tang E<lt>autrijus@autrijus.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

Matt S Trout E<lt>mst@shadowcat.co.uE<gt>

=head1 IF THIS BREAKS

Report a ticket to bugs-Module-Install <at> rt.cpan.org and cc Matt
- I appear to have volunteered as primary maintainer for this stuff so
if you run into any problems please tell me

=head1 COPYRIGHT

Copyright 2001, 2002, 2003, 2004, 2005, 2006 by Audrey Tang

Some parts copyright 2006 Adam Kennedy

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
