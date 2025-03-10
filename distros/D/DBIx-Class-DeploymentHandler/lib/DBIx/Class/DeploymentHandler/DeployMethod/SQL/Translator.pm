package DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator;
$DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::VERSION = '0.002234';
use Moose;

# ABSTRACT: Manage your SQL and Perl migrations in nicely laid out directories

use autodie;
use Carp qw( carp croak );
use DBIx::Class::DeploymentHandler::LogImporter qw(:log :dlog);
use Context::Preserve;
use Digest::MD5;

use Try::Tiny;

use SQL::SplitStatement '1.00020';
use SQL::Translator;
require SQL::Translator::Diff;

require DBIx::Class::Storage;   # loaded for type constraint
use DBIx::Class::DeploymentHandler::Types;

use Path::Class qw(file dir);

with 'DBIx::Class::DeploymentHandler::HandlesDeploy';

has ignore_ddl => (
  isa      => 'Bool',
  is       => 'ro',
  default  => undef,
);

has force_overwrite => (
  isa      => 'Bool',
  is       => 'ro',
  default  => undef,
);

has schema => (
  is       => 'ro',
  required => 1,
);

has storage => (
  isa        => 'DBIx::Class::Storage',
  is         => 'ro',
  lazy_build => 1,
);

has version_source => (
    is      => 'ro',
    default => '__VERSION',
);

sub _build_storage {
  my $self = shift;
  my $s = $self->schema->storage;
  $s->_determine_driver;
  $s
}

has sql_translator_args => (
  isa => 'HashRef',
  is  => 'ro',
  default => sub { {} },
);
has script_directory => (
  isa      => 'Str',
  is       => 'ro',
  required => 1,
  default  => 'sql',
);

has databases => (
  coerce  => 1,
  isa     => 'DBIx::Class::DeploymentHandler::Databases',
  is      => 'ro',
  default => sub { [qw( MySQL SQLite PostgreSQL )] },
);

has txn_prep => (
  isa      => 'Bool',
  is       => 'ro',
  default  => 1,
);

has txn_wrap => (
  is => 'ro',
  isa => 'Bool',
  default => 1,
);

has schema_version => (
  is => 'ro',
  lazy_build => 1,
);

# this will probably never get called as the DBICDH
# will be passing down a schema_version normally, which
# is built the same way, but we leave this in place
sub _build_schema_version {
  my $self = shift;
  $self->schema->schema_version
}

has sql_splitter => (
    is => 'ro',
    lazy => 1,
    builder => '_build_sql_splitter',
);

sub _build_sql_splitter { SQL::SplitStatement->new }

sub __ddl_consume_with_prefix {
  my ($self, $type, $versions, $prefix) = @_;
  my $base_dir = $self->script_directory;

  my $main    = dir( $base_dir, $type      );
  my $common  =
    dir( $base_dir, '_common', $prefix, join q(-), @{$versions} );

  my $common_any  =
    dir( $base_dir, '_common', $prefix, '_any' );

  my $dir_any = dir($main, $prefix, '_any');

  my %files;
  try {
     my $dir = dir( $main, $prefix, join q(-), @{$versions} );
     opendir my($dh), $dir;
     %files =
       map { $_ => "$dir/$_" }
       grep { /\.(?:sql|pl|sql-\w+)$/ && -f "$dir/$_" }
       readdir $dh;
     closedir $dh;
  } catch {
    die $_ unless $self->ignore_ddl;
  };
  for my $dirname (grep { -d $_ } $common, $common_any, $dir_any) {
    opendir my($dh), $dirname;
    for my $filename (grep { /\.(?:sql|pl)$/ && -f file($dirname,$_) } readdir $dh) {
      unless ($files{$filename}) {
        $files{$filename} = file($dirname,$filename);
      }
    }
    closedir $dh;
  }

  return [@files{sort keys %files}]
}

sub _ddl_initialize_consume_filenames {
  my ($self, $type, $version) = @_;
  $self->__ddl_consume_with_prefix($type, [ $version ], 'initialize')
}

sub _ddl_schema_consume_filenames {
  my ($self, $type, $version) = @_;
  $self->__ddl_consume_with_prefix($type, [ $version ], 'deploy')
}

