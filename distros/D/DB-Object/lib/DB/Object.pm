# -*- perl -*-
##----------------------------------------------------------------------------
## Database Object Interface - ~/lib/DB/Object.pm
## Version v1.8.1
## Copyright(c) 2025 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2017/07/19
## Modified 2025/08/29
## All rights reserved
## 
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
## This is the subclassable module for driver specific ones.
package DB::Object;
BEGIN
{
    require 5.16.0;
    use strict;
    use warnings;
    use warnings::register;
    use parent qw( Module::Generic DBI );
    use vars qw(
        $VERSION $AUTOLOAD $CACHE_DIR $CACHE_SIZE $CONNECT_VIA $DRIVER2PACK
        $ERROR $DEBUG $MOD_PERL $USE_BIND $USE_CACHE $PLACEHOLDER_REGEXP
    );
    use Regexp::Common;
    use Scalar::Util qw( blessed );
    use DB::Object::Cache::Tables;
    use DBI;
    use JSON;
    use Module::Generic::File qw( sys_tmpdir );
    use Module::Generic::Global qw( :const );
    use POSIX ();
    use Wanted;
    our $PLACEHOLDER_REGEXP = qr/\b\?\b/;
    our $VERSION = 'v1.8.1';
};

use strict;
use warnings;

our $DEBUG         = 0;
# A global setting variable. This is not changed dynamically, and can be set by the user
our $CACHE_SIZE    = 10;
our $USE_BIND      = 0;
our $USE_CACHE     = 0;
our $MOD_PERL      = 0;
# A global variable that can be set by the user to serve as a default value
our $CACHE_DIR     = '';
if( $INC{ 'Apache/DBI.pm' } && 
    substr( $ENV{GATEWAY_INTERFACE}|| '', 0, 8 ) eq 'CGI-Perl' )
{
    $CONNECT_VIA = "Apache::DBI::connect";
    $MOD_PERL++;
}
# Global constant
our $DRIVER2PACK = 
{
    mysql  => 'DB::Object::Mysql',
    Pg     => 'DB::Object::Postgres',
    SQLite => 'DB::Object::SQLite',
};

sub new
{
    my $that  = shift( @_ );
    my $class = ref( $that ) || $that;
    my $self  = {};
    bless( $self, $class );
    return( $self->init( @_ ) );
}

sub init
{
    my $self = shift( @_ );
    $self->{cache_connections} = 1;
    $self->{cache_dir} = sys_tmpdir();
    $self->{cache_table} = 0;
    $self->{driver} = '';
    # Auto-decode json data into perl hash
    $self->{auto_decode_json} = 1;
    $self->{auto_convert_datetime_to_object} = 0;
    $self->{allow_bulk_delete} = 0;
    $self->{allow_bulk_update} = 0;
    $self->{unknown_field}     = 'ignore';
    $self->{_init_strict_use_sub} = 1;
    $self->Module::Generic::init( @_ ) || return( $self->pass_error );
    return( $self );
}

sub allow_bulk_delete { return( shift->_set_get_scalar( 'allow_bulk_delete', @_ ) ); }

sub allow_bulk_update { return( shift->_set_get_scalar( 'allow_bulk_update', @_ ) ); }

sub ALL { return( shift->_operator_object_create( 'DB::Object::ALL', @_ ) ); }

sub AND { return( shift->_operator_object_create( 'DB::Object::AND', @_ ) ); }

sub ANY { return( shift->_operator_object_create( 'DB::Object::ANY', @_ ) ); }

sub auto_convert_datetime_to_object { return( shift->_set_get_scalar( 'auto_convert_datetime_to_object', @_ ) ); }

sub auto_decode_json { return( shift->_set_get_scalar( 'auto_decode_json', @_ ) ); }

sub attribute($;$@)
{
    my $self = shift( @_ );
    # $h->{AttributeName} = ...;    # set/write
    # ... = $h->{AttributeName};    # get/read
    # 1 means that the attribute may be modified
    # 0 mneas that the attribute may only be read
    my $name  = shift( @_ ) if( @_ == 1 );
    my %arg   = ( @_ );
    my %attr =
    (
        Active              => 0,
        ActiveKids          => 0,
        AutoCommit          => 1,
        AutoInactiveDestroy => 1,
        CachedKids          => 0,
        Callbacks           => 1,
        ChildHandles        => 0,
        ChopBlanks          => 1,
        CompatMode          => 1,
        CursorName          => 0,
        ErrCount            => 0,
        Executed            => 0,
        FetchHashKeyName    => 0,
        HandleError         => 1,
        HandleSetErr        => 1,
        InactiveDestroy     => 1,
        Kids                => 0,
        LongReadLen         => 1,
        LongTruncOk         => 1,
        NAME                => 0,
        NULLABLE            => 0,
        NUM_OF_FIELDS       => 0,
        NUM_OF_PARAMS       => 0,
        Name                => 0,
        PRECISION           => 0,
        PrintError          => 1,
        PrintWarn           => 1,
        Profile             => 0,
        RaiseError          => 1,
        ReadOnly            => 1,
        RowCacheSize        => 0,
        RowsInCache         => 0,
        SCALE               => 0,
        ShowErrorStatement  => 1,
        Statement           => 0,
        TYPE                => 0,
        Taint               => 1,
        TaintIn             => 1,
        TaintOut            => 1,
        TraceLevel          => 1,
        Type                => 0,
        Warn                => 1,
    );
    # Only those attribute exist
    # Using an a non existing attribute produce an exception, so we better avoid
    if( $name )
    {
        return( $self->{dbh}->{ $name } ) if( exists( $attr{ $name } ) );
    }
    else
    {
        my $value;
        while( ( $name, $value ) = each( %arg ) )
        {
            # We intend to modifiy the value of an attribute
            # we are allowed to modify this value if it is true
            if( exists( $attr{ $name } ) && 
                defined( $value ) && 
                $attr{ $name } )
            {
                $self->{dbh}->{ $name } = $value;
            }
        }
    }
}

sub available_drivers(@)
{
    my $self = shift( @_ );
    my $class = ref( $self ) || $self;
    # @ary = DBI->available_drivers( $quiet );
    return( $class->SUPER::available_drivers( 1 ) );
}

sub base_class
{
    my $self = shift( @_ );
    my @supported_classes = $self->supported_class;
    push( @supported_classes, 'DB::Object' );
    my $ok_classes = join( '|', @supported_classes );
    my $class = ref( $self ) ? ref( $self ) : $self;
    my $base_class = ( $class =~ /^($ok_classes)/ )[0];
    return( $base_class );
}

# This method is common to DB::Object and DB::Object::Statement
sub bind
{
    my $self = shift( @_ );
    # Usage:
    # This activate the binding stuff
    # $dbh->bind() or $dbh->bind->where( "something" ) or $dbh->bind->select->fetchrow_hashref();
    # Later, $dbh->bind( 'thingy' )->select->fetchrow_hashref()
    # When used like $table->bind; this means the user is setting the use bind option as a setting for all transactions, but
    # when used like $table->bind->select then the use bind option is only used for this transaction only and is reset after
    $self->{bind} = want('VOID') 
        ? 2 
        # Otherwise is it already set maybe?
        : $self->{bind} 
            # Then use it
            ? $self->{bind} 
            : 1;
    if( @_ )
    {
        # If we are using the cache system, we search the object of this query
        my $obj = '';
        # Ensure that we have something to look for at the least
        # my $queries = $self->{queries};
        my $queries = $self->_cache_queries;
        my $base_class = $self->base_class;
        if( $self->isa( "${base_class}::Statement" ) )
        {
            $obj = $self;
        }
        elsif( $self->{cache} && @$queries )
        {
            $obj = $queries->[0];
        }
        # Otherwise, our object is the statement object to use
        else
        {
            $obj = $self;
        }
        $obj->{binded} = [ @_ ];
        # Since new binded parameters have been passed, since mean a new request to the
        # same statement is pending, so we need to re-execute the statement
        # and since most of the fetch method rely on AUTOLOAD that call
        # execute() automatically *IF* the statement was not already executed....
        # we need to delete 'executed' value or set it to false, so the statement gets re-executed
        $obj->{executed} = 0;
        return( $obj );
    }
    return( $self );
}

sub cache
{
    my $self = shift( @_ );
    # activate cache
    # So we may be called as: $tbl->cache->select->fetchrow_hashref();
    $self->{cache}++;
    return( $self );
}

sub cache_connections { return( shift->_set_get_boolean( 'cache_connections', @_ ) ); }
# {
#     my $self = shift( @_ );
#     $self->{_cache_connections} = shift( @_ ) if( @_ );
#     return( $self->{_cache_connections} );
# }

sub cache_dir { return( shift->_set_get_scalar( 'cache_dir', @_ ) ); }

