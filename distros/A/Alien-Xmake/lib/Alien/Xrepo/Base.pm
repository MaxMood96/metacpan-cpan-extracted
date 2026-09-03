use v5.40;
use experimental 'class';
#
class Alien::Xrepo::Base v0.9.2 {
    use Alien::Xrepo;
    use Path::Tiny;
    use Exporter qw[import];
    our @EXPORT = qw[Build_PL];
    #
    field $pkg_name           : param = undef;
    field $version_constraint : param = undef;
    field $root               : param = undef;
    field $verbose            : param = 0;
    field $repo;
    field $packages = [];    # normalized array ref of package names
    field $infos    = {};    # package name => Alien::Xrepo::PackageInfo
    ADJUST {
        my @names = $self->_normalize_names($pkg_name);
        die "pkg_name is required" unless @names;
        @$packages = @names;

        # Attempt to populate %$infos from generated ConfigData. The config
        # module is multi-package aware (one page per package name).
        my $child_class  = ref($self);
        my $config_class = $child_class . '::ConfigData';
        try {
            my $file = $config_class =~ s|::|/|gr . '.pm';
            require $file;
            if ( $config_class->can('package') ) {
                for my $name (@names) {
                    my $c = $config_class->package($name);
                    if ($c) {
                        $infos->{$name} = Alien::Xrepo::PackageInfo->new(%$c);
                    }
                }
            }
        }
        catch ($e) {

            # Not installed or utilizing dynamic runtime fetch fallback
        }

        # Setup repo engine
        $repo = Alien::Xrepo->new( root => $root, verbose => $verbose );
    }

    # pkg_name may be a scalar or an array ref / list of package names.
    method package_names () { return @$packages }

