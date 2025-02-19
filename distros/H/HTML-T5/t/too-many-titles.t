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

use Test::More tests => 4;

use HTML::T5;

my $html = join '', <DATA>;

my $tidy = HTML::T5->new;
isa_ok( $tidy, 'HTML::T5' );
$tidy->ignore( type => TIDY_INFO );
my $rc = $tidy->parse( '-', $html );
ok( $rc, 'Parsed OK' );

my @returned = map { $_->as_string } $tidy->messages;
#s/[\r\n]+\z// for @returned;
is( scalar @returned, 1, 'Exactly one warning returned' );

# Tidy 5.6.0 returns "too many title elements in <title>" instead of "too many title elements in <head>".
# When this gets fixed, make this like() into an is().
# https://github.com/htacg/tidy-html5/issues/692
like( $returned[0], qr/^- \(3:5\) Warning: too many title elements in <(head|title)>$/, 'Error message matches' );

exit 0;

__DATA__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <HEAD>
        <TITLE>Test stuff</TITLE>
        <TITLE>As if one title isn't enough</TITLE>
    </HEAD>
    <BODY BGCOLOR="white">
        <P>This is my paragraph</P>
    </BODY>
</HTML>
