#!/usr/bin/env perl

use warnings;
use strict;

use HTML::D3;
use Test::Most tests => 19;

my $chart = HTML::D3->new(
	width  => 800,
	height => 600,
	title  => 'Zoomable Chart',
);

my $data = [
	['January',  1000],
	['February', 1200],
	['March',     950],
	['April',    1100],
	['May',      1250],
];

isa_ok($chart, 'HTML::D3', 'Chart object is created');
is($chart->{width},  800, 'Width is set correctly');
is($chart->{height}, 600, 'Height is set correctly');
is($chart->{title},  'Zoomable Chart', 'Title is set correctly');

my $fragment;
lives_ok { $fragment = $chart->render_zoomable_line_chart_snippet($data) } 'Zoomable snippet renders without error';

is(ref($fragment), 'HASH', 'Returns a hash reference');
is($fragment->{svg_id}, 'chart', 'svg_id key is present and correct');

my $html = $fragment->{html};
like($html,   qr/<svg id="chart"/,              'Fragment contains SVG element');
like($html,   qr/January/,                      'Fragment contains data label');
like($html,   qr/1000/,                         'Fragment contains data value');
like($html,   qr/<div class="tooltip"/,         'Fragment contains tooltip div');
unlike($html, qr/<!DOCTYPE/i,                   'Fragment has no DOCTYPE');
unlike($html, qr/<html/i,                       'Fragment has no <html> wrapper');

like($html, qr/d3\.brushX\(\)/,                 'Fragment uses d3.brushX for selection');
like($html, qr/brushed/,                        'Fragment contains brushed handler');
like($html, qr/Reset zoom/,                     'Fragment contains Reset zoom button');
like($html, qr/currentData = allData\.slice\(\)/, 'Reset restores full dataset');
like($html, qr/zoomed\.length < 2/,             'Guards against single-point zoom');

throws_ok {
	$chart->render_zoomable_line_chart_snippet('Invalid data');
} qr/Data must be an array of arrays/, 'Dies on invalid data';
