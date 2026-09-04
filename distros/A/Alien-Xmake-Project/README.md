# NAME

Alien::Xmake::Project - Compose and drive an xmake project from Perl

# SYNOPSIS

```perl
use v5.40;
use Alien::Xmake::Project;

my $p = Alien::Xmake::Project->new( file => 'build/xmake.lua' );
$p->set_project('myapp')->set_version('0.1.0');
$p->add_requires('zlib');

$p->target('cli')
    ->set_kind('binary')
    ->add_files('src/*.cpp')
    ->add_packages('zlib');

$p->save;                                   # writes build/xmake.lua

$p->xmake->configure(mode => 'release');    # xmake configure -F build/xmake.lua
$p->xmake->build;
$p->xmake->run;
```

# DESCRIPTION

`xmake.lua` is just a Lua file. Rather than editing it by hand, this class lets you describe a project with fluent
Perl method calls and then hands you a normal [Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake) object. Using chains like `$p->set_kind('binary')->add_files('src/*.cpp')` you may drive every stage (configure, build, run, install, IDE
generation, queries) directly from Perl.

# CONSTRUCTOR

## `new( ... )`

```perl
my $p = Alien::Xmake::Project->new(
    file => 'build/xmake.lua',   # where save() writes the build file
    yes  => 1                    # auto-confirm prompts, forwarded to Alien::Xmake
);
```

- **file**

    Path of the generated build file (default `xmake.lua`). This becomes the `file =>` option of the [Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake)
    handle returned by `xmake`, so every action reads this file via `-F`.