sub _ddl_protoschema_deploy_consume_filenames {
  my ($self, $version) = @_;
  my $base_dir = $self->script_directory;

  my $dir = dir( $base_dir, '_source', 'deploy', $version);
  return [] unless -d $dir;

  opendir my($dh), $dir;
  my %files = map { $_ => "$dir/$_" } grep { /\.yml$/ && -f "$dir/$_" } readdir $dh;
  closedir $dh;

  return [@files{sort keys %files}]
}

sub _ddl_protoschema_upgrade_consume_filenames {
  my ($self, $versions) = @_;
  my $base_dir = $self->script_directory;

  my $dir = dir( $base_dir, '_preprocess_schema', 'upgrade', join q(-), @{$versions});

  return [] unless -d $dir;

  opendir my($dh), $dir;
  my %files = map { $_ => "$dir/$_" } grep { /\.pl$/ && -f "$dir/$_" } readdir $dh;
  closedir $dh;

  return [@files{sort keys %files}]
}

sub _ddl_protoschema_downgrade_consume_filenames {
  my ($self, $versions) = @_;
  my $base_dir = $self->script_directory;

  my $dir = dir( $base_dir, '_preprocess_schema', 'downgrade', join q(-), @{$versions});

  return [] unless -d $dir;

  opendir my($dh), $dir;
  my %files = map { $_ => "$dir/$_" } grep { /\.pl$/ && -f "$dir/$_" } readdir $dh;
  closedir $dh;

  return [@files{sort keys %files}]
}

sub _ddl_protoschema_produce_filename {
  my ($self, $version) = @_;
  my $dirname = dir( $self->script_directory, '_source', 'deploy',  $version );
  $dirname->mkpath unless -d $dirname;

  return "" . file( $dirname, '001-auto.yml' );
}

sub _ddl_schema_produce_filename {
  my ($self, $type, $version) = @_;
  my $dirname = dir( $self->script_directory, $type, 'deploy', $version );
  $dirname->mkpath unless -d $dirname;

  return "" . file( $dirname, '001-auto.sql' );
}

sub _ddl_schema_upgrade_consume_filenames {
  my ($self, $type, $versions) = @_;
  $self->__ddl_consume_with_prefix($type, $versions, 'upgrade')
}

sub _ddl_schema_downgrade_consume_filenames {
  my ($self, $type, $versions) = @_;
  $self->__ddl_consume_with_prefix($type, $versions, 'downgrade')
}

sub _ddl_schema_upgrade_produce_filename {
  my ($self, $type, $versions) = @_;
  my $dir = $self->script_directory;

  my $dirname = dir( $dir, $type, 'upgrade', join q(-), @{$versions});
  $dirname->mkpath unless -d $dirname;

  return "" . file( $dirname, '001-auto.sql' );
}

sub _ddl_schema_downgrade_produce_filename {
  my ($self, $type, $versions, $dir) = @_;
  my $dirname = dir( $dir, $type, 'downgrade', join q(-), @{$versions} );
  $dirname->mkpath unless -d $dirname;

  return "" . file( $dirname, '001-auto.sql');
}

sub _run_sql_array {
  my ($self, $sql) = @_;
  my $storage = $self->storage;

  $sql = [ $self->_split_sql_chunk( @$sql ) ];

  Dlog_trace { "Running SQL $_" } $sql;
  foreach my $line (@{$sql}) {
    $storage->_query_start($line);
    # the whole reason we do this is so that we can see the line that was run
    try {
      $storage->dbh_do (sub { $_[1]->do($line) });
    }
    catch {
      die "$_ (running line '$line')"
    };
    $storage->_query_end($line);
  }
  return join "\n", @$sql
}

my %TXN = (
  SQLServer => qr/(BEGIN\s+TRANSACTION\b|COMMIT\b)/i,
  Sybase    => qr/(BEGIN\s+TRANSACTION\b|COMMIT\b)/i,
  SQLite    => qr/(BEGIN\b|COMMIT\b)/i,
  mysql     => qr/(BEGIN\b|START\s+TRANSACTION\b|COMMIT\b)/i,
  Oracle    => qr/COMMIT\b/i,
  Pg        => qr/(BEGIN\b|COMMIT\b)/i,
);

