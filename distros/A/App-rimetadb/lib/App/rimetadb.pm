package App::rimetadb;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Module::Load qw(autoload load);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-07-09'; # DATE
our $DIST = 'App-rimetadb'; # DIST
our $VERSION = '0.226'; # VERSION

our $db_schema_spec = {
    latest_v => 5,
    install => [
        'CREATE TABLE IF NOT EXISTS package (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, dist TEXT, extra TEXT, mtime INT)',
        'CREATE TABLE IF NOT EXISTS function (package VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, dist TEXT, extra TEXT, mtime INT, UNIQUE(package, name))',
    ],
    upgrade_to_v5 => [
        'ALTER TABLE function ADD COLUMN mtime INT',
    ],
    upgrade_to_v4 => [
        'ALTER TABLE function ADD COLUMN dist TEXT',
    ],
    upgrade_to_v3 => [
        'ALTER TABLE package ADD COLUMN dist TEXT',
        'ALTER TABLE package ADD COLUMN extra TEXT', # a column to store random extra stuffs
        'ALTER TABLE function ADD COLUMN extra TEXT', # a column to store random extra stuffs
    ],
    upgrade_to_v2 => [
        # rename to package
        'DROP TABLE module',
        'CREATE TABLE IF NOT EXISTS package (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, mtime INT)',

        # we'll just drop everything and rebuild, since it's painful to
        # rename column in sqlite
        'DROP TABLE function',
        'CREATE TABLE IF NOT EXISTS function (package VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, UNIQUE(package, name))',
    ],

    # for testing
    install_v4 => [
        'CREATE TABLE IF NOT EXISTS package (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, dist TEXT, extra TEXT, mtime INT)',
        'CREATE TABLE IF NOT EXISTS function (package VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, dist TEXT, extra TEXT, UNIQUE(package, name))',
    ],
    install_v3 => [
        'CREATE TABLE IF NOT EXISTS package (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, dist TEXT, extra TEXT, mtime INT)',
        'CREATE TABLE IF NOT EXISTS function (package VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, extra TEXT, UNIQUE(package, name))',
    ],
    install_v2 => [
        'CREATE TABLE IF NOT EXISTS package (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, mtime INT)',
        'CREATE TABLE IF NOT EXISTS function (package VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, UNIQUE(package, name))',
    ],
    install_v1 => [
        'CREATE TABLE IF NOT EXISTS module (name VARCHAR(255) PRIMARY KEY, summary TEXT, metadata BLOB, mtime INT)',
        'CREATE TABLE IF NOT EXISTS function (module VARCHAR(255) NOT NULL, name VARCHAR(255) NOT NULL, summary TEXT, metadata BLOB, UNIQUE(module, name))',
    ],
};

sub _cleanser {
    require Data::Clean::ForJSON;
    state $cleanser = Data::Clean::ForJSON->get_cleanser;
    $cleanser;
}

sub _json {
    require JSON::MaybeXS;
    state $json = JSON::MaybeXS->new->allow_nonref;
    $json;
}

sub _pa {
    require Perinci::Access::Perl;
    state $pa = Perinci::Access::Perl->new;
    $pa;
}

sub _connect_db {
    require DBI;
    require SQL::Schema::Versioned;

    my $args = shift;

    $args->{dsn} //= do {
        $ENV{HOME} or die "HOME not defined, can't set default for dsn";
        "dbi:SQLite:database=$ENV{HOME}/rimeta.db";
    };

    my $dbh = DBI->connect($args->{dsn}, $args->{user}, $args->{password},
                           {RaiseError=>1});

    my $res = SQL::Schema::Versioned::create_or_update_db_schema(
        spec => $db_schema_spec,
        dbh => $dbh,
    );
    return $res unless $res->[0] == 200;
    ($res, $dbh);
}

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Manage a Rinci metadata database',
};

our %args_common = (
    dsn => {
        summary => 'DBI connection DSN',
        description => <<'_',

If not specified, will default to `dbd:SQLite:$HOME/rimeta.db` where `$HOME` is
user's home directory.

Note: has been tested with MySQL and SQLite only.

_
        schema => 'str*',
        tags => ['common'],
    },
    user => {
        summary => 'DBI connection user',
        schema => 'str*',
        tags => ['common'],
    },
    password => {
        summary => 'DBI connection password',
        schema => 'str*',
        tags => ['common'],
    },
);

our %args_query_detail = (
    detail => {
        schema => 'bool',
        cmdline_aliases => {l=>{}},
    },
);

