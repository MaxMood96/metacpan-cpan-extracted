package Geo::Coder::Abbreviations;

use warnings;
use strict;
use JSON::MaybeXS;
use LWP::Simple::WithCache;

=head1 NAME

Geo::Coder::Abbreviations - Quick and Dirty Interface to https://github.com/mapbox/geocoder-abbreviations

=head1 VERSION

Version 0.09

=cut

our %abbreviations;
our $VERSION = '0.09';

# This is giving 404 errors at the moment
#	https://github.com/mapbox/mapbox-java/issues/1460
# our location = 'https://raw.githubusercontent.com/mapbox/geocoder-abbreviations/master/tokens/en.json';
use constant LOCATION => 'https://raw.githubusercontent.com/allison-strandberg/geocoder-abbreviations/master/tokens/en.json';

=head1 SYNOPSIS

Provides an interface to https://github.com/mapbox/geocoder-abbreviations.
One small function for now, I'll add others later.

=head1 SUBROUTINES/METHODS

=head2 new

Creates a Geo::Coder::Abbreviations object.
It takes no arguments.
If you have L<HTTP::Cache::Transparent> installed it will load much faster,
otherwise it will download the database from the Internet
when the class is first instantiated.

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	if(!defined($class)) {
		# Using Geo::Coder::Abbreviations->new(), not Geo::Coder::Abbreviations::new()
		# carp(__PACKAGE__, ' use ->new() not ::new() to instantiate');
		# return;

		# FIXME: this only works when no arguments are given
		$class = __PACKAGE__;
	} elsif(ref($class)) {
		# clone the given object
		# return bless { %{$class}, %args }, ref($class);
		return bless { %{$class} }, ref($class);
	}

	unless(scalar keys(%abbreviations)) {
		if(eval { require HTTP::Cache::Transparent; }) {
			require File::Spec;	# That should be installed

			File::Spec->import();
			HTTP::Cache::Transparent->import();

			my $cache_dir;
			if($cache_dir = ($ENV{'CACHE_DIR'} || $ENV{'CACHEDIR'})) {
				mkdir $cache_dir, 02700 if(!-d $cache_dir);
				$cache_dir = File::Spec->catfile($cache_dir, 'http-cache-transparent');
			} else {
				# $cache_dir = File::Spec->catfile(File::Spec->tmpdir(), 'cache', 'http-cache-transparent');
				$cache_dir = File::Spec->catfile(File::HomeDir->my_home(), '.cache', 'http-cache-transparent');
			}

			HTTP::Cache::Transparent::init({
				BasePath => $cache_dir,
				# Verbose => $opts{'v'} ? 1 : 0,
				NoUpdate => 60 * 60 * 24,
				MaxAge => 30 * 24
			}) || die "$0: $cache_dir $!";
		}

		# TODO:	Support other languages
		my $data = LWP::Simple::WithCache::get(LOCATION);

		if(!defined($data)) {
			# die 'error downloading from ', LOCATION;
			$data = join('', grep(!/^\s*(#|$)/, <DATA>));
		}
		%abbreviations = map {
			my %rc = ();
			if(defined($_->{'type'}) && ($_->{'type'} eq 'way')) {
				foreach my $token(@{$_->{'tokens'}}) {
					$rc{uc($token)} = uc($_->{'canonical'});
				}
			}
			%rc;
		} @{JSON::MaybeXS->new()->utf8()->decode($data)};

		# %abbreviations = map { (defined($_->{'type'}) && ($_->{'type'} eq 'way')) ? (uc($_->{'full'}) => uc($_->{'canonical'})) : () } @{JSON::MaybeXS->new()->utf8()->decode($data)};
	}

	return bless {
		table => \%abbreviations
	}, $class;
}

=head2 abbreviate

Abbreviate a place.

    use Geo::Coder::Abbreviations;

    my $abbr = Geo::Coder::Abbreviations->new();
    print $abbr->abbreviate('Road'), "\n";	# prints 'RD'
    print $abbr->abbreviate('RD'), "\n";	# prints 'RD'

=cut

sub abbreviate {
	my $self = shift;

	return $self->{'table'}->{uc(shift)};
}

=head2 normalize

Normalize and abbreviate street names - useful for comparisons

    print $abbr->normalize({ street => '10 Downing Street' }), "\n";	# prints '10 DOWNING ST'

Can be run as a class method

    print Geo::Coder::Abbreviations('1600 Pennsylvania Avenue NW'), "\n";	# prints '1600 Pennsylvia Ave NW'

=cut

sub normalize
{
	my $self = shift;
	my %params;

	# Try hard to support whatever API that the user wants to use
	if(!ref($self)) {
		if(scalar(@_)) {
			return(__PACKAGE__->new()->normalize(@_));
		} elsif(!defined($self)) {
			# Geo::Coder::Abbreviations->normalize()
			Carp::croak('Usage: ', __PACKAGE__, '::normalize(street => $street)');
		} elsif($self eq __PACKAGE__) {
			Carp::croak("Usage: $self", '::normalize(street => $street)');
		}
		return(__PACKAGE__->new()->normalize($self));
	} elsif(ref($self) eq 'HASH') {
		return(__PACKAGE__->new()->noralize($self));
	} elsif(ref($_[0]) eq 'HASH') {
		%params = %{$_[0]};
	# } elsif(ref($_[0]) && (ref($_[0] !~ /::/))) {
	} elsif(ref($_[0])) {
		Carp::croak('Usage: ', __PACKAGE__, '::normalize(street => $street)');
	} elsif(scalar(@_) && (scalar(@_) % 2 == 0)) {
		%params = @_;
	} else {
		$params{'street'} = shift;
	}

	my $street = $params{'street'};

	$street = uc($street);
	if($street =~ /(.+)\s+(.+)\s+(.+)/) {
		my $a;
		if((lc($2) ne 'cross') && ($a = $self->abbreviate($2))) {
			$street = "$1 $a $3";
		} elsif($a = $self->abbreviate($3)) {
			$street = "$1 $2 $a";
		}
	} elsif($street =~ /(.+)\s(.+)$/) {
		if(my $a = $self->abbreviate($2)) {
			$street = "$1 $a";
		}
	}
	$street =~ s/^0+//;     # Turn 04th St into 4th St
	return $street;
}

=head1 SEE ALSO

L<https://github.com/mapbox/geocoder-abbreviations>
L<HTTP::Cache::Transparent>
L<https://www.mapbox.com/>

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 BUGS

You may need to ensure you don't translate "Cross Street" to "X ST".
See t/abbreviations.t.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Geo::Coder::Abbreviations

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Geo-Coder-Abbreviations>

=item * Search CPAN

L<http://search.cpan.org/dist/Geo-Coder-Abbreviations/>

=back

=head1 ACKNOWLEDGMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2020-2024 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1; # End of Geo::Coder::Abbreviations

# https://raw.githubusercontent.com/mapbox/geocoder-abbreviations/master/tokens/en.json is giving 404 errors at the moment
# so here is a copy until it's back

__DATA__
[
    {
        "tokens": [
            "1",
            "one"
        ],
        "full": "one",
        "canonical": "1",
        "type": "number"
    },
    {
        "tokens": [
            "2",
            "two"
        ],
        "full": "two",
        "canonical": "2",
        "type": "number"
    },
    {
        "tokens": [
            "3",
            "three"
        ],
        "full": "three",
        "canonical": "3",
        "type": "number"
    },
    {
        "tokens": [
            "4",
            "four"
        ],
        "full": "four",
        "canonical": "4",
        "type": "number"
    },
    {
        "tokens": [
            "5",
            "five"
        ],
        "full": "five",
        "canonical": "5",
        "type": "number"
    },
    {
        "tokens": [
            "6",
            "six"
        ],
        "full": "six",
        "canonical": "6",
        "type": "number"
    },
    {
        "tokens": [
            "7",
            "seven"
        ],
        "full": "seven",
        "canonical": "7",
        "type": "number"
    },
    {
        "tokens": [
            "8",
            "eight"
        ],
        "full": "eight",
        "canonical": "8",
        "type": "number"
    },
    {
        "tokens": [
            "9",
            "nine"
        ],
        "full": "nine",
        "canonical": "9",
        "type": "number"
    },
    {
        "tokens": [
            "10",
            "ten"
        ],
        "full": "ten",
        "canonical": "10",
        "type": "number"
    },
    {
        "tokens": [
            "11",
            "eleven"
        ],
        "full": "eleven",
        "canonical": "11",
        "type": "number"
    },
    {
        "tokens": [
            "12",
            "twelve"
        ],
        "full": "twelve",
        "canonical": "12",
        "type": "number"
    },
    {
        "tokens": [
            "13",
            "thirteen"
        ],
        "full": "thirteen",
        "canonical": "13",
        "type": "number"
    },
    {
        "tokens": [
            "14",
            "fourteen"
        ],
        "full": "fourteen",
        "canonical": "14",
        "type": "number"
    },
    {
        "tokens": [
            "15",
            "fifteen"
        ],
        "full": "fifteen",
        "canonical": "15",
        "type": "number"
    },
    {
        "tokens": [
            "16",
            "sixteen"
        ],
        "full": "sixteen",
        "canonical": "16",
        "type": "number"
    },
    {
        "tokens": [
            "17",
            "seventeen"
        ],
        "full": "seventeen",
        "canonical": "17",
        "type": "number"
    },
    {
        "tokens": [
            "18",
            "eighteen"
        ],
        "full": "eighteen",
        "canonical": "18",
        "type": "number"
    },
    {
        "tokens": [
            "19",
            "nineteen"
        ],
        "full": "nineteen",
        "canonical": "19",
        "type": "number"
    },
    {
        "tokens": [
            "20",
            "twenty"
        ],
        "full": "twenty",
        "canonical": "20",
        "type": "number"
    },
    {
        "tokens": [
            "10th",
            "Tenth"
        ],
        "full": "Tenth",
        "canonical": "10th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "11th",
            "Eleventh"
        ],
        "full": "Eleventh",
        "canonical": "11th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "12th",
            "Twelfth"
        ],
        "full": "Twelfth",
        "canonical": "12th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "13th",
            "Thirteenth"
        ],
        "full": "Thirteenth",
        "canonical": "13th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "14th",
            "Fourteenth"
        ],
        "full": "Fourteenth",
        "canonical": "14th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "15th",
            "Fifteenth"
        ],
        "full": "Fifteenth",
        "canonical": "15th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "16th",
            "Sixteenth"
        ],
        "full": "Sixteenth",
        "canonical": "16th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "17th",
            "Seventeenth"
        ],
        "full": "Seventeenth",
        "canonical": "17th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "18th",
            "Eighteenth"
        ],
        "full": "Eighteenth",
        "canonical": "18th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "19th",
            "Nineteenth"
        ],
        "full": "Nineteenth",
        "canonical": "19th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "1st",
            "First"
        ],
        "full": "First",
        "canonical": "1st",
        "type": "ordinal"
    },
    {
        "tokens": [
            "20th",
            "Twentieth"
        ],
        "full": "Twentieth",
        "canonical": "20th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "2nd",
            "Second"
        ],
        "full": "Second",
        "canonical": "2nd",
        "type": "ordinal"
    },
    {
        "tokens": [
            "3rd",
            "Third"
        ],
        "full": "Third",
        "canonical": "3rd",
        "type": "ordinal"
    },
    {
        "tokens": [
            "4th",
            "Fourth"
        ],
        "full": "Fourth",
        "canonical": "4th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "5th",
            "Fifth"
        ],
        "full": "Fifth",
        "canonical": "5th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "6th",
            "Sixth"
        ],
        "full": "Sixth",
        "canonical": "6th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "7th",
            "Seventh"
        ],
        "full": "Seventh",
        "canonical": "7th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "8th",
            "Eighth"
        ],
        "full": "Eighth",
        "canonical": "8th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "9th",
            "Ninth"
        ],
        "full": "Ninth",
        "canonical": "9th",
        "type": "ordinal"
    },
    {
        "tokens": [
            "Accs",
            "Access"
        ],
        "full": "Access",
        "canonical": "Accs",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Alwy",
            "Alleyway"
        ],
        "full": "Alleyway",
        "canonical": "Alwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Aly",
            "Ally",
            "Alley"
        ],
        "full": "Alley",
        "canonical": "Aly",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Ambl",
            "Amble"
        ],
        "full": "Amble",
        "canonical": "Ambl",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "App",
            "Approach"
        ],
        "full": "Approach",
        "canonical": "App",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Apt",
            "Apartment"
        ],
        "full": "Apartment",
        "canonical": "Apt"
    },
    {
        "tokens": [
            "Apts",
            "Apartments"
        ],
        "full": "Apartments",
        "canonical": "Apts"
    },
    {
        "tokens": [
            "Arc",
            "Arcade"
        ],
        "full": "Arcade",
        "canonical": "Arc"
    },
    {
        "tokens": [
            "Artl",
            "Arterial"
        ],
        "full": "Arterial",
        "canonical": "Artl",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Arty",
            "Artery"
        ],
        "full": "Artery",
        "canonical": "Arty",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Av",
            "Ave",
            "Avenue"
        ],
        "full": "Avenue",
        "canonical": "Av",
        "type": "way"
    },
    {
        "tokens": [
            "Ba",
            "Banan"
        ],
        "full": "Banan",
        "canonical": "Ba"
    },
    {
        "tokens": [
            "Bch",
            "Beach"
        ],
        "full": "Beach",
        "canonical": "Bch"
    },
    {
        "tokens": [
            "Bg",
            "Burg"
        ],
        "full": "Burg",
        "canonical": "Bg"
    },
    {
        "tokens": [
            "Bgs",
            "Burgs"
        ],
        "full": "Burgs",
        "canonical": "Bgs"
    },
    {
        "tokens": [
            "Blf",
            "Bluff"
        ],
        "full": "Bluff",
        "canonical": "Blf"
    },
    {
        "tokens": [
            "Blk",
            "Block"
        ],
        "full": "Block",
        "canonical": "Blk"
    },
    {
        "tokens": [
            "Br",
            "Brace"
        ],
        "full": "Brace",
        "canonical": "Br"
    },
    {
        "tokens": [
            "Br",
            "Branch"
        ],
        "full": "Branch",
        "canonical": "Br",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Brg",
            "Bridge"
        ],
        "full": "Bridge",
        "canonical": "Brg",
        "onlyLayers": ["address"]
    },
    {
        "tokens": [
            "Brk",
            "Break"
        ],
        "full": "Break",
        "canonical": "Brk"
    },
    {
        "tokens": [
            "Brk",
            "Brook"
        ],
        "full": "Brook",
        "canonical": "Brk"
    },
    {
        "tokens": [
            "Brks",
            "Brooks"
        ],
        "full": "Brooks",
        "canonical": "Brks"
    },
    {
        "tokens": [
            "Btm",
            "Bottom"
        ],
        "full": "Bottom",
        "canonical": "Btm"
    },
    {
        "tokens": [
            "Blv",
            "Blvd",
            "Boulevard"
        ],
        "full": "Boulevard",
        "canonical": "Blvd",
        "type": "way"
    },
    {
        "tokens": [
            "Bwlk",
            "Boardwalk"
        ],
        "full": "Boardwalk",
        "canonical": "Bwlk",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Byp",
            "Bypa",
            "Bypass"
        ],
        "full": "Bypass",
        "canonical": "Byp",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Byu",
            "Bayou"
        ],
        "full": "Bayou",
        "canonical": "Byu"
    },
    {
        "tokens": [
            "Bywy",
            "Byway"
        ],
        "full": "Byway",
        "canonical": "Bywy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Bzr",
            "Bazaar"
        ],
        "full": "Bazaar",
        "canonical": "Bzr"
    },
    {
        "tokens": [
            "Cantt",
            "Cantonment"
        ],
        "full": "Cantonment",
        "canonical": "Cantt"
    },
    {
        "tokens": [
            "Cct",
            "Circuit"
        ],
        "full": "Circuit",
        "canonical": "Cct",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Ch",
            "Chase"
        ],
        "full": "Chase",
        "canonical": "Ch",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Chk",
            "Chowk"
        ],
        "full": "Chowk",
        "canonical": "Chk"
    },
    {
        "tokens": [
            "Cir",
            "Circle"
        ],
        "full": "Circle",
        "canonical": "Cir",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Cirs",
            "Circles"
        ],
        "full": "Circles",
        "canonical": "Cirs",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Cl",
            "Clinic"
        ],
        "full": "Clinic",
        "canonical": "Cl"
    },
    {
        "tokens": [
            "Cl",
            "Clo",
            "Close"
        ],
        "full": "Close",
        "canonical": "Cl",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Clb",
            "Club"
        ],
        "full": "Club",
        "canonical": "Clb"
    },
    {
        "tokens": [
            "Clf",
            "Cliff"
        ],
        "full": "Cliff",
        "canonical": "Clf"
    },
    {
        "tokens": [
            "Clfs",
            "Cliffs"
        ],
        "full": "Cliffs",
        "canonical": "Clfs"
    },
    {
        "tokens": [
            "Cll",
            "Calle"
        ],
        "full": "Calle",
        "canonical": "Cll",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Cly",
            "Colony"
        ],
        "full": "Colony",
        "canonical": "Cly"
    },
    {
        "tokens": [
            "Cmn",
            "Common"
        ],
        "full": "Common",
        "canonical": "Cmn"
    },
    {
        "tokens": [
            "Cmns",
            "Commons"
        ],
        "full": "Commons",
        "canonical": "Cmns"
    },
    {
        "tokens": [
            "Cnl",
            "Canal"
        ],
        "full": "Canal",
        "canonical": "Cnl"
    },
    {
        "tokens": [
            "Cnr",
            "Cor",
            "Corner"
        ],
        "full": "Corner",
        "canonical": "Cnr"
    },
    {
        "tokens": [
            "Co",
            "County"
        ],
        "full": "County",
        "canonical": "Co"
    },
    {
        "tokens": [
            "Coll",
            "College"
        ],
        "full": "College",
        "canonical": "Coll",
        "preferFull": true
    },
    {
        "tokens": [
            "Con",
            "Concourse"
        ],
        "full": "Concourse",
        "canonical": "Con",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Const",
            "Constituency"
        ],
        "full": "Constituency",
        "canonical": "Const"
    },
    {
        "tokens": [
            "Corpn",
            "Corporation"
        ],
        "full": "Corporation",
        "canonical": "Corpn"
    },
    {
        "tokens": [
            "Cp",
            "Camp"
        ],
        "full": "Camp",
        "canonical": "Cp"
    },
    {
        "tokens": [
            "Cpe",
            "Cape"
        ],
        "full": "Cape",
        "canonical": "Cpe"
    },
    {
        "tokens": [
            "Cplx",
            "Complex"
        ],
        "full": "Complex",
        "canonical": "Cplx"
    },
    {
        "tokens": [
            "Cps",
            "Copse"
        ],
        "full": "Copse",
        "canonical": "Cps"
    },
    {
        "tokens": [
            "Crcs",
            "Circus"
        ],
        "full": "Circus",
        "canonical": "Crcs"
    },
    {
        "tokens": [
            "Crk",
            "Creek"
        ],
        "full": "Creek",
        "canonical": "Crk"
    },
    {
        "tokens": [
            "Crpk",
            "Carpark"
        ],
        "full": "Carpark",
        "canonical": "Crpk"
    },
    {
        "tokens": [
            "Crse",
            "Course"
        ],
        "full": "Course",
        "canonical": "Crse"
    },
    {
        "tokens": [
            "Crst",
            "Crest"
        ],
        "full": "Crest",
        "canonical": "Crst",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Csac",
            "Cul-de-sac"
        ],
        "full": "Cul-de-sac",
        "canonical": "Csac",
        "onlyLayers": ["address"],
        "type": "way",
        "spanBoundaries": 2
    },
    {
        "tokens": [
            "Cswy",
            "Causeway"
        ],
        "full": "Causeway",
        "canonical": "Cswy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Ct",
            "Court"
        ],
        "full": "Court",
        "canonical": "Ct",
        "type": "way"
    },
    {
        "tokens": [
            "Ctr",
            "Center",
            "Centre"
        ],
        "full": "Center",
        "canonical": "Ctr"
    },
    {
        "tokens": [
            "Ctrs",
            "Centers"
        ],
        "full": "Centers",
        "canonical": "Ctrs"
    },
    {
        "tokens": [
            "Cts",
            "Courts"
        ],
        "full": "Courts",
        "canonical": "Cts",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Ctyd",
            "Courtyard"
        ],
        "full": "Courtyard",
        "canonical": "Ctyd"
    },
    {
        "tokens": [
            "Curv",
            "Curve"
        ],
        "full": "Curve",
        "canonical": "Curv",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Cutt",
            "Cutting"
        ],
        "full": "Cutting",
        "canonical": "Cutt"
    },
    {
        "tokens": [
            "Cv",
            "Cove"
        ],
        "full": "Cove",
        "canonical": "Cv"
    },
    {
        "tokens": [
            "Cyn",
            "Canyon"
        ],
        "full": "Canyon",
        "canonical": "Cyn"
    },
    {
        "tokens": [
            "Dl",
            "Dale"
        ],
        "full": "Dale",
        "canonical": "Dl"
    },
    {
        "tokens": [
            "Dm",
            "Dam"
        ],
        "full": "Dam",
        "canonical": "Dm"
    },
    {
        "tokens": [
            "Dr",
            "Dv",
            "Drive"
        ],
        "full": "Drive",
        "canonical": "Dr",
        "type": "way"
    },
    {
        "tokens": [
            "Dv",
            "Divide"
        ],
        "full": "Divide",
        "canonical": "Dv"
    },
    {
        "tokens": [
            "Drs",
            "Drives"
        ],
        "full": "Drives",
        "canonical": "Drs",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Dt",
            "District"
        ],
        "full": "District",
        "canonical": "Dt"
    },
    {
        "tokens": [
            "Dvwy",
            "Driveway"
        ],
        "full": "Driveway",
        "canonical": "Dvwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "E",
            "Est",
            "East"
        ],
        "full": "East",
        "canonical": "E",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Elb",
            "Elbow"
        ],
        "full": "Elbow",
        "canonical": "Elb"
    },
    {
        "tokens": [
            "Ent",
            "Entrance"
        ],
        "full": "Entrance",
        "canonical": "Ent",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Esp",
            "Esplanade"
        ],
        "full": "Esplanade",
        "canonical": "Esp"
    },
    {
        "tokens": [
            "Est",
            "Estate"
        ],
        "full": "Estate",
        "canonical": "Est"
    },
    {
        "tokens": [
            "Ests",
            "Estates"
        ],
        "full": "Estates",
        "canonical": "Ests"
    },
    {
        "tokens": [
            "Exp",
            "Expy",
            "Expressway"
        ],
        "full": "Expressway",
        "canonical": "Exp",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Ext",
            "Extension"
        ],
        "full": "Extension",
        "canonical": "Ext"
    },
    {
        "tokens": [
            "Exts",
            "Extensions"
        ],
        "full": "Extensions",
        "canonical": "Exts"
    },
    {
        "tokens": [
            "Fawy",
            "Fairway"
        ],
        "full": "Fairway",
        "canonical": "Fawy"
    },
    {
        "tokens": [
            "Fld",
            "Field"
        ],
        "full": "Field",
        "canonical": "Fld"
    },
    {
        "tokens": [
            "Flds",
            "Fields"
        ],
        "full": "Fields",
        "canonical": "Flds"
    },
    {
        "tokens": [
            "Fls",
            "Falls"
        ],
        "full": "Falls",
        "canonical": "Fls"
    },
    {
        "tokens": [
            "Flt",
            "Flat"
        ],
        "full": "Flat",
        "canonical": "Flt"
    },
    {
        "tokens": [
            "Ftrl",
            "Firetrail"
        ],
        "full": "Firetrail",
        "canonical": "Ftrl"
    },
    {
        "tokens": [
            "Flts",
            "Flats"
        ],
        "full": "Flats",
        "canonical": "Flts"
    },
    {
        "tokens": [
            "FM",
            "Farm-To-Market"
        ],
        "full": "Farm-To-Market",
        "canonical": "FM",
        "spanBoundaries": 2
    },
    {
        "tokens": [
            "Folw",
            "Follow"
        ],
        "full": "Follow",
        "canonical": "Folw"
    },
    {
        "tokens": [
            "Form",
            "Formation"
        ],
        "full": "Formation",
        "canonical": "Form"
    },
    {
        "tokens": [
            "Frd",
            "Ford"
        ],
        "full": "Ford",
        "canonical": "Frd"
    },
    {
        "tokens": [
            "Frg",
            "Forge"
        ],
        "full": "Forge",
        "canonical": "Frg"
    },
    {
        "tokens": [
            "Frgs",
            "Forges"
        ],
        "full": "Forges",
        "canonical": "Frgs"
    },
    {
        "tokens": [
            "Frk",
            "Fork"
        ],
        "full": "Fork",
        "canonical": "Frk",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Frst",
            "Forest"
        ],
        "full": "Forest",
        "canonical": "Frst"
    },
    {
        "tokens": [
            "Frtg",
            "Frontage"
        ],
        "full": "Frontage",
        "canonical": "Frtg"
    },
    {
        "tokens": [
            "Fry",
            "Ferry"
        ],
        "full": "Ferry",
        "canonical": "Fry"
    },
    {
        "tokens": [
            "Ft",
            "Feet"
        ],
        "full": "Feet",
        "canonical": "Ft"
    },
    {
        "tokens": [
            "Ft",
            "Fort"
        ],
        "full": "Fort",
        "canonical": "Ft"
    },
    {
        "tokens": [
            "Ftwy",
            "Footway"
        ],
        "full": "Footway",
        "canonical": "Ftwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Fwy",
            "Freeway"
        ],
        "full": "Freeway",
        "canonical": "Fwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Gdns",
            "Gardens"
        ],
        "full": "Gardens",
        "canonical": "Gdns"
    },
    {
        "tokens": [
            "Gen",
            "General"
        ],
        "full": "General",
        "canonical": "Gen"
    },
    {
        "tokens": [
            "Gl",
            "Galli"
        ],
        "full": "Galli",
        "canonical": "Gl"
    },
    {
        "tokens": [
            "Glde",
            "Glade"
        ],
        "full": "Glade",
        "canonical": "Glde"
    },
    {
        "tokens": [
            "Govt",
            "Government"
        ],
        "full": "Government",
        "canonical": "Govt"
    },
    {
        "tokens": [
            "Gr",
            "Gro",
            "Grove"
        ],
        "full": "Grove",
        "canonical": "Gr"
    },
    {
        "tokens": [
            "Gra",
            "Grange"
        ],
        "full": "Grange",
        "canonical": "Gra"
    },
    {
        "tokens": [
            "Grd",
            "Grade"
        ],
        "full": "Grade",
        "canonical": "Grd"
    },
    {
        "tokens": [
            "Gn",
            "Grn",
            "Green"
        ],
        "full": "Green",
        "canonical": "Gn"
    },
    {
        "tokens": [
            "Gte",
            "Gate"
        ],
        "full": "Gate",
        "canonical": "Gte"
    },
    {
        "tokens": [
            "Hbr",
            "Harbor"
        ],
        "full": "Harbor",
        "canonical": "Hbr"
    },
    {
        "tokens": [
            "Hbrs",
            "Harbors"
        ],
        "full": "Harbors",
        "canonical": "Hbrs"
    },
    {
        "tokens": [
            "Hird",
            "Highroad"
        ],
        "full": "Highroad",
        "canonical": "Hird",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Hl",
            "Hill"
        ],
        "full": "Hill",
        "canonical": "Hl"
    },
    {
        "tokens": [
            "Hls",
            "Hills"
        ],
        "full": "Hills",
        "canonical": "Hls"
    },
    {
        "tokens": [
            "Holw",
            "Hollow"
        ],
        "full": "Hollow",
        "canonical": "Holw"
    },
    {
        "tokens": [
            "Hosp",
            "Hospital"
        ],
        "full": "Hospital",
        "canonical": "Hosp"
    },
    {
        "tokens": [
            "Ho",
            "House"
        ],
        "full": "House",
        "canonical": "Ho"
    },
    {
        "tokens": [
            "Htl",
            "Hotel"
        ],
        "full": "Hotel",
        "canonical": "Htl"
    },
    {
        "tokens": [
            "Hts",
            "Heights"
        ],
        "full": "Heights",
        "canonical": "Hts"
    },
    {
        "tokens": [
            "Hvn",
            "Haven"
        ],
        "full": "Haven",
        "canonical": "Hvn"
    },
    {
        "tokens": [
            "Hwy",
            "Highway"
        ],
        "full": "Highway",
        "canonical": "Hwy",
        "type": "way"
    },
    {
        "tokens": [
            "I",
            "Interstate"
        ],
        "full": "Interstate",
        "canonical": "I"
    },
    {
        "tokens": [
            "Ind",
            "Industrial"
        ],
        "full": "Industrial",
        "canonical": "Ind"
    },
    {
        "tokens": [
            "Intg",
            "Interchange"
        ],
        "full": "Interchange",
        "canonical": "Intg"
    },
    {
        "tokens": [
            "Is",
            "Island"
        ],
        "full": "Island",
        "canonical": "Is"
    },
    {
        "tokens": [
            "Iss",
            "Islands"
        ],
        "full": "Islands",
        "canonical": "Iss"
    },
    {
        "tokens": [
            "Jcts",
            "Junctions"
        ],
        "full": "Junctions",
        "canonical": "Jcts"
    },
    {
        "tokens": [
            "Jn",
            "Jct",
            "Jnc",
            "Junction"
        ],
        "full": "Junction",
        "canonical": "Jn"
    },
    {
        "tokens": [
            "Jr",
            "Junior"
        ],
        "full": "Junior",
        "canonical": "Jr"
    },
    {
        "tokens": [
            "Knl",
            "Knoll"
        ],
        "full": "Knoll",
        "canonical": "Knl"
    },
    {
        "tokens": [
            "Knls",
            "Knolls"
        ],
        "full": "Knolls",
        "canonical": "Knls"
    },
    {
        "tokens": [
            "Ky",
            "Key"
        ],
        "full": "Key",
        "canonical": "Ky"
    },
    {
        "tokens": [
            "Kys",
            "Keys"
        ],
        "full": "Keys",
        "canonical": "Kys"
    },
    {
        "tokens": [
            "Lp",
            "Loop"
        ],
        "full": "Loop",
        "canonical": "Lp"
    },
    {
        "tokens": [
            "Lck",
            "Lock"
        ],
        "full": "Lock",
        "canonical": "Lck"
    },
    {
        "tokens": [
            "Lcks",
            "Locks"
        ],
        "full": "Locks",
        "canonical": "Lcks"
    },
    {
        "tokens": [
            "Ldg",
            "Lodge"
        ],
        "full": "Lodge",
        "canonical": "Ldg"
    },
    {
        "tokens": [
            "Lf",
            "Loaf"
        ],
        "full": "Loaf",
        "canonical": "Lf"
    },
    {
        "tokens": [
            "Lgt",
            "Light"
        ],
        "full": "Light",
        "canonical": "Lgt"
    },
    {
        "tokens": [
            "Lgts",
            "Lights"
        ],
        "full": "Lights",
        "canonical": "Lgts"
    },
    {
        "tokens": [
            "Lk",
            "Lake"
        ],
        "full": "Lake",
        "canonical": "Lk"
    },
    {
        "tokens": [
            "Lks",
            "Lakes"
        ],
        "full": "Lakes",
        "canonical": "Lks"
    },
    {
        "tokens": [
            "Lkt",
            "Lookout"
        ],
        "full": "Lookout",
        "canonical": "Lkt"
    },
    {
        "tokens": [
            "Ln",
            "La",
            "Lane"
        ],
        "full": "Lane",
        "canonical": "Ln",
        "type": "way"
    },
    {
        "tokens": [
            "Lndg",
            "Landing"
        ],
        "full": "Landing",
        "canonical": "Lndg"
    },
    {
        "tokens": [
            "Lnwy",
            "Laneway"
        ],
        "full": "Laneway",
        "canonical": "Lnwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Lt",
            "Lieutenant"
        ],
        "full": "Lieutenant",
        "canonical": "Lt"
    },
    {
        "tokens": [
            "Lyt",
            "Layout"
        ],
        "full": "Layout",
        "canonical": "Lyt"
    },
    {
        "tokens": [
            "Maj",
            "Major"
        ],
        "full": "Major",
        "canonical": "Maj"
    },
    {
        "tokens": [
            "Mal",
            "Mall"
        ],
        "full": "Mall",
        "canonical": "Mal"
    },
    {
        "tokens": [
            "Mcplty",
            "Municipality"
        ],
        "full": "Municipality",
        "canonical": "Mcplty"
    },
    {
        "tokens": [
            "Mdw",
            "Meadow"
        ],
        "full": "Meadow",
        "canonical": "Mdw"
    },
    {
        "tokens": [
            "Mdws",
            "Meadows"
        ],
        "full": "Meadows",
        "canonical": "Mdws"
    },
    {
        "tokens": [
            "Mws",
            "Mews"
        ],
        "full": "Mews",
        "canonical": "Mws"
    },
    {
        "tokens": [
            "Mg",
            "Marg"
        ],
        "full": "Marg",
        "canonical": "Mg"
    },
    {
        "tokens": [
            "Mhd",
            "Moorhead"
        ],
        "full": "Moorhead",
        "canonical": "Mhd"
    },
    {
        "tokens": [
            "Mkt",
            "Market"
        ],
        "full": "Market",
        "canonical": "Mkt"
    },
    {
        "tokens": [
            "Ml",
            "Mill"
        ],
        "full": "Mill",
        "canonical": "Ml"
    },
    {
        "tokens": [
            "Mndr",
            "Meander"
        ],
        "full": "Meander",
        "canonical": "Mndr",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Mnr",
            "Manor"
        ],
        "full": "Manor",
        "canonical": "Mnr"
    },
    {
        "tokens": [
            "Mnrs",
            "Manors"
        ],
        "full": "Manors",
        "canonical": "Mnrs"
    },
    {
        "tokens": [
            "Mq",
            "Mosque"
        ],
        "full": "Mosque",
        "canonical": "Mq"
    },
    {
        "tokens": [
            "Msn",
            "Mission"
        ],
        "full": "Mission",
        "canonical": "Msn"
    },
    {
        "tokens": [
            "Mt",
            "Mount"
        ],
        "full": "Mount",
        "canonical": "Mt"
    },
    {
        "tokens": [
            "Mtn",
            "Mountain"
        ],
        "full": "Mountain",
        "canonical": "Mtn"
    },
    {
        "tokens": [
            "Mtwy",
            "Motorway"
        ],
        "full": "Motorway",
        "canonical": "Mtwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "N",
            "Nth",
            "North"
        ],
        "full": "North",
        "canonical": "N",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Nck",
            "Neck"
        ],
        "full": "Neck",
        "canonical": "Nck"
    },
    {
        "tokens": [
            "NE",
            "Northeast"
        ],
        "full": "Northeast",
        "canonical": "NE",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Ngr",
            "Nagar"
        ],
        "full": "Nagar",
        "canonical": "Ngr"
    },
    {
        "tokens": [
            "Nl",
            "Nalla"
        ],
        "full": "Nalla",
        "canonical": "Nl"
    },
    {
        "tokens": [
            "NW",
            "Northwest"
        ],
        "full": "Northwest",
        "canonical": "NW",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Off",
            "Office"
        ],
        "full": "Office",
        "canonical": "Off"
    },
    {
        "tokens": [
            "Orch",
            "Orchard"
        ],
        "full": "Orchard",
        "canonical": "Orch"
    },
    {
        "tokens": [
            "Otlk",
            "Outlook"
        ],
        "full": "Outlook",
        "canonical": "Otlk"
    },
    {
        "tokens": [
            "Ovps",
            "Overpass"
        ],
        "full": "Overpass",
        "canonical": "Ovps",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Pchyt",
            "Panchayat"
        ],
        "full": "Panchayat",
        "canonical": "Pchyt"
    },
    {
        "tokens": [
            "Pde",
            "Parade"
        ],
        "full": "Parade",
        "canonical": "Pde"
    },
    {
        "tokens": [
            "Pf",
            "Platform"
        ],
        "full": "Platform",
        "canonical": "Pf"
    },
    {
        "tokens": [
            "Ph",
            "Phase"
        ],
        "full": "Phase",
        "canonical": "Ph"
    },
    {
        "tokens": [
            "Piaz",
            "Piazza"
        ],
        "full": "Piazza",
        "canonical": "Piaz"
    },
    {
        "tokens": [
            "Pk",
            "Pike"
        ],
        "full": "Pike",
        "canonical": "Pk",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Pk",
            "Park"
        ],
        "full": "Park",
        "canonical": "Pk"
    },
    {
        "tokens": [
            "Pk",
            "Peak"
        ],
        "full": "Peak",
        "canonical": "Pk"
    },
    {
        "tokens": [
            "Pkt",
            "Pocket"
        ],
        "full": "Pocket",
        "canonical": "Pkt"
    },
    {
        "tokens": [
            "Pl",
            "Place"
        ],
        "full": "Place",
        "canonical": "Pl",
        "type": "way"
    },
    {
        "tokens": [
            "Pln",
            "Plain"
        ],
        "full": "Plain",
        "canonical": "Pln"
    },
    {
        "tokens": [
            "Plns",
            "Plains"
        ],
        "full": "Plains",
        "canonical": "Plns"
    },
    {
        "tokens": [
            "Plz",
            "Plza",
            "Plaza"
        ],
        "full": "Plaza",
        "canonical": "Plz"
    },
    {
        "tokens": [
            "Pr",
            "Prairie"
        ],
        "full": "Prairie",
        "canonical": "Pr"
    },
    {
        "tokens": [
            "Prom",
            "Promenade"
        ],
        "full": "Promenade",
        "canonical": "Prom"
    },
    {
        "tokens": [
            "Prt",
            "Port"
        ],
        "full": "Port",
        "canonical": "Prt"
    },
    {
        "tokens": [
            "Prts",
            "Ports"
        ],
        "full": "Ports",
        "canonical": "Prts"
    },
    {
        "tokens": [
            "Psge",
            "Passage"
        ],
        "full": "Passage",
        "canonical": "Psge"
    },
    {
        "tokens": [
            "Pt",
            "Pnt",
            "Point"
        ],
        "full": "Point",
        "canonical": "Pt"
    },
    {
        "tokens": [
            "Pts",
            "Points"
        ],
        "full": "Points",
        "canonical": "Pts"
    },
    {
        "tokens": [
            "Pvt",
            "Private"
        ],
        "full": "Private",
        "canonical": "Pvt"
    },
    {
        "tokens": [
            "Pway",
            "Pathway"
        ],
        "full": "Pathway",
        "canonical": "Pway",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Py",
            "Pw",
            "Pky",
            "Pwy",
            "Pkwy",
            "Prkwy",
            "Parkway"
        ],
        "full": "Parkway",
        "canonical": "Pkwy",
        "type": "way"
    },
    {
        "tokens": [
            "Qdrt",
            "Quadrant"
        ],
        "full": "Quadrant",
        "canonical": "Qdrt"
    },
    {
        "tokens": [
            "Qtrs",
            "Quarters"
        ],
        "full": "Quarters",
        "canonical": "Qtrs"
    },
    {
        "tokens": [
            "Qy",
            "Quay"
        ],
        "full": "Quay",
        "canonical": "Qy"
    },
    {
        "tokens": [
            "Qys",
            "Quays"
        ],
        "full": "Quays",
        "canonical": "Qys"
    },
    {
        "tokens": [
            "R",
            "Riv",
            "River"
        ],
        "full": "River",
        "canonical": "R"
    },
    {
        "tokens": [
            "Radl",
            "Radial"
        ],
        "full": "Radial",
        "canonical": "Radl"
    },
    {
        "tokens": [
            "Rd",
            "Road"
        ],
        "full": "Road",
        "canonical": "Rd",
        "type": "way"
    },
    {
        "tokens": [
            "Rdg",
            "Rdge",
            "Ridge"
        ],
        "full": "Ridge",
        "canonical": "Rdg",
        "preferFull": true
    },
    {
        "tokens": [
            "Rdgs",
            "Ridges"
        ],
        "full": "Ridges",
        "canonical": "Rdgs"
    },
    {
        "tokens": [
            "Rds",
            "Roads"
        ],
        "full": "Roads",
        "canonical": "Rds",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Rly",
            "Railway"
        ],
        "full": "Railway",
        "canonical": "Rly"
    },
    {
        "tokens": [
            "Rmbl",
            "Ramble"
        ],
        "full": "Ramble",
        "canonical": "Rmbl"
    },
    {
        "tokens": [
            "RM",
            "Ranch-To-Market"
        ],
        "full": "Ranch-To-Market",
        "canonical": "RM",
        "spanBoundaries": 2
    },
    {
        "tokens": [
            "Rw",
            "Row"
        ],
        "full": "Row",
        "canonical": "Rw"
    },
    {
        "tokens": [
            "Rpd",
            "Rapid"
        ],
        "full": "Rapid",
        "canonical": "Rpd"
    },
    {
        "tokens": [
            "Rpds",
            "Rapids"
        ],
        "full": "Rapids",
        "canonical": "Rpds"
    },
    {
        "tokens": [
            "Rse",
            "Rise"
        ],
        "full": "Rise",
        "canonical": "Rse"
    },
    {
        "tokens": [
            "Rst",
            "Rest"
        ],
        "full": "Rest",
        "canonical": "Rst"
    },
    {
        "tokens": [
            "Rt",
            "Rte",
            "Route"
        ],
        "full": "Route",
        "canonical": "Rt",
        "type": "way"
    },
    {
        "tokens": [
            "Rtt",
            "Retreat"
        ],
        "full": "Retreat",
        "canonical": "Rtt"
    },
    {
        "tokens": [
            "Rty",
            "Rotary"
        ],
        "full": "Rotary",
        "canonical": "Rty",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Rw",
            "Row"
        ],
        "full": "Row",
        "canonical": "Rw"
    },
    {
        "tokens": [
            "S",
            "Sth",
            "South"
        ],
        "full": "South",
        "canonical": "S",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Sbwy",
            "Subway"
        ],
        "full": "Subway",
        "canonical": "Sbwy"
    },
    {
        "tokens": [
            "SE",
            "Southeast"
        ],
        "full": "Southeast",
        "canonical": "SE",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Sgt",
            "Sergeant"
        ],
        "full": "Sergeant",
        "canonical": "Sgt"
    },
    {
        "tokens": [
            "Shl",
            "Shoal"
        ],
        "full": "Shoal",
        "canonical": "Shl"
    },
    {
        "tokens": [
            "Shls",
            "Shoals"
        ],
        "full": "Shoals",
        "canonical": "Shls"
    },
    {
        "tokens": [
            "Shr",
            "Shore"
        ],
        "full": "Shore",
        "canonical": "Shr"
    },
    {
        "tokens": [
            "Shrs",
            "Shores"
        ],
        "full": "Shores",
        "canonical": "Shrs"
    },
    {
        "tokens": [
            "Shun",
            "Shunt"
        ],
        "full": "Shunt",
        "canonical": "Shun"
    },
    {
        "tokens": [
            "Skwy",
            "Skyway"
        ],
        "full": "Skyway",
        "canonical": "Skwy"
    },
    {
        "tokens": [
            "Smt",
            "Summit"
        ],
        "full": "Summit",
        "canonical": "Smt"
    },
    {
        "tokens": [
            "Spg",
            "Spring"
        ],
        "full": "Spring",
        "canonical": "Spg"
    },
    {
        "tokens": [
            "Spgs",
            "Springs"
        ],
        "full": "Springs",
        "canonical": "Spgs"
    },
    {
        "tokens": [
            "Sq",
            "Square"
        ],
        "full": "Square",
        "canonical": "Sq"
    },
    {
        "tokens": [
            "Sqs",
            "Squares"
        ],
        "full": "Squares",
        "canonical": "Sqs"
    },
    {
        "tokens": [
            "Sr",
            "Senior"
        ],
        "full": "Senior",
        "canonical": "Sr"
    },
    {
        "tokens": [
            "St",
            "Saint"
        ],
        "full": "Saint",
        "canonical": "St"
    },
    {
        "tokens": [
            "St",
            "Street"
        ],
        "full": "Street",
        "canonical": "St",
        "type": "way"
    },
    {
        "tokens": [
            "Stn",
            "Station"
        ],
        "full": "Station",
        "canonical": "Stn"
    },
    {
        "tokens": [
            "Std",
            "Stadium"
        ],
        "full": "Stadium",
        "canonical": "Std"
    },
    {
        "tokens": [
            "Stps",
            "Steps"
        ],
        "full": "Steps",
        "canonical": "Stps"
    },
    {
        "tokens": [
            "Stg",
            "Stage"
        ],
        "full": "Stage",
        "canonical": "Stg"
    },
    {
        "tokens": [
            "Strm",
            "Stream"
        ],
        "full": "Stream",
        "canonical": "Strm"
    },
    {
        "tokens": [
            "Sts",
            "Streets"
        ],
        "full": "Streets",
        "canonical": "Sts"
    },
    {
        "tokens": [
            "Svwy",
            "Serviceway"
        ],
        "full": "Serviceway",
        "canonical": "Svwy"
    },
    {
        "tokens": [
            "SW",
            "Southwest"
        ],
        "full": "Southwest",
        "canonical": "SW",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Tce",
            "Ter",
            "Terrace"
        ],
        "full": "Terrace",
        "canonical": "Ter"
    },
    {
        "tokens": [
            "Tfwy",
            "Trafficway"
        ],
        "full": "Trafficway",
        "canonical": "Tfwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Thfr",
            "Thoroughfare"
        ],
        "full": "Thoroughfare",
        "canonical": "Thfr",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Thwy",
            "Thruway"
        ],
        "full": "Thruway",
        "canonical": "Thwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Tlwy",
            "Tollway"
        ],
        "full": "Tollway",
        "canonical": "Tlwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Tpke",
            "Turnpike"
        ],
        "full": "Turnpike",
        "canonical": "Tpke",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Tpl",
            "Temple"
        ],
        "full": "Temple",
        "canonical": "Tpl"
    },
    {
        "tokens": [
            "Trce",
            "Trace"
        ],
        "full": "Trace",
        "canonical": "Trce"
    },
    {
        "tokens": [
            "Trk",
            "Track"
        ],
        "full": "Track",
        "canonical": "Trk"
    },
    {
        "tokens": [
            "Tr",
            "Trl",
            "Trail"
        ],
        "full": "Trail",
        "canonical": "Tr"
    },
    {
        "tokens": [
            "Tunl",
            "Tunnel"
        ],
        "full": "Tunnel",
        "canonical": "Tunl",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Twn",
            "Town"
        ],
        "full": "Town",
        "canonical": "Twn"
    },
    {
        "tokens": [
            "Un",
            "Union"
        ],
        "full": "Union",
        "canonical": "Un"
    },
    {
        "tokens": [
            "Univ",
            "University"
        ],
        "full": "University",
        "canonical": "Univ",
        "preferFull": true
    },
    {
        "tokens": [
            "Unp",
            "Upas",
            "Underpass"
        ],
        "full": "Underpass",
        "canonical": "Upas",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Uns",
            "Unions"
        ],
        "full": "Unions",
        "canonical": "Uns"
    },
    {
        "tokens": [
            "Via",
            "Viad",
            "Viaduct"
        ],
        "full": "Viaduct",
        "canonical": "Via",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Vis",
            "Vsta",
            "Vista"
        ],
        "full": "Vista",
        "canonical": "Vis"
    },
    {
        "tokens": [
            "Vl",
            "Ville"
        ],
        "full": "Ville",
        "canonical": "Vl"
    },
    {
        "tokens": [
            "Vlg",
            "Vill",
            "Village"
        ],
        "full": "Village",
        "canonical": "Vlg"
    },
    {
        "tokens": [
            "Vlgs",
            "Villages"
        ],
        "full": "Villages",
        "canonical": "Vlgs"
    },
    {
        "tokens": [
            "Vly",
            "Valley"
        ],
        "full": "Valley",
        "canonical": "Vly"
    },
    {
        "tokens": [
            "Vlys",
            "Valleys"
        ],
        "full": "Valleys",
        "canonical": "Vlys"
    },
    {
        "tokens": [
            "Vw",
            "View"
        ],
        "full": "View",
        "canonical": "Vw"
    },
    {
        "tokens": [
            "Vws",
            "Views"
        ],
        "full": "Views",
        "canonical": "Vws"
    },
    {
        "tokens": [
            "W",
            "Wst",
            "West"
        ],
        "full": "West",
        "canonical": "W",
        "type": "cardinal"
    },
    {
        "tokens": [
            "Wd",
            "Wood"
        ],
        "full": "Wood",
        "canonical": "Wd"
    },
    {
        "tokens": [
            "Whrf",
            "Wharf"
        ],
        "full": "Wharf",
        "canonical": "Whrf"
    },
    {
        "tokens": [
            "Wkwy",
            "Walkway"
        ],
        "full": "Walkway",
        "canonical": "Wkwy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Wlk",
            "Walk"
        ],
        "full": "Walk",
        "canonical": "Wlk"
    },
    {
        "tokens": [
            "Wy",
            "Way"
        ],
        "full": "Way",
        "canonical": "Wy",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "X",
            "Cr",
            "Cres",
            "Crss",
            "Cross",
            "Crescent"
        ],
        "full": "Crescent",
        "canonical": "X",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "Xing",
            "Crossing"
        ],
        "full": "Crossing",
        "canonical": "Xing",
        "onlyLayers": ["address"],
        "type": "way"
    },
    {
        "tokens": [
            "",
            "P\\.?O\\.? Box [0-9]+"
        ],
        "full": "P\\.?O\\.? Box [0-9]+",
        "canonical": "",
        "spanBoundaries": 2,
        "onlyLayers": ["address"],
        "type": "box",
        "regex": true
    },
    {
        "tokens": [
            "",
            "P\\.? O\\.? Box [0-9]+"
        ],
        "full": "P\\.? O\\.? Box [0-9]+",
        "canonical": "",
        "spanBoundaries": 3,
        "onlyLayers": ["address"],
        "type": "box",
        "regex": true
    },
    {
        "tokens": [
            "",
            "(?:suite|ste) #?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)"
        ],
        "full": "(?:suite|ste) #?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)",
        "canonical": "",
        "spanBoundaries": 1,
        "onlyLayers": ["address"],
        "type": "unit",
        "regex": true
    },
    {
        "tokens": [
            "Po",
            "Post Office"
        ],
        "full": "Post Office",
        "canonical": "Po",
        "spanBoundaries": 1
    },
    {
        "tokens": [
            "Rs",
            "Railway Station"
        ],
        "full": "Railway Station",
        "canonical": "Rs",
        "spanBoundaries": 1
    },
    {
        "tokens": [
            "Vpo",
            "Village Post Office"
        ],
        "full": "Village Post Office",
        "canonical": "Vpo",
        "spanBoundaries": 2
    },
    {
        "tokens": [
            "NT",
            "New Territories"
        ],
        "full": "New Territories",
        "canonical": "NT",
        "onlyCountries": ["hk"],
        "spanBoundaries": 1
    },
    {
        "tokens": [
            "NT",
            "N.T."
        ],
        "full": "N.T.",
        "canonical": "NT",
        "onlyCountries": ["hk"]
    },
    {
        "tokens": [
            "",
            "(?:apartment|apt|bldg|building|rm|room|unit) #?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)"
        ],
        "canonical": "",
        "full": "(?:apartment|apt|bldg|building|rm|room|unit) #?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)",
        "regex": true,
        "spanBoundaries": 1,
        "onlyLayers": ["address"],
        "onlyCountries": ["us"],
        "type": "unit"
    },
    {
        "tokens": [
            "",
            "(?:floor|fl) #?\\d{1,3}"
        ],
        "canonical": "",
        "full": "(?:floor|fl) #?\\d{1,3}",
        "regex": true,
        "spanBoundaries": 1,
        "onlyLayers": ["address"],
        "onlyCountries": ["us"],
        "type": "unit"
    },
    {
        "tokens": [
            "",
            "\\d{1,3}(?:st|nd|rd|th) (?:floor|fl)"
        ],
        "canonical": "",
        "full": "\\d{1,3}(?:st|nd|rd|th) (?:floor|fl)",
        "regex": true,
        "spanBoundaries": 1,
        "onlyLayers": ["address"],
        "onlyCountries": ["us"],
        "type": "unit"
    },
    {
        "tokens": [
            "$1",
            "((?!apartment|apt|bldg|building|rm|room|unit|fl|floor|ste|suite)[a-z]{2,}) # ?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)"
        ],
        "canonical": "$1",
        "full": "((?!apartment|apt|bldg|building|rm|room|unit|fl|floor|ste|suite)[a-z]{2,}) # ?(?:[A-Z]|\\d+|[A-Z]\\d+|\\d+[A-Z]|\\d+-\\d+[A-Z]?)",
        "regex": true,
        "spanBoundaries": 1,
        "onlyLayers": ["address"],
        "onlyCountries": ["us"],
        "type": "unit"
    },
    {
        "tokens": [
            "$1",
            "([0-9]+)(?:st|nd|rd|th)"
        ],
        "canonical": "$1",
        "full": "([0-9]+)(?:st|nd|rd|th)",
        "regex": true,
        "onlyLayers": ["address"],
        "onlyCountries": ["us"],
        "reduceRelevance": true
    },
    {
        "tokens": [
            "$1$2",
            "([A-Z]{1,2}[0-9][0-9A-Z]?) ?([0-9][A-Z]{2})"
        ],
        "full": "([A-Z]{1,2}[0-9][0-9A-Z]?) ?([0-9][A-Z]{2})",
        "canonical": "$1$2",
        "onlyCountries": ["gb"],
        "onlyLayers": ["address"],
        "spanBoundaries": 1,
        "note": "normalize postal code",
        "regex": true
    },
    {
        "tokens": [
            "$1$2",
            "([A-Z]\\d[A-Z]) ?(\\d[A-Z]\\d)"
        ],
        "full": "([A-Z]\\d[A-Z]) ?(\\d[A-Z]\\d)",
        "canonical": "$1$2",
        "onlyCountries": ["ca"],
        "onlyLayers": ["address"],
        "spanBoundaries": 1,
        "note": "normalize postal code",
        "regex": true
    }
]
