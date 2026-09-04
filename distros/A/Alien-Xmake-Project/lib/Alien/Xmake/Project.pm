use v5.40;
use experimental 'class';
#
package Alien::Xmake::Project::Util v1.0.0 {
    use Scalar::Util ();

    # Join a list of scalars into a comma-separated, quoted Lua argument list.
    sub _arg_list($args) {
        join ', ', map { _lua_value($_) } @$args;
    }

    # Render `name("a", "b", {k="v"})`; scalars group into one call, one trailing HASH becomes the options table appended to the same call.
    sub _stmt ( $name, @args ) {
        my ( $scalars, $opts ) = _split_opt(@args);
        my @parts = @$scalars;
        push @parts, $opts if keys %$opts;
        return $name . '(' . _arg_list( \@parts ) . ')';
    }

    # Separate a trailing HASH (options table) from positional args; flatten ARRAYs.
    sub _split_opt (@args) {
        my $opts = {};
        $opts = pop @args if @args && ref( $args[-1] ) eq 'HASH';
        my @scalars;
        for my $a (@args) {
            if   ( ref($a) eq 'ARRAY' ) { push @scalars, @$a; }
            else                        { push @scalars, $a; }
        }
        return ( \@scalars, $opts );
    }

# Variant of _stmt that treats each positional ARRAY as a single Lua list argument (not variadic), for helpers that take a list-of-links/types/headers.
    sub _stmt_list ( $name, @args ) {
        my @parts = @args;
        my $opts  = {};
        if ( @parts && ref( $parts[-1] ) eq 'HASH' ) {
            $opts = pop @parts;
            push @parts, $opts if keys %$opts;
        }
        return $name . '(' . _arg_list( \@parts ) . ')';
    }

    # Quote a string as a Lua literal with escaping.
    sub _lua_str ($s) {
        $s = '' if !defined $s;
        $s =~ s/\\/\\\\/g;
        $s =~ s/"/\\"/g;
        $s =~ s/\n/\\n/g;
        $s =~ s/\r/\\r/g;
        $s =~ s/\t/\\t/g;
        return '"' . $s . '"';
    }

    # Render a Perl value (scalar / ARRAYref / HASHref) as a Lua literal.
    sub _lua_value ($v) {
        return 'nil' unless defined $v;
        if    ( ref($v) eq 'ARRAY' ) { return _lua_array($v); }
        elsif ( ref($v) eq 'HASH' )  { return _lua_table($v); }

        # v5.36+ `true`/`false` are dualvar booleans; emit them bare so xmake sees a
        # real boolean (e.g. `configs={shared=true}`), not the string "1".
        if ( Scalar::Util::isdual($v) ) { return $v ? 'true' : 'false'; }
        return _lua_str($v);
    }

    # Render an ARRAYref as a Lua list `{"a", "b"}`.
    sub _lua_array ($a) {
        return '{' . join( ', ', map { _lua_value($_) } @$a ) . '}';
    }

    # Render a HASHref as a Lua table `{["k"]="v", n=1}` (stable sorted keys; bracket form is
    # always valid for string keys).
    sub _lua_table ($h) {
        return '{}' unless $h && keys %$h;
        my @pairs;
        for my $k ( sort keys %$h ) {
            my $v = $h->{$k};
            next if !defined $v;
            push @pairs, '[' . _lua_str($k) . ']=' . _lua_value($v);
        }
        return '{' . join( ', ', @pairs ) . '}';
    }

    # Render script-hook arguments: strings that start with `function` are emitted verbatim (raw
    # Lua body); everything else is quoted as a normal Lua value.
    sub _lua_script (@args) {
        return '' unless @args;
        return join ', ', map { ref($_) ? _lua_value($_) : ( /^function\b/ ? $_ : _lua_value($_) ) } @args;
    }

    # Create a domain object of the requested kind and register it in its pool.
    sub _wrap ( $kind, $dname, $pool, @body ) {
        my $class = {
            option    => 'Alien::Xmake::Project::Option',
            rule      => 'Alien::Xmake::Project::Rule',
            toolchain => 'Alien::Xmake::Project::Toolchain',
            package   => 'Alien::Xmake::Project::Package',
            xpack     => 'Alien::Xmake::Project::Xpack'
        }->{$kind};
        return undef unless $class;
        my $obj = $class->new( _name => $dname, _body => \@body );
        push @$pool, $obj;
        return $obj;
    }
};
class Alien::Xmake::Project v1.0.0 {
    use Path::Tiny;
    use Alien::Xmake;
    #
    field $file : param //= 'xmake.lua';
    field $yes  : param //= 0;
    field $name;
    field $vers           = undef;
    field $xmakever       = undef;
    field $root           = [];
    field $includes       = [];
    field $requires       = [];
    field $xpack_included = 0;
    field $check_included = 0;
    field $domains        = [];      # option/rule/toolchain/package/xpack, in order
    field $xpackdoms      = [];      # xpack entries (packed last)
    field $namespaces     = [];
    field $targets        = [];
    field $xmake;

