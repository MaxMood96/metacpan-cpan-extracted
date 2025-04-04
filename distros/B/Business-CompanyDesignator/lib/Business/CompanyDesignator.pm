package Business::CompanyDesignator;

# Require perl 5.010 because the 'track' functionality of Regexp::Assemble
# is unsafe for earlier versions.
use 5.010001;
use Moose;
use utf8;
use warnings qw(FATAL utf8);
use FindBin qw($Bin);
use YAML;
use File::ShareDir qw(dist_file);
use List::MoreUtils qw(uniq);
use Regexp::Assemble;
use Unicode::Normalize;
use Carp;

use Business::CompanyDesignator::Record;
use Business::CompanyDesignator::SplitResult;

our $VERSION = '0.17';

# Hardcode the set of languages that we treat as 'continuous'
# i.e. their non-ascii designators don't require a word break
# before/after.
our %LANG_CONTINUA = map { $_ => 1 } qw(
  zh
  ja
  ko
);

has 'datafile' => ( is => 'ro', default => sub {
  # Development/test version
  my $local_datafile = "$Bin/../share/company_designator_dev.yml";
  return $local_datafile if -f $local_datafile;
  $local_datafile = "$Bin/../share/company_designator.yml";
  return $local_datafile if -f $local_datafile;
  # Installed version
  return dist_file('Business-CompanyDesignator', 'company_designator.yml');
});

# data is the raw dataset as loaded from datafile, keyed by long designator
has data => ( is => 'ro', lazy_build => 1 );

# regex_cache is a cache of regexes by language and type, since they're expensive to build
has 'regex_cache' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

# abbr_long_map is a hash mapping abbreviations (strings) back to an arrayref of
# long designators (since abbreviations are not necessarily unique)
has 'abbr_long_map' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# pattern_string_map is a hash mapping patterns back to their source string,
# since we do things like add additional patterns without diacritics
has 'pattern_string_map' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
# pattern_string_map_lang is a hash of hashes, mapping language codes to hashes
# of patterns back to their source string
has 'pattern_string_map_lang' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

sub _build_data {
  my $self = shift;
  YAML::LoadFile($self->datafile);
}

sub _build_abbr_long_map {
  my $self = shift;
  my $map = {};
  while (my ($long, $entry) = each %{ $self->data }) {
    if (my $abbr = $entry->{abbr_std}) {
      $map->{$abbr} ||= [];
      push @{ $map->{$abbr} }, $long;
    }
    my $abbr_list = $entry->{abbr} or next;
    $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
    for my $abbr (@$abbr_list) {
      $map->{$abbr} ||= [];
      push @{ $map->{$abbr} }, $long;
    }
  }
  return $map;
}

sub long_designators {
  my $self = shift;
  sort keys %{ $self->data };
}

sub abbreviations {
  my $self = shift;
  sort keys %{ $self->abbr_long_map };
}

sub designators {
  my $self = shift;
  sort $self->long_designators, $self->abbreviations;
}

# Return the B::CD::Record for $long designator
sub record {
  my ($self, $long) = @_;
  my $entry = $self->data->{$long}
    or croak "Invalid long designator '$long'";
  return Business::CompanyDesignator::Record->new( long => $long, record => $entry );
}

# Return a list of B::CD::Records for $designator
sub records {
  my ($self, $designator) = @_;
  croak "Missing designator" if ! $designator;
  if (exists $self->data->{$designator}) {
    return ( $self->record($designator) );
  }
  elsif (my $long_set = $self->abbr_long_map->{$designator}) {
    return map { $self->record($_) } @$long_set
  }
  else {
    croak "Invalid designator '$designator'";
  }
}

