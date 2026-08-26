use 5.008;

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok('DBD::Mock');
    use_ok('DBI');
}

{
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');
    
    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ?',
            bound_params => [ 100 ],
            results      => [[ 'foo' ], [ 10 ]]
        },
        {
            statement    => 'SELECT bar FROM foo WHERE baz = ?',
            bound_params => [ 125 ],
            results      => [[ 'bar' ], [ 15 ]]
        },
    ));
    isa_ok($session, 'DBD::Mock::Session');
    
    $dbh->{mock_session} = $session;
    
    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ?');
        $sth->execute(100);
        my ($result) = $sth->fetchrow_array();
        is($result, 10, '... got the right value');        
    };
    ok(!$@, '... everything worked as planned');
    
    eval {
        my $sth = $dbh->prepare('SELECT bar FROM foo WHERE baz = ?');
        $sth->execute(125);
        my ($result) = $sth->fetchrow_array();
        is($result, 15, '... got the right value');
    };
    ok(!$@, '... everything worked as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

{
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');
    
    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ?',
            bound_params => [ 100 ],
            results      => [[ 'foo' ], [ 10 ]]
        },
        {
            statement => 'SELECT bar FROM foo WHERE baz = 125',
            results   => [[ 'bar' ], [ 15 ]]
        },        
        {
            statement    => 'DELETE FROM bar WHERE baz = ?',
            results      => [[], [], []],
            bound_params => [ 100 ]            
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');
    
    $dbh->{mock_session} = $session;
    
    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ?');
        $sth->execute(100);
        my ($result) = $sth->fetchrow_array();
        is($result, 10, '... got the right value');        
    };
    ok(!$@, '... first state worked as planned');
    
    eval {
        my $sth = $dbh->prepare('SELECT bar FROM foo WHERE baz = 125');
        $sth->execute();
        my ($result) = $sth->fetchrow_array();
        is($result, 15, '... got the right value');
    };
    ok(!$@, '... second state worked as planned');
        
    eval {
        my $sth = $dbh->prepare('DELETE FROM bar WHERE baz = ?');
        $sth->execute(100);
        is($sth->rows(), 2, '... got the right number of affected rows');
    };
    ok(!$@, '... third state worked as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# check some errors

{
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');
    
    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ?',
            bound_params => [ 100 ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');
    
    $dbh->{mock_session} = $session;
    
    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ?');
        $sth->execute(100, 200);
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@, 
        qr/Session Error\: Not the same number of bound params in current state in DBD\:\:Mock\:\:Session/, 
        '... everything failed as planned');    

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

{
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');
    
    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ?',
            bound_params => [ 100 ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');
    
    $dbh->{mock_session} = $session;
    
    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ?');
        $sth->execute(200);
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@, 
        qr/Session Error\: Bound param 0 do not match in current state in DBD\:\:Mock\:\:Session/, 
        '... everything failed as planned');    

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

{ 
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1,  PrintError => 0 }); 
    isa_ok($dbh, 'DBI::db'); 
 
    my $session = DBD::Mock::Session->new(( 
        { 
            statement    => 'SELECT foo FROM bar WHERE baz = ?', 
            bound_params => [ 100 ], 
            results      => [[ 'foo' ], [ 10 ]] 
        }, 
        { 
            statement    => 'SELECT foo FROM bar WHERE baz = ?', 
            bound_params => [ 125 ], 
            results      => [[ 'foo' ], [ 15 ]] 
        }, 
    )); 
    isa_ok($session, 'DBD::Mock::Session'); 
 
    $dbh->{mock_session} = $session; 
 
    eval { 
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ?'); 
        $sth->execute(100); 
        my ($result) = $sth->fetchrow_array(); 
        is($result, 10, '... first execute got the right  value'); 
        $sth->execute(125); 
        ($result) = $sth->fetchrow_array(); 
        is($result, 15, '... second execute got the right value'); 
    }; 
    ok(!$@, '... everything worked as planned'); 

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}


{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1,  PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 100, 101 ] ],
            results      => [[ 'foo' ], [ 10 ]]
        },
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 125, undef ] ],
            results      => [[ 'foo' ], [ 15 ]]
        },
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 150, qr/^abc/ ] ],
            results      => [[ 'foo' ], [ 20 ]]
        },
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute([ 100, 101 ]);
        my ($result) = $sth->fetchrow_array();
        is($result, 10, '... first execute got the right  value');
        $sth->execute([125, undef]);
        ($result) = $sth->fetchrow_array();
        is($result, 15, '... second execute got the right value');
        $sth->execute([150, 'abcdef']);
        ($result) = $sth->fetchrow_array();
        is($result, 20, '... third execute got the right value');
    };
    ok(!$@, '... everything worked as planned')
        or diag $@;

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array, find scalar
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute(200);
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: 200\s+expected: ARRAY/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array with undef, find array with scalar
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ undef ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( [200] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: 200\s+expected: \<undef\>/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array with scalar, find array with undef
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 200 ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( [undef] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: \<undef\>\s+expected: 200/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array with scalar, find array with different scalar
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 200 ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( [201] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: 201\s+expected: 200/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array with scalar matching regex, find array with mismatching scalar
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ qr/abc/ ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( ['def'] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: def\s+expected: \(\?[^:]*:abc\)/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Expect array with 2 elements, find array with 1 element
{
    my $dbh = DBI->connect('dbi:Mock:PostgreSQL', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 1, 2 ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( ['def'] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: array of length 1\s+expected: array of length 2/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

# Non-PostgreSQL driver doesn't support bound arrays
{
    my $dbh = DBI->connect('dbi:Mock:', '', '', { RaiseError => 1, PrintError => 0 });
    isa_ok($dbh, 'DBI::db');

    my $session = DBD::Mock::Session->new((
        {
            statement    => 'SELECT foo FROM bar WHERE baz = ANY(?)',
            bound_params => [ [ 1 ] ],
            results      => [[ 'foo' ], [ 10 ]]
        }
    ));
    isa_ok($session, 'DBD::Mock::Session');

    $dbh->{mock_session} = $session;

    eval {
        my $sth = $dbh->prepare('SELECT foo FROM bar WHERE baz = ANY(?)');
        $sth->execute( [1] );
        my ($result) = $sth->fetchrow_array();
    };
    ok($@, '... everything failed as planned');
    like($@,
        qr/got: ARRAY\(0x[0-9a-f]+\)\s+expected: ARRAY\(0x[0-9a-f]+\)/m,
        '... everything failed as planned');

    # Shuts up warning when object is destroyed
    undef $dbh->{mock_session};
}

done_testing();