our %args_query = (
    query => {
        schema => 'str*',
        pos => 0,
        tags => ['category:filtering'],
    },
    %args_query_detail,
);

our %args_package = (
    package => {
        summary => 'Select specific package only',
        schema => 'perl::modname*',
        tags => ['category:filtering'],
    },
);

our %args_function = (
    function => {
        summary => 'Select specific function only',
        schema => 'str*', # XXX function name
        tags => ['category:filtering'],
    },
);

sub _is_excluded {
    my ($x, $exc_list) = @_;
    for (@$exc_list) {
        if (/(.+)::\*?\z/) {
            return 1 if index($x, "$1\::") == 0;
        } else {
            return 1 if $x eq $_;
        }
    }
    0;
}

sub _package_in_list_of_modnames_or_prefixes {
    my ($pkg, $list) = @_;
    #log_debug "Checking if package %s is in list %s", $pkg, $list;
    my $res = 0;
    for (@$list) {
        if (/::\z/) {
            do { $res++; last } if $pkg =~ /\A\Q$_\E/;
        } else {
            do { $res++; last } if $pkg eq $_;
        }
    }
    #log_debug "  result: $res";
    $res;
}

sub _complete_package {
    require Complete::Util;

    my %args = @_;

    my $word = $args{word};

    # only run under pericmd
    my $cmdline = $args{cmdline} or return undef; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef
    my $r = $args{r};

    # allow writing Mod::SubMod as Mod/SubMod
    my $uses_slash = $word =~ s!/!::!g ? 1:0;

    # force read config file, because by default it is turned off when in
    # completion
    $r->{read_config} = 1;
    my $pres = $cmdline->parse_argv($r);
    my $pargs = $pres->[2];

    my ($res, $dbh) = _connect_db($pargs);
    return undef unless $res->[0] == 200; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef

    my @words;
    my $sth = $dbh->prepare("SELECT DISTINCT name FROM package ORDER BY name");
    $sth->execute;
    while (my $h = $sth->fetchrow_hashref) { push @words, $h->{name} }

    my $compres = Complete::Util::complete_array_elem(
        array => \@words, word => $word,
    );

    # convert back to slash if user originally typed with slash
    if ($uses_slash) { for (@$compres) { s!::!/!g } }

    $compres;
}

sub _complete_func {
    require Complete::Util;

    my %args = @_;

    my $word = $args{word};

    # only run under pericmd
    my $cmdline = $args{cmdline} or return undef; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef
    my $r = $args{r};

    # force read config file, because by default it is turned off when in
    # completion
    $r->{read_config} = 1;
    my $pres = $cmdline->parse_argv($r);
    my $pargs = $pres->[2];

    my ($res, $dbh) = _connect_db($pargs);
    return undef unless $res->[0] == 200; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef

    my @words;
    my @wheres;
    my @binds;

    if ($pargs->{package}) {
        push @wheres, "package=?";
        push @binds, $pargs->{package};
    }
    my $sth = $dbh->prepare(
        "SELECT DISTINCT name FROM function".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "").
            " ORDER BY name");
    $sth->execute(@binds);
    while (my $h = $sth->fetchrow_hashref) { push @words, $h->{name} }

    my $compres = Complete::Util::complete_array_elem(
        array => \@words, word => $word,
    );

    $compres;
}

sub _complete_fqfunc_or_package {
    require Complete::Util;

    my %args = @_;

    my $word = $args{word};

    # only run under pericmd
    my $cmdline = $args{cmdline} or return undef; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef
    my $r = $args{r};

    # allow writing Mod::SubMod as Mod/SubMod
    my $uses_slash = $word =~ s!/!::!g ? 1:0;

    # force read config file, because by default it is turned off when in
    # completion
    $r->{read_config} = 1;
    my $pres = $cmdline->parse_argv($r);
    my $pargs = $pres->[2];

    my ($res, $dbh) = _connect_db($pargs);
    return undef unless $res->[0] == 200; ## no critic: TestingAndDebugging::ProhibitExplicitReturnUndef

    my @words;
    my $sth = $dbh->prepare("SELECT DISTINCT name FROM package ORDER BY name");
    $sth->execute;
    while (my $h = $sth->fetchrow_hashref) { push @words, $h->{name} }
    $sth = $dbh->prepare("SELECT DISTINCT package, name FROM function ORDER BY package, name");
    $sth->execute;
    while (my $h = $sth->fetchrow_hashref) { push @words, "$h->{package}::$h->{name}" }

    my $compres = Complete::Util::complete_array_elem(
        array => \@words, word => $word,
    );

    # convert back to slash if user originally typed with slash
    if ($uses_slash) { for (@$compres) { s!::!/!g } }

    $compres;
}

