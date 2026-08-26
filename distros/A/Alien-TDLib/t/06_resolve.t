use strict;
use warnings;
use Test::More;

plan skip_all => 'run from the dist root' unless -f 'alienfile';

require './inc/Alien/TDLib/Resolve.pm';

# --- parse_spec ------------------------------------------------------------

for my $latest (undef, '', 'latest', 'LATEST') {
    my $got = Alien::TDLib::Resolve::parse_spec($latest);
    is($got->{mode}, 'latest',
        'unset/empty/latest means the newest published release'
        . (defined $latest ? " ('$latest')" : ' (undef)'));
}

my $sha = '022d60202e446ad1287b9fb68e687c8a0760788b';
is(Alien::TDLib::Resolve::parse_spec($sha)->{mode}, 'commit', 'a 40-hex string is a commit');
is(Alien::TDLib::Resolve::parse_spec(uc $sha)->{commit}, $sha, 'commit is lowercased');

for my $v (qw(1.8.66 1.8 10.20.30)) {
    my $got = Alien::TDLib::Resolve::parse_spec($v);
    is($got->{mode}, 'version', "$v is a version");
    is($got->{version}, $v, "$v is kept verbatim");
}

for my $bad ('nonsense', '1.8.66-rc1', 'deadbeef', '1.8.66.77.88') {
    ok(!eval { Alien::TDLib::Resolve::parse_spec($bad); 1 }, "'$bad' is rejected");
    like($@, qr/ALIEN_TDLIB_VERSION/, "'$bad' names the variable in the error");
}

# --- pick (pure: caller fetches, this decides) -----------------------------

my $meta = {
    'dist-tags' => { latest => '0.1008066.0', 'td-1.8.65' => '0.1008065.0' },
    versions => {
        '0.1008064.0' => { tdlib => { version => '1.8.64', commit => 'a' x 40 } },
        '0.1008065.0' => { tdlib => { version => '1.8.65', commit => 'b' x 40 } },
        '0.1008066.0' => { tdlib => { version => '1.8.66', commit => 'c' x 40 } },
    },
};
my $P = \&Alien::TDLib::Resolve::pick;
my $spec = \&Alien::TDLib::Resolve::parse_spec;

my $latest = $P->($meta, $spec->(undef));
is($latest->{version}, '1.8.66', 'latest follows the dist-tag');
is($latest->{npm}, '0.1008066.0', 'latest carries its npm version');
is($latest->{commit}, 'c' x 40, 'latest carries its commit');

is($P->($meta, $spec->('1.8.65'))->{npm}, '0.1008065.0', 'a version resolves via its td- dist-tag');
is($P->($meta, $spec->('1.8.64'))->{npm}, '0.1008064.0', 'a version with no dist-tag is found by scanning');
is($P->($meta, $spec->('b' x 40))->{version}, '1.8.65', 'a published commit maps back to its release');

my $unpublished = $P->($meta, $spec->('f' x 40));
is($unpublished->{commit}, 'f' x 40, 'an unpublished commit is still usable');
is($unpublished->{npm}, undef, 'an unpublished commit has no prebuilt package');

is($P->($meta, $spec->('9.9.9')), undef, 'an unknown version resolves to nothing');

# a release the registry lists without provenance must not be selected
my $no_prov = { 'dist-tags' => { latest => '0.1' }, versions => { '0.1' => {} } };
is($P->($no_prov, $spec->(undef)), undef, 'a release without tdlib provenance is refused');

# --- fallback --------------------------------------------------------------

my $fb = Alien::TDLib::Resolve::fallback();
ok($fb->{fallback}, 'the fallback is flagged as such');
is($fb->{version}, $Alien::TDLib::Resolve::FALLBACK_VERSION, 'fallback reports its version');
like($fb->{commit}, qr/^[0-9a-f]{40}$/, 'fallback carries a real commit');

done_testing;
