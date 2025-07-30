# -*- perl -*-
##----------------------------------------------------------------------------
## Database Object Interface - ~/lib/DB/Object/Statement.pm
## Version v0.7.0
## Copyright(c) 2024 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2017/07/19
## Modified 2025/03/09
## All rights reserved
## 
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
## This package's purpose is to automatically terminate the statement object and
## separate them from the connection object (DB::Object).
## Connection object last longer than statement objects
##----------------------------------------------------------------------------
package DB::Object::Statement;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( DB::Object );
    use vars qw( $VERSION $DEBUG );
    use Class::Struct qw( struct );
    use Wanted;
    our $DEBUG = 0;
    our $VERSION = 'v0.7.0';
};

use strict;
use warnings;

sub as_string
{
    my $self = shift( @_ );
    # my $q = $self->_query_object_current;
    # used by select, insert, update, delete to flag that we need to reformat the query
    $self->{as_string}++;
    if( my $qo = $self->query_object )
    {
        $qo->final(1);
    }
    # return( $self->{sth}->{Statement} );
    # Same:
    # return( $q->as_string );
    return( $self->{query} );
}

sub bind_param
{
    my $self = shift( @_ );
    my( $pack, $file, $line ) = caller();
    my $sub = ( caller(1) )[3];
    $self->{pack} = $pack;
    $self->{file} = $file;
    $self->{line} = $line;
    $self->{sub}  = $sub;
    my $rc = eval
    {
        $self->{sth}->bind_param( @_ );
    };
    if( $@ )
    {
        my $err = $self->errstr();
        $err =~ s/ at line \d+.*$//;
        # printf( STDERR "%s in %s at line %d within sub '%s'.\n", $err, $self->{file}, $self->{line}, $self->{sub} );
        # exit(1);
        return( $self->error( $err ) );
    }
    elsif( $rc )
    {
        return( $rc );
    }
    else
    {
        my $err = $@ = $self->{sth}->errstr() || "Unknown error while binding parameters to query.";
        return( $self->error( $err ) );
    }
}

sub commit
{
    my $self = shift( @_ );
    if( $self->{sth} && $self->param( 'autocommit' ) )
    {
        my $sth = $self->prepare( 'COMMIT' ) || return( $self->pass_error );
        $sth->execute() || return( $self->error( "An error occurred while executing query: ", $sth->error ) );
        $sth->finish();
    }
    return( $self );
}

sub database_object { return( shift->_set_get_object_without_init( 'dbo', 'DB::Object', @_ ) ); }

sub distinct
{
    my $self = shift( @_ );
    my $query = $self->{query} ||
        return( $self->error( "No query to set as to be ignored." ) );
    
    my $type = uc( ( $query =~ /^\s*(\S+)\s+/ )[0] );
    # ALTER for table alteration statements (DB::Object::Tables
    my @allowed = qw( SELECT );
    my $allowed = CORE::join( '|', @allowed );
    if( !scalar( grep{ /^$type$/i } @allowed ) )
    {
        return( $self->error( "You may not flag statement of type \U$type\E to be distinct:\n$query" ) );
    }
    # Incompatible. Do not bother going further
    return( $self ) if( $query =~ /^\s*(?:$allowed)\s+(?:DISTINCT|DISTINCTROW|ALL)\s+/i );
    
    $query =~ s/^(\s*)($allowed)(\s+)/$1$2 DISTINCT /;
    # my $sth = $self->prepare( $query ) ||
    # $self->{ 'query' } = $query;
    # saving parameters to bind later on must have been done previously
    my $sth = $self->_cache_this( $query ) ||
    return( $self->error( "Error while preparing new ignored query:\n$query" ) );
    if( !defined( wantarray() ) )
    {
        $sth->execute() ||
        return( $self->error( "Error while executing new ignored query:\n$query" ) );
    }
    return( $sth );
}

sub dump
{
    my $self = shift( @_ );
    my $file = shift( @_ );
    if( $file )
    {
        # Used to be handled by SQL server
        # my $query = $self->as_string();
        # $query    =~ s/(\s+FROM\s+)/ INTO OUTFILE '$file'$1/;
        # my $sth   = $self->prepare( $query ) ||
        # return( $self->error( "Error while preparing query to dump result on select:\n$query" ) );
        # $sth->execute() ||
        # return( $self->error( "Error while executing query to dump result on select:\n$query" ) );
        $self->_load_class( 'DateTime' ) || return( $self->pass_error );
        my $fields = $self->{_fields};
        my @header = sort{ $fields->{ $a } <=> $fields->{ $b } } keys( %$fields );
        # new_file is inherited from Module::Generic
        $file = $self->new_file( $file );
        my $io = $file->open( '>', { binmode => 'utf8' }) ||
            return( $self->error( "Unable to open file '$file' in write mode: ", $file->error ) );
        my $date = DateTime->now;
        my $table = $self->{table};
        $io->printf( "## Generated on %s for table $table\n", $date->strftime( '%c' ) );
        $io->print( "## ", CORE::join( "\t", @header ), "\n" );
        my @data = ();
        while( @data = $self->fetchrow() )
        {
            print( $io CORE::join( "\t", @data ), "\n" );
        }
        $io->close;
        $self->finish;
        return( $self );
    }
    elsif( exists( $self->{sth} ) )
    {
        # my $fields = $self->{ '_fields' };
        my @fields = @{ $self->{sth}->FETCH( 'NAME' ) };
        my $max    = 0;
        # foreach my $field ( keys( %$fields ) )
        foreach my $field ( @fields )
        {
            $max = length( $field ) if( length( $field ) > $max );
        }
        my $template = '';
        ## foreach my $field ( sort{ $fields->{ $a } <=> $fields->{ $b } } keys( %$fields ) )
        foreach my $field ( @fields )
        {
            $template .= "$field" . ( '.' x ( $max - length( $field ) ) ) . ": %s\n";
        }
        $template .= "\n";
        my @data = ();
        while( @data = $self->fetchrow() )
        {
            printf( STDERR $template, @data );
        }
        $self->finish;
        return( $self );
    }
    else
    {
        return( $self->error( "No query to dump." ) );
    }
}

sub exec { return( shift->execute( @_ ) ); }