# Add $string to regex assembler
sub _add_to_assembler {
  my ($self, $assembler, $lang, $string, $reference_string) = @_;
  $reference_string ||= $string;
# printf "+ add_to_assembler (%s): '%s' => '%s'\n", join(',', @{ $lang || []}), $string, $reference_string;

  # FIXME: RA->add() doesn't work here because of known quantifier-escaping bugs:
  # https://rt.cpan.org/Public/Bug/Display.html?id=50228
  # https://rt.cpan.org/Public/Bug/Display.html?id=74449
  # $assembler->add($string)
  # Workaround by lexing and using insert()
  my $optional1 = '\\.?,?\\s*';
  my @pattern = map {
    # Periods are treated as optional literals, with optional trailing commas and/or whitespace
    /\./   ? $optional1 :
    # Embedded spaces can be multiple, and include leading commas
    / /    ? ',?\s+' :
    # Escape other regex metacharacters
    /[()]/ ? "\\$_" : $_
  } split //, $string;
  $assembler->insert(@pattern);

  # Also add pattern => $string mapping to pattern_string_map and pattern_string_map_lang
  my $pattern_string = join '', @pattern;

  # Special case - optional match characters can cause clashes between
  # distinct pattern_strings e.g. /A\.?,?\s*S\.?,?\s*/ clashes with /AS/
  # We need to handle such cases as ambiguous with extra checks
  my $optional1e = "\Q$optional1\E";
  my $alt_pattern_string1;
  if ($pattern_string =~ /^(\w)(\w)$/) {
    $alt_pattern_string1 = "$1$optional1$2$optional1";
  } elsif ($pattern_string =~ /^(\w)$optional1e(\w)$optional1e$/) {
    $alt_pattern_string1 = "$1$2";
  }

  # If $pattern_string already exists in pattern_string_map then the pattern is ambiguous
  # across entries, and we can't unambiguously map back to a standard designator
  if (exists $self->pattern_string_map->{ $pattern_string }) {
    my $current = $self->pattern_string_map->{ $pattern_string };
    if ($current && $current ne $reference_string) {
      # Reset to undef to mark ambiguity
      $self->pattern_string_map->{ $pattern_string } = undef;
    }
  }
  # Also check for the existence of $alt_pattern_string1, since this is also an ambiguity
  elsif ($alt_pattern_string1 && exists $self->pattern_string_map->{ $alt_pattern_string1 }) {
    my $current = $self->pattern_string_map->{ $alt_pattern_string1 };
    if ($current && $current ne $reference_string) {
      # Reset both pairs to undef to mark ambiguity
      $self->pattern_string_map->{ $pattern_string } = undef;
      $self->pattern_string_map->{ $alt_pattern_string1 } = undef;
    }
  }
  else {
    $self->pattern_string_map->{ $pattern_string } = $reference_string;
  }
  if ($lang) {
    for my $l (@$lang) {
      if (exists $self->pattern_string_map_lang->{$l}->{ $pattern_string }) {
        my $current = $self->pattern_string_map_lang->{$l}->{ $pattern_string };
        if ($current && $current ne $reference_string) {
          # Reset to undef to mark ambiguity
          $self->pattern_string_map_lang->{$l}->{ $pattern_string } = undef;
        }
      }
      else {
        $self->pattern_string_map_lang->{$l}->{ $pattern_string } = $reference_string;
      }
    }
  }

  # If $string contains unicode diacritics, also add a version without them for misspellings
  if ($string =~ m/\pM/) {
    my $stripped = $string;
    $stripped =~ s/\pM//g;
    $self->_add_to_assembler($assembler, $lang, $stripped, $reference_string);
  }
}

# Assemble designator regexes
sub _build_regex {
  my $self = shift;
  my ($type, $lang) = @_;

  state $types = { map { $_ => 1 } qw(end end_cont begin) };
  if (! $types->{$type}) {
    croak "invalid regex type '$type'";
  }

  # RA constructor - case insensitive, with match tracking
  my $assembler = Regexp::Assemble->new->flags('i')->track(1);

  # Construct language regex if $lang is set
  my $lang_re;
  if ($lang) {
    $lang = [ $lang ] if ! ref $lang;
    my $lang_str = join '|', sort @$lang;
    $lang_re = qr/^($lang_str)$/;
  }

  my $count = 0;
  while (my ($long, $entry) = each %{ $self->data }) {
    # If $lang is set, restrict to entries that include $lang
    next if $lang_re && $entry->{lang} !~ $lang_re;
    # If $type is 'begin', restrict to 'lead' entries
    next if $type eq 'begin' && ! $entry->{lead};
    # if $type is 'end_cont', restrict to languages in %LANG_CONTINUA
    next if $type eq 'end_cont' && ! $LANG_CONTINUA{$entry->{lang}};

    $count++;
    my $long_nfd = NFD($long);
    $self->_add_to_assembler($assembler, $lang, $long_nfd);

    # Add all abbreviations
    if (my $abbr_list = $entry->{abbr}) {
      $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
      for my $abbr (@$abbr_list) {
        # Only treat non-ascii abbreviations as continuous
        next if $type eq 'end_cont' && $abbr =~ /^\p{ASCII}+$/;
        my $abbr_nfd = NFD($abbr);
        my $abbr_std = NFD($entry->{abbr_std} || $abbr);
        $self->_add_to_assembler($assembler, $lang, $abbr_nfd, $abbr_std);
      }
    }
  }

  # If no entries found (a strange/bogus language?), return undef
  return if $count == 0;

  return wantarray ? ( $assembler->re, $assembler ) : $assembler->re;
}