$SPEC{update_from_modules} = {
    v => 1.1,
    summary => 'Update Rinci metadata database from local Perl modules',
    description => <<'_',

This routine scans Perl modules, load them, and update the database using Rinci
metadata from each modules into the database.

For each package, function, or function argument metadata, you can put this
attribute:

    'x.app.rimetadb.exclude' => 1,

to exclude the entity from being imported into the database. When you exclude a
package, all its contents (currently functions) are also excluded.

_
    args => {
        %args_common,
        module_or_package => {
            summary => 'Perl module or prefixes or package to add/update',
            description => <<'_',

For each entry, you can specify:

* a Perl module name e.g. `Foo::Bar`. An attempt will be made to load that
  module.

* a module prefix ending with `::` e.g. `Foo::Bar::`. `Module::List` will be
  used to list all modules under `Foo::Bar::` recursively and load all those
  modules.

* a package name using `+Foo::Bar` syntax. An attempt to load module with that
  name will *not* be made. This can be used to add an already-loaded package
  e.g. by another module).

* a package prefix using `+Foo::Bar::` or `+Foo::Bar::` syntax. Subpackages will
  be listed recursively (using <pm:Package::Util::Lite>'s `list_subpackages`).

_
            schema => ['array*' => of => 'perl::modname_or_prefix*'],
            req => 1,
            pos => 0,
            greedy => 1,
            element_completion => \&_complete_package,
        },
        exclude => {
            summary => 'Perl package names or prefixes to exclude',
            schema => ['array*' => of => 'perl::modname_or_prefix*'],
            description => <<'_',

You can also use this attribute in your package metadata:

    'x.app.rimetadb.exclude' => 1,

to exclude the package (as well as its contents: all functions) from being
imported into the database.

_
        },
        library => {
            summary => "Include library path, like Perl's -I",
            schema => 'dirname*',
            description => <<'_',

Note that some modules are already loaded before this option takes effect. To
make sure you use the right library, you can use `PERL5OPT` or explicitly use
`perl` and use its `-I` option.

_
            cmdline_aliases => { I=>{} },
            cmdline_on_getopt => sub {
                my %args = @_;
                require lib;
                lib->import($args{value});
            },
        },
        use => {
            schema => ['array' => of => 'perl::modname*'],
            summary => 'Use a Perl module, a la Perl\'s -M',
            cmdline_aliases => {M=>{}},
            cmdline_on_getopt => sub {
                my %args = @_;
                my $val = $args{value};
                if (my ($mod, $imp) = $val =~ /(.+?)=(.+)/) {
                    log_debug("Loading module $mod ...");
                    load $mod;
                    $mod->import(split /,/, $imp);
                } else {
                    log_debug("Loading module $val ...");
                    autoload $val;
                }
            },
        },
        require => {
            schema => ['array' => of => 'perl::modname*'],
            summary => 'Require a Perl module, a la Perl\'s -m',
            cmdline_aliases => {m=>{}},
            cmdline_on_getopt => sub {
                my %args = @_;
                my $val = $args{value};
                log_debug("Loading module $val ...");
                load $val;
            },
        },
        force_update => {
            summary => "Force update database even though module ".
                "hasn't changed since last update",
            schema => 'bool',
            cmdline_aliases => { force=>{} }, # old alias
        },
        delete => {
            summary => "Whether to delete packages from DB if no longer ".
                "mentioned as arguments or found in filesystem",
            schema  => 'bool',
            default => 1,
        },
    },
    features => {
        progress => 1,
        dry_run => 1,
    },
};
sub update_from_modules {
    require Module::List;
    require Module::Path::More;
    require Package::Util::Lite;

    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $exc = $args{exclude} // [];

    my @pkgs;
    for my $entry (@{ $args{module_or_package} }) {
        if ($entry =~ /\A\+(.+)::\z/) {
            # package prefix
            log_debug("Listing all packages under $1 ...");
            for my $p (Package::Util::Lite::list_subpackages($1, 1)) {
                next if (grep { $_ eq $p } @pkgs) || _is_excluded($_, $exc);
                push @pkgs, $_;
            }
        } elsif ($entry =~ /\A\+(.+)/) {
            # package name
            my $pkg = $1;
            next if (grep { $_ eq $pkg } @pkgs) || _is_excluded($pkg, $exc);
            push @pkgs, $pkg;
        } elsif ($entry =~ /(.+::)\z/) {
            # module prefix
            log_debug("Listing all modules under $1 ...");
            my $res = Module::List::list_modules(
                $1, {list_modules=>1, recurse=>1});
            for my $mod (sort keys %$res) {
                next if (grep { $_ eq $mod } @pkgs) || _is_excluded($mod, $exc);
                log_debug("Loading module $mod ...");
                load $mod;
                push @pkgs, $mod;
            }
        } else {
            # module name
            next if (grep { $_ eq $entry } @pkgs) || _is_excluded($entry, $exc);
            log_debug("Loading module $entry ...");
            load $entry;
            push @pkgs, $entry;
        }
    }

    my @excluded_pkgs;
    my $progress = $args{-progress};
    $progress->pos(0) if $progress;
    $progress->target(scalar @pkgs) if $progress;
    my $i = 0;
  PKG:
    for my $pkg (@pkgs) {
        $i++;
        $progress->update(pos=>$i, message => "Processing package $pkg ...") if $progress;
        log_debug("Processing package $pkg ...");
        #sleep 1;
        my $rec = $dbh->selectrow_hashref("SELECT * FROM package WHERE name=?",
                                          {}, $pkg);
        my $mp = Module::Path::More::module_path(module=>$pkg);
        my @st; @st = stat($mp) if $mp;

        unless ($args{force} || !$rec || !$rec->{mtime} || !@st || $rec->{mtime} < $st[9]) {
            log_debug("$pkg ($mp) hasn't changed since last recorded, skipped");
            next;
        }

        next if $args{-dry_run};

        my $uri = $pkg; $uri =~ s!::!/!g; $uri = "pl:/$uri/";

        $res = _pa->request(meta => "$uri");
        die "Can't meta $uri: $res->[0] - $res->[1]" unless $res->[0] == 200;
        _cleanser->clean_in_place(my $pkgmeta = $res->[2]);

        if ($pkgmeta->{'x.app.rimetadb.exclude'}) {
            log_debug("Package $pkg has x.app.rimetadb.exclude set to true, excluding ...");
            push @excluded_pkgs, $pkg;
            if ($rec) {
                log_debug("Deleting package $pkg from the database ...");
                $dbh->do("DELETE FROM package  WHERE name=?"   , {}, $pkg);
                $dbh->do("DELETE FROM function WHERE package=?", {}, $pkg);
            }
            next PKG;
        }

        $res = _pa->request(list => $uri, {type=>'function'});
        die "Can't list $uri: $res->[0] - $res->[1]" unless $res->[0] == 200;
        my $numf = @{ $res->[2] };

        $dbh->do("INSERT INTO package (name, summary, metadata, mtime) VALUES (?,?,?,0)", {}, $pkg, $pkgmeta->{summary}, _json->encode($pkgmeta), $st[9]) unless $rec;
        $dbh->do("UPDATE package set mtime=? WHERE name=?", {}, $st[9], $pkg);
        $dbh->do("DELETE FROM function WHERE package=?", {}, $pkg);
        my $j = 0;
      FUNC:
        for my $e (@{ $res->[2] }) {
            my $func = $e; $func =~ s!.+/!!;
            $j++;
            log_debug("Processing function $pkg\::$func ...");
            $progress->update(pos => $i + $j/$numf, message => "Processing function $pkg\::$func ...") if $progress;
            $res = _pa->request(meta => "$uri$e");
            die "Can't meta $e: $res->[0] - $res->[1]" unless $res->[0] == 200;
            _cleanser->clean_in_place(my $funcmeta = $res->[2]);

            if ($funcmeta->{'x.app.rimetadb.exclude'}) {
                log_debug("Function $pkg\::$func has x.app.rimetadb.exclude set to true, excluding ...");
                next FUNC;
            }

            for my $argname (sort keys %{ $funcmeta->{args} // {} }) {
                my $argspec = $funcmeta->{args}{$argname};
                if ($argspec->{'x.app.rimetadb.exclude'}) {
                    log_debug("Function argument $argname (of function $pkg\::$func) has x.app.rimetadb.exclude set to true, excluding ...");
                    delete $funcmeta->{args}{$argname};
                }
            }

            $dbh->do("INSERT INTO function (package, name, summary, metadata) VALUES (?,?,?,?)", {}, $pkg, $func, $funcmeta->{summary}, _json->encode($funcmeta));
        }
    }
    $progress->finish if $progress;

    @pkgs = grep { my $p = $_; !(grep { $_ eq $p } @excluded_pkgs) } @pkgs;

    if ($args{delete} // 1) {
        my @deleted_pkgs;
        my $sth = $dbh->prepare("SELECT name FROM package");
        $sth->execute;
        while (my $row = $sth->fetchrow_hashref) {
            next unless _package_in_list_of_modnames_or_prefixes($row->{name}, $args{module_or_package});
            next if grep { $_ eq $row->{name} } @pkgs;
            log_info("Package $row->{name} no longer exists, deleting from database ...");
            push @deleted_pkgs, $row->{name};
        }
        if (@deleted_pkgs && !$args{-dry_run}) {
            my $in = join(",", map {$dbh->quote($_)} @deleted_pkgs);
            $dbh->do("DELETE FROM function WHERE package IN ($in)");
            $dbh->do("DELETE FROM package WHERE name IN ($in)");
        }
    }

    [200, "OK"];
}

$SPEC{update} = {
    v => 1.1,
    summary => 'Add/update a package or function metadata in the database',
    description => <<'_',

This routine lets you add/update a package or function metadata in the database
with the specified metadata.

_
    args => {
        %args_common,
        package => {
            schema => 'perl::modname*',
            req => 1,
            completion => \&_complete_package,
        },
        function => {
            schema => 'str*',
            completion => \&_complete_func,
        },
        metadata => {
            schema => 'hash*',
            req => 1,
        },
        dist => {
            schema => 'str*',
        },
        extra => {
            schema => 'str*',
        },
    },
};
sub update {
    require Perinci::Sub::Normalize;

    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $pkg  = $args{package};
    my $func = $args{function};
    my $meta = $args{metadata};

    if ($func) {
        $meta = Perinci::Sub::Normalize::normalize_function_metadata($meta);
    }

    my $pkgsummary;
    $pkgsummary = $meta->{summary} unless $func;
    if ($dbh->selectrow_array("SELECT name FROM package WHERE name=?", {}, $pkg)) {
        $dbh->do("UPDATE package SET summary=?, metadata=?, mtime=?, dist=?, extra=? WHERE name=?",
                 {}, $pkgsummary, _json->encode($meta), time(), $args{dist}, $args{extra},
                 $pkg);
    } else {
        $dbh->do("INSERT INTO package (name, summary, metadata, mtime, extra) VALUES (?,?,?,?,?)",
                 {}, $pkg, $pkgsummary, _json->encode($meta), $args{dist}, $args{extra});
    }

    if ($func) {
        my $funcsummary = $meta->{summary};
        if ($dbh->selectrow_array("SELECT name FROM function WHERE package=? AND name=?", {}, $pkg, $func)) {
            $dbh->do("UPDATE function SET summary=?, metadata=?, mtime=?, dist=?, extra=? WHERE package=? AND name=?",
                     {}, $funcsummary, _json->encode($meta), time(), $args{dist}, $args{extra},
                     $pkg, $func);
        } else {
            $dbh->do("INSERT INTO function (package, name, summary, metadata, mtime, dist, extra) VALUES (?,?,?,?,?,?,?)",
                     {}, $pkg, $func, $funcsummary, _json->encode($meta), time(), $args{dist}, $args{extra});
        }
    }

    [200, "OK"];
}

$SPEC{delete} = {
    v => 1.1,
    summary => 'Delete a package or function metadata from the database',
    args => {
        %args_common,
        package => {
            schema => 'perl::modname*',
            req => 1,
            completion => \&_complete_package,
        },
        function => {
            schema => 'str*',
            completion => \&_complete_func,
        },
    },
};
sub delete {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $pkg  = $args{package};
    my $func = $args{function};

    if ($func) {
        $dbh->do("DELETE FROM function WHERE package=? AND name=?", {}, $pkg, $func);
    } else {
        $dbh->do("DELETE FROM function WHERE package=?", {}, $pkg);
        $dbh->do("DELETE FROM package WHERE name=?", {}, $pkg);
    }
    [200, "OK"];
}

$SPEC{packages} = {
    v => 1.1,
    summary => 'List packages in the database',
    args => {
        %args_common,
        %args_query,
    },
};
sub packages {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $q  = $args{query};

    my @rows;
    my @columns = qw(name summary dist mtime extra);
    my @wheres;
    my @binds;

    if (length $q) {
        push @wheres, "(name LIKE ? OR dist LIKE ? OR extra LIKE ?)";
        push @binds, "%$q%", "%$q%", "%$q%";
    }

    my $sth = $dbh->prepare(
        "SELECT name,summary,dist,mtime,extra FROM package".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "").
            " ORDER by name"
    );
    $sth->execute(@binds);

    while (my $row = $sth->fetchrow_hashref) {
        if ($args{detail}) {
            push @rows, $row;
        } else {
            push @rows, $row->{name};
        }
    }

    [200, "OK", \@rows, {'table.fields'=>\@columns}];
}