sub _split_sql_chunk {
  my $self = shift;
  my ($storage_class) = ref($self->storage) =~ /.*:(\w+)$/;
  my $txn = $TXN{$storage_class} || $TXN{mysql};

  # MySQL's DELIMITER is not understood by the server but handled on the client.
  # SQL::SplitStatement treats the statements between the DELIMITERs correctly
  # as ONE statement - but it does not remove the DELIMITER lines.
  # https://rt.cpan.org/Public/Bug/Display.html?id=130473
  # Transaction statements should not be present if txn_prep is false, if it
  # is true then anything that looks like a transaction is removed here.
  my @sql =
    grep {
      ($storage_class ne 'mysql' || /^(?!DELIMITER\s+)/i) &&
      (!$self->txn_prep || /^(?!$txn)/gim)
    }
    map {
      $self->sql_splitter->split($_)
    } @_;

  for ( @sql ) {
    s/\s*\n+\s*/ /g;    # put on single line
  }

  return @sql;
}

sub _run_sql {
  my ($self, $filename) = @_;
  log_debug { "Running SQL from $filename" };
  try {
     $self->_run_sql_array($self->_read_sql_file($filename));
  } catch {
     die "failed to run SQL in $filename: $_"
  };
}

my ( %f2p, %p2f );
sub _generate_script_package_name {
    my $file = shift;

    my $pkgbase = 'DBICDH::Sandbox::';
    my $maxlen = 200;    # actual limit is "about 250" according to perldiag

    return $pkgbase . $f2p{"$file"} if $f2p{"$file"};

    my $package = Digest::MD5::md5_hex("$file");
    $package++ while exists $p2f{$package};    # increment until unique

    die "unable to generate a unique short name for '$file'"
      if length($pkgbase) + length($package) > $maxlen;

    $f2p{"$file"} = $package;
    $p2f{$package} = "$file";

    return $pkgbase . $package;
}

sub _load_sandbox {
  my $_file = shift;
  $_file = "$_file";

  my $_package = _generate_script_package_name($_file);

  my $fn = eval sprintf <<'END_EVAL', $_package;
package %s;
{
  our $app;
  $app ||= require $_file;
  if ( !$app && ( my $error = $@ || $! )) { die $error; }
  $app;
}
END_EVAL

  croak $@ if $@;

  croak "$_file should define an anonymous sub that takes a schema but it didn't!"
     unless ref $fn && ref $fn eq 'CODE';

  return $fn;
}

sub _run_perl {
  my ($self, $filename, $versions) = @_;
  log_debug { "Running Perl from $filename" };

  my $fn = _load_sandbox($filename);

  Dlog_trace { "Running Perl $_" } $fn;

  try {
     $fn->($self->schema, $versions)
  } catch {
     die "failed to run Perl in $filename: $_"
  };
}

sub txn_do {
   my ( $self, $code ) = @_;
   return $code->() unless $self->txn_wrap;

   my $guard = $self->schema->txn_scope_guard;

   return preserve_context { $code->() } after => sub { $guard->commit };
}

sub _run_sql_and_perl {
  my ($self, $filenames, $sql_to_run, $versions) = @_;
  my @files   = @{$filenames};
  $self->txn_do(sub {
     $self->_run_sql_array($sql_to_run) if $self->ignore_ddl;

     my $sql = ($sql_to_run)?join ";\n", @$sql_to_run:'';
     FILENAME:
     for my $filename (map file($_), @files) {
       if ($self->ignore_ddl && $filename->basename =~ /^[^-]*-auto.*\.sql$/) {
         next FILENAME
       } elsif ($filename =~ /\.sql$/) {
          $sql .= $self->_run_sql($filename)
       } elsif ( $filename =~ /\.pl$/ ) {
          $self->_run_perl($filename, $versions)
       } else {
         croak "A file ($filename) got to deploy that wasn't sql or perl!";
       }
     }

     return $sql;
  });
}

sub deploy {
  my $self = shift;
  my $version = (shift @_ || {})->{version} || $self->schema_version;
  log_info { "deploying version $version" };
  my $sqlt_type = $self->storage->sqlt_type;
  my $sql;
  my $sqltargs = $self->sql_translator_args;
  if ($self->ignore_ddl) {
     $sql = $self->_sql_from_yaml($sqltargs,
       '_ddl_protoschema_deploy_consume_filenames', $sqlt_type
     );
  }
  return $self->_run_sql_and_perl($self->_ddl_schema_consume_filenames(
    $sqlt_type,
    $version,
  ), $sql, [$version]);
}

