#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most tests => 4;

BEGIN {
	use_ok('Locale::Places');
}

ERROR: {
	my $places;

	dies_ok { $places->translate('me' => 'tulip') } 'Unknown parameter "me"';
	dies_ok { $places->translate({ from => 'en' }) } 'Required parameter is missing';
	dies_ok { $places->translate({ from => 'x' }) } 'Required parameter is missing';
}
