use Test2::V0;
use Clone 'clone';
use DBIx::Query;

my $data = load_sponge_data();
my $dq   = test_connection();

test_sql( $dq, $data );
test_get( $dq, $data );
test_sql_uncached( $dq, $data );
test_get_uncached( $dq, $data );
test_add( $dq, $data );
test_rm( $dq, $data );
test_update( $dq, $data );

isa_ok( $dq->abstract, 'SQL::Abstract::Complete' );

test_get_run( $dq, $data );
test_db_helper_methods( $dq, $data );
test_statement_handle_methods( $dq, $data );
test_up_methods( $dq, $data );

done_testing;

sub load_sponge_data {
    my $sponge_data;
    while ( <DATA> ) {
        chomp;
        my $data = [ split(/\|/) ];

        unless ( exists $sponge_data->{'NAME'} ) {
            $sponge_data->{'NAME'} = $data;
        }
        else {
            push( @{ $sponge_data->{'rows'} }, $data );
        }
    }

    return $sponge_data;
}

sub test_connection {
    my $dq = DBIx::Query->connect_uncached( 'dbi:Sponge:', '', '' );
    ok( $dq, 'DBIx::Query->connect_uncached()' );
    isa_ok( $dq, 'DBIx::Query::db' );

    is( $dq->connection('dsn'), 'dbi:Sponge:', q{connection('dsn') should return dsn} );
    is(
        scalar $dq->connection,
        {
            'dsn'  => 'dbi:Sponge:',
            'user' => '',
            'pass' => '',
            'attr' => {
                dbi_connect_method => 'connect',
                RaiseError         => 1,
                PrintError         => 0,
            },
        },
        'scalar connection() should return full hashref',
    );
    is(
        [ $dq->connection ],
        [ 'dbi:Sponge:', '', '', {
            dbi_connect_method => 'connect',
            RaiseError         => 1,
            PrintError         => 0,
        } ],
        'connection() in list context should return full list',
    );

    $dq = DBIx::Query->connect( 'dbi:Sponge:', '', '', { 'RaiseError' => 1 } );
    ok( $dq, 'DBIx::Query->connect()' );
    isa_ok( $dq, 'DBIx::Query::db' );

    is(
        scalar $dq->connection,
        {
            'dsn'  => 'dbi:Sponge:',
            'user' => '',
            'pass' => '',
            'attr' => {
                dbi_connect_method => 'connect_cached',
                RaiseError         => 1,
                PrintError         => 0,
            },
        },
        'scalar connection() should return full hashref',
    );
    is(
        [ $dq->connection ],
        [ 'dbi:Sponge:', '', '', {
            dbi_connect_method => 'connect_cached',
            RaiseError         => 1,
            PrintError         => 0,
        } ],
        'connection() in list context should return full list',
    );

    is(
        scalar $dq->connection( qw( dsn user ) ),
        [ 'dbi:Sponge:', '' ],
        'connection( qw( dsn user ) ) in scalar context should return arrayref',
    );
    is(
        [ $dq->connection( qw( dsn user ) ) ],
        [ 'dbi:Sponge:', '' ],
        'connection( qw( dsn user ) ) in list context should return array',
    );

    return $dq;
}

sub test_sql {
    my ( $dq, $sponge_data ) = @_;
    my $sth = $dq->sql( 'SELECT * FROM data', clone($sponge_data) );

    is( ref($sth), 'DBIx::Query::st', 'ref( $dq->sql() )' );
    is( $sth->structure->{'table_names'}->[0], 'data', '$dq->sql()->structure()' );
}

sub test_get {
    my ( $dq, $sponge_data ) = @_;

    my $row_set = $dq->get(
        'data',
        [ qw( a b c ) ],
        { 'id' => 1 },
        undef,
        clone($sponge_data),
    );

    is( $row_set->sql, 'SELECT a, b, c FROM data WHERE ( id = ? )', '$row_set->sql()' );
}

sub test_sql_uncached {
    my ( $dq, $sponge_data ) = @_;
    my $query = $dq->sql_uncached( 'SELECT * FROM data', clone($sponge_data) );
    ok( $query, 'sql_cached() should return a query object' );
    isa_ok( $query, 'DBIx::Query::st' );
}

sub test_get_uncached {
    my ( $dq, $sponge_data ) = @_;
    my $row_set = $dq->get_uncached(
        'data',
        [ qw( a b c ) ],
        { 'id' => 1 },
        undef,
        clone($sponge_data),
    );

    is( $row_set->sql, 'SELECT a, b, c FROM data WHERE ( id = ? )', '$dq->get_cached()->sql()' );
}

sub test_add {
    my ( $dq, $sponge_data ) = @_;

    my $rv = $dq->add( 'data', {
        'open'  => 'Jun 17, 2011',
        'final' => 'Jun 19, 2011',
        'west'  => 'Hunt for Red October',
        'east'  => 'Jane Eyre'
    }, clone($sponge_data) );

    is( $rv, undef, 'add() does not break' );
}

sub test_rm {
    my ( $dq, $sponge_data ) = @_;

    my $rv = $dq->rm( 'data', {
        'west' => 'Hunt for Red October',
    }, clone($sponge_data) );

    isa_ok( $rv, 'DBIx::Query::db' );
}