    method _normalize_names ($in) {
        if ( ref $in eq 'ARRAY' )        { return @$in }
        if ( defined $in && length $in ) { return ($in) }
        if ( $self->can('pkg_name') ) {
            my $v = $self->pkg_name;
            return ref $v eq 'ARRAY' ? @$v : ($v);
        }
        return ();
    }
    method _pkg_info ( $pkg = undef ) { $infos->{ $pkg // $packages->[0] } }

    method install (%opts) {
        %$infos = ();
        for my $name (@$packages) {
            $infos->{$name} = $repo->install( $name, $version_constraint, %opts );
        }
        return wantarray ? values %$infos : $self->_pkg_info;
    }

    method upgrade (%opts) {
        $repo->update_repo();
        return $self->install(%opts);
    }

    # Delegation methods. Each takes an optional package name; without one it refers to the first
    # (primary) package, keeping single-package subclasses and existing callers working unchanged.
    method libpath ( $pkg = undef ) { my $i = $self->_pkg_info($pkg); $i ? $i->libpath : undef }
    method ffi_lib ( $pkg = undef ) { $self->libpath($pkg) }
    method bin_dir ( $pkg = undef ) { my $i = $self->_pkg_info($pkg); $i ? $i->bin_dir : () }
    method version ( $pkg = undef ) { my $i = $self->_pkg_info($pkg); $i ? $i->version : undef }
    method kind    ( $pkg = undef ) { my $i = $self->_pkg_info($pkg); $i ? $i->kind : undef }

    method cflags ( $pkg = undef ) {
        my $i = $self->_pkg_info($pkg);
        return '' unless $i;
        return join ' ', map {"-I$_"} @{ $i->includedirs };
    }
    method cflags_static ( $pkg = undef ) { $self->cflags($pkg) }

    method libs ( $pkg = undef ) {
        my $i = $self->_pkg_info($pkg);
        return '' unless $i;
        my $libs = join ' ', map {"-L$_"} @{ $i->linkdirs // [] };
        $libs .= ' ' . join ' ', map {"-l$_"} @{ $i->links // [] };
        return $libs;
    }
    method libs_static ( $pkg = undef ) { $self->libs($pkg) }

    # Absolute paths to the shared libraries / objects of the package.
    method dynamic_libs ( $pkg = undef ) {
        my $i = $self->_pkg_info($pkg);
        return () unless $i;
        return map { $_ // () } @{ $i->libfiles // [] };
    }

    # Where the alien's files live (the xrepo install root for the package).
    method dist_dir ( $pkg = undef ) {
        my $i = $self->_pkg_info($pkg);
        return $i ? $i->installdir : undef;
    }

    # 'share' once we have installed anything into our xrepo root; 'system' if nothing is installed
    # yet (matches the Alien::Base install_type contract).
    method install_type ( $pkg = undef ) { $self->_pkg_info($pkg) ? 'share' : 'system' }

    # Split a flags string into a list, mirroring Alien::Base::split_flags but splitting on
    # whitespace so Windows paths (which use backslashes) survive.
    method split_flags ( $flags, $pkg = undef ) {
        return () unless defined $flags;
        return grep {length} split ' ', $flags;
    }

    # Alien::Base accessor to select a non-primary package. Without a name (or with the primary
    # name) it returns $self; with a different name it returns a delegate object whose accessors
    # are pinned to that package, e.g. Alien::SDL3->alt('libsdl3_ttf')->cflags
    method alt ( $name = undef ) {
        my $pkg = $name // $packages->[0];
        die "Unknown package '$pkg'. Known packages: @$packages" unless grep { $_ eq $pkg } @$packages;
        return $self if $pkg eq $packages->[0];
        return Alien::Xrepo::Base::Alt->new( base => $self, pkg => $pkg );
    }

    method find_header ( $filename, $pkg = undef ) {
        my $i = $self->_pkg_info($pkg);
        return $i ? $i->find_header($filename) : undef;
    }
    method package_info ( $pkg = undef ) { $self->_pkg_info($pkg) }

    # Builder support
    sub Build_PL ($alien_class) {
        use CPAN::Meta;
        use JSON::PP;
        use ExtUtils::Helpers qw[make_executable];
        use Config;
        my $meta = CPAN::Meta->load_file('META.json');
        say sprintf 'Creating new Build script for %s %s (%s)', $meta->name, $meta->version, $alien_class;
        my $perl5lib = join( $Config{path_sep}, @INC );
        path('Build')->spew_raw( sprintf <<~'EOF', $^X, $perl5lib, __PACKAGE__, $alien_class );
            #!%s
            BEGIN { $ENV{PERL5LIB} = '%s' }
            use lib 'lib';
            use %s;
            Alien::Xrepo::Base::Build('%s');
            EOF
        make_executable('Build');
        path('_build_params')->spew_raw( encode_json( [ \@ARGV, $alien_class ] ) );
        $meta->save(@$_) for ['MYMETA.json'];
    }

    sub Build ( $alien_class = undef ) {
        use JSON::PP;
        my $action = shift @ARGV // 'build';
        if ( !$alien_class && -e '_build_params' ) {
            my $params = decode_json( path('_build_params')->slurp_raw );
            $alien_class = $params->[1];
        }
        Alien::Xrepo::Base::Builder->new( alien_class => $alien_class, action => $action, argv => \@ARGV )->execute();
    }
    class #
    Alien::Xrepo::Base::Builder v0.9.2 {
        use CPAN::Meta;
        use ExtUtils::Install qw[install];
        use ExtUtils::InstallPaths;
        use Path::Tiny;
        use JSON::PP;
        use Alien::Xrepo;
        field $alien_class : param;
        field $action      : param  //= 'build';
        field $argv        : param  //= [];
        field $meta        : reader //= CPAN::Meta->load_file('META.json');
        field $verbose     : param  //= 0;

        method execute() {
            my $method = 'ACTION_' . $action;
            if ( $self->can($method) ) {
                $self->$method();
            }
            else {
                die 'No such action: ' . $action;
            }
        }

        method ACTION_build() {
            say 'Building ' . $meta->name;
            path('blib/lib')->mkpath;
            path('blib/arch')->mkpath;
            $self->_copy_libs();
            my $config_data = $self->_resolve_alien();
            $self->_write_config_data($config_data);
            say 'Build complete';
        }

        method ACTION_test() {
            my $config_file = path('blib/lib')->child( ( split /::/, $alien_class ), 'ConfigData.pm' );
            $self->ACTION_build() unless -e $config_file;
            say 'Running tests...';
            require Test::Harness;
            my @tests = glob('t/*.t');
            Test::Harness::runtests(@tests) if @tests;
        }

        method ACTION_install() {
            say 'Installing...';
            my $ip = ExtUtils::InstallPaths->new( dist_name => $meta->name );
            install( $ip->install_map, 1, 0, 0 );
        }

        method ACTION_clean() {
            say 'Cleaning...';
            path('blib')->remove_tree;
            path('_build_params')->remove;
            path('Build')->remove;
            path('MYMETA.json')->remove;
            path('MYMETA.yml')->remove;
        }

        method _copy_libs() {
            my $src_root = path('lib');
            return unless $src_root->exists;
            my $iter = $src_root->iterator( { recurse => 1 } );
            while ( my $file = $iter->() ) {
                next unless $file->is_file;
                my $rel = $file->relative($src_root);
                next if $rel =~ m{(^|/)\.};
                my $dest = path('blib/lib')->child($rel);
                $dest->parent->mkpath;
                $file->copy($dest) or die 'Copy failed: ' . $!;
            }
        }

        method _resolve_alien() {
            eval "require $alien_class; 1" or die "Could not load $alien_class: $@";
            my $alien     = $alien_class->new;
            my @pkgs      = $alien->package_names;
            my %opts      = $alien->can('install_opts') ? $alien->install_opts : ();
            my $dist_name = $meta->name;
            my $share_dir = path('blib/lib/auto/share/dist')->child($dist_name)->absolute;
            $share_dir->mkpath;
            my $repo = Alien::Xrepo->new( root => $share_dir->stringify, verbose => $verbose );
            say "Installing @pkgs via Xrepo into $share_dir";
            my $make_rel = sub ($p) {
                return undef unless defined $p;
                my $path = path($p);
                return $path->relative($share_dir)->stringify if $share_dir->subsumes($path);
                return $path->stringify;
            };
            my %out;
            for my $pkg (@pkgs) {
                say "Installing $pkg via Xrepo into $share_dir";
                my $info = $repo->install( $pkg, undef, %opts );
                $out{$pkg} = {
                    version     => $info->version,
                    kind        => $info->kind,
                    links       => $info->links,
                    libfiles    => [ map { $make_rel->($_) } @{ $info->libfiles    // [] } ],
                    includedirs => [ map { $make_rel->($_) } @{ $info->includedirs // [] } ],
                    linkdirs    => [ map { $make_rel->($_) } @{ $info->linkdirs    // [] } ],
                    bindirs     => [ map { $make_rel->($_) } @{ $info->bindirs     // [] } ],
                    libpath     => $make_rel->( $info->libpath ),
                    installdir  => $make_rel->( $info->installdir ),
                    license     => $info->license,
                    shared      => $info->shared ? 1 : 0,
                    static      => $info->static ? 1 : 0
                };
            }
            $self->_prune_store( $repo, $share_dir, \@pkgs, \%opts );
            return \%out;
        }

        # `xrepo install` pulls the whole build toolchain the package drags in (python, meson,
        # ninja, cmake, pkgconf, etc.) but we only need the resulting shared libraries and headers.
        method _prune_store ( $repo, $share_dir, $pkgs, $opts ) {
            my $export_dir = path($share_dir)->parent->child( $share_dir->basename . '-prune' . $$ )->absolute;
            $export_dir->remove_tree if $export_dir->exists;
            $export_dir->mkpath;
            say "Exporting shared @$pkgs into $export_dir";
            $repo->export( $_, undef, %$opts, packagedir => $export_dir->stringify, shallow => 1 ) for @$pkgs;
            return unless $export_dir->exists && $export_dir->children;
            $share_dir->remove_tree;
            $share_dir->mkpath;
            for my $entry ( $export_dir->children ) {
                $entry->move( $share_dir->child( $entry->basename ) ) or die "Could not move $entry: $!";
            }
            $export_dir->remove_tree;
        }

        method _write_config_data($data) {
            my $package       = $alien_class . '::ConfigData';
            my @parts         = split( /::/, $package );
            my $target_config = path('blib/lib')->child( @parts[ 0 .. $#parts - 1 ] )->child( $parts[-1] . '.pm' );
            $target_config->parent->mkpath;
            my $json = encode_json($data);
            $json =~ s/\\/\\\\/g;
            $json =~ s/'/\\'/g;
            my $depth   = scalar(@parts);
            my $content = sprintf <<~'PERL', $package, $meta->name, $depth, $json;
            package %s {
                use v5.40;
                use JSON::PP qw[decode_json];
                use File::ShareDir qw[dist_dir];
                use Path::Tiny qw[path];
                my $dist_name = '%s';
                my $depth     = %d;
                my $config    = decode_json('%s');
                my $share_dir;
                try {
                    $share_dir = path( dist_dir($dist_name) );
                } catch ($e) {
                    $share_dir = path(__FILE__)->parent($depth)->child('auto', 'share', 'dist', $dist_name);
                }
                my $make_abs = sub ($p) {
                    return undef unless defined $p;
                    return $p if path($p)->is_absolute;
                    return $share_dir->child($p)->stringify;
                };
                sub config ($class, $key //= ()) {
                    state $expanded = do {
                        my $copy = {};
                        for my $pkg (keys %%$config) {
                            my $c = $config->{$pkg};
                            $copy->{$pkg} = {
                                %%$c,
                                libpath     => $make_abs->($c->{libpath}),
                                installdir  => $make_abs->($c->{installdir}),
                                includedirs =>[ map { $make_abs->($_) } @{ $c->{includedirs} // [] } ],
                                linkdirs    =>[ map { $make_abs->($_) } @{ $c->{linkdirs} // [] } ],
                                bindirs     =>[ map { $make_abs->($_) } @{ $c->{bindirs} // [] } ]
                            };
                        }
                        $copy;
                    };
                    defined $key ? $expanded->{$key} : $expanded;
                }
                sub package ($class, $pkg = undef) {
                    $pkg //= (keys %%$config)[0];
                    return __PACKAGE__->config->{$pkg};
                }
            };
            1;
            PERL
            $target_config->spew_utf8($content);
            say "Generated $target_config";
        }
    };
    class #
    Alien::Xrepo::Base::Alt v0.9.2 {
        field $base : param;
        field $pkg  : param;
        method package_names ()      { $base->package_names }
        method package_info ()       { $base->package_info($pkg) }
        method install (%opts)       { $base->install(%opts) }
        method pkg_name ()           {$pkg}
        method alt ( $name = undef ) { $base->alt( $name // $pkg ) }
        method libpath ()            { $base->libpath($pkg) }
        method ffi_lib ()            { $base->libpath($pkg) }
        method bin_dir ()            { $base->bin_dir($pkg) }
        method version ()            { $base->version($pkg) }
        method kind ()               { $base->kind($pkg) }
        method cflags ()             { $base->cflags($pkg) }
        method cflags_static ()      { $base->cflags($pkg) }
        method libs ()               { $base->libs($pkg) }
        method libs_static ()        { $base->libs($pkg) }
        method dynamic_libs ()       { $base->dynamic_libs($pkg) }
        method dist_dir ()           { $base->dist_dir($pkg) }
        method install_type ()       { $base->install_type($pkg) }
        method split_flags ($flags)    { $base->split_flags( $flags, $pkg ) }
        method find_header ($filename) { $base->find_header( $filename, $pkg ) }
    }
    }
    #
    1;
__END__
Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in
the Artistic License 2. Other copyrights, terms, and conditions may apply to data transmitted
through this module.
