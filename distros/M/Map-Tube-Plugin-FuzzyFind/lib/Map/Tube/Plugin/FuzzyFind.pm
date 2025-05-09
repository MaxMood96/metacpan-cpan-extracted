# -*- perl -*-
#
# Author: Gisbert W. Selke, TapirSoft Selke & Selke GbR.
#
# Copyright (C) 2015, 2025 Gisbert W. Selke. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: gws@cpan.org
#
package Map::Tube::Plugin::FuzzyFind;

use 5.10.0;
use version 0.77 ( );
use strict;
use warnings;

our $VERSION = version->declare('v0.81.2');

=head1 NAME

Map::Tube::Plugin::FuzzyFind - Map::Tube add-on for finding stations and lines by inexact name.

=head1 VERSION

Version 0.81.0

=cut

use 5.010;
use Carp;
use Moo::Role;
use namespace::clean;
use Try::Tiny;

=head1 DESCRIPTION

This is an add-on for L<Map::Tube> to find stations and lines by name, possibly
partly or inexactly specified. The module is a Moo role which gets plugged into the
Map::Tube::* family automatically once it is installed.


=head1 SYNOPSIS

    use strict; use warnings;
    use Map::Tube::London;

    my $tube = Map::Tube::London->new();

    print 'line matches exactly: ',
      scalar(    $tube->fuzzy_find(   search  => 'erloo',
                                      objects => 'lines' ) ), "\n";
    print 'line contains       : ',
      scalar(    $tube->fuzzy_find(   search  => 'erloo',
                                      objects => 'lines',
                                      method  => 'in' ) ), "\n";
    print 'same thing          : ',
      scalar(    $tube->fuzzy_find(              'erloo',
                                      objects => 'lines',
                                      method  => 'in' ) ), "\n";
    print 'same thing          : ',
      scalar(    $tube->fuzzy_find( { search  => 'erloo',
                                      objects => 'lines',
                                      method  => 'in' } ) ), "\n";
    print 'station re          : ',
      join( ' ', $tube->fuzzy_find(   search  => qr/[htrv]er/i,
                                      objects => 'stations' ) ), "\n";
    print 'station re          : ',
      join( ' ', $tube->fuzzy_find(   search  => '[htrv]er',
                                      objects => 'stations',
                                      method  => 'regex' ) ), "\n";
    print 'line fuzzy          : ',
      scalar(    $tube->fuzzy_find(   search  => 'Kyrkle',
                                      objects => 'stations',
                                      method  => 'levenshtein' ) ), "\n";


=head1 METHODS

=head2 fuzzy_find(%args)

Find a tube line or station by some pattern, which may be partly or
inexactly specified. In array context, a (possibly empty) array of
Map::Tube::{Line,Node} objects is returned that match the pattern. If
the matching method employed provides a measure of similarity, the
result set will be ordered by decreasing similarity. Otherwise, it will
be ordered alphabetically. In scalar context, a Map::Tube::{Line,Node}
object (or undef) is returned. In the case of more than one match, the
most similar or the alphabetically first match will be returned, as
applicable to the matching method.

C<%args> is a hash of optional named parameters to guide actions. It may
be specified as a hash or as a reference to a hash. For convenience, the
search pattern may be specified as the first argument, outside the hash.
While formally all arguments are optional, not specifying a search
pattern will, predictably, not produce any exciting result.

=over 4

=item search=...

The pattern to be searched for. It may be a string or a (possibly
precompiled) regular expression. The latter requires the matching
method (cf. below) to be C<'regex'>.

=item objects=...

This specifies whether stations or lines should be found. The value should
be either C<'lines'> or C<'stations'>. (C<'nodes'> is a synonym for
C<'stations'>.) If it is none of these, then both lines and stations will
be searched.

=item method=...

The method for matching. If this parameter is missing, the default is to
use C<'regex'> if the pattern is a precompiled regex, or C<'exact'>
otherwise. Otherwise, the value should be one of the following.

=over 4

=item 'exact'

Exact matching will be performed (up to case). This is also the default
method if only a search string (without any further arguments) is supplied.

=item 'start'

The given string pattern must match at the beginning of the line or station
name (up to case).

=item 'in'

The given string pattern must match somewhere within the line or station
name (up to case).