$SPEC{functions} = {
    v => 1.1,
    summary => 'List functions in the database',
    args => {
        %args_common,
        %args_query,
        %args_package,
    },
};
sub functions {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $q  = $args{query};

    my @rows;
    my @columns = qw(package name summary dist mtime extra);
    my @wheres;
    my @binds;

    if (length $q) {
        push @wheres, "(package LIKE ? OR name LIKE ? OR dist LIKE ? OR extra LIKE ?)";
        push @binds, "%$q%", "%$q%", "%$q%", "%$q%";
    }

    if (defined $args{package}) {
        push @wheres, "(package=?)";
        push @binds, $args{package};
    }

    my $sth = $dbh->prepare(
        "SELECT package,name,summary,dist,mtime,extra FROM function".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "").
            " ORDER by package,name"
    );
    $sth->execute(@binds);

    while (my $row = $sth->fetchrow_hashref) {
        if ($args{detail}) {
            push @rows, $row;
        } else {
            push @rows, "$row->{package}\::$row->{name}";
        }
    }

    [200, "OK", \@rows, {'table.fields'=>\@columns}];
}

$SPEC{arguments} = {
    v => 1.1,
    summary => 'List function arguments in the database',
    args => {
        %args_common,
        %args_query,
        %args_package,
        %args_function,
        type => {
            summary => 'Select arguments with specific type only',
            schema => 'str*',
            tags => ['category:filtering'],
        },
    },
};
sub arguments {
    require Data::Sah::Util::Type;

    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $q  = $args{query};

    my @rows;
    my @columns = qw(name package function summary schema schema_type req pos greedy);
    my @wheres;
    my @binds;

    if (length $q) {
        push @wheres, "(package LIKE ? OR name LIKE ? OR dist LIKE ? OR extra LIKE ?)";
        push @binds, "%$q%", "%$q%", "%$q%", "%$q%";
    }

    if (defined $args{package}) {
        push @wheres, "(package=?)";
        push @binds, $args{package};
    }

    if (defined $args{function}) {
        push @wheres, "(function=?)";
        push @binds, $args{function};
    }

    my $sth = $dbh->prepare(
        "SELECT package,name AS function,metadata FROM function".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "").
            " ORDER by package,name"
    );
    $sth->execute(@binds);

    while (my $row0 = $sth->fetchrow_hashref) {
        my $meta = _json->decode(delete $row0->{metadata});
        if ($meta->{args}) {
          ARG:
            for my $arg (sort keys %{ $meta->{args} }) {
                my $argspec = $meta->{args}{$arg};
                my $row = {%$row0};
                $row->{name} = $arg;
                $row->{summary} = $argspec->{summary};
                $row->{schema} = _json->encode($argspec->{schema});
                $row->{schema_type} = Data::Sah::Util::Type::get_type($argspec->{schema});
                $row->{req} = $argspec->{req};
                $row->{pos} = $argspec->{pos};
                $row->{greedy} = $argspec->{greedy};
                if (defined $args{type}) {
                    next ARG unless defined($row->{schema_type}) &&
                        $args{type} eq $row->{schema_type};
                }
                if ($args{detail}) {
                    push @rows, $row;
                } else {
                    push @rows, "$row->{package}\::$row->{function}\::$row->{name}";
                }
            }
        }
    }

    [200, "OK", \@rows, {'table.fields'=>\@columns}];
}

