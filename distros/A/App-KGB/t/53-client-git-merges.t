use strict;
use warnings;

use autodie qw(:all);
use Test::More;
use Test::Differences;
unified_diff();

BEGIN {
    eval { require Git; 1 }
        or plan skip_all => "Git.pm required for testing Git client";
}

use lib 't';
use TestBot;

use App::KGB::Change;
use App::KGB::Client::Git;
use App::KGB::Client::ServerRef;
use Git;
use File::Temp qw(tempdir);
use File::Spec;

use utf8;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

my $tmp_cleanup = not $ENV{TEST_KEEP_TMP};
my $dir = tempdir( 'kgb-XXXXXXX', CLEANUP => $tmp_cleanup, DIR => File::Spec->tmpdir );
diag "Temp directory $dir will be kept" unless $tmp_cleanup;

my $test_bot = TestBot->start;

sub write_tmp {
    my( $fn, $content ) = @_;

    open my $fh, '>', "$dir/$fn";
    print $fh $content;
    close $fh;
}

my $remote = "$dir/there.git";
my $local = "$dir/here";

sub w {
    my ( $fn, $content ) = @_;

    write_tmp( "here/$fn", "$content\n" );
}

sub a {
    my ( $fn, $content ) = @_;

    open my $fh, '>>', "$local/$fn";
    print $fh $content, "\n";
    close $fh;
}

mkdir $remote;
$ENV{GIT_DIR} = $remote;
system 'git', 'init', '--bare';

use Cwd;
my $R = getcwd;

my $hook_log = "$dir/hook.log";
my $hook = "$dir/there.git/hooks/post-receive";

my $client_script = $ENV{KGB_CLIENT_SCRIPT} || "$R/script/kgb-client";

# the real test client
{
    my $ccf = $test_bot->client_config_file;
    open my $fh, '>', $hook;
    print $fh <<EOF;
#!/bin/sh

tee -a "$dir/reflog" | PERL5LIB=$R/lib $^X -- $client_script --conf $ccf >> $hook_log 2>&1
EOF
    close $fh;
    chmod 0755, $hook;
}

if ( $ENV{TEST_KGB_BOT_RUNNING} ) {
    diag "will try to send notifications to locally running bot";
    open( my $fh, '>>', $hook );
    print $fh <<"EOF";

cat "$dir/reflog" | PERL5LIB=$R/lib $^X -- $client_script --conf $R/eg/test-client.conf --status-dir $dir
EOF
    close $fh;
}

mkdir $local;
$ENV{GIT_DIR} = "$local/.git";
mkdir "$local/.git";
system 'git', 'init';

my $git = 'Git'->repository($local);
ok( $git, 'local repository allocated' );
isa_ok( $git, 'Git' );

my $ign = $git->command( 'config', 'user.name', 'Test U. Ser' );
$ign = $git->command( 'config', 'user.email', 'ser@example.neverland' );

write_tmp 'reflog', '';

my $c = new_ok(
    'App::KGB::Client::Git' => [
        {   repo_id => 'test',
            servers => [
                App::KGB::Client::ServerRef->new(
                    {   uri      => "http://127.0.0.1:1234/",
                        password => "hidden",               # not used by this client instance
                    }
                ),
            ],

            #br_mod_re      => \@br_mod_re,
            #br_mod_re_swap => $br_mod_re_swap,
            #ignore_branch  => $ignore_branch,
            git_dir => $remote,
            reflog  => "$dir/reflog",
        }
    ]
);

sub push_ok {
    write_tmp 'reflog', '';
    unlink $hook_log if $hook_log and -s $hook_log;

    my $ignore = $git->command( [qw( push origin --all )], { STDERR => 0 } );
    $ignore = $git->command( [qw( push origin --tags )], { STDERR => 0 } );

    $c->_reset;
    $c->_detect_commits;

    diag `cat $hook_log` if $hook_log and -s $hook_log;
}

my %commits;
sub do_commit {
    my $ignore = $git->command_oneline( 'commit', '-m', shift ) =~ /\[(\w+).*\s+(\w+)\]/;
    push @{ $commits{$1} }, $2;
    diag "commit $2 in branch $1" unless $tmp_cleanup;
}

my $commit;

###### first commit
w( 'old', 'content' );
$ign = $git->command( 'add', '.' );
do_commit('import old content');
$ign = $git->command( 'remote', 'add', 'origin', "file://$remote" );
push_ok;