=item 're' or 'regex'

The given pattern is matched as a regex (case-insensitively) against the
line or station names. The pattern may also be specified as a precompiled
regex. In this case, its case sensitivity will be used unaltered.

=item 'soundex'

All names matching according to the soundex algorithm
(see L<Text::Soundex>) will be returned. Actually, a variant of Donald E. Knuth's
original algorithm is used which also tries to cope with non-ASCII characters.
It works well only for English-like words.

=item 'phonix'

All names matching according to the phonix algorithm
(see L<Text::Phonetic::Phonix>) will be returned. This is an alternative to soundex.

=item 'daitchmokotoff' or 'dmsoundex'

All names matching according to the Daitch-Motokoff algorithm
(see L<Text::Phonetic::DaitchMotokoff>) will be returned. This alternative to soundex
may be preferable for Slavic and Yiddish names.

=item 'koeln'

All names matching according to the Koeln phonetic encoding
(see L<Text::Phonetic::Koeln>) will be returned. This alternative to soundex
may work better for German names, as well as for longer names.

=item 'metaphone'

All names matching according to the Metaphone algorithm
(see L<Text::Metaphone>) will be returned. This is a method that strives to be
"a modern version of soundex". It is also tuned towards English words.

=item 'doublemetaphone'

All names matching according to the DoubleMetaphone algorithm
(see L<Text::DoubleMetaphone>) will be returned. This was developped as an improvement
on Metaphone.

=item 'levenshtein' or 'editdistance'

The closest names as calculated by the Levenshtein edit distance
(see L<Text::Levenshtein>) will be returned.

=item 'levenshteindamerau' or 'damerau'

The closest names as calculated by the Levenshtein-Damerau edit distance
(see L<Text::Levenshtein::Damerau>) will be returned. This is an
alternative to the edit distance defined by Levenshtein.

=item 'jarowinkler'

The closest names as calculated by the Jaro-Winkler edit distance (see
L<Text::JaroWinkler>) will be returned. This is an alternative to the
edit distance defined by Levenshtein.

=item 'ngram'

The closest names as calculated by a comparison of trigrams
(see L<String::Trigram>) will be returned. (Future versions may include
n-grams for n other than 3).

=item 'fuzzy'

Currently, this is a synonym for C<'levenshtein'>.
I<This may change in the future.>

=item a code ref

Reserved for future use.

=item ...

Further fuzzy matchers may be added in the future according to interest.

=back

=item maxdist=...

For some matchers that define a metric on strings (like Levenshtein),
this may specify the maximum allowable distance from the pattern specified.
The default is half the length of the pattern. If 0 is specified, no
limit will be applied. Note that, in array context, this may result in a large
number of returned values. In scalar context, a non-null value (including the
default value) may lead to no result being returned.

=item maxsize=...

In array context, this may be used to specify the maximum number of values
to return, in order to prevent flooding. There is no default. If 0 is specified,
no limit will be applied. In scalar context, this parameter is disregarded.

=item maxcodelen=...

(Used only for Metaphone) The original definition of the Metaphone algorithm uses
a maximum of 4 characters for the encoded strings (just like Soundex). 4 is
also used here by default. This parameter allows to set other values.


=back

=cut

# Note: The code comes on purpose in just one sub, in order to prevent
# name space pollution of Map::Tube::xxx. Other solutions are possible,
# but currently it is felt they would introduce more hassle than clarity.