sub initialize {
  my $self         = shift;
  my $args         = shift;
  my $version      = $args->{version}      || $self->schema_version;
  log_info { "initializing version $version" };
  my $storage_type = $args->{storage_type} || $self->storage->sqlt_type;

  my @files = @{$self->_ddl_initialize_consume_filenames(
    $storage_type,
    $version,
  )};

  for my $filename (@files) {
    # We ignore sql for now (till I figure out what to do with it)
    if ( $filename =~ /^(.+)\.pl$/ ) {
      my $filedata = do { local( @ARGV, $/ ) = $filename; <> };

      no warnings 'redefine';
      my $fn = eval "$filedata";
      use warnings;

      if ($@) {
        croak "$filename failed to compile: $@";
      } elsif (ref $fn eq 'CODE') {
        $fn->()
      } else {
        croak "$filename should define an anonymous sub but it didn't!";
      }
    } else {
      croak "A file ($filename) got to initialize_scripts that wasn't sql or perl!";
    }
  }
}

sub _sqldiff_from_yaml {
  my ($self, $from_version, $to_version, $db, $direction) = @_;
  my $dir       = $self->script_directory;
  my $sqltargs = {
    add_drop_table => 0,
    ignore_constraint_names => 1,
    ignore_index_names => 1,
    %{$self->sql_translator_args}
  };

  my $source_schema;
  {
    my $prefilename = $self->_ddl_protoschema_produce_filename($from_version, $dir);

    # should probably be a croak
    carp("No previous schema file found ($prefilename)")
       unless -e $prefilename;

    my $t = SQL::Translator->new({
       %{$sqltargs},
       debug => 0,
       trace => 0,
       parser => 'SQL::Translator::Parser::YAML',
    });

    my $out = $t->translate( $prefilename )
      or croak($t->error);

    $source_schema = $t->schema;

    $source_schema->name( $prefilename )
      unless  $source_schema->name;
  }

  my $dest_schema;
  {
    my $filename = $self->_ddl_protoschema_produce_filename($to_version, $dir);

    # should probably be a croak
    carp("No next schema file found ($filename)")
       unless -e $filename;

    my $t = SQL::Translator->new({
       %{$sqltargs},
       debug => 0,
       trace => 0,
       parser => 'SQL::Translator::Parser::YAML',
    });

    my $out = $t->translate( $filename )
      or croak($t->error);

    $dest_schema = $t->schema;

    $dest_schema->name( $filename )
      unless $dest_schema->name;
  }

  my $transform_files_method =  "_ddl_protoschema_${direction}_consume_filenames";
  my $transforms = $self->_coderefs_per_files(
    $self->$transform_files_method([$from_version, $to_version])
  );
  $_->($source_schema, $dest_schema) for @$transforms;

  # SQL::Translator::Diff::schema_diff or rather the underlying
  # SQL::Translator::Diff::produce_diff_sql has severe issues:
  # 1. It is undocumented
  # 2. It wraps the result in "BEGIN; ... COMMIT;" *SIGH*
  # 3. In a first glance it seems it could also return undef in
  #    list context, but the code is broken enough so that part
  #    is never reached. *roll eyes*
  my $i = 0;
  my @stmts = SQL::Translator::Diff::schema_diff(
    $source_schema, $db,
    $dest_schema,   $db,
    { sqlt_args => $sqltargs }
  );

  if (!$self->txn_prep && $self->txn_wrap) {
    pop @stmts;                                         # remove final COMMIT
    ++$i while $stmts[$i] =~ /^-- /;                    # skip leading comments
    splice @stmts, $i, 1 if $stmts[$i] =~ /^BEGIN;/;    # remove first BEGIN;
  }

  return \@stmts;
}

sub _sql_from_yaml {
  my ($self, $sqltargs, $from_file, $db) = @_;
  my $schema    = $self->schema;
  my $version   = $self->schema_version;

  my @sql;

  my $actual_file = $self->$from_file($version);
  for my $yaml_filename (@{(
     DlogS_trace { "generating SQL from Serialized SQL Files: $_" }
        (ref $actual_file?$actual_file:[$actual_file])
  )}) {
     my $sqlt = SQL::Translator->new({
       add_drop_table          => 0,
       parser                  => 'SQL::Translator::Parser::YAML',
       %{$sqltargs},
       producer => $db,
     });

     push @sql, $sqlt->translate($yaml_filename);
     if(!@sql) {
       carp("Failed to translate to $db, skipping. (" . $sqlt->error . ")");
       return undef;
     }
  }
  return \@sql;
}