$SPEC{stats} = {
    v => 1.1,
    summary => 'Show some statistics from the database',
    args => {
        %args_common,
    },
};
sub stats {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my %stats;
    ($stats{db_dsn}) = $args{dsn};
    ($stats{num_packages}) = $dbh->selectrow_array("SELECT COUNT(*) FROM package");
    ($stats{num_functions}) = $dbh->selectrow_array("SELECT COUNT(*) FROM function");

    # XXX avg_num_args
    # XXX top_arg_types
    # XXX top_arg_entities
    # XXX pct_arg_has_entity
    # XXX pct_arg_has_element_entity

    [200, "OK", \%stats];
}

$SPEC{function_stats} = {
    v => 1.1,
    summary => 'Show some statistics on functions from the database',
    args => {
        %args_common,
    },
};
sub function_stats {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my @rows;
    my @columns = qw(package name num_args);
    my @wheres;
    my @binds;

    my $sth = $dbh->prepare(
        "SELECT package,name,metadata FROM function".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "").
            " ORDER by package,name"
    );
    $sth->execute(@binds);

    while (my $row = $sth->fetchrow_hashref) {
        my $meta = _json->decode(delete $row->{metadata});
        $row->{num_args} = keys %{ $meta->{args} // {} };
        push @rows, $row;
    }

    [200, "OK", \@rows, {'table.fields'=>\@columns}];
}

