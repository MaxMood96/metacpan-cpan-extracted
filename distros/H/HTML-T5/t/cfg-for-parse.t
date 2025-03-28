#!perl -T
use 5.010001;
use warnings;
use strict;

BEGIN
{
    $ENV{LC_ALL} = 'C';

    # See: https://github.com/shlomif/html-tidy5/issues/6
    $ENV{LANG} = 'en_US.UTF-8';
}

use Test::More tests => 3;

use HTML::T5 ();

my $html = do { local $/ = undef; <DATA> };

my @expected_messages = split /\n/, <<'HERE';
DATA (7:1) Error: <x> is not recognized!
DATA (8:1) Error: <y> is not recognized!
HERE

chomp @expected_messages;

my $tidy = HTML::T5->new( { config_file => 't/cfg-for-parse.cfg' } );
isa_ok( $tidy, 'HTML::T5' );

my $rc = $tidy->parse( 'DATA', $html );
ok( $rc, 'Parsed OK' );

my @returned = map { $_->as_string } $tidy->messages;
s/[\r\n]+\z// for @returned;
is_deeply( \@returned, \@expected_messages, 'Matching errors' );

__DATA__
<HTML>
<HEAD>
<TITLE>Foo
</HEAD>
<BODY>
</B>
<X>
<Y>
</I>
</BODY>
