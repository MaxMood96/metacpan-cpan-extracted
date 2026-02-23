#!/usr/bin/perl
# t/01-unit.t
# Unit tests for: url_decode, parse_query, mime_type,
#                 response builders, and HTTP::Handy::Input.
# No network or fork required; runs on all platforms.
use strict;

# ---- Minimal test harness (no Test::More required) --------------------
my ($T_PLAN, $T_RUN, $T_FAIL) = (0, 0, 0);
sub plan_tests { $T_PLAN = $_[0]; print "1..$T_PLAN\n" }
sub plan_skip  { print "1..0 # SKIP $_[0]\n"; exit 0 }
sub ok   { my($ok,$n)=@_; $T_RUN++; $ok||$T_FAIL++;
           print +($ok?'':'not ')."ok $T_RUN".($n?" - $n":"")."\n"; $ok }
sub is   { my($g,$e,$n)=@_; my $ok=(defined $g && $g eq $e);
           ok($ok,$n) or print "# got: ".(defined $g?$g:'undef')." expected: $e\n" }
sub like { my($g,$re,$n)=@_; ok(defined $g && $g=~$re,$n) }
END { exit 1 if $T_PLAN && $T_FAIL }
# -----------------------------------------------------------------------

use HTTP::Handy;
plan_tests(65);

# --- url_decode (ok 1-10) -----------------------------------------------

# ok 1: no escape sequences
is(HTTP::Handy->url_decode('hello'),         'hello',       'url_decode: plain string');
# ok 2: %20 decodes to space
is(HTTP::Handy->url_decode('hello%20world'), 'hello world', 'url_decode: %20 -> space');
# ok 3: + decodes to space
is(HTTP::Handy->url_decode('hello+world'),   'hello world', 'url_decode: + -> space');
# ok 4: %3D decodes to =
is(HTTP::Handy->url_decode('foo%3Dbar'),     'foo=bar',     'url_decode: %3D -> =');
# ok 5: %2F decodes to /
is(HTTP::Handy->url_decode('%2F'),           '/',           'url_decode: %2F -> /');
# ok 6: lowercase hex digits
is(HTTP::Handy->url_decode('%61%62%63'),     'abc',         'url_decode: lower hex');
# ok 7: uppercase hex digits
is(HTTP::Handy->url_decode('%41%42%43'),     'ABC',         'url_decode: upper hex');
# ok 8: empty string
is(HTTP::Handy->url_decode(''),              '',            'url_decode: empty string');
# ok 9: undef treated as empty string
is(HTTP::Handy->url_decode(undef),           '',            'url_decode: undef -> empty');
# ok 10: %2B decodes to literal + which must NOT be further converted to space
is(HTTP::Handy->url_decode('no%2Bchange'),   'no+change',   'url_decode: literal +');

# --- parse_query (ok 11-25) ---------------------------------------------

my %p;

# ok 11: single key
%p = HTTP::Handy->parse_query('name=ina');
is($p{name}, 'ina', 'parse_query: single key');

# ok 12-14: multiple distinct keys
%p = HTTP::Handy->parse_query('a=1&b=2&c=3');
is($p{a}, '1', 'parse_query: a');
is($p{b}, '2', 'parse_query: b');
is($p{c}, '3', 'parse_query: c');

# ok 15-19: repeated key produces an array reference
%p = HTTP::Handy->parse_query('tag=perl&tag=cpan&tag=ltsv');
ok(ref($p{tag}) eq 'ARRAY',    'parse_query: multi-value arrayref');
ok(scalar @{$p{tag}} == 3,     'parse_query: multi-value count');
is($p{tag}[0], 'perl',         'parse_query: multi [0]');
is($p{tag}[1], 'cpan',         'parse_query: multi [1]');
is($p{tag}[2], 'ltsv',         'parse_query: multi [2]');

# ok 20: + in value decodes to space
%p = HTTP::Handy->parse_query('msg=hello+world');
is($p{msg}, 'hello world', 'parse_query: + in value');

# ok 21: empty value
%p = HTTP::Handy->parse_query('key=');
is($p{key}, '', 'parse_query: empty value');

# ok 22-23: key with no = sign gets an empty string value
%p = HTTP::Handy->parse_query('novalue');
ok(exists $p{novalue}, 'parse_query: key without =');
is($p{novalue}, '',    'parse_query: key without = empty value');

# ok 24: empty string produces no keys
%p = HTTP::Handy->parse_query('');
ok(scalar keys %p == 0, 'parse_query: empty string');

# ok 25: undef produces no keys
%p = HTTP::Handy->parse_query(undef);
ok(scalar keys %p == 0, 'parse_query: undef');

# --- mime_type (ok 26-36) -----------------------------------------------

# ok 26-28: html extension in three forms (no dot, with dot, uppercase)
is(HTTP::Handy->mime_type('html'),  'text/html; charset=utf-8',  'mime_type: html');
is(HTTP::Handy->mime_type('.html'), 'text/html; charset=utf-8',  'mime_type: .html');
is(HTTP::Handy->mime_type('HTML'),  'text/html; charset=utf-8',  'mime_type: HTML uppercase');
# ok 29: css
is(HTTP::Handy->mime_type('css'),   'text/css',                  'mime_type: css');
# ok 30: js
is(HTTP::Handy->mime_type('js'),    'application/javascript',    'mime_type: js');
# ok 31: json
is(HTTP::Handy->mime_type('json'),  'application/json',          'mime_type: json');
# ok 32: png
is(HTTP::Handy->mime_type('png'),   'image/png',                 'mime_type: png');
# ok 33: jpg
is(HTTP::Handy->mime_type('jpg'),   'image/jpeg',                'mime_type: jpg');
# ok 34: ltsv is treated as text/plain
is(HTTP::Handy->mime_type('ltsv'),  'text/plain; charset=utf-8', 'mime_type: ltsv');
# ok 35: unknown extension falls back to octet-stream
is(HTTP::Handy->mime_type('xyz'),   'application/octet-stream',  'mime_type: unknown');
# ok 36: empty extension falls back to octet-stream
is(HTTP::Handy->mime_type(''),      'application/octet-stream',  'mime_type: empty');