# Regex accessor, returning regexes by type (begin/end) and language (en, es, etc.)
# $type defaults to 'end', $lang defaults to undef (for all)
sub regex {
  my $self = shift;
  my ($type, $lang) = @_;
  $type ||= 'end';

  # $lang might be an arrayref containing multiple language codes
  my $lang_key;
  if ($lang) {
    $lang_key = $lang;
    if (ref $lang && ref $lang eq 'ARRAY' && @$lang) {
      if (@$lang == 1) {
        $lang_key = $lang->[0];
      }
      else {
        $lang_key = join '_', sort map { lc $_ } @$lang;
      }
    }
  }

  my $cache_key = $type;
  $cache_key .= "_$lang_key" if $lang_key;

  if (my $entry = $self->regex_cache->{ $cache_key }) {
    return wantarray ? @$entry : $entry->[0];
  }

  my ($re, $assembler) = $self->_build_regex($type, $lang);
  $self->regex_cache->{ $cache_key } = [ $re, $assembler ];
  return wantarray ? ( $re, $assembler ) : $re;
}

# Helper to return split_designator results
sub _split_designator_result {
  my $self = shift;
  my ($lang, $before, $des, $after, $matched_pattern) = @_;

  # $before can end in whitespace (that we don't want to consume in the RE
  # for technical reasons around handling punctuation like '& Co' in designators)
  # So trim here to handle that case.
  $before =~ s/\s+$// if $before;

  my $des_std;
  if ($matched_pattern) {
    $des_std = $self->pattern_string_map_lang->{$lang}->{$matched_pattern} if $lang;
    $des_std ||= $self->pattern_string_map->{$matched_pattern};
    if ($des_std) {
      # Always coalesce spaces and delete commas from $des_std
      $des_std =~ s/,+/ /g;
      $des_std =~ s/\s\s+/ /g;
    }
  }

  # Legacy interface - return a simple before / des / after tuple, plus $des_std
  return map { defined $_ && ! ref $_ ? NFC($_) : '' } ($before, $des, $after, $des_std)
    if wantarray;

  # New scalar-context interface - return SplitResult object
  Business::CompanyDesignator::SplitResult->new(
    before          => NFC($before // ''),
    designator      => NFC($des // ''),
    designator_std  => NFC($des_std // ''),
    after           => NFC($after // ''),
    records         => [ $des_std ? $self->records(NFC $des_std) : () ],
  );
}

# Split $company_name on (the first) company designator, returning a triplet of strings:
# ($before, $designator, $after), plus the normalised form of the designator. If no
# designator is found, just returns ($company_name).
# e.g. matching "ABC Pty Ltd" would return "Pty Ltd" for $designator, but "Pty. Ltd." for
# the normalised form, and "Accessoires XYZ Ltee" would return "Ltee" for $designator,
# but "Ltée" for the normalised form
sub split_designator {
  my $self = shift;
  my ($company_name, %arg) = @_;
  my $lang = $arg{lang};
  my $allow_embedded = $arg{allow_embedded};
  $allow_embedded //= 1;    # backwards-compatibility, unfortunately
  my $company_name_match = NFD($company_name);

  # Handle older perls without XPosixPunct
  state $punct_class = eval { '.' =~ m/\p{XPosixPunct}/ } ?
                       '[\s\p{XPosixPunct}]' :
                       '[\s[:punct:]]';

  # Strip all brackets for continuous language matching
  (my $company_name_match_cont_stripped = $company_name_match) =~ s/[()\x{ff08}\x{ff09}]//g;

  my ($end_re, $end_asr, $end_cont_re, $end_cont_asr, $begin_re, $begin_asr);
  if ($lang) {
    if ($LANG_CONTINUA{$lang}) {
      ($end_cont_re, $end_cont_asr) = $self->regex('end_cont', $lang);
    } else {
      ($end_re,      $end_asr)      = $self->regex('end',      $lang);
    }
    ($begin_re,    $begin_asr)      = $self->regex('begin',    $lang);
  } else {
    ($end_re,      $end_asr)      = $self->regex('end');
    ($end_cont_re, $end_cont_asr) = $self->regex('end_cont');
    ($begin_re,    $begin_asr)    = $self->regex('begin');
  }

  # Designators are usually final, so try $end_re first
  if ($end_re &&
      $company_name_match =~ m/^\s*(.*?)${punct_class}\s*\(?($end_re)\)?\s*$/) {
    return $self->_split_designator_result($lang, $1, $2, undef, $end_asr->source($^R));
  }

  # No final designator - retry without a word break for the subset of languages
  # that use continuous scripts (see %LANG_CONTINUA above)
  if ($end_cont_re &&
      $company_name_match_cont_stripped =~ m/^\s*(.*?)\(?($end_cont_re)\)?\s*$/) {
    return $self->_split_designator_result($lang, $1, $2, undef, $end_cont_asr->source($^R));
  }

  # No final designator - check for a lead designator instead (e.g. RU, NL, etc.)
  if ($begin_re &&
      $company_name_match =~ m/^\s*\(?($begin_re)\)?${punct_class}\s*(.*?)\s*$/) {
    return $self->_split_designator_result($lang, undef, $1, $2, $begin_asr->source($^R));
  }

  # No final or initial - check for an embedded designator with trailing content
  if ($end_re && $allow_embedded &&
      $company_name_match =~ m/(.*?)${punct_class}\s*\(?($end_re)\)?(?:\s+(.*?))?$/) {
    return $self->_split_designator_result($lang, $1, $2, $3, $end_asr->source($^R));
  }

  # No match - return $company_name unchanged
  return $self->_split_designator_result($lang, $company_name);
}

1;

__END__

=encoding utf-8

=head1 NAME

Business::CompanyDesignator - module for matching and stripping/manipulating the
company designators appended to company names

=head1 VERSION

Version: 0.17.

This module is considered a B<BETA> release. Interfaces may change and/or break
without notice until the module reaches version 1.0.

=head1 SYNOPSIS

Business::CompanyDesignator is a perl module for matching and stripping/manipulating
the typical company designators appended (or sometimes, prepended) to company names.
It supports both long forms (e.g. Corporation, Incorporated, Limited etc.) and
abbreviations (e.g. Corp., Inc., Ltd., GmbH etc).

  use Business::CompanyDesignator;

  # Constructor
  $bcd = Business::CompanyDesignator->new;
  # Optionally, you can provide your own company_designator.yml file, instead of the bundled one
  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

  # Get lists of designators, which may be long (e.g. Limited) or abbreviations (e.g. Ltd.)
  @des = $bcd->designators;
  @long = $bcd->long_designators;
  @abbrev = $bcd->abbreviations;

  # Lookup individual designator records (returns B::CD::Record objects)
  # Lookup record by long designator (unique)
  $record = $bcd->record($long_designator);
  # Lookup records by abbreviation or long designator (may not be unique)
  @records = $bcd->records($designator);

  # Get a regex for matching designators by type ('end'/'begin') and lang
  # By default, returns 'end' regexes for all languages
  $re = $bcd->regex;
  $company_name =~ $re and say 'designator found!';
  $company_name =~ /$re\s*$/ and say 'final designator found!';
  my $re_begin_en = $bcd->regex('begin', 'en');

  # Split $company_name on designator, returning a ($before, $designator, $after) triplet,
  # plus the normalised form of the designator matched (can pass to records(), for example)
  ($before, $des, $after, $normalised_des) = $bcd->split_designator($company_name);

  # Or in scalar context, return a L<Business::CompanyDesignator::SplitResult> object
  $res = $bcd->split_designator($company_name, lang => 'en');
  print join ' / ', $res->designator_std, $res->short_name, $res->extra;


=head1 DATASET

Business::CompanyDesignator uses the company designator dataset from here:

  L<https://github.com/ProfoundNetworks/company_designator>

which is bundled with the module. You can use your own (updated or custom)
version, if you prefer, by passing a 'datafile' parameter to the constructor.

The dataset defines multiple long form designators (like "Company", "Limited",
or "Incorporée"), each of which have zero or more abbreviations (e.g. 'Co.',
'Ltd.', 'Inc.' etc.), and one or more language codes. The 'Company' entry,
for instance, looks like this:

  Company:
    abbr:
      - Co.
      - '& Co.'
      - and Co.
      - and Company
    lang: en

Long designators are unique across the dataset, but abbreviations are not
e.g. 'Inc.' is used for both "Incorporated" and French "Incorporée".

=head1 METHODS

=head2 new()

Creates a Business::CompanyDesignator object.

  $bcd = Business::CompanyDesignator->new;

By default this uses the bundled company_designator dataset. You may
provide your own (updated or custom) version by passing via a 'datafile'
parameter to the constructor.

  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

=head2 designators()

Returns the full list of company designator strings from the dataset
(both long form and abbreviations).

  @designators = $bcd->designators;

=head2 long_designators()

Returns the full list of long form designators from the dataset.

  @long = $bcd->long_designators;

=head2 abbreviations()

Returns the full list of abbreviation designators from the dataset.

  @abbrev = $bcd->abbreviations;

=head2 record($long_designator)

Returns the Business::CompanyDesignator::Record object for the given
long designator (and dies if not found).

=head2 records($designator)

Returns a list of Business::CompanyDesignator::Record objects for the
given abbreviation or long designator (for long designators there will
only be a single record returned, but abbreviations may map to multiple
records).

Use this method for abbreviations, or if you're aren't sure of a
designator's type.

=head2 regex([$type], [$lang])

Returns a regex for all matching designators for $type ('begin'/'end') and
$lang (iso 639-1 language code e.g. 'en', 'es', de', etc.) from the dataset.
$lang may be either a single language code scalar, or an arrayref of language
codes, for multiple alternative languages. The returned regex is case-insensitive
and non-anchored.

$type defaults to 'end', so without parameters regex() returns a regex
matching all designators for all languages.

=head2 split_designator($company_name, [lang => $lang], [allow_embedded => $bool])

Attempts to split $company_name on (the first) company designator found.

In array context split_designator returns a list of four items - a triplet of
strings from $company_name ( $before, $designator, $after ), plus the
standardised version of the designator as a fourth element.

  ($short_name, $des, $after_text, $des_std) = $bcd->split_designator($company_name);

In scalar context split_designator returns a L<Business::CompanyDesignator::SplitResult>
object.

  $res = $bcd->split_designator($company_name, lang => $lang);

The $des designator in array context, and the SplitResult $res->designator
is the designator text as it matched in $company_name, while the array context
$des_std, and the SplitResult $res->designator_std is the standardised version
as found in the dataset.

For instance, "ABC Pty Ltd" would return "Pty Ltd" as the $designator, but
"Pty. Ltd." as the stardardised form, and the latter would be what you
would find in designators() or would lookup with records(). Similarly,
"Accessoires XYZ Ltee" (without the french acute) would match, returning
"Ltee" (as found) for the $designator, but "Ltée" (with the acute) as the
standardised form.

split_designator accepts the following optional (named) parameters:

=over 4

=item lang => $lang

$lang can be a scalar ISO 639-1 language code ('en', 'fr', 'cn', etc.), or an
arrayref containing multiple language codes. If $lang is defined, split_designator
will only match designators for the specified set of languages, which can improve
the accuracy of the split by reducing false positive matches.

=item allow_embedded => $boolean

allow_embedded is a boolean indicating whether or not designators can occur in
the middle of strings, instead of only at the beginning or end. Defaults to true,
for backwards compatibility, which yields more matches, but also more false
positives. Setting to false is safer, but yields fewer matches (and embedded
designators do occur surprisingly often in the wild.)

For more discussion, see L<AMBIGUITIES> below.

=back

=head2 AMBIGUITIES

Note that split_designator does not always get the split right. It checks for
final designators first, then leading ones, and then finally looks for embedded
designators (if allow_embedded is set to true).

Leading and trailing designators are usually reasonably accurate, but embedded
designators are problematic. For instance, embedded designators allow names like
these to split correctly:

    Amerihealth Insurance Company of NJ
    Trenkwalder Personal AG Schweiz
    Vicente Campano S L (COMERCIAL VICAM)
    Gvozdika, gostinitsa OOO ""Eko-Treyd""

but it will also wrongly split names like the following:

    XYZ PC Repairs ('PC' is a designator meaning 'Professional Corporation')
    Dr S L Ledingham ('S L' is a Spanish designator for 'Sociedad Limitada')

If you do want to allow splitting on embedded designators, you might want to pass
a 'lang' parameter to split_designator if you know the language(s) used for your
company names, as this will reduce the number of false positives by restricting the
set of designators matched against. It won't eliminate the issue altogether though,
so some post-processing might be required. (And I'd love to hear of ideas on how
to improve this.)

=head1 SEE ALSO

Finance::CompanyNames

=head1 AUTHOR

Gavin Carr <gavin@profound.net>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2013-2021 Gavin Carr

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