sub _prepare_install {
  my $self      = shift;
  my $sqltargs  = { %{$self->sql_translator_args}, %{shift @_} };
  my $from_file = shift;
  my $to_file   = shift;
  my $dir       = $self->script_directory;
  my $databases = $self->databases;
  my $version   = $self->schema_version;

  foreach my $db (@$databases) {
    my $sql = $self->_sql_from_yaml($sqltargs, $from_file, $db ) or next;

    my $filename = $self->$to_file($db, $version, $dir);
    if (-e $filename ) {
      if ($self->force_overwrite) {
         carp "Overwriting existing DDL file - $filename";
         unlink $filename;
      } else {
         die "Cannot overwrite '$filename', either enable force_overwrite or delete it"
      }
    }
    open my $file, q(>), $filename;
    binmode $file;
    print {$file} join ";\n", @$sql, '';
    close $file;
  }
}

sub _resultsource_install_filename {
  my ($self, $source_name) = @_;
  return sub {
    my ($self, $type, $version) = @_;
    my $dirname = dir( $self->script_directory, $type, 'deploy', $version );
    $dirname->mkpath unless -d $dirname;

    return "" . file( $dirname, "001-auto-$source_name.sql" );
  }
}

sub _resultsource_protoschema_filename {
  my ($self, $source_name) = @_;
  return sub {
    my ($self, $version) = @_;
    my $dirname = dir( $self->script_directory, '_source', 'deploy', $version );
    $dirname->mkpath unless -d $dirname;

    return "" . file( $dirname, "001-auto-$source_name.yml" );
  }
}

sub install_resultsource {
  my ($self, $args) = @_;
  my $source          = $args->{result_source}
    or die 'result_source must be passed to install_resultsource';
  my $version         = $args->{version}
    or die 'version must be passed to install_resultsource';
  log_info { 'installing_resultsource ' . $source->source_name . ", version $version" };
  my $rs_install_file =
    $self->_resultsource_install_filename($source->source_name);

  my $files = [
     $self->$rs_install_file(
      $self->storage->sqlt_type,
      $version,
    )
  ];
  $self->_run_sql_and_perl($files, [], [$version]);
}

sub prepare_resultsource_install {
  my $self = shift;
  my $source = (shift @_)->{result_source};
  log_info { 'preparing install for resultsource ' . $source->source_name };

  my $install_filename = $self->_resultsource_install_filename($source->source_name);
  my $proto_filename = $self->_resultsource_protoschema_filename($source->source_name);
  $self->prepare_protoschema({
      parser_args => { sources => [$source->source_name], }
  }, $proto_filename);
  $self->_prepare_install({}, $proto_filename, $install_filename);
}

sub prepare_deploy {
  log_info { 'preparing deploy' };
  my $self = shift;
  $self->prepare_protoschema({
      # Exclude version table so that it gets installed separately
      parser_args => {
         sources => [
            sort { $a cmp $b }
            grep { $_ ne $self->version_source }
            $self->schema->sources
         ],
      }
  }, '_ddl_protoschema_produce_filename');
  $self->_prepare_install({}, '_ddl_protoschema_produce_filename', '_ddl_schema_produce_filename');
}

sub prepare_upgrade {
  my ($self, $args) = @_;
  log_info {
     "preparing upgrade from $args->{from_version} to $args->{to_version}"
  };
  $self->_prepare_changegrade(
    $args->{from_version}, $args->{to_version}, $args->{version_set}, 'upgrade'
  );
}

sub prepare_downgrade {
  my ($self, $args) = @_;
  log_info {
     "preparing downgrade from $args->{from_version} to $args->{to_version}"
  };
  $self->_prepare_changegrade(
    $args->{from_version}, $args->{to_version}, $args->{version_set}, 'downgrade'
  );
}

sub _coderefs_per_files {
  my ($self, $files) = @_;
  no warnings 'redefine';
  [map eval do { local( @ARGV, $/ ) = $_; <> }, @$files]
}

sub _prepare_changegrade {
  my ($self, $from_version, $to_version, $version_set, $direction) = @_;
  my $schema    = $self->schema;
  my $databases = $self->databases;
  my $dir       = $self->script_directory;

  my $schema_version = $self->schema_version;
  my $diff_file_method = "_ddl_schema_${direction}_produce_filename";
  foreach my $db (@$databases) {
    my $diff_file = $self->$diff_file_method($db, $version_set, $dir );
    if(-e $diff_file) {
      if ($self->force_overwrite) {
         carp("Overwriting existing $direction-diff file - $diff_file");
         unlink $diff_file;
      } else {
         die "Cannot overwrite '$diff_file', either enable force_overwrite or delete it"
      }
    }

    open my $file, q(>), $diff_file;
    binmode $file;
    print {$file} join ";\n", @{$self->_sqldiff_from_yaml($from_version, $to_version, $db, $direction)};
    close $file;
  }
}