# --- response builders (ok 37-48) ---------------------------------------

my ($r, %h);

# ok 37-40: response_html basic behavior
$r = HTTP::Handy->response_html('<h1>Hi</h1>');
ok($r->[0] == 200,                             'response_html: status 200');        # ok 37
%h = @{$r->[1]};
like($h{'Content-Type'}, qr{text/html},        'response_html: Content-Type');      # ok 38
ok($h{'Content-Length'} == length('<h1>Hi</h1>'), 'response_html: Content-Length'); # ok 39
is($r->[2][0], '<h1>Hi</h1>',                  'response_html: body');              # ok 40

# ok 41: custom status code
$r = HTTP::Handy->response_html('<p>x</p>', 201);
ok($r->[0] == 201, 'response_html: custom status');

# ok 42-43: response_text
$r = HTTP::Handy->response_text('hello');
ok($r->[0] == 200, 'response_text: status');
%h = @{$r->[1]};
like($h{'Content-Type'}, qr{text/plain}, 'response_text: Content-Type');

# ok 44-45: response_json
$r = HTTP::Handy->response_json('{"ok":1}');
ok($r->[0] == 200, 'response_json: status');
%h = @{$r->[1]};
is($h{'Content-Type'}, 'application/json', 'response_json: Content-Type');

# ok 46-47: response_redirect defaults to 302
$r = HTTP::Handy->response_redirect('/new');
ok($r->[0] == 302, 'response_redirect: 302');
%h = @{$r->[1]};
is($h{'Location'}, '/new', 'response_redirect: Location');

# ok 48: response_redirect with explicit 301
$r = HTTP::Handy->response_redirect('/new', 301);
ok($r->[0] == 301, 'response_redirect: custom 301');

# --- HTTP::Handy::Input (ok 49-60) -------------------------------------
# HTTP::Handy::Input is an in-memory psgi.input compatible object.
# open-on-scalar-ref requires Perl 5.6+, so HTTP::Handy::Input provides
# a compatible alternative for Perl 5.5.3.

my $in = HTTP::Handy::Input->new("hello\nworld\n");

# ok 49-51: read and tell
my ($buf, $n) = ('', 0);
$n = $in->read($buf, 5);
ok($n == 5,        'Input->read: byte count');   # ok 49
is($buf, 'hello',  'Input->read: data');         # ok 50
ok($in->tell == 5, 'Input->tell: position');     # ok 51

# ok 52: seek rewinds to the beginning
$in->seek(0, 0);
ok($in->tell == 0, 'Input->seek: rewind');       # ok 52

# ok 53-55: getline reads one line at a time; returns undef at EOF
my $line = $in->getline; is($line, "hello\n", 'Input->getline: line 1'); # ok 53
$line    = $in->getline; is($line, "world\n", 'Input->getline: line 2'); # ok 54
$line    = $in->getline; ok(!defined $line,   'Input->getline: EOF');    # ok 55

# ok 56-58: getlines returns all remaining lines as an array
$in->seek(0, 0);
my @lines = $in->getlines;
ok(scalar @lines == 2,   'Input->getlines: count'); # ok 56
is($lines[0], "hello\n", 'Input->getlines: [0]');   # ok 57
is($lines[1], "world\n", 'Input->getlines: [1]');   # ok 58

# ok 59-60: empty buffer
my $empty = HTTP::Handy::Input->new('');
$buf = ''; $n = $empty->read($buf, 100);
ok($n == 0,                  'Input->read: 0 from empty');        # ok 59
ok(!defined $empty->getline, 'Input->getline: undef from empty'); # ok 60

# --- is_htmx (ok 61-65) ------------------------------------------------

# ok 61: returns false when HX-Request is absent
my %plain_env = ();
ok(!HTTP::Handy->is_htmx(\%plain_env), 'is_htmx: false when header absent'); # ok 61

# ok 62: returns true when HX-Request is "true"
my %htmx_env = ('HTTP_HX_REQUEST' => 'true');
ok(HTTP::Handy->is_htmx(\%htmx_env),  'is_htmx: true when HX-Request: true'); # ok 62

# ok 63: returns false when HX-Request has an unexpected value
my %bad_env = ('HTTP_HX_REQUEST' => 'yes');
ok(!HTTP::Handy->is_htmx(\%bad_env),  'is_htmx: false when value != "true"'); # ok 63

# ok 64: returns 1 (not just truthy) for true case
my $val = HTTP::Handy->is_htmx(\%htmx_env);
ok($val == 1, 'is_htmx: returns exactly 1'); # ok 64

# ok 65: returns 0 (not just falsy) for false case
$val = HTTP::Handy->is_htmx(\%plain_env);
ok($val == 0, 'is_htmx: returns exactly 0'); # ok 65