    # top level
    method set_project      ($n)           { $name     = $n; $self; }
    method set_version      ($v)           { $vers     = $v; $self; }
    method set_xmakever     ($v)           { $xmakever = $v; $self; }
    method set_config       ( $n, $value ) { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_config', $n, $value ); $self; }
    method set_defaultplat  (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_defaultplat',  @a ); $self; }
    method set_defaultarchs (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_defaultarchs', @a ); $self; }
    method set_defaultmode  (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_defaultmode',  @a ); $self; }
    method set_allowedplats (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_allowedplats', @a ); $self; }
    method set_allowedarchs (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_allowedarchs', @a ); $self; }
    method set_allowedmodes (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_allowedmodes', @a ); $self; }
    method add_moduledirs   (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'add_moduledirs',   @a ); $self; }
    method add_plugindirs   (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'add_plugindirs',   @a ); $self; }
    method set_runtimes     (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'set_runtimes',     @a ); $self; }
    method add_rules        (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'add_rules',        @a ); $self; }
    method add_addons       (@a)           { push @$root, Alien::Xmake::Project::Util::_stmt( 'add_addons',       @a ); $self; }

    # Global scope applies to every target (root scope). These mirror the Target methods but emit
    # at the project root so all targets inherit them.
    method add_defines    (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'add_defines',    @a ); $self; }
    method set_toolchains (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'set_toolchains', @a ); $self; }
    method set_toolset    (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'set_toolset',    @a ); $self; }
    method set_plat       (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'set_plat',       @a ); $self; }
    method set_arch       (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'set_arch',       @a ); $self; }
    method set_languages  (@a) { push @$root,     Alien::Xmake::Project::Util::_stmt( 'set_languages',  @a ); $self; }
    method includes       (@a) { push @$includes, Alien::Xmake::Project::Util::_stmt( 'includes',       @a ); $self; }

    method add_requires (@args) {
        push @$requires, Alien::Xmake::Project::Util::_stmt( 'add_requires', @args );
        $self;
    }

    method add_requireconfs (@args) {
        push @$root, Alien::Xmake::Project::Util::_stmt( 'add_requireconfs', @args );
        $self;
    }

    method add_repositories (@args) {
        push @$root, Alien::Xmake::Project::Util::_stmt( 'add_repositories', @args );
        $self;
    }

    # scope root/global statements behind a Lua condition (see ::Target::when).
    method when ( $predicate, $body ) {
        my $start = @$root;
        if    ( ref($body) eq 'ARRAY' ) { push @$root, @$body; }
        elsif ( ref($body) eq 'CODE' )  { $body->($self); }
        elsif ( defined $body )         { push @$root, $body; }
        my @inner = @$root[ $start .. $#$root ];
        @$root = @$root[ 0 .. $start - 1 ];
        push @$root, "if $predicate then";
        push @$root, map {"    $_"} @inner;
        push @$root, 'end';
        $self;
    }

    # domain entries
    method target ($tname) {
        my $t = Alien::Xmake::Project::Target->new( _project => $self, _name => $tname );
        push @$targets, $t;
        return $t;
    }

    # `option($name)` chains setter statements into an `option(name) ... option_end()`
    # block. Calling `option($name, {atts})` instead emits the inline table form:
    #   option("name", {["default"]=1, ["values"]={"a","b"}})
    method option ( $n, @b ) {
        if ( @b == 1 && ref( $b[0] ) eq 'HASH' ) {
            my $obj = Alien::Xmake::Project::Option->new( _name => $n, _inline => $b[0], _body => [] );
            push @$domains, $obj;
            return $obj;
        }
        return $self->_newdomain( 'option', $n, @b );
    }
    method rule      ( $n, @b ) { return $self->_newdomain( 'rule',      $n, @b ); }
    method toolchain ( $n, @b ) { return $self->_newdomain( 'toolchain', $n, @b ); }
    method package   ( $n, @b ) { return $self->_newdomain( 'package',   $n, @b ); }

    method xpack ( $n, @b ) {
        unless ($xpack_included) {
            push @$root, 'includes("@builtin/xpack")';
            $xpack_included = 1;
        }
        return $self->_newdomain( 'xpack', $n, @b );
    }

    method _ensure_check {
        unless ($check_included) {
            unshift @$root, 'includes("@builtin/check")';
            $check_included = 1;
        }
        return $self;
    }

    method namespace ( $nsname, @body ) {
        my $ns = Alien::Xmake::Project::Namespace->new( _project => $self, _name => $nsname, _body => \@body );
        push @$namespaces, $ns;
        return $ns;
    }
    #
    method save {
        my $lua   = $self->_render;
        my $pfile = Path::Tiny::path($file);
        $pfile->parent->mkpath;
        $pfile->spew_raw($lua);
        $self;
    }

    method _newdomain ( $kind, $n, @body ) {
        my $obj = Alien::Xmake::Project::Util::_wrap( $kind, $n, $domains, @body );
        return $obj;
    }

    method _render {
        my @lua;
        push @lua, qq{set_project("$name")}      if defined $name     && length $name;
        push @lua, qq{set_version("$vers")}      if defined $vers     && length $vers;
        push @lua, qq{set_xmakever("$xmakever")} if defined $xmakever && length $xmakever;
        push @lua, @$root;
        push @lua, @$requires;
        push @lua, @$includes;
        push @lua, $_->render      for @$domains;
        push @lua, @{ $_->render } for @$namespaces;

        for my $t (@$targets) {
            my $tname = $t->name;
            push @lua, qq{target("$tname")};
            push @lua, map {"    $_"} @{ $t->lines };
            push @lua, 'target_end()';
            push @lua, '';
        }
        return join( "\n", grep { length $_ } @lua ) . "\n";
    }

    method xmake {
        $xmake ||= Alien::Xmake->new( file => $file, yes => $yes );
        $xmake;
    }

    # execution convenience methods (delegated to xmake handle)
    method configure (%opts) {
        $self->save unless -e $file;
        $self->xmake->configure(%opts);
    }

    method build (@args) {
        $self->save unless -e $file;
        $self->xmake->build(@args);
    }
    method run     (@args) { $self->xmake->run(@args) }
    method clean   (@args) { $self->xmake->clean(@args) }
    method install (@args) { $self->xmake->install(@args) }

    method pack (@args) {
        $self->save unless -e $file;
        $self->xmake->pack(@args);
    }

    method project ( $kind //= (), %opts ) {
        if ( defined $kind && !ref $kind && !%opts ) {
            %opts = ( kind => $kind );
        }
        elsif ( defined $kind && ref $kind eq 'HASH' ) {
            %opts = %$kind;
        }
        elsif ( defined $kind ) {
            $opts{kind} = $kind;
        }
        $self->save unless -e $file;
        return $self->xmake->project(%opts);
    }

    method target_info ( $target, %opts ) {
        return $self->xmake->target_info( $target, %opts );
    }

    method show (@args) {
        return $self->xmake->show(@args);
    }
};
#
class Alien::Xmake::Project::Target v1.0.0 {
    field $_project : param;
    field $_name    : param : reader(name);
    field $lines    : reader = [];
    #
    method _line ( $name, @args ) { push @$lines, Alien::Xmake::Project::Util::_stmt( $name, @args );               $self; }
    method _hook ( $name, @args ) { push @$lines, "$name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }

    # scope a block of statements behind a Lua condition, e.g.
    #   $t->when('is_plat("windows", "linux")', sub { $t->add_links('pthread','m') });
    # emits:
    #   if is_plat("windows", "linux") then
    #       add_links("pthread", "m")
    #   end
    # $body may be a code ref (calls chained back into $self) or an ARRAYref of
    # raw Lua body lines. Any condition expression string works, including
    # negations: 'not is_plat("windows")'.
    method when ( $predicate, $body ) {
        my $start = @$lines;
        if    ( ref($body) eq 'ARRAY' ) { push @$lines, @$body; }
        elsif ( ref($body) eq 'CODE' )  { $body->($self); }
        elsif ( defined $body )         { push @$lines, $body; }
        my @inner = @$lines[ $start .. $#$lines ];
        @$lines = @$lines[ 0 .. $start - 1 ];
        push @$lines, "if $predicate then";
        push @$lines, map {"    $_"} @inner;
        push @$lines, 'end';
        $self;
    }

    # naming / output
    method set_kind       (@a) { $self->_line( 'set_kind',       @a ); }
    method set_basename   (@a) { $self->_line( 'set_basename',   @a ); }
    method set_filename   (@a) { $self->_line( 'set_filename',   @a ); }
    method set_prefixname (@a) { $self->_line( 'set_prefixname', @a ); }
    method set_suffixname (@a) { $self->_line( 'set_suffixname', @a ); }
    method set_extension  (@a) { $self->_line( 'set_extension',  @a ); }
    method set_strip      (@a) { $self->_line( 'set_strip',      @a ); }
    method set_group      (@a) { $self->_line( 'set_group',      @a ); }
    method set_objectdir  (@a) { $self->_line( 'set_objectdir',  @a ); }
    method set_dependir   (@a) { $self->_line( 'set_dependir',   @a ); }
    method set_installdir (@a) { $self->_line( 'set_installdir', @a ); }
    method set_prefixdir  (@a) { $self->_line( 'set_prefixdir',  @a ); }

    # enablement / options
    method set_default (@a) { $self->_line( 'set_default', @a ); }
    method set_enabled (@a) { $self->_line( 'set_enabled', @a ); }
    method set_options (@a) { $self->_line( 'set_options', @a ); }
    method add_options (@a) { $self->_line( 'add_options', @a ); }

    # compile model
    method set_warnings      (@a) { $self->_line( 'set_warnings',      @a ); }
    method set_optimize      (@a) { $self->_line( 'set_optimize',      @a ); }
    method set_symbols       (@a) { $self->_line( 'set_symbols',       @a ); }
    method set_fpmodels      (@a) { $self->_line( 'set_fpmodels',      @a ); }
    method set_exceptions    (@a) { $self->_line( 'set_exceptions',    @a ); }
    method set_encodings     (@a) { $self->_line( 'set_encodings',     @a ); }
    method set_policy        (@a) { $self->_line( 'set_policy',        @a ); }
    method set_pcheader      (@a) { $self->_line( 'set_pcheader',      @a ); }
    method set_pcxxheader    (@a) { $self->_line( 'set_pcxxheader',    @a ); }
    method set_pmheader      (@a) { $self->_line( 'set_pmheader',      @a ); }
    method set_pmxxheader    (@a) { $self->_line( 'set_pmxxheader',    @a ); }
    method set_runtimes      (@a) { $self->_line( 'set_runtimes',      @a ); }
    method set_languages     (@a) { $self->_line( 'set_languages',     @a ); }
    method add_forceincludes (@a) { $self->_line( 'add_forceincludes', @a ); }
    method add_vectorexts    (@a) { $self->_line( 'add_vectorexts',    @a ); }

    # content / deps
    method add_files    (@a) { $self->_line( 'add_files',    @a ); }
    method remove_files (@a) { $self->_line( 'remove_files', @a ); }
    method remove_headerfiles(@a) { $self->_line( 'remove_headerfiles', @a ); }
    method add_defines     (@a) { $self->_line( 'add_defines',     @a ); }
    method add_undefines   (@a) { $self->_line( 'add_undefines',   @a ); }
    method add_includedirs (@a) { $self->_line( 'add_includedirs', @a ); }
    method add_sysincludedirs(@a) { $self->_line( 'add_sysincludedirs', @a ); }
    method add_embeddirs     (@a) { $self->_line( 'add_embeddirs',     @a ); }
    method add_links         (@a) { $self->_line( 'add_links',         @a ); }
    method add_syslinks      (@a) { $self->_line( 'add_syslinks',      @a ); }
    method add_linkorders    (@a) { $self->_line( 'add_linkorders',    @a ); }
    method add_linkgroups    (@a) { $self->_line( 'add_linkgroups',    @a ); }
    method add_linkdirs      (@a) { $self->_line( 'add_linkdirs',      @a ); }
    method add_rpathdirs     (@a) { $self->_line( 'add_rpathdirs',     @a ); }
    method add_deps          (@a) { $self->_line( 'add_deps',          @a ); }
    method add_rules         (@a) { $self->_line( 'add_rules',         @a ); }
    method add_packages      (@a) { $self->_line( 'add_packages',      @a ); }
    method add_requires      (@a) { $self->_line( 'add_requires',      @a ); }
    method add_headerfiles   (@a) { $self->_line( 'add_headerfiles',   @a ); }
    method add_installfiles  (@a) { $self->_line( 'add_installfiles',  @a ); }
    method add_extrafiles    (@a) { $self->_line( 'add_extrafiles',    @a ); }
    method add_imports       (@a) { $self->_line( 'add_imports',       @a ); }
    method add_languages     (@a) { $self->_line( 'add_languages',     @a ); }
    method add_frameworks    (@a) { $self->_line( 'add_frameworks',    @a ); }
    method add_frameworkdirs (@a) { $self->_line( 'add_frameworkdirs', @a ); }
    method add_values        (@a) { $self->_line( 'add_values',        @a ); }
    method set_values        (@a) { $self->_line( 'set_values',        @a ); }

    # runtime / run
    method set_targetdir (@a) { $self->_line( 'set_targetdir', @a ); }
    method set_rundir    (@a) { $self->_line( 'set_rundir',    @a ); }
    method set_runargs   (@a) { $self->_line( 'set_runargs',   @a ); }
    method set_runenv    (@a) { $self->_line( 'set_runenv',    @a ); }
    method add_runenvs   (@a) { $self->_line( 'add_runenvs',   @a ); }
    method add_tests     (@a) { $self->_line( 'add_tests',     @a ); }

    # toolchain / plat / arch
    method set_plat       (@a) { $self->_line( 'set_plat',       @a ); }
    method set_arch       (@a) { $self->_line( 'set_arch',       @a ); }
    method set_toolchains (@a) { $self->_line( 'set_toolchains', @a ); }
    method set_toolset    (@a) { $self->_line( 'set_toolset',    @a ); }

    # compile / link flags
    method add_cflags     (@a) { $self->_line( 'add_cflags',     @a ); }
    method add_cxflags    (@a) { $self->_line( 'add_cxflags',    @a ); }
    method add_cxxflags   (@a) { $self->_line( 'add_cxxflags',   @a ); }
    method add_mflags     (@a) { $self->_line( 'add_mflags',     @a ); }
    method add_mxflags    (@a) { $self->_line( 'add_mxflags',    @a ); }
    method add_mxxflags   (@a) { $self->_line( 'add_mxxflags',   @a ); }
    method add_scflags    (@a) { $self->_line( 'add_scflags',    @a ); }
    method add_asflags    (@a) { $self->_line( 'add_asflags',    @a ); }
    method add_gcflags    (@a) { $self->_line( 'add_gcflags',    @a ); }
    method add_dcflags    (@a) { $self->_line( 'add_dcflags',    @a ); }
    method add_rcflags    (@a) { $self->_line( 'add_rcflags',    @a ); }
    method add_fcflags    (@a) { $self->_line( 'add_fcflags',    @a ); }
    method add_zcflags    (@a) { $self->_line( 'add_zcflags',    @a ); }
    method add_cuflags    (@a) { $self->_line( 'add_cuflags',    @a ); }
    method add_culdflags  (@a) { $self->_line( 'add_culdflags',  @a ); }
    method add_cugencodes (@a) { $self->_line( 'add_cugencodes', @a ); }
    method add_ascnpuarchs(@a) { $self->_line( 'add_ascnpuarchs', @a ); }
    method add_ldflags (@a) { $self->_line( 'add_ldflags', @a ); }
    method add_arflags (@a) { $self->_line( 'add_arflags', @a ); }
    method add_shflags (@a) { $self->_line( 'add_shflags', @a ); }

    # config-file generation
    method add_configfiles (@a) { $self->_line( 'add_configfiles', @a ); }
    method set_configvar   (@a) { $self->_line( 'set_configvar',   @a ); }
    method set_configdir   (@a) { $self->_line( 'set_configdir',   @a ); }

    # compile-time feature detection (includes("@builtin/check"))
    method _check ( $name, @args ) {
        $_project->_ensure_check;
        push @$lines, Alien::Xmake::Project::Util::_stmt_list( $name, @args );
        return $self;
    }
    method check_links                 (@a) { $self->_check( 'check_links',                 @a ); }
    method check_syslinks              (@a) { $self->_check( 'check_syslinks',              @a ); }
    method check_ctypes                (@a) { $self->_check( 'check_ctypes',                @a ); }
    method check_cxxtypes              (@a) { $self->_check( 'check_cxxtypes',              @a ); }
    method check_cfuncs                (@a) { $self->_check( 'check_cfuncs',                @a ); }
    method check_cxxfuncs              (@a) { $self->_check( 'check_cxxfuncs',              @a ); }
    method check_cincludes             (@a) { $self->_check( 'check_cincludes',             @a ); }
    method check_cxxincludes           (@a) { $self->_check( 'check_cxxincludes',           @a ); }
    method check_csnippets             (@a) { $self->_check( 'check_csnippets',             @a ); }
    method check_cxxsnippets           (@a) { $self->_check( 'check_cxxsnippets',           @a ); }
    method check_features              (@a) { $self->_check( 'check_features',              @a ); }
    method check_macros                (@a) { $self->_check( 'check_macros',                @a ); }
    method check_sizeof                (@a) { $self->_check( 'check_sizeof',                @a ); }
    method check_alignof               (@a) { $self->_check( 'check_alignof',               @a ); }
    method check_bigendian             (@a) { $self->_check( 'check_bigendian',             @a ); }
    method check_cflags                (@a) { $self->_check( 'check_cflags',                @a ); }
    method check_cxxflags              (@a) { $self->_check( 'check_cxxflags',              @a ); }
    method configvar_check_links       (@a) { $self->_check( 'configvar_check_links',       @a ); }
    method configvar_check_syslinks    (@a) { $self->_check( 'configvar_check_syslinks',    @a ); }
    method configvar_check_ctypes      (@a) { $self->_check( 'configvar_check_ctypes',      @a ); }
    method configvar_check_cxxtypes    (@a) { $self->_check( 'configvar_check_cxxtypes',    @a ); }
    method configvar_check_cfuncs      (@a) { $self->_check( 'configvar_check_cfuncs',      @a ); }
    method configvar_check_cxxfuncs    (@a) { $self->_check( 'configvar_check_cxxfuncs',    @a ); }
    method configvar_check_cincludes   (@a) { $self->_check( 'configvar_check_cincludes',   @a ); }
    method configvar_check_cxxincludes (@a) { $self->_check( 'configvar_check_cxxincludes', @a ); }
    method configvar_check_csnippets   (@a) { $self->_check( 'configvar_check_csnippets',   @a ); }
    method configvar_check_cxxsnippets (@a) { $self->_check( 'configvar_check_cxxsnippets', @a ); }
    method configvar_check_features    (@a) { $self->_check( 'configvar_check_features',    @a ); }
    method configvar_check_macros      (@a) { $self->_check( 'configvar_check_macros',      @a ); }
    method configvar_check_sizeof      (@a) { $self->_check( 'configvar_check_sizeof',      @a ); }
    method configvar_check_alignof     (@a) { $self->_check( 'configvar_check_alignof',     @a ); }
    method configvar_check_bigendian   (@a) { $self->_check( 'configvar_check_bigendian',   @a ); }
    method configvar_check_cflags      (@a) { $self->_check( 'configvar_check_cflags',      @a ); }
    method configvar_check_cxxflags    (@a) { $self->_check( 'configvar_check_cxxflags',    @a ); }

    # run / prepare hooks (raw Lua)
    method on_load        (@a) { $self->_hook( 'on_load',        @a ); }
    method on_config      (@a) { $self->_hook( 'on_config',      @a ); }
    method on_build       (@a) { $self->_hook( 'on_build',       @a ); }
    method on_build_file  (@a) { $self->_hook( 'on_build_file',  @a ); }
    method before_build   (@a) { $self->_hook( 'before_build',   @a ); }
    method after_build    (@a) { $self->_hook( 'after_build',    @a ); }
    method on_link        (@a) { $self->_hook( 'on_link',        @a ); }
    method before_link    (@a) { $self->_hook( 'before_link',    @a ); }
    method after_link     (@a) { $self->_hook( 'after_link',     @a ); }
    method on_clean       (@a) { $self->_hook( 'on_clean',       @a ); }
    method before_clean   (@a) { $self->_hook( 'before_clean',   @a ); }
    method after_clean    (@a) { $self->_hook( 'after_clean',    @a ); }
    method on_install     (@a) { $self->_hook( 'on_install',     @a ); }
    method before_install (@a) { $self->_hook( 'before_install', @a ); }
    method after_install  (@a) { $self->_hook( 'after_install',  @a ); }
    method on_uninstall(@a)     { $self->_hook( 'on_uninstall',     @a ); }
    method before_uninstall(@a) { $self->_hook( 'before_uninstall', @a ); }
    method after_uninstall      (@a) { $self->_hook( 'after_uninstall',      @a ); }
    method on_run               (@a) { $self->_hook( 'on_run',               @a ); }
    method before_run           (@a) { $self->_hook( 'before_run',           @a ); }
    method after_run            (@a) { $self->_hook( 'after_run',            @a ); }
    method on_prepare           (@a) { $self->_hook( 'on_prepare',           @a ); }
    method on_prepare_file      (@a) { $self->_hook( 'on_prepare_file',      @a ); }
    method on_prepare_files     (@a) { $self->_hook( 'on_prepare_files',     @a ); }
    method before_prepare       (@a) { $self->_hook( 'before_prepare',       @a ); }
    method after_prepare        (@a) { $self->_hook( 'after_prepare',        @a ); }
    method before_prepare_file  (@a) { $self->_hook( 'before_prepare_file',  @a ); }
    method after_prepare_file   (@a) { $self->_hook( 'after_prepare_file',   @a ); }
    method before_prepare_files (@a) { $self->_hook( 'before_prepare_files', @a ); }
    method after_prepare_files  (@a) { $self->_hook( 'after_prepare_files',  @a ); }

    # raw Lua escape hatch
    method lua (@lines) {
        push @$lines, map { ref($_) eq 'ARRAY' ? @$_ : $_ } @lines;
        $self;
    }
};
#
class Alien::Xmake::Project::Namespace v1.0.0 {
    field $_project : param;
    field $_name    : param : reader(name);
    field $_body    : param = [];

    method render {
        my @out = ( 'namespace("' . $_name . '")' );
        for my $b (@$_body) {
            if ( ref($b) eq 'CODE' ) {
                my $r = $b->($_project);
                push @out, map {"    $_"} ref($r) eq 'ARRAY' ? @$r : ($r);
            }
            else {
                push @out, map {"    $_"} ref($b) eq 'ARRAY' ? @$b : ($b);
            }
        }
        push @out, 'namespace_end()';
        return \@out;
    }
};
#
class Alien::Xmake::Project::Option v1.0.0 {
    field $_name   : param : reader(name);
    field $_body   : param  = [];
    field $_inline : param  = undef;
    field $lines   : reader = [];

    method _line ( $name, @args ) {
        die "option \"$_name\" declared inline (table form) can't be extended with set_* calls\n" if defined $_inline;
        push @$lines, "    " . Alien::Xmake::Project::Util::_stmt( $name, @args );
        $self;
    }

    method _hook ( $name, @args ) {
        die "option \"$_name\" declared inline (table form) can't add hooks\n" if defined $_inline;
        push @$lines, "    $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")";
        $self;
    }
    method set_default     (@a) { $self->_line( 'set_default',     @a ); }
    method set_values      (@a) { $self->_line( 'set_values',      @a ); }
    method set_showmenu    (@a) { $self->_line( 'set_showmenu',    @a ); }
    method set_category    (@a) { $self->_line( 'set_category',    @a ); }
    method set_description (@a) { $self->_line( 'set_description', @a ); }
    method add_deps        (@a) { $self->_line( 'add_deps',        @a ); }
    method add_links       (@a) { $self->_line( 'add_links',       @a ); }
    method add_linkdirs    (@a) { $self->_line( 'add_linkdirs',    @a ); }
    method add_rpathdirs   (@a) { $self->_line( 'add_rpathdirs',   @a ); }
    method add_cincludes   (@a) { $self->_line( 'add_cincludes',   @a ); }
    method add_cxxincludes (@a) { $self->_line( 'add_cxxincludes', @a ); }
    method add_ctypes      (@a) { $self->_line( 'add_ctypes',      @a ); }
    method add_cxxtypes    (@a) { $self->_line( 'add_cxxtypes',    @a ); }
    method add_csnippets   (@a) { $self->_line( 'add_csnippets',   @a ); }
    method add_cxxsnippets (@a) { $self->_line( 'add_cxxsnippets', @a ); }
    method add_cfuncs      (@a) { $self->_line( 'add_cfuncs',      @a ); }
    method add_cxxfuncs    (@a) { $self->_line( 'add_cxxfuncs',    @a ); }
    method add_defines     (@a) { $self->_line( 'add_defines',     @a ); }
    method add_cxflags     (@a) { $self->_line( 'add_cxflags',     @a ); }
    method before_check    (@a) { $self->_hook( 'before_check', @a ); }
    method on_check        (@a) { $self->_hook( 'on_check',     @a ); }
    method after_check     (@a) { $self->_hook( 'after_check',  @a ); }

    method render {
        if ( defined $_inline ) {
            return 'option("' . $_name . '", ' . Alien::Xmake::Project::Util::_lua_table($_inline) . ')';
        }
        return ( 'option("' . $_name . '")', @$lines, 'option_end()' );
    }
};
#
class Alien::Xmake::Project::Rule v1.0.0 {
    field $_name : param : reader(name);
    field $_body : param  = [];
    field $lines : reader = [];
    method _line          ( $name, @args ) { push @$lines, "    " . Alien::Xmake::Project::Util::_stmt( $name, @args );          $self; }
    method _hook          ( $name, @args ) { push @$lines, "    $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }
    method set_extensions (@a)             { $self->_line( 'set_extensions', @a ); }
    method add_deps       (@a)             { $self->_line( 'add_deps',       @a ); }
    method add_imports    (@a)             { $self->_line( 'add_imports',    @a ); }
    method on_load        (@a)             { $self->_hook( 'on_load',       @a ); }
    method on_config      (@a)             { $self->_hook( 'on_config',     @a ); }
    method on_link        (@a)             { $self->_hook( 'on_link',       @a ); }
    method before_link    (@a)             { $self->_hook( 'before_link',   @a ); }
    method after_link     (@a)             { $self->_hook( 'after_link',    @a ); }
    method on_build       (@a)             { $self->_hook( 'on_build',      @a ); }
    method before_build   (@a)             { $self->_hook( 'before_build',  @a ); }
    method after_build    (@a)             { $self->_hook( 'after_build',   @a ); }
    method on_build_file  (@a)             { $self->_hook( 'on_build_file', @a ); }
    method before_build_file(@a)  { $self->_hook( 'before_build_file',  @a ); }
    method after_build_file (@a)  { $self->_hook( 'after_build_file',   @a ); }
    method on_build_files(@a)     { $self->_hook( 'on_build_files',     @a ); }
    method before_build_files(@a) { $self->_hook( 'before_build_files', @a ); }
    method after_build_files (@a) { $self->_hook( 'after_build_files', @a ); }
    method on_clean          (@a) { $self->_hook( 'on_clean',          @a ); }
    method before_clean(@a) { $self->_hook( 'before_clean', @a ); }
    method after_clean (@a) { $self->_hook( 'after_clean', @a ); }
    method on_package  (@a) { $self->_hook( 'on_package',  @a ); }
    method before_package(@a) { $self->_hook( 'before_package', @a ); }
    method after_package (@a) { $self->_hook( 'after_package', @a ); }
    method on_install    (@a) { $self->_hook( 'on_install',    @a ); }
    method before_install(@a)   { $self->_hook( 'before_install',   @a ); }
    method after_install (@a)   { $self->_hook( 'after_install',    @a ); }
    method on_uninstall(@a)     { $self->_hook( 'on_uninstall',     @a ); }
    method before_uninstall(@a) { $self->_hook( 'before_uninstall', @a ); }
    method after_uninstall (@a) { $self->_hook( 'after_uninstall',  @a ); }

    method lua (@lines) {
        push @$lines, map { ref($_) eq 'ARRAY' ? @$_ : $_ } @lines;
        $self;
    }

    method render {
        return ( 'rule("' . $_name . '")', @$lines, 'rule_end()' );
    }
};
#
class Alien::Xmake::Project::Toolchain v1.0.0 {
    field $_name : param : reader(name);
    field $_body : param        = [];
    field $lines : reader(line) = [];
    #
    method _line       ( $name, @args ) { push @$lines, "    " . Alien::Xmake::Project::Util::_stmt( $name, @args );          $self; }
    method _hook       ( $name, @args ) { push @$lines, "    $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }
    method set_kind    (@a)             { $self->_line( 'set_kind',    @a ); }
    method set_sdkdir  (@a)             { $self->_line( 'set_sdkdir',  @a ); }
    method set_bindir  (@a)             { $self->_line( 'set_bindir',  @a ); }
    method set_toolset (@a)             { $self->_line( 'set_toolset', @a ); }
    method add_defines (@a)             { $self->_line( 'add_defines', @a ); }
    method on_load     (@a)             { $self->_hook( 'on_load',  @a ); }
    method on_check    (@a)             { $self->_hook( 'on_check', @a ); }

    method render {
        return ( 'toolchain("' . $_name . '")', @$lines, 'toolchain_end()' );
    }
};
#
class Alien::Xmake::Project::Package v1.0.0 {
    field $_name : param : reader;
    field $_body : param  = [];
    field $lines : reader = [];
    #
    method _line           ( $name, @args ) { push @$lines, "    " . Alien::Xmake::Project::Util::_stmt( $name, @args );          $self; }
    method _hook           ( $name, @args ) { push @$lines, "    $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }
    method set_homepage    (@a)             { $self->_line( 'set_homepage',    @a ); }
    method set_description (@a)             { $self->_line( 'set_description', @a ); }
    method set_license     (@a)             { $self->_line( 'set_license',     @a ); }
    method set_kind        (@a)             { $self->_line( 'set_kind',        @a ); }
    method set_urls        (@a)             { $self->_line( 'set_urls',        @a ); }
    method add_urls        (@a)             { $self->_line( 'add_urls',        @a ); }
    method add_versions    (@a)             { $self->_line( 'add_versions',    @a ); }
    method add_versionfiles(@a) { $self->_line( 'add_versionfiles', @a ); }
    method set_sourcedir   (@a) { $self->_line( 'set_sourcedir',   @a ); }
    method add_patches     (@a) { $self->_line( 'add_patches',     @a ); }
    method add_links       (@a) { $self->_line( 'add_links',       @a ); }
    method add_syslinks    (@a) { $self->_line( 'add_syslinks',    @a ); }
    method add_includedirs (@a) { $self->_line( 'add_includedirs', @a ); }
    method add_bindirs     (@a) { $self->_line( 'add_bindirs',     @a ); }
    method add_defines     (@a) { $self->_line( 'add_defines',     @a ); }
    method add_frameworks  (@a) { $self->_line( 'add_frameworks',  @a ); }
    method add_linkdirs    (@a) { $self->_line( 'add_linkdirs',    @a ); }
    method add_linkorders  (@a) { $self->_line( 'add_linkorders',  @a ); }
    method add_linkgroups  (@a) { $self->_line( 'add_linkgroups',  @a ); }
    method add_configs     (@a) { $self->_line( 'add_configs',     @a ); }
    method add_extsources  (@a) { $self->_line( 'add_extsources',  @a ); }
    method add_deps        (@a) { $self->_line( 'add_deps',        @a ); }
    method add_components  (@a) { $self->_line( 'add_components',  @a ); }
    method set_base        (@a) { $self->_line( 'set_base',        @a ); }
    method add_schemes     (@a) { $self->_line( 'add_schemes',     @a ); }
    method on_load         (@a) { $self->_hook( 'on_load',      @a ); }
    method on_fetch        (@a) { $self->_hook( 'on_fetch',     @a ); }
    method on_check        (@a) { $self->_hook( 'on_check',     @a ); }
    method on_install      (@a) { $self->_hook( 'on_install',   @a ); }
    method on_download     (@a) { $self->_hook( 'on_download',  @a ); }
    method on_test         (@a) { $self->_hook( 'on_test',      @a ); }
    method on_component    (@a) { $self->_hook( 'on_component', @a ); }

    method lua (@lines) {
        push @$lines, map { ref($_) eq 'ARRAY' ? @$_ : $_ } @lines;
        $self;
    }

    method render {
        return ( 'package("' . $_name . '")', @$lines, 'package_end()' );
    }
};
#
class Alien::Xmake::Project::Xpack v1.0.0 {
    field $_name : param : reader(name);
    field $_body : param  = [];
    field $lines : reader = [];
    field $components = [];
    #
    method _line           ( $name, @args ) { push @$lines, "    " . Alien::Xmake::Project::Util::_stmt( $name, @args );          $self; }
    method _hook           ( $name, @args ) { push @$lines, "    $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }
    method set_version     (@a)             { $self->_line( 'set_version',     @a ); }
    method set_homepage    (@a)             { $self->_line( 'set_homepage',    @a ); }
    method set_title       (@a)             { $self->_line( 'set_title',       @a ); }
    method set_author      (@a)             { $self->_line( 'set_author',      @a ); }
    method set_maintainer  (@a)             { $self->_line( 'set_maintainer',  @a ); }
    method set_description (@a)             { $self->_line( 'set_description', @a ); }
    method set_copyright   (@a)             { $self->_line( 'set_copyright',   @a ); }
    method set_company     (@a)             { $self->_line( 'set_company',     @a ); }
    method set_inputkind   (@a)             { $self->_line( 'set_inputkind',   @a ); }
    method set_formats     (@a)             { $self->_line( 'set_formats',     @a ); }
    method set_basename    (@a)             { $self->_line( 'set_basename',    @a ); }
    method set_extension   (@a)             { $self->_line( 'set_extension',   @a ); }
    method set_bindir      (@a)             { $self->_line( 'set_bindir',      @a ); }
    method set_libdir      (@a)             { $self->_line( 'set_libdir',      @a ); }
    method set_includedir  (@a)             { $self->_line( 'set_includedir',  @a ); }
    method set_prefixdir   (@a)             { $self->_line( 'set_prefixdir',   @a ); }
    method set_specfile    (@a)             { $self->_line( 'set_specfile',    @a ); }
    method set_specvar     (@a)             { $self->_line( 'set_specvar',     @a ); }
    method set_iconfile    (@a)             { $self->_line( 'set_iconfile',    @a ); }
    method set_license     (@a)             { $self->_line( 'set_license',     @a ); }
    method set_licensefile (@a)             { $self->_line( 'set_licensefile', @a ); }
    method set_nsis_displayicon(@a) { $self->_line( 'set_nsis_displayicon', @a ); }
    method add_sourcefiles  (@a) { $self->_line( 'add_sourcefiles',  @a ); }
    method add_installfiles (@a) { $self->_line( 'add_installfiles', @a ); }
    method add_targets      (@a) { $self->_line( 'add_targets',      @a ); }
    method add_components   (@a) { $self->_line( 'add_components',   @a ); }
    method add_buildrequires(@a) { $self->_line( 'add_buildrequires', @a ); }
    method on_load             (@a) { $self->_hook( 'on_load',             @a ); }
    method on_package          (@a) { $self->_hook( 'on_package',          @a ); }
    method before_package      (@a) { $self->_hook( 'before_package',      @a ); }
    method after_package       (@a) { $self->_hook( 'after_package',       @a ); }
    method before_buildcmd     (@a) { $self->_hook( 'before_buildcmd',     @a ); }
    method on_buildcmd         (@a) { $self->_hook( 'on_buildcmd',         @a ); }
    method after_buildcmd      (@a) { $self->_hook( 'after_buildcmd',      @a ); }
    method before_installcmd   (@a) { $self->_hook( 'before_installcmd',   @a ); }
    method on_installcmd       (@a) { $self->_hook( 'on_installcmd',       @a ); }
    method after_installcmd    (@a) { $self->_hook( 'after_installcmd',    @a ); }
    method before_uninstallcmd (@a) { $self->_hook( 'before_uninstallcmd', @a ); }
    method on_uninstallcmd     (@a) { $self->_hook( 'on_uninstallcmd',     @a ); }
    method after_uninstallcmd  (@a) { $self->_hook( 'after_uninstallcmd',  @a ); }

    method component ( $comp, @body ) {
        my $c = Alien::Xmake::Project::XpackComponent->new( _name => $comp, _body => \@body );
        push @$components, $c;
        return $c;
    }

    method render {
        my @out = ( 'xpack("' . $_name . '")', @$lines );
        for my $c (@$components) {
            push @out, @{ $c->render };
        }
        push @out, 'xpack_end()';
        return @out;
    }
};
#
class Alien::Xmake::Project::XpackComponent v1.0.0 {
    field $_name : param : reader(name);
    field $_body : param  = [];
    field $lines : reader = [];
    #
    method _line           ( $name, @args ) { push @$lines, "        " . Alien::Xmake::Project::Util::_stmt( $name, @args );          $self; }
    method _hook           ( $name, @args ) { push @$lines, "        $name(" . Alien::Xmake::Project::Util::_lua_script(@args) . ")"; $self; }
    method set_title       (@a)             { $self->_line( 'set_title',       @a ); }
    method set_description (@a)             { $self->_line( 'set_description', @a ); }
    method set_default     (@a)             { $self->_line( 'set_default',     @a ); }
    method add_sourcefiles (@a)             { $self->_line( 'add_sourcefiles', @a ); }
    method add_installfiles(@a) { $self->_line( 'add_installfiles', @a ); }
    method on_load             (@a) { $self->_hook( 'on_load',             @a ); }
    method before_installcmd   (@a) { $self->_hook( 'before_installcmd',   @a ); }
    method on_installcmd       (@a) { $self->_hook( 'on_installcmd',       @a ); }
    method after_installcmd    (@a) { $self->_hook( 'after_installcmd',    @a ); }
    method before_uninstallcmd (@a) { $self->_hook( 'before_uninstallcmd', @a ); }
    method on_uninstallcmd     (@a) { $self->_hook( 'on_uninstallcmd',     @a ); }
    method after_uninstallcmd  (@a) { $self->_hook( 'after_uninstallcmd',  @a ); }

    method lua (@lines) {
        push @$lines, map { ref($_) eq 'ARRAY' ? @$_ : $_ } @lines;
        $self;
    }

    method render {
        my @out = ( '    xpack_component("' . $_name . '")' );
        push @out, @$lines;
        push @out, '    xpack_component_end()';
        return \@out;
    }
};
#
1;
