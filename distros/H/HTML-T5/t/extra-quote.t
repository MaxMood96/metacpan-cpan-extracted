#!perl -T

BEGIN
{
    $ENV{LC_ALL} = 'C';

    # See: https://github.com/shlomif/html-tidy5/issues/6
    $ENV{LANG} = 'en_US.UTF-8';
};


use 5.010001;
use warnings;
use strict;

# Response to an HTML::Lint request that it handle mishandled quotes.
# See https://rt.cpan.org/Ticket/Display.html?id=1459

use Test::More tests => 4;

use HTML::T5;

my $html = do { local $/ = undef; <DATA> };

my $tidy = HTML::T5->new;
isa_ok( $tidy, 'HTML::T5' );

$tidy->ignore( text => qr/DOCTYPE/ );
my $rc = $tidy->parse( '-', $html );
ok( $rc, 'Parsed OK' );

my @expected = split /\n/, <<'HERE';
- (4:1) Warning: <img> unexpected or duplicate quote mark
- (4:1) Warning: <img> escaping malformed URI reference
- (4:1) Warning: <img> illegal characters found in URI
- (4:1) Warning: <img> lacks "alt" attribute
HERE

chomp @expected;

my @messages = $tidy->messages;
is( scalar @messages, 4, 'Should have exactly three messages' );

my @strings = map { $_->as_string } @messages;
s/[\r\n]+\z// for @strings;
is_deeply( \@strings, \@expected, 'Matching warnings' );

__DATA__
<html>
<title>Bogo</title>
<body>
<img src="foo alt="">
</body>
</html>
