#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

# The grants half of Punk::Plugin::Authorisation, against the real table it
# ships. t/25 proves the machinery with rules alone; this proves the DDL and
# the three helpers over it - a column renamed in one place and not the other
# fails here rather than in somebody's deploy. No App::Sqitch needed: the
# point is the SQL, not the tool that ships it.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
    plan skip_all => 'DBD::SQLite required'
        unless eval { require DBI; require DBD::SQLite; 1 };
}
use File::Spec ();
use Punk::Plugin::Authorisation ();
use Punk::Model::Grant ();

my $pm = $INC{'Punk/Plugin/Authorisation.pm'} or die 'not loaded from a file';
(my $dir = $pm) =~ s/\.pm\z//;
my $sql_file = File::Spec->catfile($dir, 'sqitch', 'sqlite', 'deploy', 'grants.sql');
ok(-f $sql_file, 'the sqlite deploy script ships') or do { done_testing(); exit };
my $sql = do { open my $fh, '<', $sql_file or die $!; local $/; <$fh> };

my $db = File::Spec->catfile(File::Spec->tmpdir, "punk-authz-$$.db");
unlink $db;
END { unlink $db if $db }
my $dsn = "dbi:SQLite:dbname=$db";
{
    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1, PrintError => 0 });
    my $body = $sql;
    $body =~ s/^\s*(?:BEGIN|COMMIT)\s*;\s*$//gmi;
    for my $stmt (grep { /\S/ } split /;\s*\n/, $body) {
        next if $stmt =~ /\A\s*--/ && $stmt !~ /\bCREATE\b/i;
        $dbh->do($stmt);
    }
    $dbh->do('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT, role TEXT, verified INTEGER)');
    $dbh->do("INSERT INTO users (id, email, role, verified) VALUES (1,'a\@x','admin',1), (2,'b\@x','member',1)");
    my @cols = map { $_->[1] }
        @{ $dbh->selectall_arrayref('PRAGMA table_info(authz_grants)') };
    is_deeply([ sort @cols ],
        [ sort qw(id subject_id action object_id granted_by created) ],
        'the table has exactly the columns the plugin reads');
    $dbh->disconnect;
}

{
    package GPolicy;
    use Punk::Plugin::Authorisation;
    rule 'doc.edit' => sub {
        my ($c, $doc) = @_;
        return 1 if $doc->{owner_id} == ($c->auth_id // 0);   # ownership first
        return 1 if $c->granted('doc.edit', $doc->{id});
        return $c->not_yours;
    };
    1;
}
{
    package App::Grants;
    use Punk;
    session secret => 'x' x 32;
    database dsn => $dsn;
    auth model => 'TFake::Model::User', rank => [qw(member admin owner)],
         roles => sub { $_[1]->{role} };
    model 'TFake::Model::User';
    model 'Punk::Model::Grant';
    # GPolicy never calls rank_at_least, which is what rank => [] says - and
    # says on any Punk, with or without $app->auth_config to read the
    # `auth` keyword's ladder through.
    plugin 'Authorisation' => { policy => 'GPolicy', grants => 'Punk::Model::Grant',
                                rank => [] };

    our $AS = 0;
    hook before_dispatch => sub { $_[0]->session->{user_id} = $AS if $AS; return };

    get '/edit/:id' => sub {
        my ($c) = @_;
        my $doc = { id => $c->param('id'), owner_id => 1 };   # every doc is alice's
        $c->may('doc.edit', $doc) or return $c->deny;
        return $c->text('edited');
    };
    get '/grant/:id'  => sub { my ($c) = @_; $c->grant('doc.edit', $c->param('id'), to => 2); $c->text('granted') };
    get '/revoke/:id' => sub { my ($c) = @_; $c->text($c->revoke_grant('doc.edit', $c->param('id'), from => 2)) };
}
use TFake ();

my $app = App::Grants->to_app;
sub hit {
    my ($path, %o) = @_;
    local $App::Grants::AS = $o{as} // 0;
    my $r = $app->({ REQUEST_METHOD => 'GET', PATH_INFO => $path, QUERY_STRING => '',
                     SERVER_NAME => 'x', SERVER_PORT => 80, HTTP_HOST => 'x',
                     'psgi.url_scheme' => 'http' });
    my $body = join('', map { defined $_ ? $_ : '' } @{ $r->[2] });
    diag("$path as " . ($o{as} // 0) . " -> $r->[0]: $body") if $ENV{AUTHZ_DEBUG};
    return { status => $r->[0], body => $body };
}
sub rows {
    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1 });
    my $r = $dbh->selectall_arrayref('SELECT * FROM authz_grants', { Slice => {} });
    $dbh->disconnect;
    return $r;
}

# ---- ownership first, and it costs no query --------------------------------------
is(hit('/edit/7', as => 1)->{status}, 200, 'the owner may edit, by the rule alone');
is(scalar @{ rows() }, 0, 'and no grant was consulted or created');

# ---- without a grant: 404, not 403 -------------------------------------------------
{
    my $r = hit('/edit/7', as => 2);
    is($r->{status}, 404, 'somebody else may not, and the id is not confirmed');
}

# ---- grant, and it takes effect at once ---------------------------------------------
is(hit('/grant/7', as => 1)->{body}, 'granted', 'alice grants bob doc.edit on 7');
is(scalar @{ rows() }, 1, 'one row');
{
    my $g = rows()->[0];
    is($g->{subject_id}, 2, 'the subject is who it was granted to');
    is($g->{action}, 'doc.edit', 'the action');
    is($g->{object_id}, '7', 'the object, as text');
    is($g->{granted_by}, 1, 'and who granted it');
    ok($g->{created}, 'stamped');
}
is(hit('/edit/7', as => 2)->{status}, 200, 'and bob may now edit it');
is(hit('/edit/8', as => 2)->{status}, 404, 'the grant is for that object only');

# ---- granting twice is one row ------------------------------------------------------
is(hit('/grant/7', as => 1)->{body}, 'granted', 'granting again is not an error');
is(scalar @{ rows() }, 1, 'and does not make a second row');

# ---- revoke, and it stops working at once --------------------------------------------
is(hit('/revoke/7', as => 1)->{body}, '1', 'revoking removes the one row');
is(scalar @{ rows() }, 0, 'the table is empty again');
is(hit('/edit/7', as => 2)->{status}, 404, 'and bob is refused on the very next request');
is(hit('/revoke/7', as => 1)->{body}, '0', 'revoking what is not there removes nothing');

# ---- the helpers are absent unless grants were asked for --------------------------------
{
    package NPolicy;
    use Punk::Plugin::Authorisation;
    rule 'x.y' => sub { 1 };
    1;
}
{
    package App::NoGrants;
    use Punk;
    session secret => 'x' x 32;
    plugin 'Authorisation' => { policy => 'NPolicy', rank => [] };
    get '/g' => sub { my ($c) = @_; eval { $c->granted('x.y', 1) }; $c->text($@ ? 'no such helper' : 'present') };
}
{
    my $r = App::NoGrants->to_app->({ REQUEST_METHOD => 'GET', PATH_INFO => '/g',
        QUERY_STRING => '', SERVER_NAME => 'x', SERVER_PORT => 80, HTTP_HOST => 'x',
        'psgi.url_scheme' => 'http' });
    like(join('', @{ $r->[2] }), qr/no such helper/,
        'without grants => the helpers are not installed at all');
}

done_testing();