$SPEC{argument_stats} = {
    v => 1.1,
    summary => 'Show statistics on function arguments from the database',
    args => {
        %args_common,
    },
};
sub argument_stats {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    #my $q  = $args{query};

    my @rows;
    #my @columns = qw(package name summary dist mtime extra);
    my @wheres;
    my @binds;

    #if (length $q) {
    #    push @wheres, "(package LIKE ? OR name LIKE ? OR dist LIKE ? OR extra LIKE ?)";
    #    push @binds, $q, $q, $q, $q;
    #}

    my $sth = $dbh->prepare(
        "SELECT package,name,metadata FROM function".
            (@wheres ? " WHERE ".join(" AND ", @wheres) : "")
    );
    $sth->execute(@binds);

    my %num_occurences;
    while (my $row = $sth->fetchrow_hashref) {
        my $meta = _json->decode($row->{metadata});
        my $args = $meta->{args} // {};
        for (keys %$args) {
            $num_occurences{$_}++;
        }
    }

    for (sort keys %num_occurences) {
        push @rows, {name=>$_, num_occurences=>$num_occurences{$_}};
    }

    #unless ($args{detail}) {
    #    @rows = map {$_->{name}} @rows;
    #}

    my @columns = qw(name num_occurences);
    [200, "OK", \@rows, {'table.fields'=>\@columns}];
}