sub _read_sql_file {
  my ($self, $file)  = @_;
  return unless $file;

   local $/ = undef;  #sluuuuuurp

  open my $fh, '<', $file;
  return [ $self->_split_sql_chunk( <$fh> ) ];
}

sub downgrade_single_step {
  my $self = shift;
  my $version_set = (shift @_)->{version_set};
  Dlog_info { "downgrade_single_step'ing $_" } $version_set;

  my $sqlt_type = $self->storage->sqlt_type;
  my $sql_to_run;
  if ($self->ignore_ddl) {
     $sql_to_run = $self->_sqldiff_from_yaml(
       $version_set->[0], $version_set->[1], $sqlt_type, 'downgrade',
     );
  }
  my $sql = $self->_run_sql_and_perl($self->_ddl_schema_downgrade_consume_filenames(
    $sqlt_type,
    $version_set,
  ), $sql_to_run, $version_set);

  return ['', $sql];
}

sub upgrade_single_step {
  my $self = shift;
  my $version_set = (shift @_)->{version_set};
  Dlog_info { "upgrade_single_step'ing $_" } $version_set;

  my $sqlt_type = $self->storage->sqlt_type;
  my $sql_to_run;
  if ($self->ignore_ddl) {
     $sql_to_run = $self->_sqldiff_from_yaml(
       $version_set->[0], $version_set->[1], $sqlt_type, 'upgrade',
     );
  }
  my $sql = $self->_run_sql_and_perl($self->_ddl_schema_upgrade_consume_filenames(
    $sqlt_type,
    $version_set,
  ), $sql_to_run, $version_set);
  return ['', $sql];
}

sub prepare_protoschema {
  my $self      = shift;
  my $sqltargs  = { %{$self->sql_translator_args}, %{shift @_} };
  my $to_file   = shift;
  my $filename
    = $self->$to_file($self->schema_version);

  # we do this because the code that uses this sets parser args,
  # so we just need to merge in the package
  my $sqlt = SQL::Translator->new({
    parser                  => 'SQL::Translator::Parser::DBIx::Class',
    producer                => 'SQL::Translator::Producer::YAML',
    %{ $sqltargs },
  });

  my $yml = $sqlt->translate(data => $self->schema);

  croak("Failed to translate to YAML: " . $sqlt->error)
    unless $yml;

  if (-e $filename ) {
    if ($self->force_overwrite) {
       carp "Overwriting existing DDL-YML file - $filename";
       unlink $filename;
    } else {
       die "Cannot overwrite '$filename', either enable force_overwrite or delete it"
    }
  }

  open my $file, q(>), $filename;
  binmode $file;
  print {$file} $yml;
  close $file;
}

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=2 sw=2 expandtab

__END__

=pod

=head1 NAME

DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator - Manage your SQL and Perl migrations in nicely laid out directories

=head1 DESCRIPTION

This class is the meat of L<DBIx::Class::DeploymentHandler>.  It takes care
of generating serialized schemata  as well as sql files to move from one
version of a schema to the rest.  One of the hallmark features of this class
is that it allows for multiple sql files for deploy and upgrade, allowing
developers to fine tune deployment.  In addition it also allows for perl
files to be run at any stage of the process.

For basic usage see L<DBIx::Class::DeploymentHandler::HandlesDeploy>.  What's
documented here is extra fun stuff or private methods.

=head1 DIRECTORY LAYOUT