sub cache_query_get
{
    my $self = shift( @_ );
    my $name = shift( @_ ) || return( $self->error( "No name for this query cache was provided." ) );
    my $base_class = $self->base_class;
    # This is slightly confusing, but this is different from the other repository 'cache_queries', which is an array reference
    my $repo = Module::Generic::Global->new( 'queries_cache' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $cache = $repo->get // {};
    return( $self->error( "The queries cache repository data is not an hash reference." ) ) if( ref( $cache ) ne 'HASH' );
    return( $cache->{ $name } );
}

sub cache_query_set
{
    my $self = shift( @_ );
    my $name = shift( @_ ) || return( $self->error( "No name for this query cache was provided." ) );
    my $sth  = shift( @_ ) || return( $self->error( "No statement handler was provided." ) );
    my $base_class = $self->base_class;
    # This is slightly confusing, but this is different from the other repository 'cache_queries', which is an array reference
    my $repo = Module::Generic::Global->new( 'queries_cache' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    $repo->lock;
    my $cache = $repo->get // {};
    $cache->{ $name } = $sth;
    $repo->set( $cache );
    $repo->unlock;
    return( $sth );
}

sub cache_table { return( shift->_set_get_boolean( 'cache_table', @_ ) ); }

sub cache_tables { return( shift->_set_get_object( 'cache_tables', 'DB::Object::Cache::Tables', @_ ) ); }

sub check_driver()
{
    my $self   = shift( @_ );
    my $driver = shift( @_ ) || return( $self->error( "No SQL driver provided to check" ) );
    my $ok     = undef();
    local $_;
    my @drivers = $self->available_drivers();
    foreach( @drivers ) 
    {
        if( m/$driver/s )
        {
            $ok++;
            last;
        }
    }
    return( $ok );
}

sub connect
{
    my $this  = shift( @_ );
    my $class = ref( $this ) || $this;
    my $opts  = $this->_get_args_as_hash( @_ );
    # We pass the arguments so that debug and other init parameters can be set early
    my $that  = ref( $this ) ? $this : $this->Module::Generic::new( debug => $opts->{debug} );
    my $param = $that->_connection_params2hash( $opts ) || return( $this->error( "No valid connection parameters found" ) );
    my $driver2pack = 
    {
        mysql  => 'DB::Object::Mysql',
        Pg     => 'DB::Object::Postgres',
        SQLite => 'DB::Object::SQLite',
    };
    return( $that->error( "No driver was provided." ) ) if( !exists( $param->{driver} ) );
    if( !exists( $driver2pack->{ $param->{driver} } ) )
    {
        return( $that->error( "Driver $param->{driver} is not supported." ) );
    }
    # For example, will make this object a DB::ObjectD::Postgres object
    my $driver_class = $driver2pack->{ $param->{driver} };
    my $driver_module = $driver_class;
    $driver_module =~ s|::|/|g;
    $driver_module .= '.pm';
    eval
    {
        local $DEBUG;
        require $driver_module;
    };
    return( $that->error( "Unable to load module $driver_class ($driver_module): $@" ) ) if( $@ );
    my $self = $driver_class->new || return( $this->error( "Cannot get object from package $driver_class" ) );
    $self->debug(
        CORE::exists( $param->{debug} )
            ? CORE::delete( $param->{debug} )
            : CORE::exists( $param->{Debug} )
                ? CORE::delete( $param->{Debug} )
                : $DEBUG
    );
    $self->cache_dir(
        CORE::exists( $param->{cache_dir} )
            ? CORE::delete( $param->{cache_dir} )
            : CORE::exists( $that->{cache_dir} )
                ?  $that->{cache_dir}
                : $CACHE_DIR
    );
    $self->{unknown_field} = CORE::delete( $param->{unknown_field} ) if( CORE::exists( $param->{unknown_field} ) );

    $param = $self->_check_connect_param( $param ) || return( $self->pass_error );
    my $opt = {};
    if( exists( $param->{opt} ) )
    {
        $opt = CORE::delete( $param->{opt} );
        $opt = $self->_check_default_option( $opt );
    }
    # print( STDERR ref( $self ), "::connect(): \$param is: ", $self->dumper( $param ), "\n" );
    $self->{database} = CORE::exists( $param->{database} )
        ? CORE::delete( $param->{database} )
        : CORE::exists( $param->{db} )
            ? CORE::delete( $param->{db} )
            : undef();
    $self->{host} = CORE::exists( $param->{host} )
        ? CORE::delete( $param->{host} )
        : CORE::exists( $param->{server} )
            ? CORE::delete( $param->{server} )
            : undef();
    $self->{port} = CORE::delete( $param->{port} );
    # $self->{database} = CORE::delete( $param->{ 'db' } );
    $self->{login} = CORE::delete( $param->{login} );
    $self->{passwd} = CORE::delete( $param->{passwd} );
    $self->{driver} = CORE::delete( $param->{driver} );
    $self->{cache} = CORE::exists( $param->{use_cache} )
        ? CORE::delete( $param->{use_cache} )
        : $USE_CACHE;
    $self->{bind} = CORE::exists( $param->{use_bind} )
        ? CORE::delete( $param->{use_bind} )
        : $USE_BIND;
    # Needed to be specified if the user does not want to cache connections
    # Will be used in _dbi_connect()
    $self->{cache_connections} = CORE::delete( $param->{cache_connections} ) if( CORE::exists( $param->{cache_connections} ) );
    $self->{cache_table} = CORE::delete( $param->{cache_table} ) if( CORE::exists( $param->{cache_table} ) );

    # If parameters starting with an upper case are provided, they are DBI database parameters
    #my @dbi_opts = grep( /^[A-Z][a-zA-Z]+/, keys( %$param ) );
    #@$opt{ @dbi_opts } = @$param{ @dbi_opts };

    if( my $driver = $self->driver )
    {
        my $drh = $self->SUPER::install_driver( $driver ) ||
            return( $that->pass_error( $self->error ) );
        $self->{drh} = $drh;
    }
    $opt->{RaiseError} = 0 if( !CORE::exists( $opt->{RaiseError} ) );
    $opt->{AutoCommit} = 1 if( !CORE::exists( $opt->{AutoCommit} ) );
    $opt->{PrintError} = 0 if( !CORE::exists( $opt->{PrintError} ) );
    $self->{opt} = $opt;
    my $dbh = $self->_dbi_connect || return( $that->pass_error( $self->error ) );
    $self->{dbh} = $dbh;
    #$self->param(
    #  ## Do not allow SELECT that will take too long or too much resource, i.e. over 2Gb of data
    #  ## This is idiot proof mode
    #  'SQL_BIG_SELECTS'    => 0,
    #  ## SQL will abort if a DELETE or UPDATE is being executed w/o LIMIT nor WHERE clause
    #  'SQL_SAFE_MODE'    => 1,
    #);
    local $/ = "\n";
    my $tables = [];
    # 1 day
    # my $tbl_cache_timeout = 86400;
    my $host = $self->host || 'localhost';
    my $port = $self->port || 0;
    my $driver = $self->driver;
    my $database = $self->database;
    my $cache_params = {};
    if( my $cache_dir = $self->cache_dir )
    {
        $cache_params->{cache_dir} = $cache_dir;
    }
    $cache_params->{debug} = $self->debug;
    my $cache_tables = DB::Object::Cache::Tables->new( $cache_params );
    $self->cache_tables( $cache_tables );
    $tables = $self->tables_info;
    my $cache = 
    {
        host => $host,
        driver => $driver,
        port => $port,
        database => $database,
        tables => $tables,
    };
    if( !defined( $cache_tables->set( $cache ) ) )
    {
        warn( "Unable to write to tables cache: ", $cache_tables->error, "\n" );
    }
    return( $self );
}

sub constant_queries_cache
{
    my $self = shift( @_ );
    my $base_class = $self->base_class;
    my $repo = Module::Generic::Global->new( 'constant_queries' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $cache = $repo->get // {};
    return( $cache );
}

sub constant_queries_cache_get
{
    my( $self, $def ) = @_;
    my $base_class = $self->base_class;
    my $repo = Module::Generic::Global->new( 'constant_queries' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $hash = $repo->get // {};
    return( $self->error( "Parameter provided must be a hash, but I got '", $self->_str_val( $def // 'undef' ), "'." ) ) if( !defined( $def ) || ref( $def // '' ) ne 'HASH' );
    foreach my $k ( qw( pack file line ) )
    {
        return( $self->error( "Parameter \"$k\" is missing from the hash." ) ) if( !CORE::length( $def->{ $k } // '' ) );
    }
    my $key = CORE::join( '|', @$def{qw( pack file line )} );
    my $ref = $hash->{ $key };
    # $ts is thee timestamp of the file recorded at the time
    my $ts = $ref->{ts};
    # A DB::Object::Statement object
    my $qo = $ref->query_object;
    return if( !CORE::length( $def->{file} ) );
    return if( !-e( $def->{file} ) );
    return if( ( CORE::stat( $def->{file} ) )[9] != $ts );
    return( $self->error( "Query object retrieved from constant query cache is void!" ) ) if( !$qo );
    return( $self->error( "Query object retrieved from constant query cache is not a DB::Object::Query object or one of its sub classes." ) ) if( !$self->_is_object( $qo ) || !$qo->isa( 'DB::Object::Query' ) );
    return if( $self->database ne $qo->database_object->database );
    return( $self->_cache_this( $qo ) );
}

sub constant_queries_cache_set
{
    my( $self, $def ) = @_;
    my $base_class = $self->base_class;
    my $repo = Module::Generic::Global->new( 'constant_queries' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    $repo->lock;
    my $hash = $repo->get // {};
    foreach my $k ( qw( pack file line query_object ) )
    {
        $repo->unlock;
        return( $self->error( "Parameter \"$k\" is missing from the hash." ) ) if( !CORE::length( $def->{ $k } // '' ) );
    }
    if( !$self->_is_object( $def->{query_object} ) ||
        !$def->{query_object}->isa( 'DB::Object::Query' ) )
    {
        $repo->unlock;
        return( $self->error( "Provided query object is not a DB::Object::Query." ) );
    }
    $def->{ts} = [CORE::stat( $def->{file} )]->[9];
    my $key = CORE::join( '|', @$def{qw( pack file line )} );
    $hash->{ $key } = $def;
    $repo->set( $hash );
    $repo->unlock;
    return( $def );
}

# See also datatype_to_constant()
sub constant_to_datatype
{
    my $self = shift( @_ );
    return unless( scalar( @_ ) && defined( $_[0] ) );
    my $this = shift( @_ );
    my $ref = $self->datatypes;
    foreach my $t ( keys( %$ref ) )
    {
        return( $t ) if( $ref->{ $t } eq $this );
    }
    return;
}

sub copy
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    my $ref = $self->select->fetchrow_hashref();
    my $keys = keys( %$opts );
    @$ref{ @$keys } = @$opts{ @$keys };
    return(0) if( !scalar( keys( %$ref ) ) );
    $self->insert( $ref );
    return(1);
}

sub create_db { return( shift->error( "The driver has not implemented the create database method create_db." ) ); }

sub create_table { return( shift->error( "The driver has not implemented the create table method create_table." ) ); }

sub data_sources($;\%)
{
    my $self  = shift( @_ );
    my $class = ref( $self ) || $self;
    my $opt;
    $opt = shift( @_ ) if( @_ );
    my $driver = $self->{driver} || return( $self->error( "No driver to to use to check for data sources." ) );
    return( $class->SUPER::data_sources( $driver, $opt ) );
}

sub data_type
{
    my $self = shift( @_ );
    my $type = @_ == 1 ? shift( @_ ) : [ @_ ] if( @_ );
    my $ref  = eval
    {
        local $SIG{__DIE__}  = sub{ };
        local $SIG{__WARN__} = sub{ };
        $self->{dbh}->type_info_all();
    };
    return( $self->error( "type_info_all() is unsupported by vendor '$self->{ 'driver' }'." ) ) if( $@ );
    # First item is a reference to hash containing the order of the header
    my $header   = shift( @$ref );
    my $hash     = {};
    my $name_idx = $header->{TYPE_NAME};
    my @found = ();
    if( $type )
    {
        my @types = ref( $type ) ? @$type : ( $type );
        foreach my $requested ( @types )
        {
            push( @found, grep{ uc( $requested ) eq $_->[ $name_idx ] } @$ref );
        }
    }
    else
    {
        @found = @$ref;
    }
    # Stop. No need to go further
    return( wantarray() ? () : undef() ) if( !@found );
    my @names = map{ lc( $_ ) } keys( %$header );
    my $len   = scalar( keys( %$header ) );
    my @order = values( %$header );
    map
    {
        next if( @$_ != $len );
        my %data;
        @data{ @names } = @{ $_ }[ @order ];
        $hash->{ lc( $_->[ $name_idx ] ) } = \%data;
    } @found;
    return( wantarray() ? () : undef() ) if( !%$hash );
    return( wantarray() ? %$hash : $hash );
}

sub database
{
    # Read only
    return( shift->{database} );
}

sub databases { return( shift->error( "Method databases() is not implemented by driver." ) ); }

sub datatype_dict
{
    my $self = shift( @_ );
    my $class = ( ref( $self ) || $self );
    no strict 'refs';
    my $sym = $self->_get_symbol( $class => '$DATATYPES_DICT' );
    if( !defined( $sym ) )
    {
        return( $self->pass_error ) if( $self->error );
        return( $self->error( "No global variable \$DATATYPES_DICT defined in class $class" ) );
    }
    my $dict = $$sym;
    return( $self->error( "Symbol found for \$DATATYPES_DICT in class $class did not resolve into an expecxted hash reference." ) ) if( ref( $dict ) ne 'HASH' );
    if( @_ )
    {
        return( $dict->{ lc( shift( @_ ) ) } );
    }
    return( $dict );
}

# See also constant_to_datatype()
sub datatype_to_constant
{
    my $self = shift( @_ );
    my $ref = $self->datatypes || return( $self->pass_error );
    return unless( scalar( @_ ) && defined( $_[0] ) );
    return( $ref->{ lc( shift( @_ ) ) } );
}

# Returns an hash of SQL constant name to its value
sub datatypes
{
    my $self = shift( @_ );
    my $dict = $self->datatype_dict || return( $self->pass_error );
    my $ref = +{ map{ $_ => $dict->{ $_ }->{constant} } keys( %$dict ) };
    return( $ref );
}

sub disconnect($)
{
    my $self = shift( @_ );
    # my( $pack, $file, $line ) = caller();
    # print( STDERR "disconnect() called from package '$pack' in file '$file' at line '$line'.\n" );
    my $rc = $self->{dbh}->disconnect( @_ );
    return( $rc );
}

sub do($;$@)
{
    my $self = shift( @_ );
    # $rc  = $dbh->do( $statement )           || die( $dbh->errstr );
    # $rc  = $dbh->do( $statement, \%attr )   || die( $dbh->errstr );
    # $rv  = $dbh->do( $statement, \%attr, @bind_values ) || ...
    # my( $rows_deleted ) = $dbh->do( 
    # q{
    #     DELETE FROM table WHERE status = ?
    # }, undef(), 'DONE' ) || die( $dbh->errstr );
    my $query     = shift( @_ );
    my $opt_ref   = shift( @_ ) || undef();
    my $param_ref = shift( @_ ) || [];
    my $dbh = $self->can( 'database_object' ) ? $self->database_object : $self;
    $dbh or return( $self->error( "Could not find database handler." ) );
    my $sth = $dbh->prepare( $query, $opt_ref ) || 
        return( $self->error( "Error while preparing do query:\n$query", $dbh->errstr() ) );
    $sth->execute( @$param_ref ) || 
        return( $self->error( "Error while executing do query:\n$query", $sth->errstr() ) );
    # my $rows = $sth->rows();
    # return( ( $rows == 0 ) ? "0E0" : $rows );
    return( $sth );
}

sub driver { return( shift->_set_get( 'driver' ) ); }

sub enhance
{
    my $self = shift( @_ );
    my $prev = $self->{enhance};
    $self->{enhance} = shift( @_ ) if( @_ );
    return( $prev );
}

sub err(@)
{
    my $self = shift( @_ );
    # $rv = $h->err;
    if( defined( $self->{sth} ) )
    {
        return( $self->{sth}->err() );
    }
    elsif( $self->{dbh} )
    {
        return( $self->{dbh}->err() );
    }
    #else
    #{
        # return( $self->{ 'drh' }->err() );
    # return( DBI::err();
    #}
}

sub errno
{
    goto( &err );
}

sub errmesg
{
    goto( &errstr );
}

sub errstr(@)
{
    my $self = shift( @_ );
    if( !ref( $self ) )
    {
        return( $DBI::errstr );
    }
    elsif( defined( $self->{sth} ) && $self->{sth}->errstr() )
    {
        return( $self->{sth}->errstr() );
    }
    elsif( defined( $self->{dbh} ) && $self->{dbh}->errstr() )
    {
        return( $self->{dbh}->errstr() );
    }
    else
    {
        return( $self->{errstr} );
    }
}

sub FALSE { return( 'FALSE' ); }

sub fatal
{
    my $self = shift( @_ );
    if( @_ )
    {
        $self->{fatal} = int( shift( @_ ) );
    }
    return( $self->{fatal} );
}

sub get_sql_type { return( shift->error( "The driver has not provided support for this method get_sql_type()" ) ); }

sub host { return( shift->_set_get_scalar( 'host', @_ ) ); }

sub IN { return( shift->_operator_object_create( 'DB::Object::IN', @_ ) ); }

# $rv = $dbh->last_insert_id($catalog, $schema, $table, $field, \%attr);
sub last_insert_id
{
    my $self = shift( @_ );
    return( $self->error( "Method \"last_insert_id\" has not been implemented by driver $self->{driver} (object = $self)." ) );
}

sub LIKE { return( shift->_operator_object_create( 'DB::Object::LIKE', @_ ) ); }

sub lock
{
    my $self = shift( @_ );
    return( $self->error( "Method \"lock\" has not been implemented by driver $self->{driver} (object = $self)." ) );
}

sub login { return( shift->_set_get_scalar( 'login', @_ ) ); }

# This value will be passed on to newly instantiated DB::Object::Tables objects
sub no_bind { return( shift->_set_get_boolean( 'no_bind', @_ ) ); }

sub no_cache
{
    my $self = shift( @_ );
    $self->{cache} = 0;
    return( $self );
}

sub NOT { return( shift->_operator_object_create( 'DB::Object::NOT', @_ ) ); }

sub NULL { return( 'NULL' ); }

sub OR { return( shift->_operator_object_create( 'DB::Object::OR', @_ ) ); }

sub P { return( shift->placeholder( @_ ) ); }

sub param
{
    my $self = shift( @_ );
    return if( !@_ );
    my @supported = 
    qw( 
        SQL_AUTO_IS_NULL AUTOCOMMIT SQL_BIG_TABLES SQL_BIG_SELECTS
        SQL_BUFFER_RESULT SQL_LOW_PRIORITY_UPDATES SQL_MAX_JOIN_SIZE 
        SQL_SAFE_MODE SQL_SELECT_LIMIT SQL_LOG_OFF SQL_LOG_UPDATE 
        TIMESTAMP INSERT_ID LAST_INSERT_ID 
    );
    my $params = $self->{params} ||= {};
    if( @_ == 1 )
    {
        my $type = shift( @_ );
        $type    = uc( $type ) if( scalar( grep{ /^$_[ 0 ]$/i } @supported ) );
        return( $params->{ $type } );
    }
    else
    {
        my %arg = ( @_ );
        my( $type, $value );
        my @query = ();
        while( ( $type, $value ) = each( %arg ) )
        {
            my @found = grep{ /^(SQL_)?$type$/i } @supported;
            # SQL parameter
            if( scalar( @found ) )
            {
                $type     = uc( $type );
                $value    = 0 if( !defined( $value ) || $value eq '' );
                $params->{ $type } = $value;
                if( $type eq 'AUTOCOMMIT' && $self->{dbh} && $value =~ /^(?:1|0)$/ )
                {
                    $self->{dbh}->{AutoCommit} = $value;
                }
                push( @query, "$type = $value" );
            }
            # Private parameter - May be anything
            else
            {
                $params->{ $type } = $value;
            }
        }
        return( $self ) if( !scalar( @query ) );
        my $dbh = $self->{dbh} || return( $self->error( "Could not find database handler." ) );
        my $query = 'SET ' . CORE::join( ', ', @query );
        my $sth = $dbh->prepare( $query ) ||
        return( $self->error( "Unable to set options '", CORE::join( ', ', @query ), "'" ) );
        $sth->execute();
        $sth->finish();
        return( $self );
    }
}

sub passwd { return( shift->_set_get_scalar( 'passwd', @_ ) ); }

sub ping(@)
{
    #return( shift->{ 'dbh' }->ping );
    my $self = shift( @_ );
    return( $self->{dbh}->ping );
}

sub ping_select(@)
{
    my $self = shift( @_ );
    # $rc = $dbh->ping;
    # Some new ping method replacement.... See Apache::DBI
    # my( $dbh ) = @_;
    my $ret = 0;
    eval 
    {
        local( $SIG{__DIE__}  ) = sub{ return( 0 ); };
        local( $SIG{__WARN__} ) = sub{ return( 0 ); };
        # adapt the select statement to your database:
        my $sth = $self->prepare( "SELECT 1" );
        $ret = $sth && ( $sth->execute() );
        $sth->finish();
    };
    return( ($@)  ? 0 : $ret );
}

sub placeholder
{
    my $self = shift( @_ );
    $self->_load_class( 'DB::Object::Placeholder' ) || return( $self->pass_error );
    my $opts = $self->_get_args_as_hash( @_ );
    $opts->{debug} = $self->debug if( !exists( $opts->{debug} ) );
    my $obj = DB::Object::Placeholder->new( %$opts ) ||
        return( $self->pass_error( DB::Object::Placeholder->error ) );
    return( $obj );
}

sub port { return( shift->_set_get_number( 'port', @_ ) ); }

# Gateway to DB::Object::Statement
sub prepare($;$)
{
    my $self    = shift( @_ );
    my $class   = ref( $self ) || $self;
    my $query   = shift( @_ );
    my $opt_ref = shift( @_ ) || undef();
    my $base_class = $self->base_class;
    my $q;
    if( $self->_is_a( $query => 'DB::Object::Query' ) )
    {
        $q = $query;
        $query = $q->as_string;
    }
    elsif( $self->_is_a( $self => 'DB::Object::Tables' ) )
    {
        $q = $self->query_object;
    }
    $self->_clean_statement( \$query );
    # Wether we are called from DB::Object or DB::Object::Tables object
    my $dbo = $self->{dbo} || $self;
    if( !$dbo->ping )
    {
        my $dbh = $dbo->_dbi_connect || return;
        $self->{dbh} = $dbo->{dbh} = $dbh;
    }
    local $@;
    my $sth = eval
    {
        local( $SIG{__DIE__} )  = sub{ };
        local( $SIG{__WARN__} ) = sub{ };
        $dbo->{dbh}->prepare( $query, $opt_ref );
    };
    if( $sth )
    {
        # my $data = { 'sth' => $sth, 'query' => $query };
        my( $query_values, $sel_fields );
        if( $q )
        {
            $query_values = $q->query_values;
            $sel_fields   = $q->selected_fields;
        }
        my $data = 
        {
            sth             => $sth,
            query           => $query,
            # query_values    => $q->query_values,
            # selected_fields => $q->selected_fields,
            ( defined( $query_values ) ? ( query_values => $query_values ) : () ),
            ( defined( $sel_fields ) ? ( selected_fields => $sel_fields ) : () ),
            query_object    => $q,
        };
        return( $self->_make_sth( "${base_class}::Statement", $data ) );
    }
    else
    {
        my $err = $@ || $self->{dbh}->errstr() || 'Unknown error while cache preparing query.';
        $self->{query} = $query;
        return( $self->error( $err ) );
    }
}

sub prepare_cached
{
    my $self    = shift( @_ );
    my $class   = ref( $self ) || $self;
    my $query   = shift( @_ );
    my $opt_ref = shift( @_ ) || undef();
    my $base_class = $self->base_class;
    my $q;
    if( ref( $q ) && $q->isa( 'DB::Object::Query' ) )
    {
        $q = $query;
        $query = $q->as_string;
    }
    $self->_clean_statement( \$query );
    # Wether we are called from DB::Object or DB::Object::Tables object
    my $dbo = $self->{dbo} || $self;
    if( !$dbo->ping )
    {
        my $dbh = $dbo->_dbi_connect || return;
        $self->{dbh} = $dbo->{dbh} = $dbh;
    }
    my $sth = eval
    {
        local( $SIG{__DIE__} )  = sub{ };
        local( $SIG{__WARN__} ) = sub{ };
        $dbo->{dbh}->prepare_cached( $query, $opt_ref );
    };
    if( $sth )
    {
        # my $data = { %$self, 'sth' => $sth, 'query' => $query };
        # my $data = { 'sth' => $sth, 'query' => $query };
        my $data = 
        {
            sth             => $sth,
            query           => $query,
            query_values    => $self->{query_values},
            selected_fields => $self->{selected_fields},
            query_object    => $q,
        };
        # CORE::delete( $data->{ 'executed' } );
        # This is an inner package
        # bless( $data, "DB::Object::Statement" );
        # return( $data );
        return( $self->_make_sth( "${base_class}::Statement", $data ) );
    }
    else
    {
        my $err = $@ || $self->{dbh}->errstr() || 'Unknown error while cache preparing query.';
        $self->{query} = $query;
        return( $self->error( $err ) );
    }
}

sub query($$)
{
    my $self = shift( @_ );
    my $sth  = $self->prepare( @_ );
    my $result;
    if( $sth && !( $result = $sth->execute() ) )
    {
        return;
    }
    else
    {
        # bless( $sth, ref( $self ) );
        return( $sth );
    }
}

sub query_object { return( shift->_set_get_object_without_init( 'query_object', 'DB::Object::Query', @_ ) ); }

sub quote
{
    my $self = shift( @_ );
    # my $dbh = $self->{dbh} || return( $self->error( "No database handler was set." ) );
    my $dbh;
    unless( $dbh = $self->{dbh} )
    {
        # This is a fallback in case we need to use quote, but do not have a database connection yet.
        my $str = shift( @_ );
        # print( STDERR ref( $self ), "::quote -> \$str is '$str' (without surrounding quote\n" );
        return( $self->NULL ) if( !defined( $str ) || uc( $str ) eq 'NULL' );
        if( $str =~ /^$RE{num}{real}$/ )
        {
            return( $str );
        }
        else
        {
            $str =~ s/'/''/g; # iso SQL 2
            return( "'$str'" );
        }
    }
    return( $dbh->quote( @_ ) );
}

sub set
{
    my $self = shift( @_ );
    my $vars = '';
    $vars    = shift( @_ );
    $vars  ||= $self->local();
    # Are there any variable declaration?
    if( $vars )
    {
        my $query = "SET $vars";
        eval
        {
            local( $SIG{__DIE__} )  = sub{ };
            local( $SIG{__WARN__} ) = sub{ };
            local( $SIG{ALRM} )     = sub{ die( "Timeout while processing query to set variables:\n$query\n" ) };
            $self->do( $query );
        };
        if( $@ )
        {
            my $err = '*** ' . join( "\n*** ", split( /\n/, $@ ) );
            if( $self->fatal() )
            {
                die( "Error occured while setting SQL variables before executing query:\n$self->{sth}->{Statement}\n$err\n" );
            }
            else
            {
                return( $self->error( $@ ) );
            }
        }
    }
    return(1);
}

# To also consider:
# $sth = $dbh->statistics_info( undef, $schema, $table, $unique_only, $quick );
sub stat
{
    my $self = shift( @_ );
    my $type = lc( shift( @_ ) );
    my $sth  = $self->prepare( "SHOW STATUS" );
    $sth->execute();
    my @data = ();
    my $ref  = {};
    while( @data = $sth->fetchrow() )
    {
        $ref->{ lc( $data[ 0 ] ) } = $data[ 1 ];
    }
    $sth->finish();
    if( $type )
    {
        return( exists( $ref->{ $type } ) ? $ref->{ $type } : undef() );
    }
    else
    {
        return( wantarray() ? () : undef() ) if( !%$ref );
        return( wantarray() ? %$ref : $ref );
    }
}

sub state(@)
{
    my $self = shift( @_ );
    # $str = $h->state;
    if( !ref( $self ) )
    {
        return( $DBI::state );
    }
    else
    {
        return( $self->SUPER::state() );
    }
}

sub supported_class
{
    my $self = shift( @_ );
    my @classes = values( %$DRIVER2PACK );
    return( @classes );
}

sub supported_drivers
{
    my $self = shift( @_ );
    my @drivers = keys( %$DRIVER2PACK );
    return( @drivers );
}

sub table
{
    my $self   = shift( @_ );
    my $base_class = $self->base_class;
    return( $self->error( "You must use the database object to access this method." ) ) if( ref( $self ) ne $base_class );
    my $table  = shift( @_ ) || 
        return( $self->error( "You must provide a table name to access the table methods." ) );
    my $table_class = "${base_class}::Tables";
    $self->messagec( 4, "Getting table {green}${table}{/} object with class {green}${table_class}{/}" );
    $self->_load_class( $table_class ) || return( $self->pass_error );
    my $host   = $self->{server} // '';
    my $db     = $self->{database} // '';
    my $tbl;
    if( $self->cache_table )
    {
        $tbl = $self->_cache_table(
            host => $self->host,
            database => $self->database,
            table => $table,
        );
        return( $self->pass_error ) if( !defined( $tbl ) );
        $tbl->reset if( $tbl );
    }
    else
    {
        # cache_table is not enabled.
    }

    if( !$tbl )
    {
        $tbl = $table_class->new( $table, 
            dbh => $self->{dbh},
            dbo => $self,
            debug => $self->debug,
        ) || return( $self->pass_error( $table_class->error ) );
        $self->messagec( 6, "Object for table {green}${table}{/} created." );
        $tbl->reset;
        if( $self->cache_table )
        {
            $self->messagec( 6, "Caching table {green}${table}{/}" );
            $self->_cache_table(
                host => $self->host,
                database => $self->database,
                table => $tbl,
            ) || return( $self->pass_error );
        }
    }
    $tbl->no_bind( $self->no_bind );
    # We set debug and again here in case it changed since the table object was instantiated
    $tbl->debug( $self->debug );
    $self->messagec( 6, "Returning table {green}${table}{/} object." );
    return( $tbl );
}

sub table_exists
{
    my $self = shift( @_ );
    my $table = shift( @_ ) || 
    return( $self->error( "You must provide a table name to access the table methods." ) );
    my $cache_tables = $self->cache_tables;
    my $tables_in_cache = [];
    if( defined( $cache_tables ) )
    {
        $tables_in_cache = $cache_tables->get({
            host => $self->host,
            driver => $self->driver,
            port => $self->port,
            database => $self->database,
        });
    }
    foreach my $ref ( @$tables_in_cache )
    {
        return( 1 ) if( $ref->{name} eq $table );
    }
    # We did not find it, so let's try by checking directly the database
    my $def = $self->table_info( $table );
    return( $self->pass_error ) if( !defined( $def ) );
    return(0) if( $self->_is_empty( $def ) );
    return(1);
}

sub table_info 
{
    my $self = shift( @_ );
    return( $self->error( "table_info() has not been implemented by driver \"$self->{driver}\" (object = $self)." ) );
}

sub table_push
{
    my $self = shift( @_ );
    my $table = shift( @_ ) || return( $self->error( "No table provided to add to our cache." ) );
    my $def = $self->tables_info || return;
    my $hash =
    {
    host => $self->host,
    driver => $self->driver,
    port => $self->port,
    database => $self->database,
    tables => $def,
    };
    my $cache_tables = $self->cache_tables;
    if( !defined( $cache_tables->set( $hash ) ) )
    {
        return( $self->pass_error( $cache_tables->error ) );
    }
    return( $table );
}

sub tables
{
    my $self = shift( @_ );
    my $db   = shift( @_ ) || $self->database;
    my $opts = $self->_get_args_as_hash( @_ );
    $db = $opts->{database} if( $opts->{database} );
    my $all = [];
    if( !$opts->{no_cache} && !$opts->{live} )
    {
         if( my $cache_tables = $self->cache_tables )
         {
            $all = $cache_tables->get({
                host => $self->host,
                driver => $self->driver,
                port => $self->port,
                database => $db,
            }) || do
            {
                $self->error( "Warning only: an error occured while trying to fetch the tables cache for host '", $self->host, "', driver '", $self->driver, "', port '", $self->port, "' and database '", $self->database, "': ", $cache_tables->error, "\n" );
            };
        }
        else
        {
            $self->error( "Warning only: no cache tables object found in our self ($self)! Current keys are: '", join( "', '", sort( keys( %$self ) ) ), "'." );
        }
    }
    if( $opts->{no_cache} || $opts->{live} || !scalar( @$all ) )
    {
        $all = $self->tables_info || return;
    }
    my @tables = ();
    @tables = map( $_->{name}, @$all ) if( scalar( @$all ) );
    return( \@tables );
}

sub tables_cache
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    my $cache_tables = $self->cache_tables;
    my $cache = $cache_tables->get({
        host => $self->host,
        driver => $self->driver,
        port => $self->port,
        database => $self->database,
    });
    return( $cache );
}

sub tables_info { return( shift->error( "tables_info() has not been implemented by driver." ) ); }

sub tables_refresh
{
    my $self = shift( @_ );
    my $db   = shift( @_ ) || $self->database;
    my $tables = $self->tables_info || return;
    my $hash =
    {
    host     => $self->host,
    driver   => $self->driver,
    port     => $self->port,
    database => $self->database,
    tables   => $tables,
    };
    my $cache_tables = $self->cache_tables;
    if( !defined( $cache_tables->set( $hash ) ) )
    {
        return( $self->pass_error( $cache_tables->error ) );
    }
    return( wantarray() ? @$tables : $tables );
}

# Used to flag this as a transaction when begin_work is triggered
sub transaction { return( shift->_set_get_boolean( 'transaction', @_ ) ); }

sub TRUE { return( 'TRUE' ); }

sub unknown_field { return( shift->_set_get_scalar( 'unknown_field', @_ ) ); }

sub unlock
{
    my $self = shift( @_ );
    return( $self->error( "Method \"unlock\" has not been implemented by driver $self->{driver} (object $self)." ) );
}

sub use
{
    my $self = shift( @_ );
    my $base_class = $self->base_class;
    return( $self->error( "You must use the the database object to switch database." ) ) if( ref( $self ) ne $base_class );
    my $db   = shift( @_ );
    # No need to go further
    return( $self ) if( $db eq $self->{database} );
    my $repo = Module::Generic::Global->new( 'available_databases' => CORE::ref( $self ), key => CORE::ref( $self ) ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $all_dbs = $repo->get;
    if( !defined( $all_dbs ) || !$self->_is_array( $all_dbs ) )
    {
        $all_dbs = [];
        @$all_dbs = $self->databases();
        $repo->set( $all_dbs );
    }
    if( !scalar( grep{ /^$db$/ } @$all_dbs ) )
    {
        return( $self->error( "The database '$db' does not exist." ) );
    }
    my $dbh = $base_class->connect( $db ) ||
        return( $self->error( "Unable to connect to database '$db'." ) );
    $self->param( 'multi_db' => 1 );
    $dbh->param( 'multi_db' => 1 );
    return( $dbh );
}

sub use_cache { return( shift->_set_get_boolean( 'cache', @_ ) ) }

sub use_bind { return( shift->_set_get_boolean( 'bind', @_ ) ) }

sub variables
{
    my $self = shift( @_ );
    my $type = shift( @_ );
    $self->error( "Variable '$type' is a read-only value." ) if( @_ );
    my $vars = $self->{variables} ||= {};
    if( !%$vars )
    {
        my $sth = $self->prepare( "SHOW VARIABLES" ) ||
        return( $self->error( "SHOW VARIABLES is not supported." ) );
        $sth->execute();
        my $ref = $self->fetchall_arrayref();
        my %vars = map{ lc( $_->[ 0 ] ) => $_->[ 1 ] } @$ref;
        $vars = \%vars if( %vars );
        $sth->finish();
    }
    my @found = grep{ /$type/i } keys( %$vars );
    return( '' ) if( !scalar( @found ) );
    return( $vars->{ $found[ 0 ] } );
}

sub version
{
    return( shift->error( "This driver has not set the version() method." ) );
}

sub _cache_queries
{
    my $self = shift( @_ );
    my $base_class = $self->base_class;
    # DB::Object::CACHE_QUERIES, DB::Object::Postgres::CACHE_QUERIES, etc
    my $repo = Module::Generic::Global->new( 'cache_queries' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $cachedb = $repo->get // [];
    return( $cachedb );
}

# When the table schema caching is enabled, we store the table field objects in an hash reference
# database->table => table_object
sub _cache_table
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    my $class = ( ref( $self ) || $self );
    my $repo = Module::Generic::Global->new( table_cache => 'system' ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    $repo->lock;
    my $cache = $repo->get // {};
    unless( CORE::exists( $opts->{host} ) && CORE::exists( $opts->{database} ) )
    {
        return( $cache );
    }
    my( $host, $database, $table ) = @$opts{qw( host database table )};
    return( $self->error( "A host name was provided, but is undefined or empty." ) ) if( !defined( $host ) || !CORE::length( $host // '' ) );
    return( $self->error( "A database name was provided, but is undefined or empty." ) ) if( !defined( $database ) || !CORE::length( $database // '' ) );
    my $updated = 0;
    if( !defined( $cache->{ $host } ) )
    {
        if( !CORE::exists( $cache->{ $host } ) ||
            ref( $cache->{ $host } ) ne 'HASH' )
        {
            $cache->{ $host } = {};
            $updated++;
        }
    }
    if( !defined( $cache->{ $host }->{ $database } ) )
    {
        if( !CORE::exists( $cache->{ $host }->{ $database } ) ||
            ref( $cache->{ $host }->{ $database } ) ne 'HASH' )
        {
            $cache->{ $host }->{ $database } = {};
            $updated++;
        }
    }
    $self->messagec( 6, "There are {green}", scalar( keys( %{$cache->{ $host }->{ $database }} ) ), "{/} elements in hash reference \$cache->\{ $host \}->\{ $database \}" );
    # The caller has not provided any table value, hinting it wants the entire hash repository for this database.
    if( !defined( $table ) )
    {
        $repo->set( $cache ) if( $updated );
        return( $cache->{ $host }->{ $database } );
    }
    # We are given a table object, we store it in the repository. This is mutator mode
    if( $self->_is_a( $table => 'DB::Object::Tables' ) )
    {
        my $name = $table->name || 
            return( $self->error( "No table name associated with this table object." ) );
        my $dbo = $table->database_object;
        $table->database_object( undef );
        my $clone = $table->clone;
        $table->database_object( $dbo );
        $cache->{ $host }->{ $database }->{ "$name" } = $clone;
        $repo->set( $cache );
    }
    # The user has provided a table name, and thus expects the related cloned table object from the cache table repository.
    # This is accessor mode.
    elsif( !ref( $table ) || ( ref( $table ) && $self->_can_overload( $table => '""' ) ) )
    {
        if( !CORE::exists( $cache->{ $host }->{ $database }->{ "$table" } ) || 
            !defined( $cache->{ $host }->{ $database }->{ "$table" } ) )
        {
            return( '' );
        }
        my $tbl = $cache->{ $host }->{ $database }->{ "$table" };
        my $clone = $tbl->clone;
        $clone->database_object( $self );
        return( $clone );
    }
    else
    {
        return( $self->error( "I do not understand the value provided for the 'table' option -> ", $self->_str_va( $table ) ) );
    }
}

sub _cache_this
{
    my $self    = shift( @_ );
    # When this method is accessed by method from package DB::Object::Statement, they CAN NOT
    # implicitly pass the statement string or they would risk to modify the previous stored
    # query object they represent.
    # For instance:
    # $obj->select->join( 'some_table', { 'parameter', 'list' } )->fetchrow_hashref()
    # here the first query is prepared and cached and its resulting object is passed on to join
    # here join will rebuild the query, but will search first if there was one already cached
    # if join passes implictly the statement string, this means it will modify the cached query select()
    # has just previously stored... This is why method such as join must pass explicitly the query string
    my $q       = shift( @_ );
    my $query   = ( ref( $q ) && $q->isa( 'DB::Object::Query' ) ) ? $q->as_string : $q;
    my $base_class = $self->base_class;
    my $cache   = $self->{cache};
    my $bind    = $self->{bind};
    my $queries = '';
    my @saved   = ();
    # my $cachedb = ${"${base_class}\::CACHE_QUERIES"};
    my $repo = Module::Generic::Global->new( 'cache_queries' => $base_class ) ||
        return( $self->pass_error( Module::Generic::Global->error ) );
    my $cachedb = $repo->get // [];
    $repo->lock;
    # return( $self->error( "The repository cache_queries is not set yet for class $base_class" ) ) if( !$self->_is_array( $cachedb ) );
    my $cache_size = scalar( @$cachedb );
    my $cached_sth = '';
    # If database object exists, this means this is a DB::Object::Tables object, otherwise a DB::Object object
    # my $dbo = $self->{ 'dbo' } || $self;
    if( $cache )
    {
        if( $CACHE_SIZE > 0 && $cache_size > $CACHE_SIZE )
        {
            # Take 20% off of the cache
            my $truncate_limit = int( ( $cache_size * 20 ) / 100 );
            splice( @$cachedb, ( $cache_size - $truncate_limit ) );
        }
        foreach my $obj ( @$cachedb )
        {
            # print( STDERR ref( $self ) . "::_cache_this(): Is query:\n\t'$query'\nthe same than:\n\t'$obj->{ 'query' }'\n" );
            if( $query && $obj->{query} && $obj->{query} eq $query )
            {
                $cached_sth = $obj;
                last;
            }
        }
        $repo->set( $cachedb );
    }
    my $sth;
    # We found a previous query exactly the same
    if( $cached_sth )
    {
        my $data = { sth => $cached_sth->{sth}, query => $cached_sth->{query} };
        # This is an inner package
        $sth = $self->_make_sth( "${base_class}::Statement", $data );
    }
    else
    {
        # Maybe we ought to write:
        # $prepare = $cache ? \&prepare_cached : \prepare;
        # $sth = $prepare->( $self, $self->{ 'query' } ) ||

        # $sth = $self->prepare_cached( $query ) ||
        my $prepare_options = {};
        if( $q && $self->_is_a( $q, 'DB::Object::Query' ) )
        {
            $prepare_options = $q->prepare_options->as_hash;
        }
        if( scalar( keys( %$prepare_options ) ) )
        {
            if( !( $sth = $self->prepare( $query, $prepare_options ) ) )
            {
                # Remove the lock, before we return an error
                $repo->unlock;
                return( $self->pass_error );
            }
        }
        else
        {
            if( !( $sth = $self->prepare( $query ) ) )
            {
                # Remove the lock, before we return an error
                $repo->unlock;
                return( $self->pass_error )
            }
        }
        # $sth = $self->prepare( $self->{ 'query' } ) ||
        # return( $self->error( "Error while preparing the query on table '$self->{ 'table' }':\n$self->{ 'query' }\n", $self->errstr() ) );
        # Let the proper method set its error text
        # If caching of queries is turned on, cache the request
        if( $cache )
        {
            unshift( @$cachedb, $sth );
        }
        # If caching is off, but the query is a binded parameters' one,
        # make the current object hold the statement object
        elsif( $bind )
        {
            $self->{sth} = $sth;
        }
        $repo->set( $cachedb );
        # Unlocking normally is done automatically by Module::Generic::Global, but we make sure it is done now.
        $repo->unlock;
    }
    #$sth->{query_object} = ( ref( $q ) && $q->isa( 'DB::Object::Query' ) ) ? $q : '';
    $sth->query_object( $q ) if( $self->_is_a( $q, 'DB::Object::Query' ) );
    # print( STDERR ref( $self ) . "::_cache_this(): prepared statement was ", $cached_sth ? 'cached' : 'not cached.', "\n" );
    # Caching the query as a constant
    if( $q && $self->_is_object( $q ) && $q->isa( 'DB::Object::Query' ) )
    {
        my $constant = $q->constant;
        if( scalar( keys( %$constant ) ) )
        {
            foreach my $k (qw( pack file line ))
            {
                return( $self->error( "Could not find the parameter \"$k\" in the constant query hash reference." ) ) if( !$constant->{ $k } );
            }
            $constant->{query_object} = $q;
            $self->constant_queries_cache_set( $constant );
        }
    }
    return( $sth );
}

sub _check_connect_param
{
    my $self  = shift( @_ );
    my $param = shift( @_ );
    my $valid = $self->_connection_parameters( $param );
    my $opts = $self->_connection_options( $param );
    foreach my $k ( keys( %$param ) )
    {
        # If it is not in the list and it does not start with an upper case; those are like RaiseError, AutoCommit, etc
        if( CORE::length( $param->{ $k } ) && !grep( /^$k$/, @$valid ) && !CORE::exists( $opts->{ $k } ) )
        {
            return( $self->error( "Invalid parameter '$k'." ) );
        }
    }
    my @opts_to_remove = keys( %$opts );
    CORE::delete( @$param{ @opts_to_remove } ) if( scalar( @opts_to_remove ) );
    $param->{opt} = $opts;
    $param->{database} = CORE::delete( $param->{db} ) if( !length( $param->{database} ) && $param->{db} );
    return( $param );
}

sub _check_default_option
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    # return( $self->error( "Provided option is not a hash reference." ) ) if( !$self->_is_hash( $opts ) );
    # This method should be superseded by an inherited class
    return( $opts );
}

# Simplistic clone by design. We do not want a recursive clone like Clone::clone()
sub _clone
{
    my( $self, $this ) = @_;
    if( $self->_is_array( $this ) )
    {
        my @clone = @$this;
        return( \@clone );
    }
    elsif( ref( $this ) eq 'HASH' )
    {
        my @keys = keys( %$this );
        my $clone = {};
        @$clone{ @keys } = @$this{ @keys };
        return( $clone );
    }
    else
    {
        return( $self->error( "Unsupported data type to clone. This method only support hash or array reference." ) );
    }
}

sub _connection_options
{
    my $self  = shift( @_ );
    my $param = shift( @_ );
    my @dbi_opts = grep( /^[A-Z][a-zA-Z]+/, keys( %$param ) );
    my $opt = {};
    $opt = CORE::delete( $param->{opt} ) if( $param->{opt} && $self->_is_hash( $param->{opt} => 'strict' ) );
    @$opt{ @dbi_opts } = @$param{ @dbi_opts };
    return( $opt );
}

sub _connection_parameters
{
    my $self  = shift( @_ );
    my $param = shift( @_ );
    return( [qw( db login passwd host port driver database server opt uri debug cache_connections cache_dir cache_table unknown_field )] );
}

sub _connection_params2hash
{
    my $self = shift( @_ );
    my $argv = [@_];
    my $param = {};
    if( !( @_ % 2 ) )
    {
        $param = { @_ };
    }
    elsif( @_ == 1 && ( ref( $_[0] ) // '' ) eq 'HASH' )
    {
        $param = shift( @_ );
    }
    else
    {
        my @keys = qw( database login passwd host driver schema );
        # Only add in the $param hash the keys value we were given, so we don't create keys entry when not needed
        for( my $i = 0; $i < scalar( @_ ); $i++ )
        {
            $param->{ $keys[ $i ] } = $_[ $i ];
        }
    }

    my $equi =
    {
        database => 'DB_NAME',
        login    => 'DB_LOGIN',
        passwd   => 'DB_PASSWD',
        host     => 'DB_HOST',
        port     => 'DB_PORT',
        driver   => 'DB_DRIVER',
        schema   => 'DB_SCHEMA',
    };
    foreach my $prop ( keys( %$equi ) )
    {
        $param->{ $prop } = $ENV{ $equi->{ $prop } } if( $ENV{ $equi->{ $prop } } && !length( $param->{ $prop } ) );
    }

    # A simple json file
    # An URI could be http://localhost:5432?database=somedb etc...
    # or it could also be file:/foo/bar?opt={"RaiseError":true}
    if( $param->{uri} || $ENV{DB_CON_URI} )
    {
        my $uri;
        eval
        {
            require URI;
            $uri = URI->new( $param->{uri} || $ENV{DB_CON_URI} );
        };
        if( !$@ && $uri )
        {
            # Make sure our parameter is a valid URI object
            $param->{uri} = $uri;
            if( $uri->can( 'port' ) )
            {
                $param->{host} = $uri->host;
                $param->{port} = $uri->port if( $uri->port );
            }
            # file:/
            elsif( length( $uri->path ) )
            {
                $param->{database} = ( $uri->path_segments )[-1];
            }
            my( %q ) = $uri->query_form;
            $param->{host} = $q{host} if( $q{host} );
            $param->{port} = $q{port} if( $q{port} );
            $param->{database} = $q{database} if( $q{database} );
            $param->{schema} = $q{schema} if( $q{schema} );
            $param->{user} = $q{user} if( $q{user} );
            $param->{login} = $q{login} if( $q{login} );
            $param->{password} = $q{password} if( $q{password} );
            $param->{opt} = $q{opt} if( $q{opt} );
            $param->{login} = CORE::delete( $param->{user} ) if( !$param->{login} && $param->{user} );
            if( $q{opt} )
            {
                my $jdata = {};
                eval
                {
                    require JSON;
                    if( defined( *{ "JSON::" } ) )
                    {
                        my $j = JSON->new->allow_nonref;
                        $jdata = $j->decode( $q{opt} );
                    }
                };
                if( $@ )
                {
                    warn( "Found the database connection opt parameter provided in the connection uri \"$uri\", but could not decode its json value: $@\n" );
                }
                $param->{opt} = $jdata if( scalar( keys( %$jdata ) ) );
            }
        }
    }

    if( $param->{conf_file} || $param->{config_file} || $ENV{DB_CON_FILE} )
    {
        my $db_con_file = $self->new_file( CORE::delete( $param->{conf_file} ) || CORE::delete( $param->{config_file} ) || $ENV{DB_CON_FILE} );
        my $db_con_file_ok = 0;
        if( !$db_con_file->exists )
        {
            warn( "Database connection parameter file \"$db_con_file\" was provided but does not exist.\n" );
        }
        elsif( $db_con_file->is_empty )
        {
            warn( "Database connection parameter file \"$db_con_file\" was provided but the file is empty.\n" );
        }
        elsif( !$db_con_file->can_read )
        {
            warn( "Database connection parameter file \"$db_con_file\" was provided but the file lacks privileges to be read.\n" );
        }
        else
        {
            $db_con_file_ok++;
        }

        my $json = {};
        # try-catch
        local $@;
        eval
        {
            require JSON;
            if( defined( *{ "JSON::" } ) )
            {
                my $j = JSON->new->allow_nonref;
                if( my $io = $db_con_file->open_utf8( '<' ) )
                {
                    my $data = $db_con_file->load;
                    $json = $j->decode( $data );
                }
                else
                {
                    warn( "Unable to open database connection parameter file \"$db_con_file\": ", $db_con_file->error );
                }
            }
        };
        if( $@ )
        {
            warn( "Database connection parameter file \"$db_con_file\" was provided, but I encountered the following error while trying to read its json data: $@\n" );
        }
        $json = {} if( !$self->_is_hash( $json => 'strict' ) );
        my $ref = {};
        if( exists( $json->{databases} ) )
        {
            return( $self->error( "Found a property 'databases' in the connections configuration file \"$db_con_file\". I was expecting this property to be an array reference and instead I found this: '$json->{databases}'" ) ) if( !$self->_is_array( $json->{databases} ) );
            # When called from sub classes, this is set
            my $driver = $self->driver;
            # We take the first one matching our driver if any, or else we just take the first one
            foreach my $this ( @{$json->{databases}} )
            {
                if( !$param->{database} && ( !$driver || $this->{driver} eq $driver ) )
                {
                    $ref = $this;
                    last;
                }
                elsif( $param->{database} && $this->{database} eq $param->{database} &&
                    ( !$param->{host} || $param->{host} eq $this->{host} ) && 
                    ( !$param->{port} || $param->{port} eq $this->{port} ) &&
                    ( !$param->{login} || $param->{login} eq $this->{login} ) )
                {
                    $ref = $this;
                    last;
                }
            }
        }
        else
        {
            $ref = $json;
        }
        if( scalar( keys( %$ref ) ) )
        {
            foreach my $k ( qw( database login passwd host port driver schema opt ) )
            {
                $param->{ $k } = $ref->{ $k } if( !length( $param->{ $k } ) && length( $ref->{ $k } ) );
            }
        }
        $param->{cache_table} = $json->{cache_table} if( CORE::exists( $json->{cache_table} ) );
        $param->{cache_dir} = $json->{cache_dir} if( CORE::exists( $json->{cache_dir} ) );
    }
    if( CORE::exists( $param->{host} ) && index( $param->{host}, ':' ) != -1 )
    {
        @$param{ qw( host port ) } = split( /:/, $param->{host}, 2 );
    }

    if( !$param->{opt} && $ENV{DB_OPT} )
    {
        my $jdata = {};
        eval
        {
            require JSON;
            if( defined( *{ "JSON::" } ) )
            {
                my $j = JSON->new->allow_nonref;
                $jdata = $j->decode( $ENV{DB_OPT} );
            }
        };
        if( $@ )
        {
            warn( "Found the database connection opt parameter provided in the envionment variable DB_OPT, but could not decode its json value: $@\n" );
        }
        $param->{opt} = $jdata if( scalar( keys( %$jdata ) ) );
    }
    return( $param );
}

sub _clean_statement
{
    my $self  = shift( @_ );
    my $data  = shift( @_ );
    my $query = ref( $data ) ? $data : \$data;
    $$query = CORE::join( "\n", map{ s/^\s+|\s+$//gs; $_ } split( /\n/, $$query ) );
    return( $$query ) if( !ref( $data ) );
}

sub _dbi_connect
{
    my $self = shift( @_ );
    my $dbh;
    my $dsn = $self->_dsn;
    # print( STDERR ref( $self ) . "::_dbi_connect() Options are: ", $self->dumper( $self->{opt} ), "\n" );
    # See: <https://metacpan.org/pod/DBI#Timeout>
    # signals to mask in the handler
    my $mask = POSIX::SigSet->new( POSIX::SIGALRM );
    my $action = POSIX::SigAction->new(
        # the handler code ref
        sub{ die( "connect timeout\n" ) },
        $mask,
        # not using (perl 5.8.2 and later) 'safe' switch or sa_flags
    );
    my $oldaction = POSIX::SigAction->new();
    POSIX::sigaction( POSIX::SIGALRM, $action, $oldaction );
    my $failed;
    local $@;
    eval
    {
        eval
        {
            # seconds before time out
            alarm(5);
            if( $self->{cache_connections} )
            {
                $dbh = DBI->connect_cached(
                    $dsn,
                    $self->{login},
                    $self->{passwd}, 
                    $self->{opt},
                    undef(),
                    $CONNECT_VIA,
                );
            }
            else
            {
                $dbh = DBI->connect(
                    $dsn,
                    $self->{login},
                    $self->{passwd}, 
                    $self->{opt},
                    undef(),
                    $CONNECT_VIA,
                );
            }
            1;
        } or $failed = 1;
        # cancel alarm (if connect worked fast)
        alarm(0);
        # connect died
        die( "$@\n" ) if( $failed );
        1;
    } or $failed = 1;
    # restore original signal handler
    POSIX::sigaction( POSIX::SIGALRM, $oldaction );
    if( defined( $failed ) && $failed )
    {
        if( defined( $@ ) && $@ =~ /^connect timeout/ )
        {
            return( $self->error( "Connection timed out for dsn '", ( $dsn // 'undef' ), " and login '", ( $self->{login} // 'undef' ), "'" ) );
        }
        else
        {
            return( $self->error( "Error connecting with dsn '", ( $dsn // 'undef' ), " and login '", ( $self->{login} // 'undef' ), "': $@" ) );
        }
    }

    return( $self->error( $DBI::errstr ) ) if( !$dbh );
    return( $dbh );
}

sub _decode_json
{
    my $self = shift( @_ );
    my $json = shift( @_ );
    return if( !CORE::length( $json ) );
    my $j = JSON->new->allow_nonref;
    my $hash = eval
    {
        $j->decode( $json );
    };
    return if( $@ );
    return( $hash );
}

sub _dsn
{
    my $self = shift( @_ );
    my $class = ref( $self ) || $self;
    die( "Method _dsn is not implemented in class $class\n" );
}

sub _encode_json
{
    my $self = shift( @_ );
    return if( !scalar( @_ ) || ( scalar( @_ ) == 1 && !defined( $_[0] ) ) );
    my $this = shift( @_ );
    return( $self->error( "Value provided is not a hash reference. I was expecting a hash reference to encode data into json." ) ) if( !$self->_is_hash( $this => 'strict' ) );
    my $j = JSON->new;
    my $json = eval
    {
        $j->encode( $this );
    };
    return( $self->error( "An error occurred while trying to encode hash reference provided: $@" ) ) if( $@ );
    return( $json );
}

sub _make_sth
{
    my $self = shift( @_ );
    my $pkg  = shift( @_ );
    my $data = shift( @_ ) || {};
    my $base_class = $self->base_class;
    $self->_load_class( $pkg ) || return( $self->pass_error );
#     map{ $data->{ $_ } = $self->{ $_ } } 
#     qw( 
#     dbh drh server login passwd database driver 
#     table debug bind cache params selected_fields
#     local where limit group_by order_by reverse from_table left_join
#     tie tie_order
#     );
    map{ $data->{ $_ } = $self->{ $_ } } 
    qw( 
    table debug bind cache params from_table left_join
    );
    $data->{dbh} = $self->{dbh};
    $data->{dbo} = $self->{dbo} ? $self->{dbo} : ref( $self ) eq $self->base_class ? $self : '';
    # $data->{ 'binded' } = $self->{ 'binded' } if( $self->{ 'binded' } && ref( $self ) ne $base_class );
    # In any case suppress the binded parameter from our parent object to avoid polluting the next queries
    # If needed, the binded parameter will be rebuilt using the data stored in 'where', 'group', 'order' and 'limit'
    # CORE::delete( $self->{ 'binded' } );
    # Binded parameters are now either in the DB::Object::Query package or one of its descendant OR passed as arguments to execute
    $data->{errstr} = '';
    CORE::delete( $data->{executed} );
    $data->{query_time} = time();
    $data->{selected_fields} = '' if( !exists( $data->{selected_fields} ) );
    $data->{table_object} = $self;
    my $this = bless( $data, $pkg );
    $this->debug( $self->debug );
    return( $this );
}

sub _operator_object_create
{
    my $self = shift( @_ );
    my $class = shift( @_ ) || return( $self->error( "No operator class was provided." ) );
    my $q = $self->_reset_query;
    my $args = ( scalar( @_ ) == 1 && ref( $_[0] ) eq 'ARRAY' ) ? [ @{$_[0]} ] : [ @_ ];
    $self->messagec( 5, "Creating an operator object for class {green}${class}{/} and values '{green}" . join( "{/}', '{green}", map( overload::StrVal( $_ ), @$args ) ) . "{/}'" );
    return( $class->new(
        debug => $self->debug,
        query_object => $q,
        value => $args,
    ) );
}

sub _param2hash
{
    my $self = shift( @_ );
    my $opts = {};
    if( scalar( @_ ) )
    {
        if( $self->_is_hash( $_[0] => 'strict' ) )
        {
            $opts = shift( @_ );
        }
        elsif( !( scalar( @_ ) % 2 ) )
        {
            $opts = { @_ };
        }
        else
        {
            return( $self->error( "Uneven number of parameters. I was expecting a hash or a hash reference." ) );
        }
    }
    return( $opts );
}

sub _placeholder_regexp { return( $PLACEHOLDER_REGEXP ) }

# NOTE: _query_object_add needs to reside in DB::Object (called indirectly by no_bind)
sub _query_object_add
{
    my $self = shift( @_ );
    my $obj  = shift( @_ ) || return( $self->error( "No query object was provided" ) );
    my $base = $self->base_class;
    return( $self->error( "Object provided is not a query object class" ) ) if( ref( $obj ) !~ /^${base}\::Query$/ );
    $self->query_object( $obj );
    return( $obj );
}

# NOTE: _query_object_create needs to reside in DB::Object (called indirectly by no_bind)
sub _query_object_create
{
    my $self = shift( @_ );
    my $base = $self->base_class;
    my $query_class = "${base}::Query";
    $self->messagec( 6, "Loading query class {green}${query_class}{/}" );
    $self->_load_class( $query_class ) ||
        return( $self->error( "Unable to load Query builder module $query_class: ", $self->error->message ) );
    $self->messagec( 5, "Creating new query object with class $query_class for table '{green}", ( $self->isa( 'DB::Object::Tables' ) ? $self->name : '' ), "{/}' and alias {green}", ( $self->isa( 'DB::Object::Tables' ) ? $self->as : '' ), "{/}." );
    $self->messagec( 6, "Instantiating new object for query class {green}${query_class}{/}" );
    my $o = $query_class->new;
    $o->debug( $self->debug );
    $o->enhance( $self->{enhance} ) if( CORE::length( $self->{enhance} ) );
    if( $self->isa( 'DB::Object::Tables' ) )
    {
        $o->table_object( $self ) || return( $self->pass_error( $o->error ) );
        $o->database_object( $self->database_object ) || return( $self->pass_error( $o->error ) );
        # Set the table alias if any has been set
        if( my $table_alias = $self->as )
        {
            $o->table_alias( $table_alias ) if( defined( $table_alias ) );
        }
    }
    elsif( $self->isa( 'DB::Object' ) )
    {
        $o->database_object( $self ) || return( $self->pass_error( $o->error ) );
    }
    return( $o );
}

# NOTE: _query_object_current needs to reside in DB::Object (called indirectly by no_bind)
sub _query_object_current { return( shift->{query_object} ); }

# NOTE: _query_object_get_or_create needs to reside in DB::Object (called indirectly by no_bind)
# If the stack is empty, we create an object, add it and resend it
sub _query_object_get_or_create
{
    my $self = shift( @_ );
    my $obj  = $self->query_object;
    if( !$obj )
    {
        $self->messagec( 5, "Query object for table '{green}", ( $self->isa( 'DB::Object::Tables' ) ? $self->name : '' ), "{/}' does not exist yet, instantiating one." );
        $obj = $self->_query_object_create || return( $self->pass_error );
        $self->query_object( $obj );
    }
    return( $obj );
}

# NOTE: _query_object_remove needs to reside in DB::Object (called indirectly by no_bind)
sub _query_object_remove
{
    my $self = shift( @_ );
    my $obj  = shift( @_ ) || return( $self->error( "No query object was provided" ) );
    my $base = $self->base_class;
    # return( $self->error( "Object provided is not a query object class" ) ) if( ref( $obj ) !~ /^${base}\::Query$/ );
    return( $self->error( "Object provided is not a query object class" ) ) if( !$obj->isa( "DB::Object::Query" ) );
    $self->query_object( undef );
    return( $obj );
}

sub _reset_query
{
    my $self = shift( @_ );
    if( !$self->{query_reset} )
    {
        $self->{query_reset}++;
        $self->{enhance} = 1;
        my $obj = $self->query_object;
        $self->_query_object_remove( $obj ) if( $obj );
        if( $obj && $obj->join_tables->length > 0 )
        {
            $obj->join_tables->foreach(sub{
                my $tbl = shift( @_ );
                return if( $tbl->name eq $self->name );
                my $this_query_object = $tbl->query_object;
                $tbl->_query_object_remove( $this_query_object ) if( $this_query_object );
                $tbl->use_bind(0) unless( $tbl->use_bind > 1 );
                $tbl->use_cache(0) unless( $tbl->use_cache > 1 );
                $tbl->query_reset(1);
                return( $tbl->_query_object_get_or_create );
            });
        }
        $self->{bind} = 0 unless( defined( $self->{bind} ) && $self->{bind} > 1 );
        $self->{cache} = 0 unless( defined( $self->{cache} ) && $self->{cache} > 1 );
        return( $self->_query_object_get_or_create );
    }
    return( $self->_query_object_current );
}

# NOTE: AUTOLOAD
AUTOLOAD
{
    my $self;
    $self = shift( @_ ) if( blessed( $_[ 0 ] ) || index( $_[0], '::' ) != -1 );
    my( $class, $meth );
    if( $self )
    {
        $class = ref( $self ) || $self;
    }
    $meth = $AUTOLOAD;
    if( CORE::index( $meth, '::' ) != -1 )
    {
        my $idx = rindex( $meth, '::' );
        $class = substr( $meth, 0, $idx );
        $meth  = substr( $meth, $idx + 2 );
    }
    my @supported_class = DB::Object->supported_class;
    push( @supported_class, 'DB::Object' );
    my $ok_classes = join( '|', @supported_class );
    my $base_class = ( $class =~ /^($ok_classes)/ )[0];

    # Is it a table object that is being requested?
    # if( $self && scalar( grep{ /^$meth$/ } @$tables ) )
    # Getting table object take NO argument.
    # If the user wants to access a method, and somehow the table name is identical to one of our methods, 
    # it is likely it will take an argument
    if( $class eq $base_class && !scalar( @_ ) && $self->table_exists( $meth ) )
    {
        return( $self->table( $meth ) );
    }
    elsif( $self && $self->can( $meth ) && defined( &{ "$class\::$meth" } ) )
    {
        return( $self->$meth( @_ ) );
    }
    # For imported subs
    elsif( defined( &$meth ) )
    {
        no strict 'refs';
        *{"${class}\::${meth}"} = \&$meth;
        unshift( @_, $self ) if( $self );
        return( &$meth( @_ ) );
    }
    # Taken from AutoLoader.pm
    elsif( $class =~ /^(?:$ok_classes)$/ )
    {
        my $filename;
        my $pkg = $class;
        $pkg =~ s/::/\//g;
        if( defined( $filename = $INC{ "$pkg.pm" } ) )
        {
            $filename =~ s%^(.*)$pkg\.pm\z%$1auto/${pkg}/${meth}.al%s;
            if( -r( $filename ) )
            {
                unless( $filename =~ m|^/|s )
                {
                    $filename = "./$filename";
                }
            }
            else
            {
                $filename = undef();
            }
        }
        if( !defined( $filename ) )
        {
            $filename = "auto/${meth}.al";
            $filename =~ s/::/\//g;
        }
        my $save = $@;
        eval
        {
            local $SIG{__DIE__}  = sub{ };
            local $SIG{__WARN__} = sub{ };
            require $filename;
        };
        if( $@ )
        {
            if( substr( $AUTOLOAD, -9 ) eq '::DESTROY' )
            {
                no strict 'refs';
                *$meth = sub {};
            }
            else
            {
                # The load might just have failed because the filename was too
                # long for some old SVR3 systems which treat long names as errors.
                # If we can succesfully truncate a long name then it's worth a go.
                # There is a slight risk that we could pick up the wrong file here
                # but autosplit should have warned about that when splitting.
                if( $filename =~ s/(\w{12,})\.al$/substr( $1, 0, 11 ) . ".al"/e )
                {
                    eval
                    {
                        local $SIG{__DIE__}  = sub{ };
                        local $SIG{__WARN__} = sub{ };
                        require $filename
                    };
                }
            }
        }
        unless( $@ )
        {
            $@ = $save;
            unshift( @_, $self ) if( $self );
            goto &$meth;
        }
        $@ = $save;
    }

    if( $self && exists( $self->{sth} ) )
    {
        # e.g. $sth->pg_server_prepare => $self->{sth}->{pg_server_prepare}
        if( CORE::exists( $self->{sth}->{ $meth } ) )
        {
            $self->{sth}->{ $meth } = shift( @_ ) if( scalar( @_ ) );
            return( $self->{sth}->{ $meth } );
        }
        if( !$self->executed() )
        {
            $self->execute() || return( $self->error( $self->{sth}->errstr() ) );
        }
        # $self->_cleanup();
        # print( STDERR "Calling DBI method $meth with sth '$self->{sth}' arguments: '", join( "', '", @_ ), "'\n" ) if( $DEBUG );
        # *{ "${class}\::$meth" } = sub{ return( shift->{ 'sth' }->$meth( @_ ) ); };
        return( $self->{sth}->$meth( @_ ) );
    }
    # e.g. $dbh->pg_notifies
    elsif( $self && ( ( $self->{dbh} && $self->{dbh}->can( $meth ) ) || defined( &{ "DBI::db::" . $meth } ) ) )
    {
        return( $self->{dbh}->$meth( @_ ) );
    }
    # e.g. $dbh->pg_enable_utf8 becomes $self->{dbh}->{pg_enable_utf8]
    elsif( $self && $self->{dbh} && CORE::exists( $self->{dbh}->{ $meth } ) )
    {
        $self->{dbh}->{ $meth } = shift( @_ ) if( scalar( @_ ) );
        return( $self->{dbh}->{ $meth } );
    }
    elsif( defined( &{ "DBI::" . $meth } ) )
    {
        my $h = &{ "DBI::" . $meth }( @_ );
        if( defined( $h ) )
        {
            bless( $h, $class );
            return( $h );
        }
        else
        {
            return;
        }
    }
    my $what = $self ? $self : $class;
    return( $what->error( "${class}::AUTOLOAD: Not defined in $class and not autoloadable (last try $meth)" ) );
}

# NOTE: DESTROY
DESTROY
{
    # <https://perldoc.perl.org/perlobj#Destructors>
    CORE::local( $., $@, $!, $^E, $? );
    CORE::return if( ${^GLOBAL_PHASE} eq 'DESTRUCT' );
    my $self = CORE::shift( @_ );
    CORE::return if( !CORE::defined( $self ) );
    my $class = ref( $self ) || $self;
    if( $self->{sth} )
    {
        print( STDERR "DESTROY(): Terminating sth '$self' for query:\n$self->{query}\n" ) if( $DEBUG || $self->{debug} );
        $self->{sth}->finish();
    }
    elsif( $self->{dbh} && $class =~ /^AI\:\:DB(?:\:\:(?:Postgres|Mysql|SQLite))?$/ )
    {
        local( $SIG{__WARN__} ) = sub { };
        # $self->{ 'dbh' }->disconnect();
        if( $DEBUG || $self->{debug} )
        {
            my( $pack, $file, $line, $sub ) = ( caller(0) )[0, 1, 2, 3];
            my( $pack2, $file2, $line2, $sub2 ) = ( caller(1) ) [0, 1, 2, 3];
            print( STDERR "DESTROY database handle ($self) [$self->{ 'query' }]\ncalled within sub '$sub' ($sub2) from package '$pack' ($pack2) in file '$file' ($file2) at line '$line' ($line2).\n" );
        }
        $self->disconnect();
    }
    my $locks = $self->{_locks};
    if( $locks && $self->_is_array( $locks ) )
    {
        foreach my $name ( @$locks )
        {
            $self->unlock( $name );
        }
    }
}

# NOTE: package DB::Object::Operator
package DB::Object::Operator;
BEGIN
{
    use strict;
    use parent qw( Module::Generic );
};

sub init
{
    my $self = shift( @_ );
    $self->{operator}       = undef;
    $self->{query_object}   = undef;
    $self->{value}          = [];
    $self->{_init_strict_use_sub} = 1;
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    return( $self );
}

sub operator { return( '' ); }

sub query_object { return( shift->_set_get_object_without_init( 'query_object', 'DB::Object::Query', @_ ) ); }

# sub value { return( wantarray() ? @{$_[0]->{value}} : $_[0]->{value} ); }
# wantlist option instructs this method to return a list in list context instead of the default array object
sub value { return( shift->_set_get_array_as_object( { field => 'value', wantlist => 1 }, @_ ) ); }

# For arguments that have a query object like statements, we coy their binded_types and binded_values to our current query object.
# This is used by ALL, ANY and IN
sub _copy_binded_elements
{
    my $self = shift( @_ );
    if( my $qo = $self->query_object )
    {
        $self->value->foreach(sub
        {
            my $this = shift( @_ );
            my $q;
            if( $self->_is_a( $this => 'DB::Object::Statement' ) && 
                ( $q = $this->query_object ) )
            {
                $qo->binded_types->push( $q->binded_types->list );
                $qo->binded_values->push( $q->binded_values->list );
            }
        });
    }
    return( $self );
}

# Ref:
# <https://www.postgresql.org/docs/12/arrays.html#ARRAYS-SEARCHING>
# NOTE: package DB::Object::ALL
package DB::Object::ALL;
BEGIN
{
    use strict;
    use warnings;
    use parent -norequire, qw( DB::Object::Operator );
    use Scalar::Util ();
    use overload (
        '""'    => 'as_string',
        'bool'  => sub{1},
        '=='    => sub{ &_opt_overload( @_, '==' ) },
        '!='    => sub{ &_opt_overload( @_, '!=' ) },
        fallback => 1,
    );
};

sub init
{
    my $self = shift( @_ );
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    # $self->_copy_binded_elements || return( $self->pass_error );
    return( $self );
}

sub as_string
{
    my $self = shift( @_ );
    my $vals = $self->value;
    my @list = ();
    foreach my $elem ( @$vals )
    {
        next unless( defined( $elem ) );
        if( Scalar::Util::blessed( $elem ) &&
            $elem->isa( 'DB::Object::Statement' ) )
        {
            push( @list, $elem->as_string );
        }
        else
        {
            push( @list, $elem );
        }
    }
    local $" = ',';
    my $sql = "ALL (@list)";
    return( $sql );
}

sub operator { return( 'ALL' ); }

sub _opt_overload
{
    my( $self, $val, $swap, $op ) = @_;
    my $map =
    {
        '!=' => '!= ',
        '<>' => '!= ',
        '==' => '= ',
    };
    my $not = $map->{ $op };
    if( !defined( $not ) )
    {
        warn( "Unknown operator '${op}'. Falling back to '='." );
        $not = $map->{ '==' };
    }
    my $in = $self->as_string;
    my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
    my $lval = ( Scalar::Util::blessed( $val ) && $val->isa( 'DB::Object::Fields::Field' ) )
        ? $val->name
        : ( $val =~ /^$placeholder_re$/ || $self->_is_number( $val ) )
            ? $val
            : qq{'${val}'};
    return( DB::Object::Expression->new( "${lval} ${not}${in}" ) );
}

# NOTE: package DB::Object::AND
package DB::Object::AND;
BEGIN
{
    use strict;
    use parent -norequire, qw( DB::Object::Operator );
};

sub operator { return( 'AND' ); }

# Ref:
# <https://www.postgresql.org/docs/12/arrays.html#ARRAYS-SEARCHING>
# NOTE: package DB::Object::ANY
package DB::Object::ANY;
BEGIN
{
    use strict;
    use warnings;
    use parent -norequire, qw( DB::Object::Operator );
    use Scalar::Util ();
    use overload (
        '""'    => 'as_string',
        'bool'  => sub{1},
        '=='    => sub{ &_opt_overload( @_, '==' ) },
        '!='    => sub{ &_opt_overload( @_, '!=' ) },
        fallback => 1,
    );
};

sub init
{
    my $self = shift( @_ );
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    # $self->_copy_binded_elements || return( $self->pass_error );
    return( $self );
}

sub as_string
{
    my $self = shift( @_ );
    my $vals = $self->value;
    my @list = ();
    foreach my $elem ( @$vals )
    {
        next unless( defined( $elem ) );
        if( Scalar::Util::blessed( $elem ) &&
            $elem->isa( 'DB::Object::Statement' ) )
        {
            push( @list, $elem->as_string );
        }
        else
        {
            push( @list, $elem );
        }
    }
    local $" = ',';
    my $sql = "ANY (@list)";
    return( $sql );
}

sub operator { return( 'ANY' ); }

sub _opt_overload
{
    my( $self, $val, $swap, $op ) = @_;
    my $map =
    {
        '!=' => '!= ',
        '==' => '= ',
    };
    my $not = $map->{ $op };
    if( !defined( $not ) )
    {
        warn( "Unknown operator '${op}'. Falling back to '='." );
        $not = $map->{ '==' };
    }
    my $in = $self->as_string;
    my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
    my $lval = ( Scalar::Util::blessed( $val ) && $val->isa( 'DB::Object::Fields::Field' ) )
        ? $val->name
        : ( $val =~ /^$placeholder_re$/ || $self->_is_number( $val ) )
            ? $val
            : qq{'${val}'};
    return( DB::Object::Expression->new( "${lval} ${not}${in}" ) );
}

# NOTE: package DB::Object::Expression
package DB::Object::Expression;
BEGIN
{
    use strict;
    use warnings;
    use overload (
        '""'    => 'as_string',
        'bool'  => sub{1},
        fallback => 1,
    );
};

sub new
{
    my $that = shift( @_ );
    my $val = ( scalar( @_ ) == 1 && ref( $_[0] ) eq 'ARRAY' ) ? [ @{$_[0]} ] : [ @_ ];
    return( bless( { value => $val } => ( ref( $that ) || $that ) ) );
}

sub as_string
{
    my $self = shift( @_ );
    my $vals = $self->components;
    return( join( ' ', @$vals ) );
}

sub components { return( wantarray() ? @{$_[0]->{value}} : $_[0]->{value} ); }


# Ref:
# <https://www.postgresql.org/docs/12/functions-subquery.html#FUNCTIONS-SUBQUERY-IN>
# <https://www.postgresql.org/docs/12/functions-comparisons.html#FUNCTIONS-COMPARISONS-IN-SCALAR>
# <https://dev.mysql.com/doc/refman/5.7/en/comparison-operators.html#operator_in>
# <https://www.sqlite.org/lang_expr.html#the_in_and_not_in_operators>
# NOTE: package DB::Object::IN
package DB::Object::IN;
BEGIN
{
    use strict;
    use warnings;
    use parent -norequire, qw( DB::Object::Operator );
    use Scalar::Util ();
    use overload (
        '""'    => 'as_string',
        'bool'  => sub{1},
        '=='    => sub{ &_opt_overload( @_, '==' ) },
        '!='    => sub{ &_opt_overload( @_, '!=' ) },
        fallback => 1,
    );
};

sub init
{
    my $self = shift( @_ );
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    # $self->_copy_binded_elements || return( $self->pass_error );
    return( $self );
}

sub as_string
{
    my $self = shift( @_ );
    my $vals = $self->value;
    my @list = ();
    foreach my $elem ( @$vals )
    {
        next unless( defined( $elem ) );
        if( Scalar::Util::blessed( $elem ) &&
            $elem->isa( 'DB::Object::Statement' ) )
        {
            push( @list, $elem->as_string );
        }
        else
        {
            push( @list, $elem );
        }
    }
    local $" = ',';
    my $sql = "IN (@list)";
    return( $sql );
}

sub operator { return( 'IN' ); }

sub _opt_overload
{
    my( $self, $val, $swap, $op ) = @_;
    my $map =
    {
        '!=' => 'NOT ',
        '<>' => 'NOT ',
        '==' => '',
    };
    my $not  = $map->{ $op } // '';
    my $in = $self->as_string;
    my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
    my $lval = ( Scalar::Util::blessed( $val ) && $val->isa( 'DB::Object::Fields::Field' ) )
        ? $val->name
        : ( $val =~ /^$placeholder_re$/ || $self->_is_number( $val ) )
            ? $val
            : qq{'${val}'};
    return( DB::Object::Expression->new( "${lval} ${not}${in}" ) );
}

# Ref:
# <https://www.postgresql.org/docs/current/functions-matching.html>
# <https://dev.mysql.com/doc/refman/8.4/en/pattern-matching.html>
# <https://www.sqlite.org/lang_corefunc.html#like>
# <https://www.sqlite.org/lang_expr.html#the_like_glob_regexp_match_and_extract_operators>
# NOTE: package DB::Object::LIKE
# TODO: Finish the class DB::Object::LIKE
package DB::Object::LIKE;
BEGIN
{
    use strict;
    use warnings;
    use parent -norequire, qw( DB::Object::Operator );
    use Scalar::Util ();
    use overload (
        '""'    => 'as_string',
        'bool'  => sub{1},
         '=='   => sub{ &_opt_overload( @_, '==' ) },
        '!='    => sub{ &_opt_overload( @_, '!=' ) },
       fallback => 1,
    );
};

sub init
{
    my $self = shift( @_ );
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    # $self->_copy_binded_elements || return( $self->pass_error );
    return( $self );
}

sub as_string
{
    my $self = shift( @_ );
    my $vals = $self->value;
    # Parameters can be given as an array for convenience, and they will concatenated
    my $sql  = "LIKE '" . join( '', @$vals ) . "'";
    return( $sql );
}

sub _opt_overload
{
    my( $self, $val, $swap, $op ) = @_;
    my $map =
    {
        '!=' => 'NOT ',
        '<>' => 'NOT ',
        '==' => '',
    };
    my $not  = $map->{ $op } // '';
    my $like = $self->as_string;
    my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
    my $lval = ( Scalar::Util::blessed( $val ) && $val->isa( 'DB::Object::Fields::Field' ) )
        ? $val->name
        : ( $val =~ /^$placeholder_re$/ || $self->_is_number( $val ) )
            ? $val
            : qq{'${val}'};
    return( DB::Object::Expression->new( "${lval} ${not}${like}" ) );
}


# NOTE: package DB::Object::NOT
package DB::Object::NOT;
BEGIN
{
    use strict;
    use parent -norequire, qw( DB::Object::Operator );
};

sub operator { return( 'NOT' ); }

# NOTE: package DB::Object::OR
package DB::Object::OR;
BEGIN
{
    use strict;
    use parent -norequire, qw( DB::Object::Operator );
};

sub operator { return( 'OR' ); }

1;
# NOTE: POD
__END__

=encoding utf8

=head1 NAME

DB::Object - SQL API

=head1 SYNOPSIS

    use DB::Object;

    my $dbh = DB::Object->connect({
        driver => 'Pg',
        conf_file => 'db-settings.json',
        database => 'webstore',
        host => 'localhost',
        login => 'store-admin',
        schema => 'auth',
        debug => 3,
    }) || bailout( "Unable to connect to sql server on host localhost: ", DB::Object->error );

    # Legacy regular query
    my $sth = $dbh->prepare( "SELECT login,name FROM login WHERE login='jack'" ) ||
    die( $dbh->errstr() );
    $sth->execute() || die( $sth->errstr() );
    my $ref = $sth->fetchrow_hashref();
    $sth->finish();

    # Get a list of databases;
    my @databases = $dbh->databases;
    # Doesn't exist? Create it:
    my $dbh2 = $dbh->create_db( 'webstore' );
    # Load some sql into it
    my $rv = $dbh2->do( $sql ) || die( $dbh->error );

    # Check a table exists
    $dbh->table_exists( 'customers' ) || die( "Cannot find the customers table!\n" );

    # Get list of tables, as array reference:
    my $tables = $dbh->tables;

    my $cust = $dbh->customers || die( "Cannot get customers object." );
    $cust->where( email => 'john@example.org' );
    my $str = $cust->delete->as_string;
    # Becomes: DELETE FROM customers WHERE email='john\@example.org'

    # Do some insert with transaction
    $dbh->begin_work;
    # Making some other inserts and updates here...
    my $cust_sth_ins = $cust->insert(
        first_name => 'Paul',
        last_name => 'Goldman',
        email => 'paul@example.org',
        active => 0,
    ) || do
    {
        # Rollback everything since the begin_work
        $dbh->rollback;
        die( "Error while create query to add data to table customers: " . $cust->error );
    };
    $result = $cust_sth_ins->as_string;
    # INSERT INTO customers (first_name, last_name, email, active) VALUES('Paul', 'Goldman', 'paul\@example.org', '0')
    $dbh->commit;
    # Get the last used insert id
    my $id = $dbh->last_insert_id();

    $cust->where( email => 'john@example.org' );
    $cust->order( 'last_name' );
    $cust->having( email => qr/\@example/ );
    $cust->limit( 10 );
    my $cust_sth_sel = $cust->select || die( "An error occurred while creating a query to select data frm table customers: " . $cust->error );
    # Becomes:
    # SELECT id, first_name, last_name, email, created, modified, active, created::ABSTIME::INTEGER AS created_unixtime, modified::ABSTIME::INTEGER AS modified_unixtime, CONCAT(first_name, ' ', last_name) AS name FROM customers WHERE email='john\@example.org' HAVING email ~ '\@example' ORDER BY last_name LIMIT 10

    $cust->reset;
    $cust->where( email => 'john@example.org' );
    my $cust_sth_upd = $cust->update( active => 0 )
    # Would become:
    # UPDATE ONLY customers SET active='0' WHERE email='john\@example.org'

    # Lets' dump the result of our query
    # First to STDERR
    $login->where( "login='jack'" );
    $login->select->dump();
    # Now dump the result to a file
    $login->select->dump( "my_file.txt" );

Using L<fields objects|DB::Object::Fields::Field>

    $cust->where( $dbh->OR( $cust->fo->email == 'john@example.org', $cust->fo->id == 2 ) );
    my $ref = $cust->select->fetchrow_hashref;

Doing some left join

    my $geo_tbl = $dbh->geoip || return( $self->error( "Unable to get the database object \"geoip\"." ) );
    my $name_tbl = $dbh->geoname || return( $self->error( "Unable to get the database object \"geoname\"." ) );
    $geo_tbl->as( 'i' );
    $name_tbl->as( 'l' );
    $geo_tbl->where( "INET '?'" << $geo_tbl->fo->network );
    $geo_tbl->alias( id => 'ip_id' );
    $name_tbl->alias( country_iso_code => 'code' );
    my $sth = $geo_tbl->select->join( $name_tbl, $geo_tbl->fo->geoname_id == $name_tbl->fo->geoname_id );
    # SELECT
    #     -- tables fields
    # FROM
    #     geoip AS i
    #     LEFT JOIN geoname AS l ON i.geoname_id = l.geoname_id
    # WHERE
    #     INET '?' << i.network

Using a promise (L<Promise::Me>) to execute an asynchronous query:

    my $sth = $dbh->prepare( "SELECT some_slow_function(?)" ) || die( $dbh->error );
    my $p = $sth->promise(10)->then(sub
    {
        my $st = shift( @_ );
        my $ref = $st->fetchrow_hashref;
        my $obj = My::Module->new( %$ref );
    })->catch(sub
    {
        $log->warn( "Failed to execute query: ", @_ );
    });
    # Do other regular processing here
    # Get the My::Module object
    my( $obj ) = await( $p );

Sometimes, having placeholders in expression makes it difficult to work, so you can use placeholder objects to make it work:

	my $P = $dbh->placeholder( type => 'inet' );
    $orders_tbl->where( $dbh->OR( $orders_tbl->fo->ip_addr == "inet $P", "inet $P" << $orders_tbl->fo->ip_addr ) );
    my $order_ip_sth = $orders_tbl->select( 'id' ) || fail( "An error has occurred while trying to create a select by ip query for table orders: " . $orders_tbl->error );
    # SELECT id FROM orders WHERE ip_addr = inet ? OR inet ? << ip_addr

Be careful though, when using L<fields objects|DB::Object::Fields::Field>, not to do this:

    my $tbl = $dbh->some_table;
    $tbl->where( $tbl->fo->some_field => '?', $tbl->fo->other_field => '?' );
    my $sth = $tbl->select || die( $tbl->error );

Because the L<fields objects|DB::Object::Fields::Field> are overloaded, instead do this:

    my $tbl = $dbh->some_table;
    $tbl->where( $tbl->fo->some_field == '?', $tbl->fo->other_field == '?' );
    my $sth = $tbl->select || die( $tbl->error );

Accessing a property in a C<JSON> or C<JSONB> field:

    my $tbl = $dbh->some_table;
    $tbl->where( metadata => { is_system => 'true' } );
    my $sth = $tbl->select;
    say $sth->as_string;
    # SELECT * FROM some_table WHERE metadata->>is_system = 'true';

In future release, other operators than C<=> will be implemented for C<JSON> and C<JSONB> fields.

=head1 VERSION

    v1.8.1

=head1 DESCRIPTION

L<DB::Object> is a SQL API much alike C<DBI>, but with the added benefits that it formats queries in a simple object oriented, chaining way.

So why use a private module instead of using that great C<DBI> package?

At first, I started to inherit from C<DBI> to conform to C<perlmod> perl manual page and to general perl coding guidlines. It became very quickly a real hassle. Barely impossible to inherit, difficulty to handle error, too much dependent from an API that changes its behaviour with new versions.
In short, I wanted a better, more accurate control over the SQL connection and an easy way to format sql statement using an object oriented approach.

So, L<DB::Object> acts as a convenient, modifiable wrapper that provides the programmer with an intuitive, user-friendly, object oriented and hassle free interface.

However, if you use the power of this interface to prepare queries conveniently, you should cache the resulting statement handler object, because there is an obvious real cost penalty in preparing queries and they absolutely do not need to be prepared each time. So you can do something like:

    my $sth;
    unless( $sth = $dbh->cache_query_get( 'some_arbitrary_identifier' ) )
    {
        # prepare the query
        my $tbl = $dbh->some_table || die( $dbh->error );
        $tbl->where( id => '?' );
        $sth = $tbl->select || die( $tbl->error );
        $dbh->cache_query_set( some_arbitrary_identifier => $sth );
    }
    $sth->exec(12) || die( $sth->error );
    my $ref = $sth->fetchrow_hashref;

This will provide you with the convenience and power of L<DB::Object> while keeping execution fast.

=head1 CONSTRUCTOR

=head2 new

Create a new instance of L<DB::Object>. Nothing much to say.

=head2 connect

Provided with a C<database>, C<login>, C<password>, C<server>:[C<port>], C<driver>, C<schema>, and optional hash or hash reference of parameters and this will issue a, possibly cached, database connection and return the resulting database handler.

Create a new instance of L<DB::Object>, but also attempts a connection to SQL server.

It can take either an array of value in the order database name, login, password, host, driver and optionally schema, or it can take a has or hash reference. The hash or hash reference attributes are as follow.

Note that if you provide connection options that are not among the followings, this will return an error.

=over 4

=item * C<cache_connections>

Defaults to true.

If true, this will instruct L<DBI> to use L<DBI/connect_cached> instead of just L<DBI/connect>

Beware that using cached connections can have some drawbacks, such as if you open a cached connection, enters into a transaction using L<DB::Object/begin_work>, then somewhere else in your code a call to a cached connection using the same parameters, which L<DBI> will provide, but will reset the database handler parameters, including the C<AutoCommit> that will have been temporarily set to false when you called L</begin_work>, and then you close your transaction by calling L</rollback> or L</commit>, but it will trigger an error, because C<AutoCommit> will have been reset on this cached connection to a true value. L</rollback> and L</commit> require that C<AutoCommit> be disabled, which L</begin_work> normally do.

Thus, if you want to avoid using a cached connection, set this to false.

More on this issue at L<DBI documentation|https://metacpan.org/pod/DBI#connect_cached>

=item * C<database> or I<DB_NAME>

The database name you wish to connect to

=item * C<login> or I<DB_LOGIN>

The login used to access that database

=item * C<passwd> or I<DB_PASSWD>

The password that goes along

=item * C<host> or I<DB_HOST>

The server, that is hostname of the machine serving a SQL server.

=item * C<port> or I<DB_PORT>

The port to connect to

=item * C<driver> or I<DB_DRIVER>

The driver you want to use. It needs to be of the same type than the server you want to connect to. If you are connecting to a MySQL server, you would use C<mysql>, if you would connecto to an Oracle server, you would use C<oracle>.

You need to make sure that those driver are properly installed in the system before attempting to connect.

To install the required driver, you could start with the command line:

    perl -MCPAN -e shell

which will provide you a special shell to install modules in a convenient way.

=item * C<schema> or I<DB_SCHEMA>

The schema to use to access the tables. Currently only used by PostgreSQL

=item * C<opt>

This takes a hash reference and contains the standard C<DBI> options such as I<PrintError>, I<RaiseError>, I<AutoCommit>, etc

=item * C<conf_file> or C<DB_CON_FILE>

This is used to specify a json connection configuration file. It can also provided via the environment variable I<DB_CON_FILE>. It has the following structure:

    {
    "database": "some_database",
    "host": "db.example.com",
    "login": "sql_joe",
    "passwd": "some password",
    "driver": "Pg",
    "schema": "warehouse",
    "opt":
        {
        "RaiseError": false,
        "PrintError": true,
        "AutoCommit": true
        }
    }

Alternatively, it can contain connections parameters for multiple databases and drivers, such as:

    {
        "databases": [
            {
            "database": "some_database",
            "host": "db.example.com",
            "port": 5432,
            "login": "sql_joe",
            "passwd": "some password",
            "driver": "Pg",
            "schema": "warehouse",
            "opt":
                {
                "RaiseError": false,
                "PrintError": true,
                "AutoCommit": true
                }
            },
            {
            "database": "other_database",
            "host": "db.example2.com",
            "login": "sql_bob",
            "passwd": "other password",
            "driver": "mysql",
            },
            {
            "database": "/path/to/my/database.sqlite",
            "driver": "SQLite",
            }
        ]
    }

=item * C<uri> or I<DB_CON_URI>

This is used to specify an uri to contain all the connection parameters for one database connection. It can also provided via the environment variable I<DB_CON_URI>. For example:

    http://db.example.com:5432?database=some_database&login=sql_joe&passwd=some%020password&driver=Pg&schema=warehouse&&opt=%7B%22RaiseError%22%3A+false%2C+%22PrintError%22%3Atrue%2C+%22AutoCommit%22%3Atrue%7D

Here the I<opt> parameter is passed as a json string, for example:

    {"RaiseError": false, "PrintError":true, "AutoCommit":true}

=back

=head1 METHODS

=head2 alias

See L<DB::Object::Tables/alias>

=head2 allow_bulk_delete

Sets/gets the boolean value for whether to allow unsafe bulk delete. This means query without any C<where> clause.

Default is false.

=head2 allow_bulk_update

Sets/gets the boolean value for whether to allow unsafe bulk update. This means query without any C<where> clause.

Default is false.

=head2 AND

Takes any arguments and wrap them into a C<AND> clause.

    $tbl->where( $dbh->AND( $tbl->fo->id == ?, $tbl->fo->frequency >= .30 ) );

=head2 as_string

See L<DB::Object::Statement/as_string>

=head2 auto_convert_datetime_to_object

Sets or gets the boolean value. If true, then this api will automatically transcode datetime value into their equivalent L<DateTime> object.

Default is false.

=head2 auto_decode_json

Sets or gets the boolean value. If true, then this api will automatically transcode json data into perl hash reference.

Default is true.

=head2 avoid

See L<DB::Object::Tables/avoid>

=head2 attribute

Sets or get the value of database connection parameters.

If only one argument is provided, returns its value.
If multiple arguments in a form of pair => value are provided, it sets the corresponding database parameters.

The authorised parameters are:

=over 4

=item I<Active>

Is read-only.

=item I<ActiveKids>

Is read-only.

=item I<AutoCommit>

Can be changed.

=item I<AutoInactiveDestroy>

Can be changed.

=item I<CachedKids>

Is read-only.

=item I<Callbacks>

Can be changed.

=item I<ChildHandles>

Is read-only.

=item I<ChopBlanks>

Can be changed.

=item I<CompatMode>

Can be changed.

=item I<CursorName>

Is read-only.

=item I<ErrCount>

Is read-only.

=item I<Executed>

Is read-only.

=item I<FetchHashKeyName>

Is read-only.

=item I<HandleError>

Can be changed.

=item I<HandleSetErr>

Can be changed.

=item I<InactiveDestroy>

Can be changed.

=item I<Kids>

Is read-only.

=item I<LongReadLen>

Can be changed.

=item I<LongTruncOk>

Can be changed.

=item I<NAME>

Is read-only.

=item I<NULLABLE>

Is read-only.

=item I<NUM_OF_FIELDS>

Is read-only.

=item I<NUM_OF_PARAMS>

Is read-only.

=item I<Name>

Is read-only.

=item I<PRECISION>

Is read-only.

=item I<PrintError>

Can be changed.

=item I<PrintWarn>

Can be changed.

=item I<Profile>

Is read-only.

=item I<RaiseError>

Can be changed.

=item I<ReadOnly>

Can be changed.

=item I<RowCacheSize>

Is read-only.

=item I<RowsInCache>

Is read-only.

=item I<SCALE>

Is read-only.

=item I<ShowErrorStatement>

Can be changed.

=item I<Statement>

Is read-only.

=item I<TYPE>

Is read-only.

=item I<Taint>

Can be changed.

=item I<TaintIn>

Can be changed.

=item I<TaintOut>

Can be changed.

=item I<TraceLevel>

Can be changed.

=item I<Type>

Is read-only.

=item I<Warn>

Can be changed.

=back

=head2 available_drivers

Return the list of available drivers.

=head2 base_class

Returns the base class.

=head2 bind

If no values to bind to the underlying query is provided, L</bind> simply activate the bind value feature.

If values are provided, they are allocated to the statement object and will be applied when the query will be executed.

Example:

    $dbh->bind()
    # or
    $dbh->bind->where( "something" )
    # or
    $dbh->bind->select->fetchrow_hashref()
    # and then later
    $dbh->bind( 'thingy' )->select->fetchrow_hashref()

=head2 cache

Activate caching.

    $tbl->cache->select->fetchrow_hashref();

=head2 cache_connections

Sets/get the cached database connection.

=head2 cache_dir

Sets or gets the directory on the file system used for caching data.

=head2 cache_query_get

    my $sth;
    unless( $sth = $dbh->cache_query_get( 'some_arbitrary_identifier' ) )
    {
        # prepare the query
        my $tbl = $dbh->some_table || die( $dbh->error );
        $tbl->where( id => '?' );
        $sth = $tbl->select || die( $tbl->error );
        $dbh->cache_query_set( some_arbitrary_identifier => $sth );
    }
    $sth->exec(12) || die( $sth->error );
    my $ref = $sth->fetchrow_hashref;

Provided with a unique name, and this will return a cached statement object if it exists already, otherwise it will return undef

=head2 cache_query_set

    my $sth;
    unless( $sth = $dbh->cache_query_get( 'some_arbitrary_identifier' ) )
    {
        # prepare the query
        my $tbl = $dbh->some_table || die( $dbh->error );
        $tbl->where( id => '?' );
        $sth = $tbl->select || die( $tbl->error );
        $dbh->cache_query_set( some_arbitrary_identifier => $sth );
    }
    $sth->exec(12) || die( $sth->error );
    my $ref = $sth->fetchrow_hashref;

Provided with a unique name and a statement object (L<DB::Object::Statement>), and this will cache it.

What this does simply is store the statement object in a global repository C<queries_cache> of identifier-statement object pairs. This is managed using L<Module::Generic::Global>

It returns the statement object cached.

=head2 cache_table

Sets or gets a boolean value whether to cache the table fields object.

When this is enabled, the second time a database table is accessed, it will retrieve its field objects from the cache rather than recreating them after reading the structure from the database. This is much faster.

By default, this is set to false.

This can be specified in the configuration file passed when instantiating a new C<DB::Object> object with the property C<cache_table>

=head2 cache_table_fields

    my $all_dbs = $dbh->cache_table_fields;
    my $all_tables = $dbh->cache_table_fields( database => $some_database );
    my $all_fields = $dbh->cache_table_fields(
        database => $some_database,
        table => $some_table,
    );
    $dbh->cache_table_fields(
        database => $some_database,
        table => $some_table,
        fields => $some_hash_reference,
    );

Sets or gets the hash reference of database table field name to their L<corresponding object|DB::Object::Fields::Field>.

If no parameter is provided, it will return the entire cache for all databases for a given driver.

If only a database name is provided, it will return the cache hash reference for all the tables in the given database.

If a database and a table name is provided, this will return an hash reference of field name to their L<corresponding object|DB::Object::Fields::Field>.

If a database and a table name and an hash reference of field names to their L<corresponding objects|DB::Object::Fields::Field> is provided, it will set this hash as the cache for the given database and table.

=head2 cache_tables

Sets or gets the L<DB::Object::Cache::Tables> object.

=head2 check_driver

Check that the driver set in I<$SQL_DRIVER> in ~/etc/common.cfg is indeed available.

It does this by calling L</available_drivers>.

=head2 connect

This will attempt a database server connection. 

It called L</_connection_params2hash> to get the necessary connection parameters, which is superseded in each driver package.

Then, it will call L</_check_connect_param> to get the right parameters for connection.

It will also call L</_check_default_option> to get some driver specific default options unless the previous call to _check_connect_param returned an has with a property I<opt>.

It will then set the following current object properties: L</database>, L</host>, L</port>, L</login>, L</passwd>, L</driver>, L</cache>, L</bind>, L</opt>

Unless specified in the connection options retrieved with L</_check_default_option>, it sets some basic default value:

=over 4

=item I<AutoCommit> 1

=item I<PrintError> 0

=item I<RaiseError> 0

=back

Finally it tries to connect by calling the, possibly superseded, method L</_dbi_connect>

It instantiate a L<DB::Object::Cache::Tables> object to cache database tables and return the current object.

=head2 constant_queries_cache

Returns the global repository of constant queries. This uses L<Module::Generic::Global>, and is thread-safe.

This is used by L</constant_queries_cache_get> and L</constant_queries_cache_set>

=head2 constant_queries_cache_get

Provided with some hash reference with properties C<pack>, C<file> and C<line> that are together used as a key in the cache and this will use an existing entry in the cache if available.

=head2 constant_queries_cache_set

Provided with some hash reference with properties C<pack>, C<file> and C<line> that are together used as a key in the cache and C<query_object> and this will set an entry in the cache. it returns the hash reference initially provided.

=head2 constant_to_datatype

Provided with a data type constant value and this returns its equivalent data type as a string in upper case.

This constant is set by the driver, or by default by L<DBI>. For example C<SQL_VARCHAR> is C<12> and its data type is C<VARCHAR>

See also L</datatype_to_constant>

=head2 copy

Provided with either a reference to an hash or an hash of key => value pairs, L</copy> will first execute a select statement on the table object, then fetch the row of data, then replace the key-value pair in the result by the ones provided, and finally will perform an insert.

Return false if no data to copy were provided, otherwise it always returns true.

=head2 create_db

This is a method that must be implemented by the driver package.

=head2 create_table

This is a method that must be implemented by the driver package.

=head2 data_sources

Given an optional list of options as hash, this return the data source of the database handler.

=head2 data_type

Given a reference to an array or an array of data type, L</data_type> will check their availability in the database driver.

If nothing found, it return an empty list in list context, or undef in scalar context.

If something was found, it returns a hash in list context or a reference to a hash in list context.

=head2 database

Return the name of the current database.

=head2 databases

This returns the list of available databases.

This is a method that must be implemented by the driver package.

=head2 datatype_dict

Returns an hash reference of each data type with their equivalent C<constant>, regular expression (C<re>), constant C<name> and C<type> name.

Each data type is an hash with the following properties for each type: C<constant>, C<name>, C<re>, C<type>

The data returned is dependent on each driver.

=head2 datatype_to_constant

    my $type = $dbh->datatype_to_constant( 'varchar' ); # 12

    # Below achieves the same result
    use DBI ':sql_types';
    say SQL_VARCHAR; # 12

Provided with a data type as a string and this returns its equivalent driver value if any, or by default the one of set by L<DBI>.

The data type provided is case insensitive.

If no matching data type exists, it returns C<undef> in scalar context, or an empty list in list context.

As pointed out by L<DBI documentation|DBI/"DBI Constants">: "just because the DBI defines a named constant for a given data type doesn't mean that drivers will support that data type."

See also L</constant_to_datatype>

=head2 datatypes

    my $types = $dbh->datatypes;

Returns an hash reference of data types to their respective values.

If the driver has its own, it will return the driver's constants, otherwise, this will return an hash reference of L<DBI data type constants|DBI/"DBI Constants">.

As pointed out by L<DBI documentation|DBI/"DBI Constants">: "just because the DBI defines a named constant for a given data type doesn't mean that drivers will support that data type."

=head2 delete

See L<DB::Object::Tables/delete>

=head2 disconnect

Disconnect from database. Returns the return code.

    my $rc = $dbh->disconnect;

=head2 do

Provided with a string representing a sql query, some hash reference of attributes and some optional values to bind and this will execute the query and return the statement handler.

The attributes list will be used to B<prepare> the query and the bind values will be used when executing the query.

Example:

    $rc = $dbh->do( $statement ) || die( $dbh->errstr );
    $rc = $dbh->do( $statement, \%attr ) || die( $dbh->errstr );
    $rv = $dbh->do( $statement, \%attr, @bind_values ) || die( $dbh->errstr );
    my $rows_deleted = $dbh->do(
    q{
       DELETE FROM table WHERE status = ?
    }, undef(), 'DONE' ) || die( $dbh->errstr );

=head2 driver

Return the name of the driver for the current object.

=head2 enhance

Toggle the enhance mode on/off.

When on, the functions L</from_unixtime> and L</unix_timestamp> will be used on date/time field to translate from and to unix time seamlessly.

=head2 err

Get the currently set error.

=head2 errno

Is just an alias for L</err>.

=head2 errmesg

Is just an alias for L</errstr>.

=head2 errstr

Get the currently set error string.

=head2 FALSE

This return the keyword C<FALSE> to be used in queries.

=head2 fatal

Provided a boolean value and this toggles fatal mode on/off.

=head2 format_statement

See L<DB::Object::Tables/format_statement>

=head2 format_update

See L<DB::Object::Tables/format_update>

=head2 from_unixtime

See L<DB::Object::Tables/from_unixtime>

=head2 get_sql_type

Provided with a sql type, irrespective of the character case, and this will return the driver equivalent constant value.

=head2 group

See L<DB::Object::Tables/group>

=head2 host

Sets or gets the C<host> property for this database object.

=head2 insert

See L<DB::Object::Tables/insert>

=head2 last_insert_id

Get the id of the primary key from the last insert.

=head2 LIKE

Returns a new L<DB::Object::LIKE> object, passing it whatever arguments were provided.

=head2 limit

See L<DB::Object::Tables/limit>

=head2 local

See L<DB::Object::Tables/local>

=head2 lock

This method must be implemented by the driver package.

=head2 login

Sets or gets the C<login> property for this database object.

=head2 no_bind

When invoked, L</no_bind> will change any preparation made so far for caching the query with bind parameters, and instead substitute the value in lieu of the question mark placeholder.

=head2 no_cache

Disable caching of queries.

=head2 NOT

Returns a new L<DB::Object::NOT> object, passing it whatever arguments were provided.

=head2 NULL

Returns a C<NULL> string to be used in queries.

=head2 on_conflict

See L<DB::Object::Tables/on_conflict>

=head2 OR

Returns a new L<DB::Object::OR> object, passing it whatever arguments were provided.

=head2 order

See L<DB::Object::Tables/order>

=head2 P

Returns a L<DB::Object::Placeholder> object, passing it whatever arguments was provided.

=head2 param

If only a single parameter is provided, its value is return. If a list of parameters is provided they are set accordingly using the C<SET> sql command.

Supported parameters are:

=over 4

=item AUTOCOMMIT

=item INSERT_ID

=item LAST_INSERT_ID

=item SQL_AUTO_IS_NULL

=item SQL_BIG_SELECTS

=item SQL_BIG_TABLES

=item SQL_BUFFER_RESULT

=item SQL_LOG_OFF

=item SQL_LOW_PRIORITY_UPDATES

=item SQL_MAX_JOIN_SIZE 

=item SQL_SAFE_MODE

=item SQL_SELECT_LIMIT

=item SQL_LOG_UPDATE 

=item TIMESTAMP

=back

If unsupported parameters are provided, they are considered to be private and not passed to the database handler.

It then execute the query and return L<perlfunc/undef> in case of error.

Otherwise, it returns the current object used to call the method.

=head2 passwd

Sets or gets the C<passwd> property for this database object.

=head2 ping

Evals a SELECT 1 statement and returns 0 if errors occurred or the return value.

=head2 ping_select

Will prepare and execute a simple C<SELECT 1> and return 0 upon failure or return the value returned from calling L<DBI/execute>.

=head2 placeholder

Same as L</P>. Returns a L<DB::Object::Placeholder> object, passing it whatever arguments was provided.

=head2 port

Sets or gets the C<port> property for this database object.

=head2 prepare

Provided with a sql query and some hash reference of options and this will prepare the query using the options provided. The options are the same as the one in L<DBI/prepare> method.

It returns a L<DB::Object::Statement> object upon success or undef if an error occurred. The error can then be retrieved using L</errstr> or L</error>.

=head2 prepare_cached

Same as L</prepare> except the query is cached.

=head2 query

It prepares and executes the given SQL query with the options provided and return L<perlfunc/undef> upon error or the statement handler upon success.

=head2 query_object

Sets or gets the L<query object|DB::Object::Query>.

=head2 quote

This is used to properly format data by surrounding them with quotes or not.

Calls L<DBI/quote> and pass it whatever argument was provided.

=head2 replace

See L<DB::Object::Tables/replace>

=head2 reset

See L<DB::Object::Tables/reset>

=head2 returning

See L<DB::Object::Tables/returning>

=head2 reverse

See L<DB::Object::Tables/reverse>

=head2 select

See L<DB::Object::Tables/select>

=head2 set

Provided with variable and this will issue a query to C<SET> the given SQL variable.

If any error occurred, undef will be returned and an error set, otherwise it returns true.

=head2 sort

See L<DB::Object::Tables/sort>

=head2 stat

Issue a C<SHOW STATUS> query and if a particular C<$type> is provided, it will return its value if it exists, otherwise it will return L<perlfunc/undef>.

In absence of particular $type provided, it returns the hash list of values returns or a reference to the hash list in scalar context.

=head2 state

Queries the DBI state and return its value.

=head2 supported_class

Returns the list of driver packages such as L<DB::Object::Postgres>

=head2 supported_drivers

Returns the list of driver name such as L<Pg>

=head2 table

Given a table name, L</table> will return a L<DB::Object::Tables> object. The object is cached for re-use.

When a cached table object is found, it is cloned and reset (using L</reset>), before it is returned to avoid undesirable effets in following query that would have some table properties set such as table alias.

=head2 table_exists

Provided with a table name and this returns true if the table exist or false otherwise.

=head2 table_info

This is a method that must be implemented by the driver package.

It returns an array reference of hash reference containing information about each table column.

=head2 table_push

Add the given table name to the stack of cached table names.

=head2 tables

Connects to the database and finds out the list of all available tables. If cache is available, it will use it instead of querying the database server.

Returns undef or empty list in scalar or list context respectively if no table found.

Otherwise, it returns the list of table in list context or a reference of it in scalar context.

=head2 tables_cache

Returns the table cache object

=head2 tables_info

This is a method that must be implemented by the driver package.

=head2 tables_refresh

Rebuild the list of available database table.

Returns the list of table in list context or a reference of it in scalar context.

=head2 tie

See L<DB::Object::Tables/tie>

=head2 transaction

True when a transaction has been started with L</begin_work>, false otherwise.

=head2 TRUE

Returns C<TRUE> to be used in queries.

=head2 unix_timestamp

See L<DB::Object::Tables/unix_timestamp>

=head2 for POD::Coverage unknown_field

=head2 unlock

This is a convenient wrapper around L<DB::Object::Query/unlock>

=head2 update

See L<DB::Object::Tables/update>

=head2 use

Given a database, it switch to it, but before it checks that the database exists.
If the database is different than the current one, it sets the I<multi_db> parameter, which will have the fields in the queries be prefixed by their respective database name.

It returns the database handler.

=head2 use_cache

Provided with a boolean value and this sets or get the I<use_cache> parameter.

=head2 use_bind

Provided with a boolean value and this sets or get the I<use_cache> parameter.

=head2 variables

Query the SQL variable $type

It returns a blank string if nothing was found, or the value found.

=head2 version

This is a method that must be implemented by the driver package.

=head2 where

See L<DB::Object::Tables/where>

=head2 _cache_this

Provided with a query, this will cache it for future re-use.

It does some check and maintenance job to ensure the cache does not get too big whenever it exceed the value of $CACHE_SIZE set in the main config file.

It returns the cached statement as an L<DB::Object::Statement> object.

=head2 _check_connect_param

Provided with an hash reference of connection parameters, this will get the valid parameters by calling L</_connection_parameters> and the connection default options by calling L</_connection_options>

It returns the connection parameters hash reference.

=head2 _check_default_option

Provided with an hash reference of options, and it actually returns it, so this does not do much, because this method is supposed to be supereded by the driver package.

=head2 _connection_options

Provided with an hash reference of connection parameters and this will returns an hash reference of options whose keys match the regular expression C</^[A-Z][a-zA-Z]+/>

So this does not do much, because this method is supposed to be superseded by the driver package.

=head2 _connection_parameters

Returns an array reference containing the following keys: db login passwd host port driver database server opt uri debug

=head2 _connection_params2hash

Provided with an hash reference of connection parameters and this will check if the following environment variables exists and if so use them: C<DB_NAME>, C<DB_LOGIN>, C<DB_PASSWD>, C<DB_HOST>, C<DB_PORT>, C<DB_DRIVER>, C<DB_SCHEMA>

If the parameter property I<uri> was provided of if the environment variable C<DB_CON_URI> is set, it will use this connection uri to get the necessary connection parameters values.

An L<URI> could be C<http://localhost:5432?database=somedb> or C<file:/foo/bar?opt={"RaiseError":true}>

Alternatively, if the connection parameter I<conf_file> is provided then its json content will be read and decoded into an hash reference.

The following keys can be used in the json data in the I<conf_file>: C<database>, C<login>, C<passwd>, C<host>, C<port>, C<driver>, C<schema>, C<opt>

The port can be specified in the I<host> parameter by separating it with a semicolon such as C<localhost:5432>

The I<opt> parameter can Alternatively be provided through the environment variable C<DB_OPT>

It returns the hash reference of connection parameters.

=head2 _clean_statement

Given a query string or a reference to it, it cleans the statement by removing leading and trailing space before and after line breaks.

It returns the cleaned up query as a string if the original query was provided as a scalar reference.

=head2 _convert_datetime2object

Provided with an hash or hash reference of options and this will simply return the I<data> property.

This does not do anything meaningful, because it is supposed to be superseded by the diver package.

=head2 _convert_json2hash

Provided with an hash or hash reference of options and this will simply return the I<data> property.

This does not do anything meaningful, because it is supposed to be superseded by the diver package.

=head2 _dbi_connect

This will call L</_dsn> which must exist in the driver package, and based on the C<dsn> received, this will initiate a L<DBI/connect_cache> if the object property L</cache_connections> has a true value, or simply a L<DBI/connect> otherwise.

It returns the database handler.

=head2 _decode_json

Provided with some json data and this will decode it using L<JSON> and return the associated hash reference or L<perlfunc/undef> if an error occurred.

=head2 _dsn

This will die complaining the driver has not implemented this method, unless the driver did implement it.

=head2 _encode_json

Provided with an hash reference and this will encode it into a json string and return it.

=head2 _make_sth

Given a package name and a hash reference, this builds a statement object with all the necessary parameters.

It also sets the query time to the current time with the parameter I<query_time>

It returns an object of the given $package.

=head2 _param2hash

Provided with some hash reference parameters and this will simply return it, so it does not do anything meaningful.

This is supposed to be superseded by the driver package.

=head2 _process_limit

A convenient wrapper around the L<DB::Object::Query/_process_limit>

=head2 _query_object_add

Provided with a L<DB::Object::Query> and this will add it to the current object property I<query_object> and return it.

=head2 _query_object_create

This is supposed to be called from a L<DB::Object::Tables>

Create a new L<DB::Object::Query> object, sets the I<debug> and I<verbose> values and sets its property L<DB::Object::Query/table_object> to the value of the current object.

=head2 _query_object_current

Returns the current I<query_object>

=head2 _query_object_get_or_create

Check to see if the L</query_object> is already set and then return its value, otherwise create a new object by calling L</_query_object_create> and return it.

=head2 _query_object_remove

Provided with a L<DB::Object::Query> and this will remove it from the current object property I<query_object>.

It returns the object removed.

=head2 _reset_query

If this has not already been reset, this will mark the current query object as reset and calls L</_query_object_remove> and return the value for L</_query_object_get_or_create>

If it has been already reset, this will return the value for L</_query_object_current>

=head1 OPERATORS

=head2 ALL( VALUES )

This operator is used to query an array where all elements must match.

    my $tbl = $dbh->hosts || die( "Uable to get table object 'hosts'." );
    $tbl->where( $dbh->OR(
        $tbl->fo->name == 'example.com',
        'example.com' == $dbh->ALL( $tbl->fo->alias )
    ));
    my $sth = $tbl->select || die( "Failed to prepare query to get host information: ", $tbl->error );
    my $ref = $sth->fetchrow_hashref;

See L<PostgreSQL documentation|https://www.postgresql.org/docs/current/arrays.html>

=head2 AND( VALUES )

Given a value, this returns a L<DB::Object::AND> object. You can retrieve the value with L<DB::Object::AND/value>

This is used by L</where>

    my $op = $dbh->AND( login => 'joe', status => 'active' );
    # will produce:
    WHERE login = 'joe' AND status = 'active'

=head2 ANY( VALUES )

This operator is used to query an array where all elements must match.

    my $tbl = $dbh->hosts || die( "Uable to get table object 'hosts'." );
    $tbl->where( $dbh->OR(
        $tbl->fo->name == 'example.com',
        'example.com' == $dbh->ANY( $tbl->fo->alias )
    ));
    my $sth = $tbl->select || die( "Failed to prepare query to get host information: ", $tbl->error );
    my $ref = $sth->fetchrow_hashref;

See L<PostgreSQL documentation|https://www.postgresql.org/docs/current/arrays.html>

=head2 IN

For example:

    SELECT
        c.code, c.name, c.name_l10n, c.locale
    FROM country_locale AS c
    WHERE
        c.locale = 'fr_FR' OR
        ('fr_FR' NOT IN (SELECT DISTINCT l.locale FROM country_locale AS l ORDER BY l.locale) AND 
        c.locale = 'en_GB')
    ORDER BY c.code

    my $tbl = $dbh->country_locale || die( $dbh->error );
    my $tbl2 = $dbh->country_locale || die( $dbh->error );
    $tbl2->as( 'l' );
    $tbl2->order( 'locale' );
    my $sth2 = $tbl2->select( 'DISTINCT locale' ) || die( $tbl2->error );

    $tbl->as( 'c' );
    $tbl->where( $dbh->OR(
        $tbl->fo->locale == 'fr_FR',
        $dbh->AND(
            'fr_FR' != $dbh->IN( $sth2 ),
            $tbl->fo->locale == 'en_GB'
        )
    ) );

    $tbl->order( $tbl->fo->code );
    my $sth = $tbl->select( qw( code name name_l10n locale ) ) || die( $tbl->error );
    say $sth->as_string;

=head2 NOT( VALUES )

Given a value, this returns a L<DB::Object::NOT> object. You can retrieve the value with L<DB::Object::NOT/value>

This is used by L</where>

    my $op = $dbh->AND( login => 'joe', status => $dbh->NOT( 'active' ) );
    # will produce:
    WHERE login = 'joe' AND status != 'active'

=head2 OR( VALUES )

Given a value, this returns a L<DB::Object::OR> object. You can retrieve the value with L<DB::Object::OR/value>

This is used by L</where>

    my $op = $dbh->OR( login => 'joe', login => 'john' );
    # will produce:
    WHERE login = 'joe' OR login = 'john'

=head1 SEE ALSO

L<DBI>, L<Apache::DBI>

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2021 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