sub execute
{
    my $self = shift( @_ );
    my @args = @_;
    $self->messagec( 5, "{green}", scalar( @args ), "{/} arguments provided." );
    my( $pack, $file, $line ) = caller();
    my $sub = ( caller(1) )[3];
    # What we want is to get the point from where we were originatly called
    my $class = 'DB::Object';
    if( substr( $pack, 0, length( $class ) ) eq $class )
    {
        for( my $i = 1; $i < 5; $i++ )
        {
            ( $pack, $file, $line ) = caller( $i );
            $sub = ( caller( $i + 1 ) )[3];
            last if( substr( $pack, 0, length( $class ) ) ne $class );
        }
    }
    $self->{pack} = $pack;
    $self->{file} = $file;
    $self->{line} = $line;
    $self->{sub}  = $sub;
    $self->{executed}++;
    my $q = $self->query_object;
    $self->messagec( 5, "Query object for this statement is {green}", overload::StrVal( $q // 'undef' ), "{/}" );
    $q->final(1) if( $q );
    my @binded = ();
    my @binded_types = ();
    # Boolean used so we do not automatically change a string litteral into an array
    # if the number of types and values are not the same, as it would lead to undesirable results.
    my $bind_mismatch = 0;
    my $el;
    # As a rule, if the first placeholder is a numbered one, then all are, because we cannot mix numbered placeholder and non-numbered ones.
    my $use_numbered_placeholders = ( ( $q && $q->elements->first->is_numbered ) ? 1 : 0 );
    if( $q && 
        ( $el = $q->elements ) &&
        $el->types->length )
    {
        $self->messagec( 5, "There are {green}", $el->length, "{/} elements for this query." );
        my $types = $q->binded_types_as_param;
        $self->messagec( 5, "Using {green}", $el->types->length, "{/} binded types from the query object ($q) -> ", sub{ $self->Module::Generic::dump( $types ) } );
        @binded_types = @$types;
    }
    
    if( defined( $el ) )
    {
        $self->messagec( 5, "{green}", $el->elements->length, "{/} elements set and {green}", scalar( @binded_types ), "{/} types set so far with \$q->binded_types_as_param." );
    }
    
    # Get the values to bind
    if( $q && $self->{bind} )
    {
        if( @_ && 
            (
                # hash reference
                ( @_ == 1 && $self->_is_hash( $_[0] => 'strict' ) ) ||
                # key => value pairs
                ( !( @_ % 2 ) && ref( $_[0] ) ne 'HASH' )
            )
          )
        {
            my $vals = {};
            if( $self->_is_hash( $_[0] => 'strict' ) )
            {
                $vals = shift( @_ );
            }
            else
            {
                $vals = { @_ };
            }
            # This is the list of fields as they appear in the order in insert or update query
            # Knowing their order of appearance is key so we can bind follow-on values to them
            my $sorted = $q->sorted;
            foreach my $f ( @$sorted )
            {
                if( !CORE::exists( $vals->{ $f } ) )
                {
                    push( @binded, undef() );
                }
                # The value may be defined or not, or may be zero length long
                else
                {
                    push( @binded, $vals->{ $f } );
                }
            }
        }
        elsif( @_ )
        {
            push( @binded, @_ );
        }
        else
        {
            # my $binded_values = $q->binded;
            my $binded_values = $q->elements->values;
            push( @binded, @$binded_values ) if( scalar( @$binded_values ) );
        }
    }

    @binded = @_ if( !@binded && @_ );
    @binded = () if( !@binded );
    if( $q && $q->is_upsert )
    {
        if( !$use_numbered_placeholders && 
            scalar( @binded_types ) > scalar( @binded ) )
        {
            CORE::push( @binded, @binded );
        }
    }

    if( scalar( @_ ) )
    {
        my $temp = {};
        my $el;
        $el = $q->elements->elements if( $q && $q->elements );
        local $" = ', ';
        for( my $i = 0; $i < scalar( @args ); $i++ )
        {
            # { $some_value => 'varchar' }
            if( ref( $_[$i] ) eq 'HASH' && 
                scalar( keys( %{$_[$i]} ) ) == 1 &&
                # e.g. DBI::SQL_VARCHAR or DBI::SQL_INTEGER
                DBI->can( "SQL_" . uc( [values( %{$_[$i]} )]->[0] ) ) )
            {
                my $constant = DBI->can( "SQL_" . uc( [values( %{$_[$i]} )]->[0] ) );
                $temp->{$i} = { type => $constant->(), value => [keys( %{$_[$i]} )]->[0] };
            }
        }

        # The user has chosen to override any datatype computed and be explicit.
        if( scalar( keys( %$temp ) ) == scalar( @_ ) )
        {
            # @binded = @_;
            @binded_types = ();
            @binded = ();
            foreach my $i ( sort( keys( %$temp ) ) )
            {
                push( @binded_types, $temp->{ $i }->{type} );
                push( @binded, $temp->{ $i }->{value} );
            }
        }
        elsif( scalar( keys( %$temp ) ) )
        {
            foreach my $i ( sort( keys( %$temp ) ) )
            {
                CORE::splice( @binded_types, $i, 1, $temp->{ $i }->{type} );
                $binded[$i] = $temp->{ $i }->{value};
            }
        }
    }

    if( $q && scalar( @binded ) != scalar( @binded_types ) )
    {
        # Flag we use a bit below
        $bind_mismatch++;
        warn( sprintf( "Warning: total %d bound values does not match the total %d bound types ('%s')! Check the code for query $self->{sth}->{Statement}\n", scalar( @binded ), scalar( @binded_types ), CORE::join( "','", @binded_types ) ) );
        # Cancel it, because it will create problems
        @binded_types = ();
    }

    # If there are any array object of some sort provided, make sure they are transformed into a regular array so DBD::Ph can then transform it into a Postgres array.
    $self->messagec( 6, "There are {green}", scalar( @binded ), "{/} value(s) to bind for query: ", $self->{query} );
    for( my $i = 0; $i < scalar( @binded ); $i++ )
    {
        next if( !defined( $binded[$i] ) );
        my $elem;
        if( defined( $el ) && 
            !$bind_mismatch &&
            ( $elem = $el->elements->[$i] ) &&
            defined( $elem ) &&
            $self->_is_a( $elem->fo => 'DB::Object::Fields::Field' ) )
        {
        }
        
        if( defined( $el ) && 
            !$bind_mismatch &&
            ( $elem = $el->elements->[$i] ) &&
            defined( $elem ) &&
            $self->_is_a( $elem->fo => 'DB::Object::Fields::Field' ) &&
            $elem->fo->is_array &&
            !$self->_is_array( $binded[$i] ) &&
            defined( $binded[$i] ) )
        {
            $self->messagec( 5, "Transforming value {green}", $binded[$i], "{/} into an array." );
            $binded[$i] = $self->_is_number( $binded[$i] ) ? [$binded[$i]] : [$self->database_object->quote( $binded[$i] )];
        }
        elsif( defined( $el ) && 
            !$bind_mismatch &&
            ( $elem = $el->elements->[$i] ) &&
            defined( $elem ) &&
            $self->_is_a( $elem->fo => 'DB::Object::Fields::Field' ) &&
            ( $elem->fo->type eq 'jsonb' || $elem->fo->type eq 'json' ) &&
            $self->_is_hash( $binded[$i] => 'strict' ) )
        {
            $self->messagec( 5, "Transforming hash value {green}", $binded[$i], "{/} into a JSON string." );
            # try-catch
            local $@;
            my $json = eval
            {
                $self->new_json->encode( $binded[$i] );
            };
            if( $@ )
            {
                warn( "Error trying to encode hash value ", $binded[$i], ": $@" ) if( $self->_is_warnings_enabled( 'DB::Object' ) );
            }
            else
            {
                $binded[$i] = $json;
            }
        }
        # If the value provided is a DateTime object without a formatter, we transform the given value into a ISO8601 datetime string
        elsif( defined( $el ) &&
            !$bind_mismatch &&
            ( $elem = $el->elements->[$i] ) &&
            defined( $elem ) &&
            $self->_is_a( $elem->fo => 'DB::Object::Fields::Field' ) &&
            ( $elem->fo->type =~ /^(date|timestamp)/i || $elem->fo->datatype->alias->grep( qr/^(date|timestamp)/i )->length ) &&
            defined( $binded[$i] ) &&
            $self->_is_a( $binded[$i] => 'DateTime' ) &&
            # There is no formatter
            !$binded[$i]->formatter )
        {
            $binded[$i] = $binded[$i]->iso8601;
        }

        # The value is an array object, but not a simple array, so we need to convert it
        # or else the driver will not understand nor accept it.
        if( $self->_is_array( $binded[$i] ) && 
            ref( $binded[$i] ) ne 'ARRAY' )
        {
            $binded[$i] = [@{$binded[$i]}];
        }
        elsif( $self->_is_object( $binded[$i] ) && 
               overload::Overloaded( $binded[$i] ) && 
               overload::Method( $binded[$i], '""' ) )
        {
            no warnings 'uninitialized';
            my $v = "$binded[$i]";
            $binded[$i] = defined( $v ) ? $v : undef;
        }
        # Will work well with Module::Generic::Hash
        elsif( $self->_is_hash( $binded[$i] ) && 
               $self->_can( $binded[$i], 'as_json' ) )
        {
            $binded[$i] = $binded[$i]->as_json;
        }
    }
    
    local $_;
    my $rv = eval
    {
        local( $SIG{ALRM} ) = sub{ die( "Timeout while processing query $self->{sth}->{Statement}\n" ) };
        for( my $i = 0; $i < scalar( @binded ); $i++ )
        {
            # Stringify the binded value if it is a stringifyable object.
            if( ref( $binded[$i] ) && 
                $self->_is_object( $binded[$i] ) &&
                overload::Overloaded( $binded[$i] ) &&
                overload::Method( $binded[$i], '""' ) )
            {
                $binded[$i] .= '';
            }
            
            my $data_type = $binded_types[ $i ];
            if( CORE::length( $data_type ) && $self->_is_hash( $data_type ) )
            {
                $self->{sth}->bind_param( $i + 1, $binded[ $i ], $data_type );
            }
            else
            {
                $self->{sth}->bind_param( $i + 1, $binded[ $i ] );
            }
        }
        $self->{sth}->execute();
    };
    my $error = $@;
    $error ||= $self->{sth}->errstr if( !$rv );
    if( $q )
    {
        if( $q->join_tables->length > 0 )
        {
            $q->join_tables->foreach(sub{
                my $tbl = shift( @_ );
                return if( !$tbl || !ref( $tbl ) );
                $tbl->reset;
            });
        }
        $q->table_object->reset;
    }
    my $tie = $self->{tie} || {};
    # Maybe it is time to bind SQL result to possible provided perl variables?
    if( !$error && %$tie )
    {
        my $order = $self->{tie_order};
        my $sth   = $self->{sth};
        for( my $i = 0; $i < @$order; $i++ )
        {
            my $pos = $i + 1;
            my $val = $order->[ $i ];
            if( exists( $tie->{ $val } ) && ref( $tie->{ $val } ) eq 'SCALAR' )
            {
                $sth->bind_col( $pos, $tie->{ $val } );
            }
        }
    }
    if( $error )
    {
        $error =~ s/ at (\S+\s)?line \d+.*$//s;
        # $err .= ":\n\"$self->{ 'query' }\"";
        $error .= ":\n\"$self->{sth}->{Statement}\"";
        $error = "Error while trying to execute query $self->{sth}->{Statement}: $error";
        if( $self->fatal() )
        {
            die( "$error in $self->{file} at line $self->{line} within sub $self->{sub}\n" );
        }
        else
        {
            # return( $self->error( "$err in $self->{ 'file' } at line $self->{ 'line' } within sub $self->{ 'sub' }" ) );
            return( $self->error( $error ) );
        }
    }
    elsif( $self->{sth}->errstr() )
    {
        return( $self->error( "Error while trying to execute query $self->{sth}->{Statement}: ", $self->{sth}->errstr ) );
    }
    # Clear any error, since this query statement may be re-used
    $self->clear_error;

    # User wants an object for chaining like:
    # $sth->exec( 'some value' )->fetchrow;
    if( want( 'OBJECT' ) )
    {
        return( $self );
    }
    elsif( $rv )
    {
        return( $rv );
    }
    # For void context too
    else
    {
        return(1);
    }
}

sub executed
{
    my $self = shift( @_ );
    # For hand made query to avoid clash when executing generic routine such as fetchall_arrayref...
    return( 1 ) if( !exists( $self->{query} ) );
    return( exists( $self->{executed} ) && $self->{executed} );
}

sub fetchall_arrayref($@)
{
    my $self  = shift( @_ );
    my $slice = shift( @_ ) || [];
    my $dbo   = $self->database_object;
    my $sth   = $self->{sth};
    if( !$self->executed() )
    {
        $self->execute() || return;
    }
    # Ensure we set the cache of field names and types. We will need them to post process the query results with _convert_datetime2object()
# This is necessary for MySQL whose object lose that information, while the PostgreSQL or SQLite driver keep the information.
    my $need_post_processing = ( ( $dbo->auto_decode_json || $dbo->auto_convert_datetime_to_object ) ? 1 : 0 );
    if( $need_post_processing )
    {
        $self->_cache_field_names;
        $self->_cache_field_types;
    }
    # $self->_cleanup();
    my $mode  = ref( $slice );
    my @rows;
    my $row;
    if( $mode eq 'ARRAY' )
    {
        if( @$slice )
        {
            push( @rows, [ @{ $row }[ @{ $slice } ] ] ) while( $row = $sth->fetch() );
        }
        else
        {
            push( @rows, [ @{ $row } ] ) while( $row = $sth->fetch );
        }
    }
    elsif( $mode eq 'HASH' )
    {
        my @o_keys = keys( %$slice );
        if( @o_keys )
        {
            # my %i_names = map{  ( lc( $_ ) => $_ ) } @{ $sth->FETCH( 'NAME' ) };
            # my @i_keys  = map{ $i_names{ lc( $_ ) } } @o_keys;
            my $i_keys  = $self->field_names_lc;
            while( $row = $sth->fetchrow_hashref() )
            {
                my %hash;
                @hash{ @o_keys } = @{ $row }{ @$i_keys };
                push( @rows, \%hash );
            }
        }
        else
        {
            push( @rows, $row ) while( $row = $sth->fetchrow_hashref() );
        }
    }
    else
    {
        warn( "fetchall_arrayref($mode) invalid" );
    }
    # return( \@rows );
    return( \@rows ) if( !$need_post_processing );
    my $data = \@rows;
    $data = $self->_convert_json2hash({ statement => $sth, data => $data }) if( $dbo->auto_decode_json );
    $data = $self->_convert_datetime2object({ statement => $sth, data => $data }) if( $dbo->auto_convert_datetime_to_object );
    return( $data );
}

sub fetchcol($;$)
{
    my $self = shift( @_ );
    # @arr = $sth->fetchcol( $col_number );
    my $col_num = shift( @_ );
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # $self->_cleanup();
    # return( $h->fetchcol( $COL_NUM ) );
    my @col;
    # $self->dataseek( 0 );
    my $ref;
    while( $ref = $self->{sth}->fetchrow_arrayref() )
    {
        push( @col, $ref->[ $col_num ] );
    }
    return( @col );
}

sub fetchhash(@)
{
    my $self = shift( @_ );
    my $dbo  = $self->database_object;
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # Ensure we set the cache of field names and types. We will need them to post process the query results with _convert_datetime2object()
    # This is necessary for MySQL whose object lose that information, while the PostgreSQL or SQLite driver keep the information.
    if( $dbo->auto_decode_json || $dbo->auto_convert_datetime_to_object )
    {
        $self->_cache_field_names;
        $self->_cache_field_types;
    }
    # $self->_cleanup();
    # %hash = $sth->fetchhash;
    # return( $h->fetchhash );
    my $sth = $self->{sth} || die( "Unable to get the underlying statement handler!" );
    my $ref = $sth->fetchrow_hashref();
    if( $ref ) 
    {
        if( $dbo->auto_decode_json || $dbo->auto_convert_datetime_to_object )
        {
            $ref = $self->_convert_json2hash({ statement => $sth, data => $ref }) if( $dbo->auto_decode_json );
            $ref = $self->_convert_datetime2object({ statement => $sth, data => $ref }) if( $dbo->auto_convert_datetime_to_object );
        }
        return( %$ref );
    }
    else
    {
        return( () );
    }
}

sub fetchrow(@)
{
    my $self = shift( @_ );
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # $self->_cleanup();
    # @arr = $sth->fetchrow;        # Array context
    # $firstcol = $sth->fetchrow;   # Scalar context
    # return( $h->fetchrow );
    # my $ref = $self->fetchrow_arrayref();
    my $ref = $self->{sth}->fetchrow_arrayref();
    # my $ref = $self->{sth}->fetch();
    if( $ref ) 
    {
        return( wantarray ? @$ref : $ref->[0] );
    }
    else
    {
        return( () );
    }
}

# sub fetchrow_hashref(@) is inherited from DBI
sub fetchrow_hashref
{
    my $self = shift( @_ );
    my $dbo  = $self->database_object;
    my $deb = {};
    %$deb = %$self;
    my $sth = $self->{sth};
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # Ensure we set the cache of field names and types. We will need them to post process the query results with _convert_datetime2object()
    # This is necessary for MySQL whose object lose that information, while the PostgreSQL or SQLite driver keep the information.
    if( $dbo->auto_decode_json || $dbo->auto_convert_datetime_to_object )
    {
        $self->_cache_field_names;
        $self->_cache_field_types;
    }
    my $ref = $sth->fetchrow_hashref;
    $ref = $self->_convert_json2hash({ statement => $sth, data => $ref }) if( $dbo->auto_decode_json );
    $ref = $self->_convert_datetime2object({ statement => $sth, data => $ref }) if( $dbo->auto_convert_datetime_to_object );
    return( $ref );
}

sub fetchrow_object
{
    my $self = shift( @_ );
    # This should give us something like Postgres or Mysql or SQLite
    my $basePack = ( ref( $self ) =~ /^DB::Object::([^\:]+)/ )[0];
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # $self->_cleanup();
    my $rows = $self->{sth}->rows;
    my $ref = $self->{sth}->fetchrow_hashref();
    if( $ref && scalar( keys( %$ref ) ) ) 
    {
        my $struct = { map{ $_ => '$' } keys( %$ref ) };
        my $table  = $self->table;
        my $class  = "DB::Object::${basePack}::Result::${table}";
        if( !defined( &{ $class . '::new' } ) )
        {
            struct $class => $struct;
        }
        my $obj = $class->new( %$ref );
        return( $obj );
    }
    else
    {
        return( () );
    }
}

# NOTE: field_names -> NAME
# <https://metacpan.org/pod/DBI#NAME>
sub field_names { return( shift->_get_statement_attribute( 'NAME' ) ); }

# NOTE: field_names_lc -> NAME_lc
# <https://metacpan.org/pod/DBI#NAME_lc>
sub field_names_lc { return( shift->_get_statement_attribute( 'NAME_lc' ) ); }

# NOTE: field_names_uc -> NAME_uc
# <https://metacpan.org/pod/DBI#NAME_uc>
sub field_names_uc { return( shift->_get_statement_attribute( 'NAME_uc' ) ); }

# NOTE: field_nullables -> NULLABLE
# <https://metacpan.org/pod/DBI#NULLABLE>
sub field_nullables { return( shift->_get_statement_attribute( 'NULLABLE' ) ); }

# NOTE: field_precisions -> PRECISION
# <https://metacpan.org/pod/DBI#PRECISION>
sub field_precisions { return( shift->_get_statement_attribute( 'PRECISION' ) ); }

# NOTE: field_scales -> SCALE
# <https://metacpan.org/pod/DBI#SCALE>
sub field_scales { return( shift->_get_statement_attribute( 'SCALE' ) ); }

# NOTE: field_types -> TYPE
# <https://metacpan.org/pod/DBI#TYPE>
sub field_types { return( shift->_get_statement_attribute( 'TYPE' ) ); }

sub finish
{
    my $self = shift( @_ );
    my $rc   = $self->{sth}->finish();
    if( !$rc )
    {
        return( $self->error( $self->{sth}->errstr() ) );
    }
    else
    {
        return( $rc );
    }
}

sub ignore
{
    my $self = shift( @_ );
    my $query = $self->{query} ||
    return( $self->error( "No query to set as to be ignored." ) );
    
    my $type = uc( ( $query =~ /^\s*(\S+)\s+/ )[0] );
    # ALTER for table alteration statements (DB::Object::Tables
    my @allowed = qw( INSERT UPDATE ALTER );
    my $allowed = CORE::join( '|', @allowed );
    if( !scalar( grep{ /^$type$/i } @allowed ) )
    {
        return( $self->error( "You may not flag statement of type \U$type\E to be ignored:\n$query" ) );
    }
    # Incompatible. Do not bother going further
    return( $self ) if( $query =~ /^\s*(?:$allowed)\s+(?:DELAYED|LOW_PRIORITY|HIGH_PRIORITY)\s+/i );
    return( $self ) if( $type eq 'ALTER' && $query !~ /^\s*$type\s+TABLE\s+/i );
    
    $query =~ s/^(\s*)($allowed)(\s+)/$1$2 IGNORE /;
    # my $sth = $self->prepare( $query ) ||
    # $self->{ 'query' } = $query;
    # saving parameters to bind later on must have been done previously
    my $sth = $self->_cache_this( $query ) ||
    return( $self->error( "Error while preparing new ignored query:\n$query" ) );
    if( !defined( wantarray() ) )
    {
        $sth->execute() ||
        return( $self->error( "Error while executing new ignored query:\n$query" ) );
    }
    return( $sth );
}

sub join
{
    my $self = shift( @_ );
    my $data = shift( @_ );
    my $on;
    if( @_ )
    {
        $on = ( scalar( @_ ) == 1 && ref( $_[0] ) ) ? shift( @_ ) : [ @_ ];
    }
    my $q = $self->query_object || return( $self->error( "No query formatter object was set" ) );
    my $tbl_o = $q->table_object || return( $self->error( "No table object is set in query object." ) );
    my $query = $q->query ||
        return( $self->error( "No query prepared for join with another table." ) );
    if( $query !~ /^[[:blank:]]*SELECT[[:blank:]]+/i )
    {
        return( $self->error( "You may not perform a join on a query other than select." ) );
    }
    my $constant = $q->constant;
    # Constant is set and query object marked as final, which means this statement has already been processed as a join and so we skip all further processing.
    if( scalar( keys( %$constant ) ) && $q->final )
    {
        return( $self );
    }
    my $table      = $tbl_o->table;
    my $db         = $tbl_o->database;
    my $multi_db   = $tbl_o->prefix_database;
    my $alias      = $tbl_o->as;
    my $new_fields = '';
    my $new_table  = '';
    my $new_db     = '';
    my $class      = ref( $self );
    my $q_source   = $q->clone;
    my $q_target;
    # On the duplicated table object, add the current table in the join
    $q_source->join_tables( $tbl_o ) if( !$q_source->join_tables->length );
    # $data is a DB::Object::Postgres::Statement object - we get all its parameter and merge them with ours
    # if( ref( $data ) && ref( $data ) eq $class )
    if( ref( $data ) && $self->_is_a( $data, $class ) )
    {
        $q_target = $data->query_object;
    }
    # $data is the table name
    else
    {
        my $join_tbl;
        if( $self->_is_object( $data ) && $data->isa( 'DB::Object::Tables' ) )
        {
            $self->messagec( 4, "Object table {green}", $data->name, "{/} object ", overload::StrVal( $data ), " is provided." );
            $join_tbl = $data;
        }
        elsif( $self->_is_object( $data ) )
        {
            return( $self->error( "I was expecting either a table name as a scalar or a table object, but instead got \"$data\" (", ref( $data ), ")." ) );
        }
        else
        {
            $self->messagec( 4, "Table name provided for join '{green}${data}{/}' (", overload::StrVal( $data ), ")." );
            return( $self->error( "No such table \"$data\" exists in database \"$db\"." ) ) if( !$self->database_object->table_exists( $data ) );
            $join_tbl = $self->database_object->table( $data );
            return( $self->error( "Could not get a table object from \"$data\"." ) ) if( !$join_tbl );
        }
        $join_tbl->prefixed( $db ne $join_tbl->database_object->database ? 3 : 1 );
        my $sth_tmp = $join_tbl->select || return( $self->pass_error( $join_tbl->error ) );
        $q_target = $sth_tmp->query_object || 
            return( $self->error( "Could not get a query object out of the dummy select query I made from table \"$data\"." ) );
        $new_fields = $q_target->selected_fields;
        # NOTE: 2021-08-22: If we reset it here, we lose the table aliasing
        # $join_tbl->reset;
        
        # $join_tbl->prefixed( $db ne $join_tbl->database_object->database ? 3 : 1 ) unless( $join_tbl->prefixed );
        $new_table = $join_tbl->prefix;
        $join_tbl->reset;
        # We assume this table is part of our same database
        $new_db     = $db;
        # my $db_data = $self->getdefault( $new_table );
        # $new_fields = $db_data->format_statement();
        $new_fields = '';
    }
    # TODO: check this or remove it
    # $q_target->table_object->prefixed( $db ne $q_target->database_object->database ? 3 : 1 );
    $new_fields = $q_target->selected_fields;
    $new_table  = $q_target->table_object->name;
    # $new_table  = $q_target->table_object->prefix;
    $new_db     = $q_target->database_object->database;
    $q_source->join_tables->push( $q_target->table_object );
    if( $q->where && $q_target->where )
    {
        $self->messagec( 5, "Merging the where clause of target table {green}", $q_target->table_object->name, "{/} with source table {green}", $q_source->table_object->name, "{/}" );
        $q_source->where(
            $self->AND(
                ( $q->where ),
                $q_target->new_clause({ value => '( ' . ( $q_target->where ) . ' )' })
            )
        );
    }
    elsif( $q_target->where )
    {
        $self->messagec( 5, "Souce table has no where clause. Setting the where clause of target table {green}", $q_target->table_object->name, "{/} to that of the source table {green}", $q_source->table_object->name, "{/}" );
        $q_source->where( $q_target->where );
    }
    if( my $group_target = $q_target->group )
    {
        $self->messagec( 5, "Adding group clause clause of the target table {green}", $q_target->table_object->name, "{/} to the source table {green}", $q_source->table_object->name, "{/} -> ", ( $group_target->value->length ? 'yes' : 'no, nothing to set' ) );
        $q_source->group( $group_target ) if( $group_target->value->length );
    }
    if( my $order_target = $q_target->order )
    {
        $self->messagec( 5, "Adding order clause clause of the target table {green}", $q_target->table_object->name, "{/} to the source table {green}", $q_source->table_object->name, "{/} -> ", ( $order_target->value->length ? 'yes' : 'no, nothing to set' ) );
        $q_source->order( $order_target ) if( $order_target->value->length );
    }
    
    if( ( !$q_source->limit || ( $q_source->limit && !$q_source->limit->length ) ) && 
        $q_source->limit && $q_source->limit->length )
    {
        $q_source->limit( $q_target->limit );
    }
    
    my $prev_fields = length( $q->join_fields ) ? $q->join_fields : $q->selected_fields;
    # Regular express to prepend previous fields by their table name if that's not the case already
    $tbl_o->prefixed( $db ne $new_db ? 3 : 1 );
    # Prefix for previous fields list
    my $prev_prefix = $tbl_o->prefix;
    my $prev_fields_hash = $q->table_object->fields;
    my $prev_fields_list = CORE::join( '|', sort( keys( %$prev_fields_hash ) ) );
    my $re = qr/(?<![\.\"])\b($prev_fields_list)\b/;
    $prev_fields =~ s/(?<![\.\"])\b($prev_fields_list)\b/${prev_prefix}.$1/gs;
    my $fields = $new_fields ? CORE::join( ', ', $prev_fields, $new_fields ) : $prev_fields;
    $q_source->join_fields( $fields );
    $q_source->from_table->push(
        $q_source->table_alias
            ? sprintf( '%s AS %s', $q_source->table_object->name, $q_source->table_alias )
            : ( $q_source->table_object->prefixed ? $q_source->table_object->prefix : $q_source->table_object->name )
    ) if( !$q_source->from_table->length );
    my $left_join = '';
    my $condition = '';
    my $format_condition;
    $format_condition = sub
    {
        my @vals = ();
        my $vals = shift( @_ );
        my $op   = shift( @_ );
        my @res  = ();
        my $fields_tables = {};
        while( scalar( @$vals ) )
        {
            if( $self->_is_object( $vals->[0] ) && $vals->[0]->isa( 'DB::Object::Operator' ) )
            {
                my $sub_obj = shift( @$vals );
                my $sub_op = $sub_obj->operator;
                my( @sub_vals ) = $sub_obj->value;
                $self->messagec( 5, "format_condition(): Value '", overload::StrVal( $vals->[0] ), "' is a DB::Object::Operator object with operator name {green}${sub_obj}{/} and values -> ", sub{ $self->Module::Generic::dump( \@sub_vals ) } );
                my $this_ref = $format_condition->( \@sub_vals, $sub_op );
                CORE::push( @res, $this_ref->{clause} ) if( length( $this_ref->{clause} ) );
                my $tmp = $this_ref->{fields_tables};
                my @those_table_names = keys( %$tmp );
                @$fields_tables{ @those_table_names } = @$tmp{ @those_table_names };
            }
            else
            {
                if( $self->_is_object( $vals->[0] ) && $vals->[0]->isa( 'DB::Object::Fields::Overloaded' ) )
                {
                    $self->messagec( 5, "format_condition(): Value '", overload::StrVal( $vals->[0] ), "' is an overloaded field object DB::Object::Fields::Overloaded" );
                    my $f1 = shift( @$vals );
                    $f1->field->prefixed( $multi_db ? 3 : 1 );
                    CORE::push( @res, "$f1" );
                    $fields_tables->{ $f1->field->table }++ if( !$fields_tables->{ $f1->field->table } );
                    next;
                }
                
                my( $f1, $f2 ) = ( shift( @$vals ), shift( @$vals ) );
                my $i_am_negative = 0;
                if( $self->_is_object( $f2 ) && $f2->isa( 'DB::Object::NOT' ) )
                {
                    ( $f2 ) = $f2->value;
                    $i_am_negative++;
                }
                
                my( $field1, $field2 );
                if( $self->_is_object( $f1 ) && $f1->isa( 'DB::Object::Fields::Field' ) )
                {
                    $self->messagec( 5, "format_condition(): \$f1 is a field object ({green}", $f1->name, "{/}). Adding its related table {green}", $f1->table, "{/} as known." );
                    $f1->prefixed( $multi_db ? 3 : 1 );
                    $field1 = $f1->name;
                    $fields_tables->{ $f1->table }++ if( !$fields_tables->{ $f1->table } );
                }
                else
                {
                    $field1 = $multi_db ? "$new_db.$new_table.$f1" : "$new_table.$f1";
                }
                if( $self->_is_object( $f2 ) && $f2->isa( 'DB::Object::Fields::Field' ) )
                {
                    $self->messagec( 5, "format_condition(): \$f2 is a field object ({green}", $f2->name, "{/}). Adding its related table {green}", $f2->table, "{/} as known." );
                    $f2->prefixed( $multi_db ? 3 : 1 );
                    $field2 = $f2->name;
                    $fields_tables->{ $f2->table }++ if( !$fields_tables->{ $f2->table } );
                }
                else
                {
                    $field2 = $multi_db ? "$new_db.$new_table.$f2" : "$new_table.$f2";
                }
                CORE::push( @res, $i_am_negative ? "$field1 != $field2" : "$field1 = $field2" );
            }
        }
        return({
            clause => CORE::join( $op, @res ),
            fields_tables => $fields_tables,
        });
    };
    
    # $on is either a $dbh->AND, or $dbh->OR
    if( defined( $on ) )
    {
        if( $self->_is_object( $on ) && $on->isa( 'DB::Object::Operator' ) )
        {
            my $op = $on->operator;
            my( @vals ) = $on->value;
            my $ret = $format_condition->( \@vals, $op );
            my $as = $q_target->table_alias ? sprintf( ' AS %s', $q_target->table_alias ) : '';
            $left_join = "LEFT JOIN ${new_table}${as} ON $ret->{clause}";
        }
        elsif( $self->_is_object( $on ) && $on->isa( 'DB::Object::Fields::Overloaded' ) )
        {
            my $as = $q_target->table_alias ? sprintf( ' AS %s', $q_target->table_alias ) : '';
            $left_join = "LEFT JOIN ${new_table}${as} ON ${on}";
        }
        elsif( $self->_is_array( $on ) )
        {
            my $ret = $format_condition->( $on, 'AND' );
            my $as = $q_target->table_alias ? sprintf( ' AS %s', $q_target->table_alias ) : '';
            $left_join = "LEFT JOIN ${new_table}${as} ON $ret->{clause}";
        }
        # There is a second parameter - if so this is the condition of the 'LEFT JOIN'
        elsif( $self->_is_hash( $on => 'strict' ) )
        {
            # Previous join
            my $join_ref = $q_source->left_join;
            my $def = { on => $on, table_object => $q_target->table_object, query_object => $q_target };
            ## Add the current one
            if( $multi_db )
            {
                $join_ref->{ "$new_db.$new_table" } = $def;
            }
            else
            {
                $join_ref->{ $new_table } = $def;
            }
            # (Re)build the LEFT JOIN ... ON ... definition
            my @join_data = ();
            foreach my $joined ( keys( %$join_ref ) )
            {
                my $condition = $join_ref->{ $joined }->{on};
                my $to = $join_ref->{ $joined }->{table_object};
                my $qo = $join_ref->{ $joined }->{query_object};
                my $join_table_name = $to->prefix;
                my $join_table_alias = '';
                if( length( $join_table_alias = $qo->table_alias ) )
                {
                    $join_table_alias = " AS $join_table_alias";
                }
                push( @join_data, "LEFT JOIN ${join_table_name}${join_table_alias} ON " . CORE::join( ' AND ', map{ "$_=$condition->{ $_ }" } keys( %$condition ) ) );
            }
            $left_join = CORE::join( ' ', @join_data );
        }
        else
        {
            warn( "Warning: I have no clue what to do with '$on' (", overload::StrVal( $on ), ") in this join for table \"", $q->table_object->name, "\"\n" );
        }
    }
    # Otherwise, this is a straight JOIN
    else
    {
        # $q_source->from_table->push( $multi_db ? "$new_db.$new_table" : $new_table );
        $q_source->from_table->push(
            $q_target->table_alias
                ? sprintf( '%s AS %s', $q_target->table_object->name, $q_target->table_alias )
                : ( $q_target->table_object->prefixed ? $q_target->table_object->prefix : $q_target->table_object->name )
        );
    }
    my $from = $q_source->from_table->join( ', ' );
    my $clause = $q_source->_query_components( 'select', { no_bind_copy => 1 } );
    my @query = ( "SELECT ${fields} FROM ${from} ${left_join}" );
    push( @query, @$clause ) if( @$clause );
    my $statement = CORE::join( ' ', @query );
    $q_source->query( $statement );
    my $sth = $tbl_o->_cache_this( $q_source ) ||
        return( $self->error( "Error while preparing query to select:\n", $q_source->as_string(), $tbl_o->error ) );
    # Routines such as as_string() expect an array on pupose so we do not have to commit the action
    # but rather get the statement string. At the end, we write:
    # $obj->select() to really select
    # $obj->select->as_string() to ONLY get the formatted statement
    # wantarray() returns the undefined value in void context, which is typical use of a real select command
    # i.e. $obj->select();
    if( !defined( wantarray() ) )
    {
        $sth->execute() ||
            return( $self->error( "Error while executing query to select:\n", $q_source->as_string(), "\nError: ", $sth->error() ) );
    }
    return( $sth );
}

# NOTE: number_of_fields -> NUM_OF_FIELDS
# <https://metacpan.org/pod/DBI#NUM_OF_FIELDS>
sub number_of_fields { return( shift->_get_statement_attribute( 'NUM_OF_FIELDS' ) ); }

# NOTE: number_of_params -> NUM_OF_PARAMS
# <https://metacpan.org/pod/DBI#NUM_OF_PARAMS>
sub number_of_params { return( shift->_get_statement_attribute( 'NUM_OF_PARAMS' ) ); }

sub object
{
    my $self = shift( @_ );
    # This is intended for statement to fetched their object:
    # my $obj = $table->select( '*' )->object();
    # my $obj = $table->select( '*' )
    # would merly execute the statement before returning its object, but there are conditions
    # such like using a SELECT to create a table where we do not want the statement to be executed already
    return( $self->{sth} ) if( $self->{sth} );
    # More sensible approach will return a special Module::Generic::Null object to avoid perl complaining of 'called on undef value' if this is used in chaining
    return( Module::Generic::Null->new ) if( want( 'OBJECT' ) );
    return;
}

sub priority
{
    my $self = shift( @_ );
    my $prio = shift( @_ );
    my $map  =
    {
    0    => 'LOW_PRIORITY',
    1    => 'HIGH_PRIORITY',
    };
    ## Bad argument. Do not bother
    return( $self ) if( !exists( $map->{ $prio } ) );
    
    my $query = $self->{query} ||
    return( $self->error( "No query to set priority for was provided." ) );
    my $type = uc( ( $query =~ /^\s*(\S+)\s+/ )[ 0 ] );
    my @allowed = qw( DELETE INSERT REPLACE SELECT UPDATE );
    my $allowed = CORE::join( '|', @allowed );
    # Ignore if not allowed
    if( !scalar( grep{ /^$type$/i } @allowed ) )
    {
        $self->error( "You may not set priority on statement of type \U$type\E:\n$query" );
        return( $self );
    }
    # Incompatible. Do not bother going further
    return( $self ) if( $query =~ /^\s*(?:$allowed)\s+(?:DELAYED|LOW_PRIORITY|HIGH_PRIORITY)\s+/i );
    # SELECT with something else than HIGH_PRIORITY is incompatible, so do not bother to go further
    return( $self ) if( $prio != 1 && $type =~ /^(?:SELECT)$/i );
    return( $self ) if( $prio != 0 && $type =~ /^(?:DELETE|INSERT|REPLACE|UPDATE)$/i );
    
    $query =~ s/^(\s*)($allowed)(\s+)/$1$2 $map->{ $prio } /i;
    # $self->{ 'query' } = $query;
    # my $sth = $self->prepare( $query ) ||
    my $sth = $self->_cache_this( $query ) ||
    return( $self->error( "Error while preparing new low priority query:\n$query" ) );
    if( !defined( wantarray() ) )
    {
        $sth->execute() ||
        return( $self->error( "Error while executing new low priority query:\n$query" ) );
    }
    return( $sth );
}

sub promise
{
    my $self = shift( @_ );
    $self->_load_class( 'Promise::Me' ) || return( $self->pass_error );
    return( Promise::Me->new(sub
    {
        return( $self->execute( @_ ) );
    }) );
}

sub query { return( shift->_set_get_scalar( 'query', @_ ) ); }

sub query_object { return( shift->_set_get_object_without_init( 'query_object', 'DB::Object::Query', @_ ) ); }

sub query_time { return( shift->_set_get_datetime( 'query_time', @_ ) ); }

sub rollback
{
    my $self = shift( @_ );
    if( $self->{sth} && $self->param( 'autocommit' ) )
    {
        my $sth = $self->prepare( "ROLLBACK" ) || return( $self->error( "An error occurred while preparing query to rollback: ", $self->error ) );
        $sth->execute() || return( $self->error( "Error occurred while executing query to rollback: ", $sth->error ) );
        $sth->finish();
    }
    return( $self );
}

sub rows(@)
{
    my $self = shift( @_ );
    if( !$self->executed() )
    {
        $self->execute() || return( $self->pass_error );
    }
    # $self->_cleanup();
    # $rv = $sth->rows;
    if( !ref( $self ) )
    {
        return( $DBI::rows );
    }
    else
    {
        return( $self->{sth}->rows() );
    }
}

# NOTE: statement -> Statement
# <https://metacpan.org/pod/DBI#Statement>
sub statement { return( shift->_get_statement_attribute( 'Statement' ) ); }

# A DBI::sth object. This should rather be a _set_get_object helper method, but I am not 100% sure if this is really a DBI::sth
sub sth { return( shift->_set_get_scalar( 'sth', @_ ) ); }

sub table { return( shift->{table} ); }

sub table_object { return( shift->_set_get_object_without_init( 'table_object', 'DB::Object::Tables', @_ ) ); }

sub undo
{
    goto( &rollback );
}

sub wait { return( shift->error( "Method wait() is not implemented by this driver." ) ); }

# Used to get the cached field names by _convert_datetime2object
sub _cache_field_names
{
    my $self = shift( @_ );
    my $names;
    if( !( $names = $self->{_cache_field_names} ) )
    {
        $names = $self->{_cache_field_names} = $self->field_names;
    }
    return( $names );
}

# Used to get the cached field names by _convert_datetime2object
sub _cache_field_types
{
    my $self = shift( @_ );
    my $types;
    if( !( $types = $self->{_cache_field_types} ) )
    {
        $types = $self->{_cache_field_types} = $self->field_types;
    }
    return( $types );
}

# sub _convert_datetime2object { return( shift->database_object->_convert_datetime2object( @_ ) ); }
# sub _convert_datetime2object
# {
#     my $self = shift( @_ );
#     my $opts = $self->_get_args_as_hash( @_ );
#     return( $opts->{data} );
# }
sub _convert_datetime2object
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    my $sth = $opts->{statement} || return( $self->error( "No statement handler was provided to convert data from json to perl." ) );
    # my $data = $opts->{data} || return( $self->error( "No data was provided to convert from json to perl." ) );
    return( $opts->{data} ) if( !CORE::length( $opts->{data} ) );
    my $data  = $opts->{data};
    # my $names = $sth->FETCH('NAME');
    # my $types = $sth->FETCH('pg_type');
    # Get the cached field names and types that we stored after executing the query, but before we finished reading the statement
    my $names = $self->_cache_field_names;
    my $types = $self->_cache_field_types;
    my $mode = ref( $data );

    for( my $i = 0; $i < scalar( @$names ); $i++ )
    {
        if( $types->[$i] eq DBI::SQL_DATE || 
            $types->[$i] eq DBI::SQL_TIMESTAMP || 
            $types->[$i] eq 'date' || 
            $types->[$i] eq 'timestamp' )
        {
            if( $mode eq 'ARRAY' )
            {
                for( my $j = 0; $j < scalar( @$data ); $j++ )
                {
                    next if( !$data->[ $j ]->{ $names->[ $i ] } );
                    my $dt = $self->_convert_string2datetime( $data->[ $j ]->{ $names->[ $i ] } );
                    if( !defined( $dt ) )
                    {
                        warn( $self->error );
                    }
                    $data->[ $j ]->{ $names->[ $i ] } = $dt;
                }
            }
            elsif( $mode eq 'HASH' )
            {
                next if( !$data->{ $names->[ $i ] } );
                my $dt = $self->_convert_string2datetime( $data->{ $names->[ $i ] } );
                if( !defined( $dt ) )
                {
                    warn( $self->error );
                }
                $data->{ $names->[ $i ] } = $dt;
            }
        }
    }
    return( $data );
}

# sub _convert_json2hash { return( shift->database_object->_convert_json2hash( @_ ) ); }
# Does nothing by default
# Must be superseded by the subclasses because we use the data types like PG_JSON, PG_JSONB
# and we don't have them at this top level
sub _convert_json2hash 
{
    my $self = shift( @_ );
    my $opts = $self->_get_args_as_hash( @_ );
    return( $opts->{data} );
}

sub _convert_string2datetime
{
    my $self = shift( @_ );
    my $str = shift( @_ ) || return;
    my $dt = $self->_parse_timestamp( $str );
    if( !defined( $dt ) )
    {
        return( $self->pass_error );
    }
    # An empty string means it did not fail, but probably did not recognise the format
    elsif( !$dt )
    {
        return( $str );
    }
    return( $dt );
}

sub _get_statement_attribute
{
    my $self = shift( @_ );
    my $attr = shift( @_ );
    if( !length( $attr // '' ) )
    {
        return( $self->error( "No statement attribute was provided to retrieve its value." ) );
    }
    my $sth = $self->{sth} || die( "Unable to get the underlying statement handler!" );
    my $val;
    # try-catch
    local $@;
    eval
    {
        # Ensure we stringify
        $val = $sth->{ "$attr" };
    };
    if( $@ )
    {
        return( $self->error( "Error retrieving value for '${attr}': $@" ) );
    }
    return( $val );
}

# NOTE: DESTROY
DESTROY
{
    # Do nothing but existing so it is handled by this package
    # print( STDERR "DESTROY'ing statement $self ($self->{ 'query' })\n" );
};

1;
# NOTE: POD
__END__

=encoding utf-8

=head1 NAME

DB::Object::Statement - Statement Object

=head1 SYNOPSIS

    say $sth->as_string;
    $sth->bind_param( 2, $binded_value );
    $sth->bind_param( 2, $binded_value, $binded_type );
    $sth->commit;
    my $dbh = $sth->database_object;
    $sth->distinct;
    say $sth->dump;
    say $sth->execute;
    $sth->execute( $val1, $val2 ) || die( $sth->error );
    # explicitly specify types
    # Here in this mixed example, $val1 and $val3 have known types
    $tbl->where( $dbh->AND(
        $tbl->fo->name == '?',
        $tbl->fo->city == '?',
        '?' == $dbh->ANY( $tbl->fo->alias )
    ) );
    my $sth = $tbl->select || die( $tbl->error );
    $sth->execute( $val1, $val2, { $val3 => 'varchar' } ) || die( $sth->error );
    my $ref = $sth->fetchall_arrayref;
    my $val = $sth->fetchcol;
    my %hash = $sth->fetchhash;
    my @values = $sth->fetchrow;
    my $ref = $sth->fetchrow_hashref;
    my $obj = $sth->fetchrow_object;
    $sth->finish;
    $sth->ignore;
    $sth->join( $join_condition );
    my $qo = $sth->query_object;
    $sth->rollback;
    my $rows = $sth->rows;
    my $dbi_sth = $sth->sth;
    my $tbl = $sth->table_object;

=head1 VERSION

v0.7.0

=head1 DESCRIPTION

This is the statement object package from which other driver specific packages inherit from.

=head1 METHODS

=head2 as_string

Returns the current statement object as a string.

=head2 bind_param

Provided with a list of arguments and they will be passed to L<DBI/bind_param>

If an error occurred, an error is returned, otherwise the return value of calling C<bind_param> is returned.

=head2 commit

If the statement parameter I<autocommit> is true, a C<COMMIT> statement will be prepared and executed.

The current object is returned.

=head2 database_object

Sets or gets the current database object.

=head2 distinct

Assuming a I<query> object property has already been set previously, this will add the C<DISTINCT> keyword to it if not already set.

If L</distinct> is called in void context, the query is executed immediately.

The query statement is returned.

=head2 dump

Provided with a file and this will print on STDOUT the columns used, separated by a tab and then will process each rows fetched with L<DBI::fetchrow> and will join the column valus with a tab before printing it out to STDOUT.

It returns the current object for chaining.

=head2 exec

This is an alias for L</execute>

=head2 execute

    $sth->execute || die( $sth->error );
    $sth->execute( $val1, $val2 ) || die( $sth->error );
    # explicitly specify types
    # Here in this mixed example, $val1 and $val3 have known types
    $tbl->where( $dbh->AND(
        $tbl->fo->name == '?',
        $tbl->fo->city == '?',
        '?' == $dbh->ANY( $tbl->fo->alias )
    ) );
    my $sth = $tbl->select || die( $tbl->error );
    $sth->execute( $val1, $val2, { $val3 => 'varchar' } ) || die( $sth->error );

If binded values have been prepared, they are applied here before executing the query.

Sometime, you need to clearly specify what the datatype are for the value provided with C<execute>, because L<DB::Object::Query> could not figure it out.

Thus, if you do:

    $tbl->where(
        $tbl->fo->name == '?'
    );

L<DB::Object::Query> knows the datatype, because you are using a field object (C<fo>), but if you were doing:

    $tbl->where(
        '?' == $dbh->ANY( $tbl->fo->alias )
    );

In this scenario, L<DB::Object::Query> does not know what the bind value would be, although we could venture a guess by looking at the right-hand side, but this is a bit hazardous. So you are left with a placeholder, but no datatype. So you would execute like:

    $sth->execute({ $val => 'varchar' });

If the total number of binded values does not match the total number of binded type, this will trigger a warning.

L<DBI/execute> will be called with the binded values and if this method was called in an object context, the current object is returned, otherwise the returned value from L<DBI/execute> is returned.

With the version C<0.5.0> of this module, this method is more able to find out the data type of the table field. To achieve this, it uses the L<field object|DB::Object::Fields::Field> set in each L<element object|DB::Object::Query::Element>. Those element objects are instantiated upon C<insert> or C<update> query.

Also, if you provide a value during an C<insert> or C<update> for a field that the database expects an array, this method will automatically convert it into an array.

Likewise, if the table field is of type C<json> or C<jsonb> and an hash reference value is provided, this method will encode the hash reference into a C<JSON> string.

=head2 executed

Returns true if this statement has already been executed, and false otherwise.

=head2 fetchall_arrayref

Similar to L<DBI/fetchall_arrayref>, this will execute the query and return an array reference of data.

=head2 fetchcol

Provided with an integer that represents a column number, starting from 0, and this will get each row of results and add the value for the column at the given offset.

it returns a list of those column value fetched.

=head2 fetchhash

This will retrieve an hash reference for the given row and return it as a regular hash.

=head2 fetchrow

This will retrieve the data from database using L</fetchrow_arrayref> and return the list of data as array in list context, or the first entry of the array in scalar context.

=head2 fetchrow_hashref

This will retrieve the data from the database as an hash reference.

It will convert any data from json to hash reference if L<DB::Object/auto_decode_json> is set to true.

it will also convert any datetime data into a L<DateTime> object if L<DB::Object/auto_convert_datetime_to_object> is true.

It returns the hash reference retrieved.

=head2 fetchrow_object

This will create dynamically a package named C<DB::Object::Postgres::Result::SomeTable> for example and load the hash reference retrieved from the database into this dynamically created packackage.

It returns the object thus created.

=head2 field_names

    my $array_ref = $sth->field_names;

Returns an array reference of field names for the query.
This must be called after executing the query, and before finishing retrieving all data from the database.

See also L<https://metacpan.org/pod/DBI#NAME1>

=head2 field_names_lc

    my $array_ref = $sth->field_names_lc;

Same as L<field_names|/field_names>, except this makes all the column names in lower case.

See also L<https://metacpan.org/pod/DBI#NAME_lc>

=head2 field_names_uc

    my $array_ref = $sth->field_names_uc;

Same as L<field_names|/field_names>, except this makes all the column names in lower case.

See also L<https://metacpan.org/pod/DBI#NAME_uc>

=head2 field_nullables

    my $array_ref = $sth->field_nullables;

Returns an array reference of value for each field indicating if they can be null or not.

Possible values are: C<0> (or an empty string) = no, C<1> = yes, C<2> = unknown.

See also L<https://metacpan.org/pod/DBI#NULLABLE>

=head2 field_precisions

    my $array_ref = $sth->field_precisions;

Returns an array reference of integer value foe each field indicating their precision.

As per DBI documentation: "For numeric columns, the value is the maximum number of digits (without considering a sign character or decimal point). Note that the "display size" for floating point types (REAL, FLOAT, DOUBLE) can be up to 7 characters greater than the precision (for the sign + decimal point + the letter E + a sign + 2 or 3 digits).

For any character type column the value is the OCTET_LENGTH, in other words the number of bytes, not characters."

See also L<https://metacpan.org/pod/DBI#PRECISION>

=head2 field_scales

    my $array_ref = $sth->field_scales;

Returns an array reference of integer value foe each field. "C<NULL> (C<undef>) values indicate columns where scale is not applicable."

See also L<https://metacpan.org/pod/DBI#SCALE>

=head2 field_types

    my $array_ref = $sth->field_types;

Returns an array reference of integer value foe each field. "The value indicates the data type of the corresponding column."

You can important those constant with C<use DBI ':sql_types'>

See also L<https://metacpan.org/pod/DBI#TYPE>

=head2 finish

Calls L<DBI/finish> and return the returned value, or an error if an error occurred.

=head2 ignore

This will change the query prepared and add the keyword C<IGNORE>.

If called in void context, this will execute the resulting statement handler immediately.

=head2 join

Provided with a target and an hash reference, or list or array reference of condition for the join and this will prepare the join statement.

If the original query is not of type C<select>, this will trigger an error.

The target mentioned above can be either a L<DB::Object::Statement> object, or a table object (L<DB::Object::Tables>), or even just a string representing the name of a table.

    $tbl->select->join( $sth );
    $tbl->select->join( $other_tbl );
    $tbl->select->join( 'table_name' );

The condition mentioned above can be a L<DB::Object::Operator> (C<AND>, C<OR> or C<NOT>), in which case the actual condition will be taken from that operator embedded value.

The condition can also be a L<DB::Object::Fields::Overloaded> object, which implies a table field with some operator and some value.

    $tbl->select->join( $other_tbl, $other_tbl->fo->id == 2 );

Here C<$other_tbl->fo->id == 2> will become a L<DB::Object::Fields::Overloaded> object.

The condition can also be an array reference or array object of conditions and implicitly the array entry will be joined with C<AND>:

    $tbl->select->join( $other_tbl, ["user = 'joe'", $other_tbl->fo->id == 2] );

The condition can also be an hash reference with each key being a table name to join and each value an hash reference of condition for that particular join with each key being a column name and each value the value of the join for that column.

    my $tbl = $dbh->first_table;
    $tbl->select->join({
        other_table =>
        {
            id => 'first_table.id',
            user => 'first_table.user',
        },
        yet_another_table =>
        {
            id => 'other_table.id',
        },
    });

would become something like:

    SELECT *
    FROM first_table
    LEFT JOIN other_table ON
        first_table.id = id AND
        first_table.user = user
    LEFT JOIN yet_another_table ON
        other_table.id = id

Each condition will be formatted assuming an C<AND> expression, so this is less flexible than using operator objects and table field objects.

If no condition is provided, this is taken to be a straight join.

    $tbl->where( $tbl->fo->id == 2 );
    $other_tbl->where( $other_tbl->fo->user 'john' );
    $tbl->select->join( $other_tbl );

Would become something like:

    SELECT *
    FROM first_table, other_table
    WHERE id = 2 AND user = 'john'

If called in void context, this will execute the resulting statement handler immediately.

It returns the resulting statement handler.

It returns the statement handler.

=head2 number_of_fields

    $sth->exec || die( $sth->error );
    say "There are ", $sth->number_of_fields, " columns in this tuple.";

Returns an integer representing the number of fields in the SQL query executed.

See also L<https://metacpan.org/pod/DBI#NUM_OF_FIELDS>

=head2 number_of_params

    $sth->exec || die( $sth->error );
    say "There are ", $sth->number_of_params, " placeholders for this query.";

Returns the number of parameters (placeholders) in the prepared statement.

See also L<https://metacpan.org/pod/DBI#NUM_OF_PARAMS>

=head2 object

Returns the statement object explicitly.

    my $sth = $tbl->select->object;

which is really equivalent to:

    my $sth = $tbl->select;

=head2 priority

Provided with a priority integer that can be 0 or 1 with 0 being C<LOW_PRIORITY> and 1 being C<HIGH_PRIORITY> and this will adjust the query formatted to add the priority. This works only on Mysql drive though.

If used on queries other than C<DELETE>, C<INSERT>, C<REPLACE>, C<SELECT>, C<UPDATE> an error will be returned.

If called in void context, this will execute the newly create statement handler immediately.

It returns the newly create statement handler.

=head2 promise

This the same as calling L</execute>, except that the query will be executed asynchronously and a L<Promise::Me> object will be returned, so you can do asynchronous queries like this:

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
    my( $obj ) = await( $p );

=head2 query

Sets or gets the previously formatted query as a regular string.

=head2 query_object

Sets or gets the query object used in this query.

=head2 query_time

Sets or gets the query time as a L<DateTime> object.

=head2 rollback

If there is a statement handler and the database parameter C<autocommit> is set to true, this will prepare a C<ROLLBACK> query and execute it.

=head2 rows

Returns the number of rows affected by the last query.

=head2 statement

Returns the SQL statement that was sent to the server to be prepared.

This is different from L<as_string|/as_string> in that L<as_string|/as_string> returns the SQL query built by L<DB::Object>. Obviously, both should be the same, but they come from different sources.

=head2 sth

Sets or gets the L<DBI> statement handler.

=head2 table

Sets or gets the table object (L<DB::Object::Tables>) for this query.

=head2 table_object

Sets or get the table object (L<DB::Object::Tables>)

=head2 undo

This is an alias for L</rollback>

=head2 wait

The implementation is driver dependent, and in this case, this is implemented only in L<DB::Object::Mysql>

=head2 _convert_datetime2object

A convenient short to enable or disable L<DB::Object/_convert_datetime2object>

=head2 _convert_json2hash

A convenient short to enable or disable L<DB::Object/_convert_json2hash>

=head1 SEE ALSO

L<DB::Object::Query>, L<DB::Object::Mysql::Query>, L<DB::Object::Postgres::Query>, L<DB::Object::SQLite::Query>

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2021 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