Arguably this is the best feature of L<DBIx::Class::DeploymentHandler>.
It's spiritually based upon L<DBIx::Migration::Directories>, but has a
lot of extensions and modifications, so even if you are familiar with it,
please read this.  I feel like the best way to describe the layout is with
the following example:

 $sql_migration_dir
 |- _source
 |  |- deploy
 |     |- 1
 |     |  `- 001-auto.yml
 |     |- 2
 |     |  `- 001-auto.yml
 |     `- 3
 |        `- 001-auto.yml
 |- SQLite
 |  |- downgrade
 |  |  `- 2-1
 |  |     `- 001-auto.sql
 |  |- deploy
 |  |  `- 1
 |  |     `- 001-auto.sql
 |  `- upgrade
 |     |- 1-2
 |     |  `- 001-auto.sql
 |     `- 2-3
 |        `- 001-auto.sql
 |- _common
 |  |- downgrade
 |  |  `- 2-1
 |  |     `- 002-remove-customers.pl
 |  `- upgrade
 |     `- 1-2
 |     |  `- 002-generate-customers.pl
 |     `- _any
 |        `- 999-bump-action.pl
 `- MySQL
    |- downgrade
    |  `- 2-1
    |     `- 001-auto.sql
    |- initialize
    |  `- 1
    |     |- 001-create_database.pl
    |     `- 002-create_users_and_permissions.pl
    |- deploy
    |  `- 1
    |     `- 001-auto.sql
    `- upgrade
       `- 1-2
          `- 001-auto.sql

So basically, the code

 $dm->deploy(1)

on an C<SQLite> database that would simply run
C<$sql_migration_dir/SQLite/deploy/1/001-auto.sql>.  Next,

 $dm->upgrade_single_step([1,2])

would run C<$sql_migration_dir/SQLite/upgrade/1-2/001-auto.sql> followed by
C<$sql_migration_dir/_common/upgrade/1-2/002-generate-customers.pl>, and
finally punctuated by
C<$sql_migration_dir/_common/upgrade/_any/999-bump-action.pl>.

C<.pl> files don't have to be in the C<_common> directory, but most of the time
they should be, because perl scripts are generally database independent.

Note that unlike most steps in the process, C<initialize> will not run SQL, as
there may not even be an database at initialize time.  It will run perl scripts
just like the other steps in the process, but nothing is passed to them.
Until people have used this more it will remain freeform, but a recommended use
of initialize is to have it prompt for username and password, and then call the
appropriate C<< CREATE DATABASE >> commands etc.

=head2 Directory Specification

The following subdirectories are recognized by this DeployMethod:

=over 2

=item C<_source>

This directory can contain the following directories:

=over 2

=item C<deploy>

This directory merely contains directories named after schema
versions, which in turn contain C<yaml> files that are serialized versions
of the schema at that version.  These files are not for editing by hand.

=back

=item C<_preprocess_schema>

This directory can contain the following directories:

=over 2

=item C<downgrade>

This directory merely contains directories named after migrations, which are of
the form C<$from_version-$to_version>.  Inside of these directories you may put
Perl scripts which are to return a subref that takes the arguments C<<
$from_schema, $to_schema >>, which are L<SQL::Translator::Schema> objects.

=item C<upgrade>

This directory merely contains directories named after migrations, which are of
the form C<$from_version-$to_version>.  Inside of these directories you may put
Perl scripts which are to return a subref that takes the arguments C<<
$from_schema, $to_schema >>, which are L<SQL::Translator::Schema> objects.

=back

A typical usage of C<_preprocess_schema> is to define indices or other non-DBIC
type metadata.  Here is an example of how one might do that:

The following coderef could be placed in a file called
F<_preprocess_schema/1-2/001-add-user-index.pl>

 sub {
    my ($from, $to) = @_;

    $to->get_table('Users')->add_index(
       name => 'idx_Users_name',
       fields => ['name'],
    )
 }

This would ensure that in version 2 of the schema the generated migrations
include an index on C<< Users.name >>.  Frustratingly, due to the nature of
L<SQL::Translator>, you'll need to add this to each migration or it will detect
that it was left out and kindly remove the index for you.

An alternative to the above, which is likely to be a lot less annoying, is to
define such data in your schema directly, and only change it as you need to:

 package MyApp::Schema::Result::User;

 #[...]

 sub sqlt_deploy_hook ( $self, $sqlt_table ) {
    $sqlt_table->add_index(name => 'idx_Users_name', fields => [ 'name' ]);
 }

=item C<$storage_type>

This is a set of scripts that gets run depending on what your storage type is.
If you are not sure what your storage type is, take a look at the producers
listed for L<SQL::Translator>.  Also note, C<_common> is a special case.
C<_common> will get merged into whatever other files you already have.  This
directory can contain the following directories itself:

=over 2

=item C<initialize>

If you are using the C<initialize> functionality,
you should call initialize() before calling C<install>. This has the same structure as the
C<deploy> subdirectory as well; that is, it has a directory for each schema
version.  Unlike C<deploy>, C<upgrade>, and C<downgrade> though, it can only run
C<.pl> files, and the coderef in the perl files get no arguments passed to them.

=item C<deploy>

Gets run when the schema is C<deploy>ed.  Structure is a directory per schema
version, and then files are merged with C<_common> and run in filename order.
C<.sql> files are merely run, as expected.  C<.pl> files are run according to
L</PERL SCRIPTS>.

=item C<upgrade>

Gets run when the schema is C<upgrade>d.  Structure is a directory per upgrade
step, (for example, C<1-2> for upgrading from version 1 to version 2,) and then
files are merged with C<_common> and run in filename order.  C<.sql> files are
merely run, as expected.  C<.pl> files are run according to L</PERL SCRIPTS>.

=item C<downgrade>

Gets run when the schema is C<downgrade>d.  Structure is a directory per
downgrade step, (for example, C<2-1> for downgrading from version 2 to version
1,) and then files are merged with C<_common> and run in filename order.
C<.sql> files are merely run, as expected.  C<.pl> files are run according to
L</PERL SCRIPTS>.

=back

=back

Note that there can be an C<_any> in the place of any of the versions (like
C<1-2> or C<1>), which means those scripts will be run B<every> time.  So if
you have an C<_any> in C<_common/upgrade>, that script will get run for every
upgrade.

=head1 PERL SCRIPTS

A perl script for this tool is very simple.  It merely needs to contain an
anonymous sub that takes a L<DBIx::Class::Schema> and the version set as it's
arguments.

A very basic perl script might look like:

 #!perl

 use strict;
 use warnings;

 use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers
    'schema_from_schema_loader';

 schema_from_schema_loader({ naming => 'v4' }, sub {
   my $schema = shift;

   # [1] for deploy, [1,2] for upgrade or downgrade, probably used with _any
   my $versions = shift;

   $schema->resultset('Users')->create({
     name => 'root',
     password => 'root',
   })
 })

Note that the above uses
L<DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers/schema_from_schema_loader>.
Using a raw coderef is strongly discouraged as it is likely to break as you
modify your schema.

=head1 SEE ALSO

This class is an implementation of
L<DBIx::Class::DeploymentHandler::HandlesDeploy>.  Pretty much all the
documentation is there.

=head1 ATTRIBUTES

=head2 ignore_ddl

This attribute will, when set to true (default is false), cause the DM to use
L<SQL::Translator> to use the C<_source>'s serialized SQL::Translator::Schema
instead of any pregenerated SQL.  If you have a development server this is
probably the best plan of action as you will not be putting as many generated
files in your version control.  Goes well with with C<databases> of C<[]>.

=head2 force_overwrite

When this attribute is true generated files will be overwritten when the
methods which create such files are run again.  The default is false, in which
case the program will die with a message saying which file needs to be deleted.

=head2 schema

The L<DBIx::Class::Schema> (B<required>) that is used to talk to the database
and generate the DDL.

=head2 storage

The L<DBIx::Class::Storage> that is I<actually> used to talk to the database
and generate the DDL.  This is automatically created with L</_build_storage>.

=head2 sql_translator_args

The arguments that get passed to L<SQL::Translator> when it's used.

=head2 script_directory

The directory (default C<'sql'>) that scripts are stored in

=head2 databases

The types of databases (default C<< [qw( MySQL SQLite PostgreSQL )] >>) to
generate files for

=head2 txn_prep

This attribute will, when set to false (default is true), cause the DM to
I<generate> SQL without enclosing C<BEGIN> and C<COMMIT> statements.

The (current) default behavior is to create DDLs wrapped in transactions and
to remove anything that looks like a transaction from the generated DDLs
later I<when running the deployment>.

Since this default behavior is error prone it is strictly recommended to set
the C<txn_prep> attribute to false and remove all transaction statements from
previously generated DDLs.

=head2 txn_wrap

Set to true (which is the default) to wrap all upgrades and deploys in a single
transaction. This option should be false if the DDL files contain transaction
statements.

Keep in mind that not all DBMSes support transactions over DDL statements.

=head2 schema_version

The version the schema on your harddrive is at.  Defaults to
C<< $self->schema->schema_version >>.

=head2 version_source

The source name used to register the version storage with C<schema>.  Defaults
to C<__VERSION>.

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <frioux+cpan@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