sub test_update {
    my ( $dq, $sponge_data ) = @_;

    my $rv = $dq->update(
        'data',
        { 'west' => 'Hunt for Red October' },
        { 'west' => 'Hunt for Green November' },
        clone($sponge_data),
    );

    isa_ok( $rv, 'DBIx::Query::db' );
}

sub test_get_run {
    my ( $dq, $sponge_data ) = @_;

    my $sth = $dq->get_run(
        'data',
        ['*'],
        { 'id' => 1 },
        undef,
        clone($sponge_data),
    );

    isa_ok( $sth, 'DBIx::Query::st' );
    is(
        $sth->fetchrow_hashref,
        {
            'open'  => 'Jun 17, 2011',
            'final' => 'Jun 19, 2011',
            'west'  => 'Hunt for Red October',
            'east'  => 'Jane Eyre'
        },
        'get_run() returns results',
    );
}

sub test_db_helper_methods {
    my ( $dq, $sponge_data ) = @_;

    local $@;
    eval { $dq->fetch_value( 'data', ['west'], { 'id' => 1 }, undef, clone($sponge_data) ) };
    is( ($@) ? 1 : 0, 0, 'fetch_value() does not die' );

    eval { $dq->fetchall_arrayref( 'data', ['west'], { 'id' => 1 }, undef, clone($sponge_data) ) };
    is( ($@) ? 1 : 0, 0, 'fetchall_arrayref() does not die' );

    eval { $dq->fetchall_hashref( 'data', ['west'], { 'id' => 1 }, undef, clone($sponge_data) ) };
    is( ($@) ? 1 : 0, 0, 'fetchall_hashref() does not die' );

    eval { $dq->fetch_column_arrayref( 'data', ['west'], { 'id' => 1 }, undef, clone($sponge_data) ) };
    is( ($@) ? 1 : 0, 0, 'fetch_column_arrayref() does not die' );
}

sub test_statement_handle_methods {
    my ( $dq, $sponge_data ) = @_;

    my $rs = $dq->get(
        'movies',
        [ qw( west east ) ],
        { 'final' => 'Jun 19, 2011' },
        undef,
        clone($sponge_data),
    )->run;
    isa_ok( $rs, 'DBIx::Query::_Dq::RowSet' );

    is(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->sql,
        'SELECT west, east FROM movies WHERE ( final = ? )',
        '$dq->get(...)->sql() returns SQL',
    );

    is(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->structure,
        {
            'original_string' => 'SELECT west, east FROM movies WHERE ( final = ? )',
            'org_table_names' => ['movies'],
            'column_lookup' => { 'west' => 0, 'east' => 1 },
            'where_cols' => { 'final' => ['?'] },
            'column_aliases' => {},
            'where_clause' => {
                'arg2' => {
                    'value' => '?',
                    'type' => 'placeholder',
                    'fullorg' => '?'
                },
                'arg1' => {
                    'value' => 'final',
                    'type' => 'column',
                    'fullorg' => 'final'
                },
                'nots' => {},
                'neg' => 0,
                'op' => '='
            },
            'list_ids' => [],
            'table_names' => ['movies'],
            'command' => 'SELECT',
            'table_alias' => {},
            'ORG_NAME' => { 'west' => undef, 'east' => undef },
            'num_placeholders' => 1,
            'column_invert_lookup' => { '1' => 'east', '0' => 'west' },
            'dialect' => 'ANSI',
            'org_col_names' => [ 'west', 'east' ],
            'column_defs' => [
                {
                    'value' => 'west',
                    'type' => 'column',
                    'fullorg' => 'west'
                },
                {
                    'value' => 'east',
                    'type' => 'column',
                    'fullorg' => 'east'
                }
            ]
        },
        '$dq->get(...)->structure() returns parsed SQL structure',
    );

    is(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->table,
        'movies',
        '$dq->get(...)->table() returns primary table',
    );

    isa_ok(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->up,
        'DBIx::Query::db',
    );
}

sub test_up_methods {
    my ( $dq, $sponge_data ) = @_;

    isa_ok(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->run->up,
        'DBIx::Query::st',
    );

    isa_ok(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->run->next->up,
        'DBIx::Query::_Dq::RowSet',
    );

    isa_ok(
        $dq->get(
            'movies',
            [ qw( west east ) ],
            { 'final' => 'Jun 19, 2011' },
            undef,
            clone($sponge_data),
        )->run->next->cell('west')->up,
        'DBIx::Query::_Dq::Row',
    );
}

__DATA__
open|final|west|east
Jun 17, 2011|Jun 19, 2011|Hunt for Red October|Jane Eyre
Jun 24, 2011|Jun 26, 2011|Robots|Meek's Cutoff
Jul 1, 2011|Jul 3, 2011|Raising Arizona|There Be Dragons
Jul 8, 2011|Jul 10, 2011|Miller's Crossing|Forks Over Knives
Jul 15, 2011|Jul 17, 2011|Big Lebowski|Midnight in Paris
Jul 22, 2011|Jul 24, 2011|Super 8|Midnight in Paris
Jul 29, 2011|Jul 31, 2011|Raiders of the Lost Ark|Tree of Life
Aug 5, 2011|Aug 7, 2011|Indiana Jones and the Temple of Doom|A Better Life
Aug 12, 2011|Aug 14, 2011|Indiana Jones and the Last Crusade|First Grader
Aug 19, 2011|Aug 21, 2011|Neverending Story|Buck
Aug 26, 2011|Aug 28, 2011|Gladiator|The Trip
