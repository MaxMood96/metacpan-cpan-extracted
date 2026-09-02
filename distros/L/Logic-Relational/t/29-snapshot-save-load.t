#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use File::Temp qw(tempfile);
use Logic::Relational::Program;
use Logic::Relational::Syntax;

# 1. Test OO API save_snapshot & load_snapshot with JSON string
my $p1 = Logic::Relational::Program->new;
$p1->fact( located_at => 'alice', 'home' );
$p1->fact( carrying   => 'alice', [ 'keys', 'wallet' ] );
$p1->fact( profile    => 'alice', { role => 'admin', level => 5 } );

my $json_str;
$p1->save_snapshot( \$json_str );
ok( $json_str, 'Saved snapshot to scalar ref' );
like( $json_str, qr/"engine"/x,     'Contains engine header' );
like( $json_str, qr/"located_at"/x, 'Contains located_at fact' );

my $p2           = Logic::Relational::Program->new;
my $loaded_count = $p2->load_snapshot( \$json_str );
is( $loaded_count, 3, 'Loaded 3 facts into new program' );

# Verify data structures reconstituted accurately
my $who  = Logic::Relational::DSL::variable('who');
my $data = Logic::Relational::DSL::variable('data');

my $q_prof =
  $p2->query( Logic::Relational::DSL::call( profile => $who, $data ) );
my $sol_prof = $q_prof->next;
is( $sol_prof->value($who), 'alice', 'Profile user is alice' );
is(
    $sol_prof->value($data),
    { role => 'admin', level => 5 },
    'Profile hash reconstituted correctly'
);

my $q_carr =
  $p2->query( Logic::Relational::DSL::call( carrying => $who, $data ) );
my $sol_carr = $q_carr->next;
is(
    $sol_carr->value($data),
    [ 'keys', 'wallet' ],
    'Carrying array reconstituted correctly'
);

# 2. Test File I/O save_snapshot & load_snapshot
my ( $fh, $filename ) = tempfile( UNLINK => 1 );
close $fh;

$p1->save_snapshot($filename);
ok( -s $filename, 'Snapshot file written to disk' );

my $p3 = Logic::Relational::Program->new;
$p3->load_snapshot($filename);
is( $p3->clauses_for( 'located_at', 2 ), 1,
    'Loaded located_at fact from file' );

# 3. Test merge vs replace modes
$p3->fact( located_at => 'bob', 'office' );
is( $p3->clauses_for( 'located_at', 2 ),
    2, '2 located_at facts exist before reload' );

# Replace mode (default)
$p3->load_snapshot( \$json_str, mode => 'replace' );
is( $p3->clauses_for( 'located_at', 2 ),
    1, 'Replace mode cleared existing facts' );

# Merge mode
$p3->fact( located_at => 'bob', 'office' );
$p3->load_snapshot( \$json_str, mode => 'merge' );
is( $p3->clauses_for( 'located_at', 2 ),
    3, 'Merge mode blended snapshot facts' );

# 4. Test Expiring Facts with TTL in snapshots
my $p_ttl = Logic::Relational::Program->new;
$p_ttl->assert_fact(
    term       => [ session => 'tok_active', 'user1' ],
    expires_in => 10,
);
$p_ttl->assert_fact(
    term       => [ session => 'tok_expired', 'user2' ],
    expires_at => time - 5,
);

my $ttl_json;
$p_ttl->save_snapshot( \$ttl_json );

my $p_ttl_restore = Logic::Relational::Program->new;
my $ttl_loaded    = $p_ttl_restore->load_snapshot( \$ttl_json );
is( $ttl_loaded, 1, 'Only unexpired session was saved and loaded' );

my $tok    = Logic::Relational::DSL::variable('tok');
my $user   = Logic::Relational::DSL::variable('user');
my $q_sess = $p_ttl_restore->query(
    Logic::Relational::DSL::call( session => $tok, $user ) );
my $sol_sess = $q_sess->next;
is( $sol_sess->value($tok),
    'tok_active', 'Unexpired session token loaded correctly' );

# 4b. Test Relative TTL Mode (simulated game time / paused time)
my $p_match = Logic::Relational::Program->new;
$p_match->assert_fact(
    term       => [ match_lit => 'bedroom' ],
    expires_in => 10,
);

my $match_json;
$p_match->save_snapshot( \$match_json );

sleep 2;

my $p_match_restore = Logic::Relational::Program->new;
$p_match_restore->load_snapshot( \$match_json, ttl_mode => 'relative' );

my $loc_var = Logic::Relational::DSL::variable('loc');
my $q_match = $p_match_restore->query(
    Logic::Relational::DSL::call( match_lit => $loc_var ) );
my $sol_match = $q_match->next;
ok( $sol_match, 'Match is still lit after load in relative TTL mode' );
is( $sol_match->value($loc_var), 'bedroom', 'Match location is bedroom' );

# 5. Test logic syntax integration with save_snapshot & load_snapshot helpers
logic SaveLoadSyntaxTest {
    facts {
        player('hero', 100);
        inventory('sword');
    }

    rule get_player($n, $hp) {
        player($n, $hp);
    }
}

my $syn_json;
$SaveLoadSyntaxTest::PROGRAM->save_snapshot( \$syn_json );

# Mutate state
$SaveLoadSyntaxTest::PROGRAM->retract( player => 'hero', 100 );
$SaveLoadSyntaxTest::PROGRAM->fact( player => 'hero', 50 );

query SaveLoadSyntaxTest::get_player( fresh my $p_name, fresh my $p_hp )
  ->my $q_mut;
is( $q_mut->next->value($p_hp), 50, 'Player HP mutated to 50' );

# Restore saved state
$SaveLoadSyntaxTest::PROGRAM->load_snapshot( \$syn_json, mode => 'replace' );

query SaveLoadSyntaxTest::get_player( fresh my $r_name, fresh my $r_hp )
  ->my $q_rest;
is( $q_rest->next->value($r_hp),
    100, 'Restored Player HP back to 100 via load_snapshot' );

done_testing;
