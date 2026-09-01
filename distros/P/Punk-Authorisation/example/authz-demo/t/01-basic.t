#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../lib";
use Test::More;
use File::Spec ();
use File::Path ();

# The demo, driven as PSGI. What is asserted is the behaviour the README
# claims: that a refusal is a 404 when a 403 would confirm somebody else's
# row exists, a 403 when the row is already yours, and that a grant starts
# and stops working on the request after it is made.
#
# Against a real SQLite database deployed by Sqitch, because the DDL is half
# of what this distribution ships and a fake backend would not exercise it.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
    plan skip_all => 'DBD::SQLite required'
        unless eval { require DBI; require DBD::SQLite; 1 };
    plan skip_all => 'App::Sqitch required to deploy the schema'
        unless eval { require App::Sqitch; 1 };
    plan skip_all => 'Punk::Sqitch required to deploy the schema'
        unless eval { require Punk::Sqitch; 1 };
}

# config/punk.test.yml puts the database under var/test, so `prove t/` does
# not disturb the one the server uses. PUNK_ENV has to be set before
# AuthzDemo is loaded, because the class reads its configuration as it
# compiles.
$ENV{PUNK_ENV} = 'test';

chdir "$FindBin::Bin/.." or die "cannot chdir to the application root: $!";

my $db = File::Spec->catfile('var', 'test', 'authz-demo.db');

# `punk sqitch deploy` in a child, against that database: three projects, in
# dependency order - punk_auth's users table, the plugin's punk_authz grants
# table, and this application's own changes on top of both.
{
    File::Path::make_path(File::Spec->catdir('var', 'test'));
    unlink $db, File::Spec->catfile('var', 'test', 'sqitch.db');

    my $inc = join ' ', map { "-I'$_'" } 'lib', grep { !ref } @INC;
    my $out = qx{$^X $inc -MPunk::Command -e 'exit Punk::Command->main(\@ARGV)' -- sqitch deploy 2>&1};
    my $rc  = $?;
    diag($out) if $rc;
    plan skip_all => 'the schema did not deploy, so there is nothing to test'
        if $rc || !-s $db;
}

require AuthzDemo;
my $app = AuthzDemo->to_app;

# One cookie jar for the whole run, so signing in sticks the way a browser
# makes it stick.
my $COOKIE = '';

sub hit {
    my ($method, $path, %o) = @_;
    my $body = '';
    if ($o{form}) {
        $body = join '&', map { "$_=" . _esc($o{form}{$_}) }
                              sort keys %{ $o{form} };
    }
    open my $in, '<', \$body or die $!;
    my $env = {
        REQUEST_METHOD => $method,
        PATH_INFO      => $path,
        QUERY_STRING   => '',
        SERVER_NAME    => 'localhost',
        SERVER_PORT    => 80,
        HTTP_HOST      => 'localhost',
        HTTP_ACCEPT    => 'text/html',
        'psgi.url_scheme' => 'http',
        'psgi.input'      => $in,
    };
    if ($method eq 'POST') {
        $env->{CONTENT_TYPE}   = 'application/x-www-form-urlencoded';
        $env->{CONTENT_LENGTH} = length $body;
    }
    $env->{HTTP_COOKIE} = $COOKIE if length $COOKIE;

    my $r = $app->($env);
    for (my $i = 0; $i < @{ $r->[1] }; $i += 2) {
        next unless lc $r->[1][$i] eq 'set-cookie';
        my ($pair) = split /;/, $r->[1][$i + 1];
        $COOKIE = $pair;
    }
    return ($r->[0], join '', map { defined $_ ? $_ : '' } @{ $r->[2] });
}

sub _esc { my $s = shift // ''; $s =~ s/([^A-Za-z0-9_.~-])/sprintf '%%%02X', ord $1/ge; return $s }
sub act_as { my ($id) = @_; hit(POST => '/signin', form => { user_id => $id }) }

my ($ALICE, $BOB, $CAROL) = (1, 2, 3);
my ($HERS, $HIS, $PUBLIC) = (1, 2, 3);   # doc ids from authzdemo:demo_data

# ---- signed out ----------------------------------------------------------------

{
    my ($status) = hit(GET => "/doc/$HERS");
    is($status, 404, 'signed out, a private document is not even there');

    ($status) = hit(GET => "/doc/$PUBLIC");
    is($status, 200, 'and a public one is readable by anybody');
}

# ---- 404 against 403 -----------------------------------------------------------

act_as($ALICE);

{
    my ($status) = hit(POST => "/doc/$HIS/edit", form => { title => 'mine now' });
    is($status, 404, "somebody else's row is a 404, never a 403");

    ($status) = hit(GET => "/doc/$HIS");
    is($status, 404, 'and reading it says the same nothing');

    ($status) = hit(POST => "/doc/$HERS/edit", form => { title => 'Notes' });
    is($status, 302, 'her own row she may edit');

    # A member, on her own document: she knows it exists, so the refusal is
    # allowed to say so. This is the distinction the plugin exists to make.
    ($status) = hit(POST => "/doc/$HERS/publish");
    is($status, 403, 'rank she lacks on a row she owns is a 403');

    # And the same rule on somebody else's row must NOT be that 403. A rule
    # that asks rank_at_least before ownership passes every other assertion
    # in this file and fails this one, which is why it is here.
    ($status) = hit(POST => "/doc/$HIS/publish");
    is($status, 404, "the same rank refusal on somebody else's row is a 404");
}

# ---- the ladder ----------------------------------------------------------------

act_as($BOB);
{
    my ($status) = hit(POST => "/doc/$HIS/publish");
    is($status, 302, 'an editor may publish his own');
}

act_as($CAROL);
{
    my ($status) = hit(POST => "/doc/$HERS/share", form => { user_id => $CAROL });
    is($status, 404, 'an admin is not an owner: no granting herself access');
}

# ---- grants --------------------------------------------------------------------

act_as($BOB);
{
    my ($status) = hit(POST => "/doc/$HERS/edit", form => { title => 'nope' });
    is($status, 404, "bob cannot edit alice's notes to begin with");
}

act_as($ALICE);
{
    my ($status) = hit(POST => "/doc/$HERS/share", form => { user_id => $BOB });
    is($status, 302, 'alice grants bob edit on her notes');
}

act_as($BOB);
{
    my ($status) = hit(POST => "/doc/$HERS/edit", form => { title => 'Bob was here' });
    is($status, 302, 'and now he may - on the very next request, uncached');

    my (undef, $body) = hit(GET => "/doc/$HERS");
    like($body, qr/Bob was here/, 'the edit landed');
}

act_as($ALICE);
{
    my ($status) = hit(POST => "/doc/$HERS/unshare", form => { user_id => $BOB });
    is($status, 302, 'alice revokes it');
}

act_as($BOB);
{
    my ($status) = hit(POST => "/doc/$HERS/edit", form => { title => 'again' });
    is($status, 404, 'and it stops working at once, for the same reason');
}

# ---- the page the demo is for --------------------------------------------------

act_as($ALICE);
{
    my ($status, $body) = hit(GET => '/');
    is($status, 200, 'the matrix renders');
    like($body, qr/alice\@example\.com/, 'and says who is acting');
    like($body, qr/\b403\b/, 'showing a 403 somewhere');
    like($body, qr/\b404\b/, 'and a 404 somewhere else');
}

done_testing();