$SPEC{meta} = {
    v => 1.1,
    summary => 'Get package/function metadata from the database',
    args => {
        %args_common,
        name => {
            summary => '(Fully-qualified) function name or package name',
            schema => ['perl::modname'],
            req => 1,
            pos => 0,
            completion => \&_complete_fqfunc_or_package,
        },
    },
};
sub meta {
    my %args = @_;

    my ($res, $dbh) = _connect_db(\%args);
    return $res unless $res->[0] == 200;

    my $name = $args{name};

    # try function metadata first
    {
        my ($package, $func) = $name =~ /(.+)::(.+)/
            or last;

        my ($row) = $dbh->selectrow_hashref(
            "SELECT metadata FROM function WHERE package=? AND name=?", {},
            $package, $func)
            or last;

        return [200, "OK (func meta)", $row->{metadata}];
    }

    # try package metadata
    my ($row) = $dbh->selectrow_hashref(
        "SELECT metadata FROM package WHERE name=?", {}, $name)
        or return [404, "Can't find function or package with that name"];

    [200, "OK (package meta)", $row->{metadata}];
}

1;
# ABSTRACT: Manage a Rinci metadata database

__END__

=pod

=encoding UTF-8

=head1 NAME

App::rimetadb - Manage a Rinci metadata database

=head1 VERSION

This document describes version 0.226 of App::rimetadb (from Perl distribution App-rimetadb), released on 2023-07-09.

=head1 SYNOPSIS

See the included CLI script L<rimetadb>.

=head1 FUNCTIONS


=head2 argument_stats

Usage:

 argument_stats(%args) -> [$status_code, $reason, $payload, \%result_meta]

Show statistics on function arguments from the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 arguments

Usage:

 arguments(%args) -> [$status_code, $reason, $payload, \%result_meta]

List function arguments in the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<detail> => I<bool>

(No description)

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<function> => I<str>

Select specific function only.

=item * B<package> => I<perl::modname>

Select specific package only.

=item * B<password> => I<str>

DBI connection password.

=item * B<query> => I<str>

(No description)

=item * B<type> => I<str>

Select arguments with specific type only.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 delete

Usage:

 delete(%args) -> [$status_code, $reason, $payload, \%result_meta]

Delete a package or function metadata from the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<function> => I<str>

(No description)

=item * B<package>* => I<perl::modname>

(No description)

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 function_stats

Usage:

 function_stats(%args) -> [$status_code, $reason, $payload, \%result_meta]

Show some statistics on functions from the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 functions

Usage:

 functions(%args) -> [$status_code, $reason, $payload, \%result_meta]

