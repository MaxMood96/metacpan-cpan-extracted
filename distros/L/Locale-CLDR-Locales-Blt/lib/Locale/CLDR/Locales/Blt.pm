=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Blt - Package for language Tai Dam

=cut

package Locale::CLDR::Locales::Blt;
# This file auto generated from Data\common\main\blt.xml
#	on Thu 29 Feb  5:43:51 pm GMT

use strict;
use warnings;
use version;

our $VERSION = version->declare('v0.44.1');

use v5.10.1;
use mro 'c3';
use utf8;
use if $^V ge v5.12.0, feature => 'unicode_strings';
use Types::Standard qw( Str Int HashRef ArrayRef CodeRef RegexpRef );
use Moo;

extends('Locale::CLDR::Locales::Root');
has 'display_name_language' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub {
		 sub {
			 my %languages = (
				'blt' => 'ꪼꪕꪒꪾ',

			);
			if (@_) {
				return $languages{$_[0]};
			}
			return \%languages;
		}
	},
);

has 'characters' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> $^V ge v5.18.0
	? eval <<'EOT'
	sub {
		no warnings 'experimental::regex_sets';
		return {
			main => qr{[꪿ ꫁ ꫝ ꪀ ꪁ ꪄ ꪅ ꪆ ꪇ ꪈ ꪉ ꪊ ꪋ ꪎ ꪏ ꪐ ꪑ ꪒ ꪓ ꪔ ꪕ ꪖ ꪗ ꪘ ꪙ ꪚ ꪛ ꪜ ꪝ ꪠ ꪡ ꪢ ꪣ ꪤ ꪥ ꪦ ꪧ ꪨ ꪩ ꪪ ꪫ ꪬ ꪭ ꪮ ꪯ ꪰ ꪱ ꪲ ꪳ ꪴ ꪵ ꪶ ꪷ ꪸ ꪹ ꪺ ꪻ ꪼ ꪽ ꪾ ꫀ ꫂ ꫛ ꫜ]},
			punctuation => qr{[. ꫞ ꫟]},
		};
	},
EOT
: sub {
		return {};
},
);


no Moo;

1;

# vim: tabstop=4
