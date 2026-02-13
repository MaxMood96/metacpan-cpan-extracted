use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

use WWW::Bund::CLI::Strings;

my $strings_dir = File::Spec->catdir($FindBin::Bin, '..', 'share', 'strings');

# Load German strings
{
    my $s = WWW::Bund::CLI::Strings->new(
        lang        => 'de',
        strings_dir => $strings_dir,
    );
    ok($s, 'German strings loaded');
    is($s->get('fmt_empty'), '(leer)', 'German fmt_empty');
    is($s->get('fmt_no_data'), '(keine Daten)', 'German fmt_no_data');
    like($s->get('title'), qr/Deutscher Bundes-API/, 'German title');
    like($s->get('available_apis'), qr/Verfuegbare/, 'German available_apis');
    like($s->get('usage'), qr/Verwendung/, 'German usage');
    like($s->get('commands_header'), qr/Befehle/, 'German commands_header');
}

# Load English strings
{
    my $s = WWW::Bund::CLI::Strings->new(
        lang        => 'en',
        strings_dir => $strings_dir,
    );
    ok($s, 'English strings loaded');
    is($s->get('fmt_empty'), '(empty)', 'English fmt_empty');
    is($s->get('fmt_no_data'), '(no data)', 'English fmt_no_data');
    like($s->get('title'), qr/German Federal Government/, 'English title');
    like($s->get('available_apis'), qr/Available/, 'English available_apis');
    like($s->get('usage'), qr/Usage/, 'English usage');
    like($s->get('commands_header'), qr/Commands/, 'English commands_header');
}

# sprintf support
{
    my $s = WWW::Bund::CLI::Strings->new(
        lang        => 'de',
        strings_dir => $strings_dir,
    );
    is($s->get('err_unknown_option', '--foo'), 'Unbekannte Option: --foo', 'sprintf with one arg');
    is($s->get('err_missing_arg', 'roadId'), 'Fehlendes Argument: <roadId>', 'sprintf missing arg');
    like($s->get('fmt_more_rows', 42), qr/42 weitere/, 'sprintf more rows');
    is($s->get('alias_hint', 'pegel', 'pegel_online'),
       "Alias: 'pegel' kann statt 'pegel_online' verwendet werden",
       'sprintf with two args');
}

# Unknown key returns key itself
{
    my $s = WWW::Bund::CLI::Strings->new(
        lang        => 'de',
        strings_dir => $strings_dir,
    );
    is($s->get('nonexistent_key'), 'nonexistent_key', 'unknown key returns key');
}

# Both languages have same keys
{
    my $de = WWW::Bund::CLI::Strings->new(lang => 'de', strings_dir => $strings_dir);
    my $en = WWW::Bund::CLI::Strings->new(lang => 'en', strings_dir => $strings_dir);

    my @de_keys = sort keys %{$de->_strings};
    my @en_keys = sort keys %{$en->_strings};

    is_deeply(\@de_keys, \@en_keys, 'German and English have same keys');
}

done_testing;