List functions in the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<detail> => I<bool>

(No description)

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<package> => I<perl::modname>

Select specific package only.

=item * B<password> => I<str>

DBI connection password.

=item * B<query> => I<str>

(No description)

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 meta

Usage:

 meta(%args) -> [$status_code, $reason, $payload, \%result_meta]

Get packageE<sol>function metadata from the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<name>* => I<perl::modname>

(Fully-qualified) function name or package name.

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 packages

Usage:

 packages(%args) -> [$status_code, $reason, $payload, \%result_meta]

List packages in the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<detail> => I<bool>

(No description)

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<password> => I<str>

DBI connection password.

=item * B<query> => I<str>

(No description)

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 stats

Usage:

 stats(%args) -> [$status_code, $reason, $payload, \%result_meta]

Show some statistics from the database.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 update

Usage:

 update(%args) -> [$status_code, $reason, $payload, \%result_meta]

AddE<sol>update a package or function metadata in the database.

This routine lets you add/update a package or function metadata in the database
with the specified metadata.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<dist> => I<str>

(No description)

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<extra> => I<str>

(No description)

=item * B<function> => I<str>

(No description)

=item * B<metadata>* => I<hash>

(No description)

=item * B<package>* => I<perl::modname>

(No description)

=item * B<password> => I<str>

DBI connection password.

=item * B<user> => I<str>

DBI connection user.


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)



=head2 update_from_modules

Usage:

 update_from_modules(%args) -> [$status_code, $reason, $payload, \%result_meta]

Update Rinci metadata database from local Perl modules.

This routine scans Perl modules, load them, and update the database using Rinci
metadata from each modules into the database.

For each package, function, or function argument metadata, you can put this
attribute:

 'x.app.rimetadb.exclude' => 1,

to exclude the entity from being imported into the database. When you exclude a
package, all its contents (currently functions) are also excluded.

This function is not exported.

This function supports dry-run operation.


Arguments ('*' denotes required arguments):

=over 4

=item * B<delete> => I<bool> (default: 1)

Whether to delete packages from DB if no longer mentioned as arguments or found in filesystem.

=item * B<dsn> => I<str>

DBI connection DSN.

If not specified, will default to C<dbd:SQLite:$HOME/rimeta.db> where C<$HOME> is
user's home directory.

Note: has been tested with MySQL and SQLite only.

=item * B<exclude> => I<array[perl::modname_or_prefix]>

Perl package names or prefixes to exclude.

You can also use this attribute in your package metadata:

 'x.app.rimetadb.exclude' => 1,

to exclude the package (as well as its contents: all functions) from being
imported into the database.

=item * B<force_update> => I<bool>

Force update database even though module hasn't changed since last update.

=item * B<library> => I<dirname>

Include library path, like Perl's -I.

Note that some modules are already loaded before this option takes effect. To
make sure you use the right library, you can use C<PERL5OPT> or explicitly use
C<perl> and use its C<-I> option.

=item * B<module_or_package>* => I<array[perl::modname_or_prefix]>

Perl module or prefixes or package to addE<sol>update.

For each entry, you can specify:

=over

=item * a Perl module name e.g. C<Foo::Bar>. An attempt will be made to load that
module.

=item * a module prefix ending with C<::> e.g. C<Foo::Bar::>. C<Module::List> will be
used to list all modules under C<Foo::Bar::> recursively and load all those
modules.

=item * a package name using C<+Foo::Bar> syntax. An attempt to load module with that
name will I<not> be made. This can be used to add an already-loaded package
e.g. by another module).

=item * a package prefix using C<+Foo::Bar::> or C<+Foo::Bar::> syntax. Subpackages will
be listed recursively (using L<Package::Util::Lite>'s C<list_subpackages>).

=back

=item * B<password> => I<str>

DBI connection password.

=item * B<require> => I<array[perl::modname]>

Require a Perl module, a la Perl's -m.

=item * B<use> => I<array[perl::modname]>

Use a Perl module, a la Perl's -M.

=item * B<user> => I<str>

DBI connection user.


=back

Special arguments:

=over 4

=item * B<-dry_run> => I<bool>

Pass -dry_run=E<gt>1 to enable simulation mode.

=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-rimetadb>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-rimetadb>.

=head1 SEE ALSO

L<Rinci>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTOR

=for stopwords Steven Haryanto

Steven Haryanto <stevenharyanto@gmail.com>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023, 2020, 2019, 2017, 2016, 2015, 2014 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-rimetadb>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