$commit = $c->describe_commit;
ok( defined($commit), 'initial import commit' );
is( $c->describe_commit, undef, 'no more commits' );

TestBot->expect( "dummy/#test 12test/03there 05master "
        . $commit->id
        . " 06Test U. Ser (06ser) 03old import old content * 14http://scm.host.org/there/master/?commit="
        . $commit->id.'' );

#### branch, two changes, merge. then the changes should be reported only once
my $b1 = 'a-new';
$ign = $git->command( [ 'checkout', '-b', $b1, 'master' ],
    { STDERR => 0 } );
w( 'new', 'content' );
$ign = $git->command( 'add', 'new' );
$ign = $git->command( 'commit', '-m', 'created new content' );
w( 'new', 'more content' );
$ign = $git->command( 'commit', '-a', '-m', 'updated new content' );
$ign = $git->command( 'checkout', '-q', 'master' );
$ign = $git->command( 'merge', '--no-ff', '-m', "merge '$b1' into master", $b1 );

# same with a branch name sorting after 'master'
my $b2 = 'new-content';
$ign = $git->command( [ 'checkout', '-b', $b2, 'master' ],
    { STDERR => 0 } );
w( 'new', 'content' );
$ign = $git->command( 'add', 'new' );
$ign = $git->command( 'commit', '-m', 'created new content' );
w( 'new', 'more content' );
$ign = $git->command( 'commit', '-a', '-m', 'updated new content' );
$ign = $git->command( 'checkout', '-q', 'master' );
$ign = $git->command( 'merge', '--no-ff', '-m', "merge '$b2' into master", $b2 );
push_ok();

$commit = $c->describe_commit;
ok( defined($commit), 'merge commit exists' );
is( $commit->branch, 'master' );
is( $commit->log,    "merge '$b1' into master" );

TestBot->expect( 'dummy/#test 12test/03there 05master '
        . $commit->id
        . ' 06Test U. Ser (06ser) merge \'a-new\' into master * 14http://scm.host.org/there/master/?commit='
        . $commit->id
        . '' );

$commit = $c->describe_commit;
ok( defined($commit), 'merge commit exists' );
is( $commit->branch, 'master' );
is( $commit->log,    "merge '$b2' into master" );

TestBot->expect( 'dummy/#test 12test/03there 05master '
        . $commit->id
        . ' 06Test U. Ser (06ser) merge \'new-content\' into master * 14http://scm.host.org/there/master/?commit='
        . $commit->id
        . '' );

$commit = $c->describe_commit;
ok( defined($commit), "first $b1 commit exists" );
is( $commit->branch, $b1 );
is( $commit->log,    "created new content" );

TestBot->expect( 'dummy/#test 12test/03there 05a-new '
        . $commit->id
        . ' 06Test U. Ser (06ser) 03new created new content * 14http://scm.host.org/there/a-new/?commit='
        . $commit->id
        . '' );

$commit = $c->describe_commit;
ok( defined($commit), "second $b1 commit exists" );
is( $commit->branch, $b1 );
is( $commit->log,    "updated new content" );

TestBot->expect( 'dummy/#test 12test/03there 05a-new '
        . $commit->id
        . ' 06Test U. Ser (06ser) 10new updated new content * 14http://scm.host.org/there/a-new/?commit='
        . $commit->id
        . '' );

$commit = $c->describe_commit;
ok( defined($commit), "first $b2 commit exists" );
is( $commit->branch, $b2 );
is( $commit->log,    "created new content" );

TestBot->expect( 'dummy/#test 12test/03there 05new-content '
        . $commit->id
        . ' 06Test U. Ser (06ser) 10new created new content * 14http://scm.host.org/there/new-content/?commit='
        . $commit->id
        . '' );

$commit = $c->describe_commit;
ok( defined($commit), "second $b2 commit exists" );
is( $commit->branch, $b2 );
is( $commit->log,    "updated new content" );

TestBot->expect( 'dummy/#test 12test/03there 05new-content '
        . $commit->id
        . ' 06Test U. Ser (06ser) 10new updated new content * 14http://scm.host.org/there/new-content/?commit='
        . $commit->id
        . '' );

##### No more commits after the last
$commit = $c->describe_commit;
is( $commit, undef );

my $output = $test_bot->get_output;

undef($test_bot);   # make sure all output us there

eq_or_diff( $output, TestBot->expected_output );

done_testing();
