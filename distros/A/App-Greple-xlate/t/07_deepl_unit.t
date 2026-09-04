use v5.14;
use warnings;

use Test::More;

use App::Greple::xlate::deepl;

local $App::Greple::xlate::deepl::lang_from = 'ORIGINAL';
local $App::Greple::xlate::deepl::lang_to = 'TR';
local $App::Greple::xlate::deepl::auth_key;
local $App::Greple::xlate::glossary;
local @App::Greple::xlate::contexts;

is_deeply(
    [ App::Greple::xlate::deepl::deepl_command() ],
    [ 'deepl', 'text', '--to', 'TR' ],
    'plain translation does not enable XML handling',
);

is_deeply(
    [ App::Greple::xlate::deepl::_marker_tags(
        '<person id="1" /> and <company id="2" />') ],
    [ 'company', 'person' ],
    'category tags are detected without mask options',
);
is_deeply(
    [ App::Greple::xlate::deepl::deepl_command('company', 'person') ],
    [ 'deepl', 'text', '--to', 'TR', '--tag-handling', 'xml',
      '--non-splitting-tags', 'company,person' ],
    'all detected category tags are protected by DeepL XML handling',
);

my $raw = "A & B < C; keep <person id=\"3\" /> here\n";
my $xml = App::Greple::xlate::deepl::_xml_wrap($raw);
is($xml,
   qq{<xlate>A &amp; B &lt; C; keep <person id="3"/> here\n</xlate>},
   'masked payload is converted to well-formed XML');
is(App::Greple::xlate::deepl::_xml_unwrap("$xml\n", $raw), $raw,
   'XML wrapper and entities round trip exactly');

my $adjacent = "<m id=\"1\" /> <m id=\"2\" /> module\n";
my $response = qq{<xlate><m id="1"/><m id="2"/> modül\n</xlate>\n};
is(App::Greple::xlate::deepl::_xml_unwrap($response, $adjacent),
   "<m id=\"1\" /> <m id=\"2\" /> modül\n",
   'separator between consecutive placeholders is restored');

done_testing;