- **yes**

    Boolean. Forwarded to ["new" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#new) so captured installs (e.g. `add_requires`) never hang on a prompt.

# METHODS

## Project level

### Identity

- `set_project( $name )`

    ```
    ...->set_project( 'libobseum' )
    ```

    Sets the project name at the top of the build file.

- `set_version( $version )`

    ```
    ...->set_version( '0.1.0' )
    ```

    Sets the project version string.

- `set_xmakever( $version )`

    ```
    ...->set_xmakever( '2.9.1' )
    ```

    Sets the minimum xmake version required to build the project.

### Global options and defaults

- `set_config( $name, $value )`

    ```
    ...->set_config( 'plat', 'windows' )
    ```

    Sets a global configuration item that applies to the whole project.

- `set_defaultplat( @plats )`

    ```
    ...->set_defaultplat( 'windows' )
    ```

    Sets the default platform used when none is given on the command line.

- `set_defaultarchs( @archs )`

    ```
    ...->set_defaultarchs( 'x86_64' )
    ```

    Sets the default architectures used when none are given.

- `set_defaultmode( @modes )`

    ```
    ...->set_defaultmode( 'release' )
    ```

    Sets the default build mode(s) used when none are given.

- `set_allowedplats( @plats )`

    ```
    ...->set_allowedplats( 'windows', 'linux', 'macosx' )
    ```

    Whitelists the platforms the project may be built for.

- `set_allowedarchs( @archs )`

    ```
    ...->set_allowedarchs( 'x86', 'x86_64' )
    ```

    Whitelists the architectures the project may be built for.

- `set_allowedmodes( @modes )`

    ```
    ...->set_allowedmodes( 'debug', 'release' )
    ```

    Whitelists the build modes the project supports.

- `set_runtimes( @runtimes )`

    ```
    ...->set_runtimes( 'MT', 'MD' )
    ```

    Sets the runtime flavour(s), e.g. `MT`/`MD` on MSVC.

### Global scope (applies to every target)

- `set_toolchains( @names )`

    ```
    ...->set_toolchains( 'clang' )
    ```

    Declares the toolchain(s) to use project-wide.

- `set_toolset( %pairs )`

    ```perl
    ...->set_toolset( cc => 'gcc', cxx => 'g++' )
    ```

    Sets the tool programs used by the toolchain, as a table of `name => program` pairs.

- `set_plat( $plat )`

    ```
    ...->set_plat( 'windows' )
    ```

    Pins the target platform for the whole project.

- `set_arch( $arch )`

    ```
    ...->set_arch( 'x86_64' )
    ```

    Pins the target architecture for the whole project.

- `set_languages( @langs )`

    ```
    ...->set_languages( 'c99', 'cxx11' )
    ```

    Sets the language standards for every target.

### Structure

- `add_moduledirs( @dirs )`

    ```
    ...->add_moduledirs( 'modules' )
    ```

    Adds extra module search directories.

- `add_plugindirs( @dirs )`

    ```
    ...->add_plugindirs( 'plugins' )
    ```

    Adds extra plugin search directories.

- `includes( @files )`

    ```
    ...->includes( 'build/config.lua' )
    ```

    Includes other build files.

- `add_rules( @rules )`

    ```
    ...->add_rules( 'mode.debug', 'mode.release' )
    ```

    Adds rule names to the whole project.

- `add_addons( @addons )`

    ```
    ...->add_addons( 'tools.xmake' )
    ```

    Enables addons.

### Packages and repositories

- `add_requires( @packages )`

    ```perl
    ...->add_requires( 'zlib', { system => true } )
    ```

    Adds project-wide package requirements. A trailing hashref becomes an options table; version strings pass through
    verbatim, and booleans must be real `true`/`false` (xmake expects `true`, not `1`).

- `add_requireconfs( @configs )`

    ```perl
    ...->add_requireconfs( 'zlib', { configs => { shared => true } } )
    ```

    Overrides requirement configs. Accepts a trailing options hashref.

- `add_repositories( @repos )`

    ```
    ...->add_repositories( 'myrepo', 'https://github.com/user/repo' )
    ```

    Registers package repositories. Accepts a trailing options hashref.

### Domain builders

- `target( $name )`

    ```
    ...->target( 'app' )
    ```

    Begins a `target(...)` block and returns a ["Target builder"](#target-builder).

- `option( $name )`

    ```
    ...->option( 'with_foo' )
    ```

    Begins a `option(...)` block and returns the ["Option builder"](#option-builder). Passing a trailing hashref instead emits the inline
    table form.

- `rule( $name )`

    ```
    ...->rule( 'markdown' )
    ```

    Begins a `rule(...)` block and returns the ["Rule builder"](#rule-builder).

- `toolchain( $name )`

    ```
    ...->toolchain( 'mycc' )
    ```

    Begins a `toolchain(...)` block and returns the ["Toolchain builder"](#toolchain-builder).

- `package( $name )`

    ```go
    ...->package( 'zlib' )
    ```

    Begins a `package(...)` block and returns the ["Package builder"](#package-builder).

- `xpack( $name )`

    ```
    ...->xpack( 'myapp' )
    ```

    Begins an `xpack(...)` block and returns the ["Xpack builder"](#xpack-builder). The first call also emits
    `includes("@builtin/xpack")` so the xpack plugin is enabled.

- `namespace( $name, @lines )`

    ```
    ...->namespace( 'core', 'add_rules("xmake.lua.lint")' )
    ```

    Begins a `namespace(...)` block. Items may be raw Lua line strings or CODE refs called with the project so they can
    emit lines (`sub { $project->... }` returning the statement text or lines).

### Emission and execution

- `save`

    ```
    ...->save
    ```

    Writes the accumulated description to `file`. Returns the project.

- `xmake`

    ```
    ...->xmake
    ```

    Returns an [Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake) handle whose every action reads this project's build file (constructed once, cached).

- `configure( %options )`

    ```perl
    ...->configure( mode => 'release' )
    ```

    Configures the project via ["configure" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#configure), auto-saving `file` if not yet written.

- `build( [$target], %options )`

    ```
    ...->build
    ```

    Builds the project (or a specific target) via ["build" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#build), auto-saving `file` if not yet written.

- `run( [$target], %options )`

    ```
    ...->run( 'app' )
    ```

    Runs the target via ["run" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#run).

- `clean( [$target], %options )`

    ```
    ...->clean
    ```

    Cleans target binaries and build directories via ["clean" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#clean).

- `install( [$target], %options )`

    ```
    ...->install
    ```

    Installs the built artifacts via ["install" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#install).

- `pack( [$name], %options )`

    ```
    ...->pack
    ```

    Packs installation archives via ["pack" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#pack), auto-saving `file` if not yet written.

- `project( [$kind], %options )`

    ```perl
    ...->project( 'compile_commands' )
    ...->project( kind => 'vsxmake', modes => 'release' )
    ```

    Generates project files (e.g. `compile_commands`, `vsxmake`, `xcode`, `cmake`, `make`) via
    ["project" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#project). Auto-saves `file` if not yet written.

- `target_info( $name, %options )`

    ```
    ...->target_info( 'app' )
    ```

    Returns rich target metadata parsed from `xmake show -t <name` --format=json> via ["target\_info" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#target_info).

- `show( [$list], %options )`

    ```perl
    ...->show
    ...->show( 'targets' )                          # list target names
    ...->show( 'platforms' )                        # list supported platforms
    ...->show( 'toolchains' )                       # list available toolchains
    ...->show( 'packages' )
    ...->show( 'options' )
    ...->show( 'lua', 'deps' )                      # show graph info for a config
    ...->show( targets => { group => 'Library' } )  # targets in a group
    ...->show( platforms => { pretty => 1 } )       # pretty-printed tree
    ...->show( targets => { format => 'json' } )    # JSON (parsed to a structure)
    ...->show( 'configs' )
    ...->show( 'arch' )                             # target architecture
    ...->show( 'plat' )
    ...->show( 'mode' )
    ...->show( 'host' )
    ```

    Runs `xmake show` queries via ["show" in Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake#show) and returns the parsed results (a list of lines, a list of names
    for list queries, or a decoded structure when `format => 'json'`).

## Target builder

Each method is chainable and corresponds to the same-named `xmake.lua` statement inside a `target(...)` block. A
trailing hashref is emitted as an options table; `true`/`false` emit bare Lua booleans.

- `set_kind( $kind )`

    ```
    ...->set_kind( 'binary' )
    ```

    Sets the kind of target: `binary` (executable), `static`, `shared`, `object`, `headeronly`, `phony`.

    - **naming and output**
        - `set_basename( $name )`

            ```
            ...->set_basename( 'myapp' )
            ```

            Overrides the base (file) name of the generated target.

        - `set_filename( $name )`

            ```
            ...->set_filename( 'myapp.exe' )
            ```

            Overrides the full file name of the generated binary/library, including extension if desired.

        - `set_prefixname( $name )`

            ```
            ...->set_prefixname( 'lib' )   # static lib -> libfoo.a
            ```

            Sets the prefix prepended to the target output file name.

        - `set_suffixname( $name )`

            ```
            ...->set_suffixname( 'd' )     # myapp -> myappd
            ```

            Sets the suffix appended to the target output file name.

        - `set_extension( $ext )`

            ```
            ...->set_extension( '.exe' )
            ```

            Sets the output file extension; calling with no argument clears a toolchain default.

        - `set_strip( $level )`

            ```
            ...->set_strip( 'all' )
            ```

            Sets the strip mode applied at link time: `debug` (strip debug symbols only), `all` (strip all symbols), `none`.
            Combined with `set_symbols('debug')`, a separate debug-symbol file (dSYM/pdb/.sym) is also generated.

        - `set_group( $group )`

            ```
            ...->set_group( 'Library' )
            ```

            Assigns the target to a project group, used by IDE generators to nest targets in folders.

        - `set_objectdir( $dir )`

            ```
            ...->set_objectdir( '$(builddir)/.objs' )
            ```

            Sets the directory for intermediate object files.

        - `set_dependir( $dir )`

            ```
            ...->set_dependir( '$(builddir)/.deps' )
            ```

            Sets the directory for compile dependency (`.deps`) files.

        - `set_installdir( $dir )`

            ```
            ...->set_installdir( '$(buildir)/lib' )
            ```

            Sets the directory into which the target's install files are placed on `install`.

        - `set_prefixdir( $dir )`

            ```
            ...->set_prefixdir( 'usr/local' )
            ```

            Sets the directory to strip as a prefix when installing relative paths.
    - **enablement and options**
        - `set_default( $bool )`

            ```
            ...->set_default( false )
            ```

            Sets whether the target is built by default. Pass a real `false` to opt out.

        - `set_enabled( $bool )`

            ```
            ...->set_enabled( true )
            ```

            Sets whether the target is enabled at all; a disabled target is not built or used.

        - `set_options( @opts )`

            ```
            ...->set_options( 'with_foo' )
            ```

            Makes the target depend on the named project `option(...)` values.

        - `add_options( @opts )`

            ```
            ...->add_options( 'with_bar' )
            ```

            Adds additional `option(...)` requirement(s) to the target.
    - **compile model**
        - `set_warnings( $level )`

            ```
            ...->set_warnings( 'all' )
            ```

            Sets the compiler warning level; xmake maps the abstract level to the right flag per compiler. Available levels:
            `none`, `less`, `more`, `extra`, `pedantic`, `all`, `allextra`, `everything`, `error`.

        - `set_optimize( $level )`

            ```
            ...->set_optimize( 'fastest' )
            ```

            Sets the compile optimization level; each level maps to the appropriate flag for the target compiler. Available levels:
            `none`, `fast`, `faster`, `fastest`, `smallest`, `aggressive`.

        - `set_symbols( $level )`

            ```
            ...->set_symbols( 'debug' )
            ...->set_symbols( 'debug', 'hidden' )
            ```

            Sets the debug-symbol mode. Levels may be combined: `none`, `debug`, `hidden`, plus the msvc-only refinements
            `edit` and `embed`.

        - `set_fpmodels( @models )`

            ```
            ...->set_fpmodels( 'fast', 'except' )
            ```

            Sets the floating-point compilation mode: `fast`, `strict`, `except`, `noexcept`, `precise` (the default). Models
            may be combined, but `fast` conflicts with `precise`/`strict`.

        - `set_exceptions( @modes )`

            ```
            ...->set_exceptions( 'cxx' )
            ```

            Enables or disables C++ / Objective-C exceptions: `cxx`, `no-cxx`, `objc`, `no-objc`. xmake picks the
            compiler-specific flag.

        - `set_encodings( @encodings )`

            ```
            ...->set_encodings( 'utf-8' )
            ...->set_encodings( 'source:utf-8', 'target:gb2312' )
            ```

            Sets the source and/or target executable encoding. A bare encoding applies to both; prefix with `source:` or
            `target:` for one side.

        - `set_policy( $name, $value )`

            ```
            ...->set_policy( 'build.warning', true )
            ```

            Sets a build policy for this target. See the xmake builtin-policies reference for the full list.

        - `set_pcheader( $header )`

            ```
            ...->set_pcheader( 'common.h' )
            ```

            Sets the C precompiled header.

        - `set_pcxxheader( $header )`

            ```
            ...->set_pcxxheader( 'common.hpp' )
            ```

            Sets the C++ precompiled header.

        - `set_pmheader( $header )`

            ```
            ...->set_pmheader( 'common.h' )
            ```

            Sets the Objective-C precompiled header.

        - `set_pmxxheader( $header )`

            ```
            ...->set_pmxxheader( 'common.hh' )
            ```

            Sets the Objective-C++ precompiled header.

        - `set_runtimes( @runtimes )`

            ```
            ...->set_runtimes( 'MD' )
            ```

            Sets the runtime library flavour(s). On MSVC this selects the C runtime: `MT`, `MTd`, `MD`, `MDd`; on Android/iOS
            it selects the C++ STL implementation: `c++_static`, `c++_shared`.

        - `set_languages( @langs )`

            ```
            ...->set_languages( 'c99', 'cxx11' )
            ```

            Sets the language standard(s). Standard C values: `ansi`, `c89`, `gnu89`, `c90`, `gnu90`, `c99`, `gnu99`,
            `c11`, `gnu11`, `c17`, `gnu17`, ..., `clatest`. C++ values use the `cxxN` form (`cxx98`, `cxx11`, `cxx14`,
            `cxx17`, `cxx20`, `cxx23`, ..., `cxxlatest`) or the `C++N` spelling. A C and a C++ standard may be set together.

        - `add_forceincludes( @files )`

            ```
            ...->add_forceincludes( 'config.h' )
            ```

            Force-includes the given header files in every translation unit.

        - `add_vectorexts( @exts )`

            ```
            ...->add_vectorexts( 'sse2', 'avx' )
            ```

            Enables the given vector extensions.
    - **content and deps**

        Otherwise-identical statements grouped by shared semantics; each is chainable.

        - `add_files( @patterns )`

            ```
            ...->add_files( 'src/*.cpp' )
            ```

            Adds source files or glob patterns to compile.

        - `remove_files( @patterns )`

            ```
            ...->remove_files( 'src/old.cpp' )
            ```

            Removes source files/patterns previously added.

        - `remove_headerfiles( @files )`

            ```
            ...->remove_headerfiles( 'src/old.h' )
            ```

            Removes header files from the header set.

        - `add_defines( @defines )`

            ```
            ...->add_defines( 'NDEBUG' )
            ```

            Adds preprocessor macro definitions.

        - `add_undefines( @defines )`

            ```
            ...->add_undefines( 'DEBUG' )
            ```

            Undefines macros.

        - `add_includedirs( @dirs )`

            ```
            ...->add_includedirs( 'include' )
            ```

            Adds C header search directories.

        - `add_sysincludedirs( @dirs )`

            ```
            ...->add_sysincludedirs( '/usr/include' )
            ```

            Adds system header search directories.

        - `add_embeddirs( @dirs )`

            ```
            ...->add_embeddirs( 'assets' )
            ```

            Adds directories whose files are embedded into the target.

        - `add_links( @libs )`

            ```
            ...->add_links( 'm', 'dl' )
            ```

            Adds libraries to link against.

        - `add_syslinks( @libs )`

            ```
            ...->add_syslinks( 'pthread' )
            ```

            Adds system libraries to link against.

        - `add_linkorders( @orders )`

            ```
            ...->add_linkorders( 'liba.a', 'libb.a' )
            ```

            Forces link ordering across whole libs.

        - `add_linkgroups( @groups )`

            ```
            ...->add_linkgroups( 'pthread', 'm' )
            ```

            Wraps the named links in linker group flags, e.g. `--start-group`/`--end-group`.

        - `add_linkdirs( @dirs )`

            ```
            ...->add_linkdirs( 'lib' )
            ```

            Adds library search directories.

        - `add_rpathdirs( @dirs )`

            ```
            ...->add_rpathdirs( '$ORIGIN' )
            ```

            Adds runtime library search directories.

        - `add_deps( @targets )`

            ```
            ...->add_deps( 'core' )
            ```

            Declares dependencies on other targets.

        - `add_rules( @rules )`

            ```
            ...->add_rules( 'qt.static' )
            ```

            Attaches rule name(s) to this target.

        - `add_packages( @packages )`

            ```
            ...->add_packages( 'zlib' )
            ```

            Links against the given packages from `add_requires`.

        - `add_requires( @packages )`

            ```
            ...->add_requires( 'zlib' )
            ```

            Requires packages that are then linked into this target.

        - `add_headerfiles( @files )`

            ```
            ...->add_headerfiles( 'src/*.h' )
            ```

            Adds header files to install with the target.

        - `add_installfiles( @files )`

            ```
            ...->add_installfiles( 'src/readme.txt' )
            ```

            Adds extra files to install with the target.

        - `add_extrafiles( @files )`

            ```
            ...->add_extrafiles( 'src/license.txt' )
            ```

            Adds files that should be listed/installed but not compiled.

        - `add_imports( @mods )`

            ```
            ...->add_imports( 'core.base.task' )
            ```

            Imports xmake modules for use in the target's Lua hooks.

        - `add_languages( @langs )`

            ```
            ...->add_languages( 'cxx17' )
            ```

            Adds extra language standard(s) without replacing existing ones.

        - `add_frameworks( @frameworks )`

            ```
            ...->add_frameworks( 'Foundation' )
            ```

            Adds system frameworks to link (macOS/iOS).

        - `add_frameworkdirs( @dirs )`

            ```
            ...->add_frameworkdirs( '/System/Library/Frameworks' )
            ```

            Adds framework search directories.

        - `add_values( $key, @values )`

            ```
            ...->add_values( 'wasm.preloadfiles', 'src/assets/app.js' )
            ```

            Sets a target-specific key/value pair, e.g. the wasm preload files.

        - `set_values( %pairs )`

            ```perl
            ...->set_values( 'wasm.preloadfiles' => [ 'src/assets/app.js' ] )
            ```

            Replaces all values for a set of target-specific keys from a hashref.

    - **runtime / run**
        - `set_targetdir( $dir )`

            ```perl
            ...->set_targetdir( '$(builddir)/out', { bindir => 'bin', libdir => 'lib' } )
            ```

            Sets the output directory for the target's files. By default output goes to `build`; when set, this directory is
            preferred. Subdirectories such as `bindir`/`libdir` may be configured via a trailing table.

        - `set_rundir( $dir )`

            ```
            ...->set_rundir( 'tests' )
            ```

            Sets the working directory used when the target runs.

        - `set_runargs( @args )`

            ```
            ...->set_runargs( '--verbose' )
            ```

            Sets default arguments passed to the target when it runs.

        - `set_runenv( $name, $value )`

            ```
            ...->set_runenv( 'HOME', '/tmp' )
            ```

            Sets a single environment variable for the running target.

        - `add_runenvs( %pairs )`

            ```perl
            ...->add_runenvs( LD_LIBRARY_PATH => 'lib' )
            ```

            Adds environment variables for the running target from a hashref.

        - `add_tests( $name, @cmds )`

            ```
            ...->add_tests( 'unit', 'test.exe' )
            ```

            Registers a runnable test that `xmake test` can invoke.
    - **toolchain / plat / arch**
        - `set_plat( $plat )`

            ```
            ...->set_plat( 'windows' )
            ```

            Pins this target to a specific platform.

        - `set_arch( $arch )`

            ```
            ...->set_arch( 'x86_64' )
            ```

            Pins this target to a specific architecture.

        - `set_toolchains( @names )`

            ```
            ...->set_toolchains( 'clang' )
            ```

            Sets the toolchain(s) used to build this target.

        - `set_toolset( %pairs )`

            ```perl
            ...->set_toolset( cc => 'gcc', cxx => 'g++' )
            ```

            Sets the tool programs used by the toolchain, as a table of `name => program` pairs.
    - **flags**

        Compile and link flags carry their compiler prefix so one method covers each family: `add_cflags` `add_cxflags`
        `add_cxxflags` `add_mflags` `add_mxflags` `add_mxxflags` `add_scflags` `add_asflags` `add_gcflags`
        `add_dcflags` `add_rcflags` `add_fcflags` `add_zcflags` `add_cuflags` `add_culdflags` `add_cugencodes`
        `add_ascnpuarchs` `add_ldflags` `add_arflags` `add_shflags`.

    - **config-file generation**
        - `add_configfiles( @files )`

            ```perl
            ...->add_configfiles( 'config.h.in', { filename => 'config.h' } )
            ```

            Generates a config file from a `.in` template.

        - `set_configvar( $name, $value )`

            ```
            ...->set_configvar( 'HAVE_X', '1' )
            ```

            Sets a config variable substituted into generated config files.

        - `set_configdir( $dir )`

            ```
            ...->set_configdir( '$(projectdir)/config' )
            ```

            Sets the directory into which generated config files are written.
    - **compile-time feature detection**

        The full `@builtin/check` helper family is wired in. The first call emits `includes("@builtin/check")` at the project
        root exactly once. Each helper renders `def, arg` and passes list-style arguments (links, headers, types) as a single
        Lua list rather than flattening them; a trailing hashref becomes the options table. Both the plain `check_*` (defines
        the macro) and `configvar_check_*` (writes `set_configvar` into the generated config) forms are provided across
        `links` `syslinks` `ctypes` `cxxtypes` `cfuncs` `cxxfuncs` `cincludes` `cxxincludes` `csnippets`
        `cxxsnippets` `features` `macros` `sizeof` `alignof` `bigendian` `cflags` `cxxflags`:

        ```perl
          ...->add_configfiles( 'config.h.in', { filename => 'config.h' } )
          ...->configvar_check_links( 'HAS_PTHREAD', [ 'pthread', 'm', 'dl' ] )
          ...->configvar_check_ctypes( 'HAS_WCHAR', 'wchar_t' )

        with C<config.h.in>:

          ${define HAS_PTHREAD}
          ${define HAS_WCHAR}
        ```

    - **scoped conditions (when)**

        `when( $condition, $body )` wraps a group of statements in a Lua `if/then/end` block so they only apply when a
        compile-time predicate holds (`is_plat` `is_os` `is_arch` `is_host` `is_mode` `is_kind` `is_config`
        `has_config` `has_package`, or any Lua expression, including negations like `not is_plat("windows")`). `$body` is a
        code ref whose `-`>...>> chained calls back into the same builder, an arrayref of raw Lua lines, or a single raw
        Lua line string. Inner statements are indented one level and `end` closes the block:

        ```perl
          ...->when( 'is_plat("windows", "linux")', sub {
              ...->add_links( 'pthread', 'm', 'dl' );
          } )
          ...->when( 'is_arch("arm.*")', 'add_defines("ARM")' )

        emits:

          if is_plat("windows", "linux") then
              add_links("pthread", "m", "dl")
          end
          if is_arch("arm.*") then
              add_defines("ARM")
          end
        ```

        `when` is also available at the project (root/global) scope to guard `add_rules`/`add_requires`/`includes` and any
        root statement.

    - **raw hooks and escape hatch**

        Hooks take raw Lua function bodies: `on_load` `on_config` `on_build` `on_build_file` `before_build` `after_build`
        `on_link` `on_clean` `on_install` `on_uninstall` `on_run`. Strings that begin with `function` are emitted
        unquoted; other strings are quoted and joined as arguments:

        ```js
        ...->on_build( 'function (target) print(target:name()) end' )
        ...->on_install( 'windows', 'function (target) end' )
        ```

        `lua( @lines )` pushes raw Lua lines straight into the target body (escape hatch).

## Option builder

An `option(...)` block describes a configurable build option. Every method is chainable. A trailing hashref becomes an
options table; `true`/`false` emit bare Lua booleans. Note that an option created with the inline table form (`option('name', { ... })`) cannot be extended with these setters.

- `set_default( $value )`

    ```
    ...->set_default( true )
    ```

    Sets the option's default value.

- `set_values( @vals )`

    ```
    ...->set_values( 'debug', 'release' )
    ```

    Sets the list of allowed values for the option.

- `set_showmenu( $bool )`

    ```
    ...->set_showmenu( true )
    ```

    Sets whether to show the option in the `xmake f --help` menu.

- `set_category( $category )`

    ```
    ...->set_category( 'Features' )
    ```

    Groups the option under a category in the menu.

- `set_description( $text )`

    ```
    ...->set_description( 'Enable the foo feature' )
    ```

    Sets a human-readable description shown in the menu.

- `add_deps( @opts )`

    ```
    ...->add_deps( 'with_toolchain' )
    ```

    Requires the named other options to be resolved first.

- `add_links( @libs )`

    ```
    ...->add_links( 'm', 'dl' )
    ```

    Adds libraries the option links when enabled.

- `add_linkdirs( @dirs )`

    ```
    ...->add_linkdirs( 'lib' )
    ```

    Adds library search directories for the option.

- `add_rpathdirs( @dirs )`

    ```
    ...->add_rpathdirs( '$ORIGIN' )
    ```

    Adds runtime library search directories for the option.

- `add_cincludes( @headers )`

    ```
    ...->add_cincludes( 'math.h' )
    ```

    Probes for the presence of the given C headers.

- `add_cxxincludes( @headers )`

    ```
    ...->add_cxxincludes( 'vector' )
    ```

    Probes for the presence of the given C++ headers.

- `add_ctypes( @types )`

    ```
    ...->add_ctypes( 'wchar_t' )
    ```

    Probes for the presence of the given C types.

- `add_cxxtypes( @types )`

    ```
    ...->add_cxxtypes( 'std::string' )
    ```

    Probes for the presence of the given C++ types.

- `add_csnippets( @code )`

    ```
    ...->add_csnippets( 'int main() { return 0; }' )
    ```

    Probes C code snippets for successful compilation.

- `add_cxxsnippets( @code )`

    ```
    ...->add_cxxsnippets( 'int main() { return 0; }' )
    ```

    Probes C++ code snippets for successful compilation.

- `add_cfuncs( @funcs )`

    ```
    ...->add_cfuncs( 'pow' )
    ```

    Probes for the presence of the given C functions.

- `add_cxxfuncs( @funcs )`

    ```
    ...->add_cxxfuncs( 'std::swap' )
    ```

    Probes for the presence of the given C++ functions.

- `add_defines( @defines )`

    ```
    ...->add_defines( 'HAVE_FOO' )
    ```

    Adds macros defined when the option is enabled.

- `add_cxflags( @flags )`

    ```
    ...->add_cxflags( '-DFOO' )
    ```

    Adds C/C++ flags applied when the option is enabled.

- `before_check( $body )` `on_check( $body )` `after_check( $body )`

    ```js
    ...->on_check( 'function (option) return false end' )
    ```

    Injects raw-Lua hooks around the option's compile-time check.

## Rule builder

A `rule(...)` block describes a custom build rule. Every method is chainable.

- `set_extensions( @exts )`

    ```
    ...->set_extensions( '.c', '.cpp' )
    ```

    Sets the file extensions this rule handles.

- `add_deps( @rules )`

    ```
    ...->add_deps( 'lex' )
    ```

    Makes this rule depend on other rules.

- `add_imports( @mods )`

    ```
    ...->add_imports( 'core.base.task' )
    ```

    Imports xmake modules for use in the rule's Lua hooks.

- `on_load( $body )` `on_config( $body )` `on_link( $body )` `on_build( $body )` `on_build_file( $body )`
`on_build_files( $body )` `on_clean( $body )` `on_package( $body )` `on_install( $body )` `on_uninstall( $body )`

    ```js
    ...->on_build( 'function (target) print(target:name()) end' )
    ```

    Injects raw-Lua hooks (each takes raw Lua function bodies). `lua( @lines )` pushes raw Lua lines straight into the
    rule body.

## Toolchain builder

A `toolchain(...)` block describes a custom toolchain. Every method is chainable.

- `set_kind( $kind )`

    ```
    ...->set_kind( 'standalone' )
    ```

    Sets the toolchain kind, e.g. `standalone`.

- `set_sdkdir( $dir )`

    ```
    ...->set_sdkdir( '/opt/toolchain' )
    ```

    Sets the SDK root directory for the toolchain.

- `set_bindir( $dir )`

    ```
    ...->set_bindir( '/opt/toolchain/bin' )
    ```

    Sets the directory containing the toolchain's executables.

- `set_toolset( %pairs )`

    ```perl
    ...->set_toolset( cc => 'gcc', cxx => 'g++' )
    ```

    Sets this toolchain's tool programs as a table of `name => program` pairs.

- `add_defines( @defines )`

    ```
    ...->add_defines( 'FOO' )
    ```

    Adds preprocessor defines for the toolchain.

- `on_load( $body )` `on_check( $body )`

    ```js
    ...->on_load( 'function (toolchain) end' )
    ```

    Injects raw-Lua hooks (each takes raw Lua function bodies).

## Package builder

A `package(...)` block describes how a dependency package is fetched and installed. Every method is chainable; a
trailing hashref becomes an options table; `true`/`false` emit bare Lua booleans.

- `set_homepage( $url )`

    ```
    ...->set_homepage( 'https://example.com' )
    ```

    Sets the package homepage URL.

- `set_description( $text )`

    ```
    ...->set_description( 'A useful library' )
    ```

    Sets a short description of the package.

- `set_license( $license )`

    ```
    ...->set_license( 'MIT' )
    ```

    Sets the package license identifier.

- `set_kind( $kind )`

    ```
    ...->set_kind( 'library' )
    ```

    Sets the package kind: `library` (default), `binary`, or `headeronly`.

- `set_urls( @urls )`

    ```
    ...->set_urls( 'https://example.com/libfoo/v$(version).tar.gz' )
    ```

    Sets the official download URL(s) for the package.

- `add_urls( @urls )`

    ```
    ...->add_urls( 'https://mirror.example.com/libfoo.tar.gz' )
    ```

    Adds mirror download URL(s), tried in order until one works.

- `add_versions( @vers )`

    ```perl
    ...->add_versions( '1.0.0', { hash => 'sha256:<hexdigest>' } )
    ```

    Registers known versions of the package, each with an integrity hash.

- `add_versionfiles( @files )`

    ```perl
    ...->add_versionfiles( '1.0.0' => 'patch.tar.gz' )
    ```

    Adds version-specific file mappings.

- `set_sourcedir( $dir )`

    ```
    ...->set_sourcedir( 'src' )
    ```

    Uses a local source directory instead of downloading.

- `add_patches( @patches )`

    ```
    ...->add_patches( '1.0.0', 'patch.diff' )
    ```

    Adds patches to apply after unpacking.

- `add_links( @libs )`

    ```
    ...->add_links( 'foo' )
    ```

    Adds libraries this package provides.

- `add_syslinks( @libs )`

    ```
    ...->add_syslinks( 'pthread' )
    ```

    Adds system libraries this package links.

- `add_includedirs( @dirs )`

    ```
    ...->add_includedirs( 'include' )
    ```

    Adds include directories this package adds.

- `add_bindirs( @dirs )`

    ```
    ...->add_bindirs( 'bin' )
    ```

    Adds binary directories this package adds.

- `add_defines( @defines )`

    ```
    ...->add_defines( 'HAVE_FOO' )
    ```

    Adds defines this package adds to its consumers.

- `add_frameworks( @frameworks )`

    ```
    ...->add_frameworks( 'Foundation' )
    ```

    Adds system frameworks this package links (macOS/iOS).

- `add_linkdirs( @dirs )`

    ```
    ...->add_linkdirs( 'lib' )
    ```

    Adds library search directories this package adds.

- `add_linkorders( @orders )`

    ```
    ...->add_linkorders( 'liba.a' )
    ```

    Adds link ordering across whole libs for this package.

- `add_linkgroups( @groups )`

    ```
    ...->add_linkgroups( 'pthread', 'm' )
    ```

    Adds linker group flags for this package's links.

- `add_configs( @configs )`

    ```
    ...->add_configs( 'shared', true )
    ...->add_configs( 'shared', false, 'icu', true )
    ```

    Sets default package configurations as alternating `name, value` pairs.

- `add_extsources( @sources )`

    ```
    ...->add_extsources( 'ext/*.c' )
    ```

    Adds extra source files/objects to add when built from source.

- `add_deps( @pkgs )`

    ```
    ...->add_deps( 'zlib' )
    ```

    Declares dependencies on other packages.

- `add_components( @comps )`

    ```
    ...->add_components( 'core', 'io' )
    ```

    Declares components of this package.

- `set_base( $rule )`

    ```
    ...->set_base( 'github' )
    ```

    Bases this package on an existing package or rule.

- `add_schemes( %schemes )`

    ```perl
    ...->add_schemes( configs => { shared => true } )
    ```

    Sets scheme overrides that push configs onto consumers of this package.

- `on_load( $body )` `on_fetch( $body )` `on_check( $body )` `on_install( $body )` `on_download( $body )`
`on_test( $body )` `on_component( $body )`

    ```go
    ...->on_install( 'function (package) end' )
    ```

    Injects raw-Lua hooks (each takes raw Lua function bodies). `lua( @lines )` pushes raw Lua lines straight into the
    package body.

## Xpack builder

An `xpack(...)` block describes a distributable installer package. The first `xpack` call also emits
`includes("@builtin/xpack")` to enable the plugin. Every method is chainable; a trailing hashref becomes an options
table; `true`/`false` emit bare Lua booleans.

- `set_version( $version )`

    ```
    ...->set_version( '1.0.0' )
    ```

    Sets the package version string.

- `set_homepage( $url )`

    ```
    ...->set_homepage( 'https://example.com' )
    ```

    Sets the package homepage URL.

- `set_title( $title )`

    ```
    ...->set_title( 'MyApp' )
    ```

    Sets the display title of the installer.

- `set_author( $author )`

    ```
    ...->set_author( 'Jane Doe' )
    ```

    Sets the author name.

- `set_maintainer( $maintainer )`

    ```
    ...->set_maintainer( 'Jane Doe' )
    ```

    Sets the maintainer name.

- `set_description( $text )`

    ```
    ...->set_description( 'Cross-platform app' )
    ```

    Sets a short description shown in the installer.

- `set_copyright( $notice )`

    ```
    ...->set_copyright( '2026 Jane Doe' )
    ```

    Sets the copyright notice for the installer.

- `set_company( $company )`

    ```
    ...->set_company( 'Acme Inc.' )
    ```

    Sets the company/organization name.

- `set_inputkind( $kind )`

    ```
    ...->set_inputkind( 'binary' )
    ```

    Identifies the packaged input source type: `binary` or `source`. Optional - built-in formats usually determine this
    from the format name, but it is needed for custom formats (e.g. to distinguish a binary `deb` from a source `deb`).

- `set_formats( @formats )`

    ```
    ...->set_formats( 'nsis', 'zip', 'targz' )
    ```

    Configures the packaging format(s) to generate; `xmake pack` produces all of them at once. Supported formats: `nsis`
    (Windows NSIS installer), `wix`, `zip`, `targz`, `srczip`, `srctargz`, `runself`, `rpm`, `srpm`, `deb`,
    `dmg`, `appimage`, plus custom formats.

- `set_basename( $name )`

    ```
    ...->set_basename( 'myapp-setup' )
    ```

    Sets the base file name of the generated installer.

- `set_extension( $ext )`

    ```
    ...->set_extension( '.exe' )
    ```

    Sets the file extension of the generated installer.

- `set_bindir( $dir )`

    ```
    ...->set_bindir( 'bin' )
    ```

    Sets the directory whose contents become the payload's `bin`.

- `set_libdir( $dir )`

    ```
    ...->set_libdir( 'lib' )
    ```

    Sets the directory whose contents become the payload's `lib`.

- `set_includedir( $dir )`

    ```
    ...->set_includedir( 'include' )
    ```

    Sets the directory whose contents become the payload's `include`.

- `set_prefixdir( $dir )`

    ```
    ...->set_prefixdir( 'usr/local' )
    ```

    Sets the install prefix inside the payload.

- `set_specfile( $spec )`

    ```
    ...->set_specfile( 'packaging/foo.spec' )
    ```

    Sets the path to a packaging spec file.

- `set_specvar( $name, $value )`

    ```
    ...->set_specvar( 'VERSION', '$(version)' )
    ```

    Sets a variable substituted into the spec file.

- `set_iconfile( $file )`

    ```
    ...->set_iconfile( 'assets/icon.ico' )
    ```

    Sets the icon file for the installer.

- `set_license( $license )`

    ```
    ...->set_license( 'MIT' )
    ```

    Sets the license text or identifier.

- `set_licensefile( $file )`

    ```
    ...->set_licensefile( 'LICENSE' )
    ```

    Sets the path to a license file bundled with the installer.

- `set_nsis_displayicon( $bool )`

    ```
    ...->set_nsis_displayicon( true )
    ```

    Sets whether to show the icon in the NSIS installer.

- `add_sourcefiles( @files )`

    ```
    ...->add_sourcefiles( 'src/*.c' )
    ```

    Adds source files to package.

- `add_installfiles( @files )`

    ```
    ...->add_installfiles( 'README.md' )
    ```

    Adds extra install files to package.

- `add_targets( @targets )`

    ```
    ...->add_targets( 'myapp' )
    ```

    Includes the named build targets' outputs in the package.

- `add_components( @comps )`

    ```
    ...->add_components( 'core' )
    ```

    Includes prebuilt components in the package.

- `add_buildrequires( @pkgs )`

    ```
    ...->add_buildrequires( 'nsis' )
    ```

    Adds packages required to build the installer.

- `on_load( $body )` `on_package( $body )`

    ```js
    ...->on_package( 'function (xpack) end' )
    ```

    Injects raw-Lua hooks (each takes raw Lua function bodies).

- `component( $name, @body )`

    ```perl
    ...->component( 'core', sub { ...->set_default( true ) } )
    ```

    Begins an `xpack_component(...)` block; returns a ["XpackComponent builder"](#xpackcomponent-builder).

### XpackComponent builder

An `xpack_component(...)` block describes one sub-component of an xpack. Every method is chainable.

- `set_title( $title )`

    ```
    ...->set_title( 'Core runtime' )
    ```

    Sets the display title of the component.

- `set_description( $text )`

    ```
    ...->set_description( 'The core runtime library' )
    ```

    Sets the description of the component.

- `set_default( $bool )`

    ```
    ...->set_default( true )
    ```

    Sets whether the component is selected by default. Pass a real `false` to deselect.

- `add_sourcefiles( @files )`

    ```
    ...->add_sourcefiles( 'src/*.c' )
    ```

    Adds source files to this component.

- `add_installfiles( @files )`

    ```
    ...->add_installfiles( 'LICENSE' )
    ```

    Adds extra install files to this component.

- `on_load( $body )`

    ```js
    ...->on_load( 'function (component) end' )
    ```

    Injects a raw-Lua hook (takes a raw Lua function body).

- `before_installcmd( $body )` `on_installcmd( $body )` `after_installcmd( $body )`
`before_uninstallcmd( $body )` `on_uninstallcmd( $body )` `after_uninstallcmd( $body )`

    ```js
    ...->on_installcmd( 'function (cmd) end' )
    ```

    Injects raw-Lua hooks around the component's install/uninstall commands (each takes raw Lua function bodies). `lua(
    @lines )` pushes raw Lua lines straight into the component body.

# OPTION TABLES AND BOOLEANS

Any method that in xmake takes a trailing table accepts a Perl hashref as its last argument. It is rendered with
bracket keys so any string key is valid Lua:

```perl
$t->add_files('src/*.cpp', { unity_group => 'core' });   # add_files("src/*.cpp", {["unity_group"]="core"})
```

Use the v5.36+ `true`/`false` keywords for booleans so xmake receives a real boolean, not the string `"1"`:

```perl
$p->add_requires('zlib', { shared => true });
```

Key order in tables is deterministic (sorted).

# EXAMPLES

A dependency-driven executable and a shared library with a test, built from Perl:

```perl
use v5.40;
use Alien::Xmake::Project;

my $p = Alien::Xmake::Project->new(file => 'xmake.lua');
$p->set_project('app')->set_version('0.1.0');
$p->add_rules('mode.debug', 'mode.release');
$p->add_requires('zlib', { configs => { shared => true } });

$p->target('core')
    ->set_kind('shared')
    ->add_files('src/core/*.cpp')
    ->add_packages('zlib');

$p->target('app')
    ->set_kind('binary')
    ->add_files('src/main.cpp')
    ->add_deps('core')
    ->add_packages('zlib')
    ->set_languages('c++20')
    ->add_values('wasm.preloadfiles', 'src/assets/app.js')
    ->on_install('windows', 'function (target) end');

$p->save;

$p->xmake->configure(mode => 'release');
$p->xmake->build;
$p->xmake->test;
$p->xmake->project(kind => 'vsxmake');   # feed any IDE generator
```

# SEE ALSO

[Alien::Xmake](https://metacpan.org/pod/Alien%3A%3AXmake), the example in `eg/xmake_project.pl`

# LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2\. Other copyrights, terms, and conditions may apply to data transmitted through this module.

# AUTHOR

Sanko Robinson [https://github.com/sanko](https://github.com/sanko)