sub fuzzy_find {    ## no critic(Subroutines::ProhibitExcessComplexity)
  my( $self, @tmpargs ) = @_;
  my( %args, $pattern );

  # *** This needs to be re-organised into a hash with pointers to methods.
  my %methods = ( exact 			 =>  1,
				  start 			 =>  2,
				  in				 =>  3,
				  regex 			 =>  4,
				  re				 =>  4,
				  soundex			 =>  5,
				  phonix			 =>  6,
				  daitchmokotoff	 =>  7,
				  dmsoundex 		 =>  7,
				  koeln 			 =>  8,
				  metaphone 		 =>  9,
				  doublemetaphone	 => 10,
				  phonem			 => 11,
				  levenshtein		 => 12,
				  editdistance		 => 12,
				  fuzzy 			 => 12,
				  damerau			 => 13,
				  levenshteindamerau => 13,
				  jarowinkler		 => 14,
				  ngrams			 => 15,
                );
  my $maxmethod = ( sort { $b <=> $a } values %methods )[0];

  # unify the different ways of passing arguments:
  if ( scalar(@tmpargs) == 1 ) {
    if ( ref( $tmpargs[0] ) eq 'HASH' ) {

      # everything in just one hash ref.
      %args    = %{ $tmpargs[0] };
      $pattern = $args{search};
    } else {

      # must be a lone string or regex, with no other args
      $pattern = $tmpargs[0];
    }
  } elsif ( ( scalar(@tmpargs) == 2 ) && ( ref( $tmpargs[1] ) eq 'HASH' ) ) {

    # Pattern plus hash ref
    %args    = %{ $tmpargs[1] };
    $pattern = $tmpargs[0];        # bad luck if conflicting specs...
  } elsif ( scalar(@tmpargs) % 2 ) {

    # odd number of args >= 3. Must be pattern plus hash
    $pattern = shift(@tmpargs);
    %args    = @tmpargs;
  } else {

    # Even number of args >= 2. This must be a real hash.
    %args    = @tmpargs;
    $pattern = $args{search};
  } ## end else [ if ( scalar(@tmpargs) ...)]

  return unless defined $pattern;

  # Now all args are in the non-empty %args hash, and we know what to search for.
  $args{objects}	||= '';
  $args{objects}	  = 'stations' if ( $args{objects} eq 'nodes' );
  $args{maxsize}	||= 0;
  $args{maxcodelen} //= 4; # used only for Metaphone, optionally
  $args{method} 	||= ( ref( $args{search} ) eq 'Regexp' ) ? 'regex' : 'exact';

  # Procure the list of things in which to search
  my $source;
  if ( $args{objects} eq 'lines' ) {
    $source = $self->get_lines();
  } elsif ( $args{objects} eq 'stations' ) {
    $source = [ values %{ $self->nodes() } ];
  } else {
    $source = [ @{ $self->get_lines() }, values %{ $self->nodes() } ];
  }

  # Find the numerical index of the method which we should use:
  $args{method} ||= 'exact';
  my $nmethod = $methods{ lc( $args{method} ) } // -1;

  my @result;
  if ( $nmethod == 1 ) {    ## no critic(ControlStructures::ProhibitCascadingIfElse)

    # Exact matching (up to case)
    $pattern = lc($pattern);
    @result  = sort { $a->name() cmp $b->name() } grep { lc( $_->name() ) eq $pattern } @{$source};
  } elsif ( $nmethod == 2 ) {

    # Match at start
    $pattern = lc($pattern);
    @result  = sort { $a->name() cmp $b->name() } grep { index( lc( $_->name() ), $pattern ) == 0 } @{$source};
  } elsif ( $nmethod == 3 ) {

    # Match some substring
    $pattern = lc($pattern);
    @result  = sort { $a->name() cmp $b->name() } grep { index( lc( $_->name() ), $pattern ) >= 0 } @{$source};
  } elsif ( $nmethod == 4 ) {

    # Match regex
    $pattern = qr/$pattern/i unless ref($pattern) eq 'Regexp';
    @result  = sort { $a->name() cmp $b->name() } grep { $_->name() =~ $pattern } @{$source};
  } elsif ( ( $nmethod >= 5 ) && ( $nmethod <= $maxmethod ) ) {

    # Use some well-known fuzzy matcher
    # *** This needs to be cleaned up.
    my( $module, $loaded, $matcher );
    $pattern = lc($pattern);
    $pattern =~ s/\s+//g;
    try {
      if ( $nmethod == 5 ) {

        # Knuth's soundex, or some variant thereof, adapted for non-ASCII codes.
        $module = 'Text::Soundex';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
        my $pattern_soundex = Text::Soundex::soundex_unicode($pattern);
        $matcher = sub {
          return ( Text::Soundex::soundex_unicode( $_[0] ) eq $pattern_soundex ) ? 0 : 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
      } elsif ( $nmethod == 6 ) {

		# Phonix, (claiming to be) "an improved Soundex". This variant keeps the first letter (like original Soundex).
		$module = 'Text::Phonetic::Phonix';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $obj = Text::Phonetic::Phonix->new( );
		my $pattern_metacode = $obj->encode($pattern);
        $matcher = sub {
		  return ( $obj->encode( $_[0] ) eq $pattern_metacode ) ? 0 : 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 7 ) {

		# Daitch-Mokotoff Soundex, a Soundex variant geared towards Slavic and Yiddish.
		$module = 'Text::Phonetic::DaitchMokotoff';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $obj = Text::Phonetic::DaitchMokotoff->new( );
		my @pattern_metacodes = @{ $obj->encode($pattern) };
		# Daitch-Mokotoff returns up to two values. Results are always returned as an Arrayref.
        $matcher = sub {
		  for my $strcode( @{ $obj->encode( $_[0] ) } ) {
			for ( @pattern_metacodes ) {
			  return 0 if ( $_ eq $strcode );
			}
		  }
		  return 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 8 ) {

		# "Koeln Phonetic", a Soundex variant geared towards German. Also towards longer words.
		$module = 'Text::Phonetic::Koeln';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $obj = Text::Phonetic::Koeln->new( );
		my $pattern_metacode = $obj->encode($pattern);
        $matcher = sub {
		  return ( $obj->encode( $_[0] ) eq $pattern_metacode ) ? 0 : 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 9 ) {

        # Metaphone, (claiming to be) "A modern Soundex". Still with a slant towards English pronunciation.
        $module = 'Text::Metaphone';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $maxcodelen = $args{maxcodelen};
		my $pattern_metacode = Text::Metaphone::Metaphone($pattern, $maxcodelen);
        $matcher = sub {
		  return ( Text::Metaphone::Metaphone( $_[0], $maxcodelen ) eq $pattern_metacode ) ? 0 : 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 10 ) {

		# DoubleMetaphone, an improved Metaphone, better taking into account several non-English languages.
		# Note: There may be up to two encodings for each input.
		$module = 'Text::DoubleMetaphone';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my @pattern_metacodes = Text::DoubleMetaphone::double_metaphone($pattern);
        $matcher = sub {
		  for my $strcode( Text::DoubleMetaphone::double_metaphone( $_[0] ) ) {
			for ( @pattern_metacodes ) {
			  return 0 if ( $_ eq $strcode );
			}
		  }
		  return 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 11 ) {

		# Phonem, a Soundex-analogue better taking into account Germanic lanuages (and their penchant for long words)
		$module = 'Text::Phonetic::Phonem';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $obj = Text::Phonetic::Phonem->new( );
		my $pattern_metacode = $obj->encode($pattern);
        $matcher = sub {
		  return ( $obj->encode( $_[0] ) eq $pattern_metacode ) ? 0 : 1;
        };
        $args{maxdist} = 0.5;    # so that exactly the matches will be retained in the map - sort - grep.
	  } elsif ( $nmethod == 12 ) {

        # Levenshtein edit distance
		$module = 'Text::Levenshtein::XS';
        $loaded = eval qq{ require $module; 1 };
		if ($loaded) {
		  $matcher = sub { Text::Levenshtein::XS::distance( $_[0], $pattern ) };
		} else {
		  $module = 'Text::Levenshtein';
		  $loaded = eval qq{ require $module; 1 };
		  croak unless $loaded;
		  $matcher = sub { Text::Levenshtein::distance( $_[0], $pattern ) };
		}
		$args{maxdist} ||= int( ( length($pattern) + 1.000001 ) / 2 );
	  } elsif ( $nmethod == 13 ) {

		# Levenshtein-Damerau edit distance: almost the same as Levenshtein, but also counts adjacent swaps as one operation
		$module = 'Text::Levenshtein::Damerau::XS';
        $loaded = eval qq{ require $module; 1 };
		if ($loaded) {
		  $matcher = sub { Text::Levenshtein::Damerau::XS::xs_edistance( $_[0], $pattern ) };
		} else {
		  $module = 'Text::Levenshtein::Damerau';
		  $loaded = eval qq{ require $module; 1 };
		  croak unless $loaded;
		  $matcher = sub { Text::Levenshtein::Damerau::edistance( $_[0], $pattern ) };
		}
		$args{maxdist} ||= int( ( length($pattern) + 1.000001 ) / 2 );
	  } elsif ( $nmethod == 14 ) {

		# Jaro-Winkler string distance.
		# Originally yields a vale between 0 (very far) to 1 (identical).
		# Distances are re-normalized to better fit with Levenshtein value range.
		$module = 'Text::JaroWinkler';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
		my $stretch = 2 * length($pattern);
		$matcher = sub { $stretch * ( 1 - Text::JaroWinkler::strcmp95( $_[0], $pattern, length($_[0]) ) ) };
		$args{maxdist} ||= int( ( length($pattern) + 1.000001 ) / 2);
	  } elsif ( $nmethod == 15 ) {

		# Comparison by number of matching n-grams, by default 3-grams. (Can be changed with the windowsize argument.)
        # This needs to be re-organised so that multiple calls with the same parameters
        # (but different search strings) will re-use the string base (not the search string).
        $module = 'String::Trigram';
        $loaded = eval qq{ require $module; 1 };
        croak unless $loaded;
        $args{maxdist} ||= length($pattern) / 2;
        my %st_args;
        $st_args{minSim}  = 1 - $args{maxdist} / length($pattern);
        $st_args{minSim}  = 0 if ( $st_args{minSim} < 0 );
        $st_args{minSim}  = 1 if ( $st_args{minSim} > 1 );
        $st_args{ngram}   = $args{windowsize} || 3;
        $st_args{warp}    = 2;
        $st_args{cmpBase} = [$pattern];
        my $trigrammer = String::Trigram->new(%st_args);
        $matcher = sub {
          my $str = $_[0];
          $str =~ s/\s+//g;
          my %result;
          my $nresults = $trigrammer->getSimilarStrings( $str, \%result );
          return $nresults ? ( ( 1 - $result{$pattern} ) * length($pattern) ) : ( length($pattern) + 1 );
        };
	  } ## end elsif ( $nmethod == 15 )
    } ## end try
    catch {
      croak "Matcher module $module not loaded or not executed: $_";
    };

    # $matcher is now a coderef that takes one argument, viz., a string to match.
    # It returns the distance from the pattern; the bigger the distance, the more dissimilar.
    # In case of matchers that provide just a "match/no match" information,
    # 0 means "match" and 1 means "no match".

	my %name2obj = map { $_->name( ) => $_ } @{ $source };

    my %distance = map { $_ => $matcher->( lc($_) ) } keys %name2obj;
    @result = map { $name2obj{$_} }
      sort { ( $distance{$a} <=> $distance{$b} ) || ( $a cmp $b ) }
      grep { ( $args{maxdist} <= 0 )             || ( $distance{$_} <= $args{maxdist} ) } keys %distance;
  } else {

    # nada
	croak "Unknown matching method '$args{method}'";
  }

  if (wantarray) {
    return @result if ( ( $args{maxsize} == 0 ) || ( scalar(@result) <= $args{maxsize} ) );
    return @result[ 0 .. ( $args{maxsize} - 1 ) ];
  }

  return unless @result;
  return $result[0];
} ## end sub fuzzy_find

=head1 AUTHOR

Gisbert W. Selke, TapirSoft Selke & Selke GbR, C<< <gws at cpan.org> >>

=head1 SEE ALSO

L<Map::Tube> and the various Text::* modules referenced above

=head1 CONTRIBUTORS

Thanks to Mohammad S Anwar, author of L<Map::Tube>, for that module, for great feedback,
discussions, advice, debugging help, and willingness to refactor his code.
Thanks to Slaven Rezic for extensive testing and valuable suggestions.

=head1 BUGS

Please report any bugs or feature requests to C<bug-map-tube-plugin-fuzzyfind at rt.cpan.org>,  or
through the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Map-Tube-Plugin-FuzzyFind>.
I will  be notified and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Map::Tube::Plugin::FuzzyFind

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Map-Tube-Plugin-FuzzyFind>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Map-Tube-Plugin-FuzzyFind>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Map-Tube-Plugin-FuzzyFind>

=item * Search CPAN

L<http://search.cpan.org/dist/Map-Tube-Plugin-FuzzyFind/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015, 2025 Gisbert W. Selke, Tapirsoft Selke & Selke GbR

This  program  is  free software; you can redistribute it and/or modify it under
the  terms  of the the Artistic License (2.0). You may obtain a copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;    # End of Map::Tube::Plugin::FuzzyFind
