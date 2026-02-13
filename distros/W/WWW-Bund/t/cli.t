use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin;

my $bin = File::Spec->catfile($FindBin::Bin, '..', 'bin', 'bund');
my $bin_en = File::Spec->catfile($FindBin::Bin, '..', 'bin', 'bunden');
my $lib = File::Spec->catdir($FindBin::Bin, '..', 'lib');

sub run_bund {
    my @args = @_;
    my $cmd = "$^X -I$lib $bin " . join(' ', @args) . " 2>&1";
    my $out = `$cmd`;
    return ($out, $?);
}

sub run_bunden {
    my @args = @_;
    my $cmd = "$^X -I$lib $bin_en " . join(' ', @args) . " 2>&1";
    my $out = `$cmd`;
    return ($out, $?);
}

# No args: shows overview (German default)
{
    my ($out, $rc) = run_bund();
    is($rc, 0, 'no args exits 0');
    like($out, qr/Deutscher Bundes-API/, 'shows German title');
    like($out, qr/autobahn/, 'lists autobahn');
    like($out, qr/Verfuegbare APIs/, 'shows German available section');
}

# --help (MooX::Options auto-generated help)
{
    my ($out, $rc) = run_bund('--help');
    is($rc, 0, '--help exits 0');
    like($out, qr/--output/, '--help shows --output option');
}

# --lang en switches to English
{
    my ($out, $rc) = run_bund('--lang en');
    is($rc, 0, '--lang en exits 0');
    like($out, qr/German Federal Government/, '--lang en shows English title');
    like($out, qr/Available APIs/, '--lang en shows English available section');
}

# list (German)
{
    my ($out, $rc) = run_bund('list');
    is($rc, 0, 'list exits 0');
    like($out, qr/ID\s+TITEL/, 'de list shows German table header');
    like($out, qr/autobahn/, 'list shows autobahn');
    like($out, qr/nina/, 'list shows nina');
}

# list --lang en
{
    my ($out, $rc) = run_bund('--lang en list');
    is($rc, 0, 'en list exits 0');
    like($out, qr/ID\s+TITLE/, 'en list shows English table header');
}

# list --json
{
    my ($out, $rc) = run_bund('-o json list');
    is($rc, 0, 'json list exits 0');
    like($out, qr/^\[/, 'json list returns array');
}

# info (German)
{
    my ($out, $rc) = run_bund('info autobahn');
    is($rc, 0, 'info exits 0');
    like($out, qr/autobahn - Autobahn App API/, 'info shows API title');
    like($out, qr/Autobahn GmbH/, 'info shows provider');
    like($out, qr/Anbieter/, 'de info shows German label');
    like($out, qr/roads/, 'info shows endpoints');
}

# info --lang en
{
    my ($out, $rc) = run_bund('--lang en info autobahn');
    is($rc, 0, 'en info exits 0');
    like($out, qr/Provider/, 'en info shows English label');
}

# api help (no action) - German
{
    my ($out, $rc) = run_bund('autobahn');
    is($rc, 0, 'api help exits 0');
    like($out, qr/Befehle:/, 'de api help shows Befehle');
    like($out, qr/roads/, 'api help lists roads');
    like($out, qr/roadworks/, 'api help lists roadworks');
    like($out, qr/<roadId>/, 'api help shows path params');
}

# pegel alias
{
    my ($out, $rc) = run_bund('pegel');
    is($rc, 0, 'pegel alias exits 0');
    like($out, qr/pegel_online/, 'pegel resolves to pegel_online');
    like($out, qr/stations/, 'pegel shows stations');
}

# unknown API (German error)
{
    my ($out, $rc) = run_bund('nonexistent_api');
    isnt($rc, 0, 'unknown API exits non-zero');
    like($out, qr/Unbekannte/, 'de unknown API shows German error');
}

# unknown action (German error)
{
    my ($out, $rc) = run_bund('autobahn nonexistent');
    isnt($rc, 0, 'unknown action exits non-zero');
    like($out, qr/Unbekannter Befehl/, 'de unknown action shows German error');
}

# missing path param (German error)
{
    my ($out, $rc) = run_bund('autobahn roadworks');
    isnt($rc, 0, 'missing param exits non-zero');
    like($out, qr/Fehlendes Argument.*roadId/, 'de shows German missing param');
}

# hyphen-to-underscore API resolution
{
    my ($out, $rc) = run_bund('pegel-online');
    is($rc, 0, 'hyphenated API resolves');
    like($out, qr/stations/, 'hyphenated API shows endpoints');
}

# -o yaml for list
{
    my ($out, $rc) = run_bund('-o yaml list');
    is($rc, 0, 'yaml list exits 0');
    like($out, qr/^---/m, 'yaml list starts with ---');
    like($out, qr/autobahn/, 'yaml list contains autobahn');
}

# -o yaml for info
{
    my ($out, $rc) = run_bund('-o yaml info autobahn');
    is($rc, 0, 'yaml info exits 0');
    like($out, qr/^---/m, 'yaml info starts with ---');
    like($out, qr/title:/, 'yaml info has title field');
}

# --help shows options
{
    my ($out, $rc) = run_bund('--help');
    like($out, qr/--output/, 'help mentions output option');
    like($out, qr/--template|-t/, 'help mentions template option');
    like($out, qr/--lang/, 'help mentions lang option');
}

# --- bunden tests (English default) ---

# bunden no args: English
{
    my ($out, $rc) = run_bunden();
    is($rc, 0, 'bunden no args exits 0');
    like($out, qr/German Federal Government/, 'bunden shows English title');
    like($out, qr/Available APIs/, 'bunden shows English available section');
}

# bunden list: English headers
{
    my ($out, $rc) = run_bunden('list');
    is($rc, 0, 'bunden list exits 0');
    like($out, qr/ID\s+TITLE/, 'bunden list shows English headers');
}

# bunden --lang de: switch to German
{
    my ($out, $rc) = run_bunden('--lang de');
    is($rc, 0, 'bunden --lang de exits 0');
    like($out, qr/Deutscher Bundes-API/, 'bunden --lang de shows German title');
}

# bunden unknown API: English error
{
    my ($out, $rc) = run_bunden('nonexistent_api');
    isnt($rc, 0, 'bunden unknown API exits non-zero');
    like($out, qr/Unknown/, 'bunden shows English error');
}

# bunden api help: English
{
    my ($out, $rc) = run_bunden('autobahn');
    is($rc, 0, 'bunden autobahn exits 0');
    like($out, qr/Commands:/, 'bunden shows English Commands');
}

done_testing;
