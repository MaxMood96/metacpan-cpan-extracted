package LTSV::LINQ;
######################################################################
#
# LTSV::LINQ - LINQ-style query interface for LTSV files
#
# https://metacpan.org/dist/LTSV-LINQ
#
# Copyright (c) 2026 INABA Hitoshi <ina@cpan.org>
######################################################################

use 5.00503;    # Universal Consensus 1998 for primetools
# use 5.008001; # Lancaster Consensus 2013 for toolchains

$VERSION = '1.01';
$VERSION = $VERSION;

BEGIN { pop @INC if $INC[-1] eq '.' } # CVE-2016-1238: Important unsafe module load path flaw
use strict;
BEGIN { $INC{'warnings.pm'} = '' if $] < 5.006 } use warnings; local $^W=1;

#---------------------------------------------------------------------
# Constructor and Iterator Infrastructure
#---------------------------------------------------------------------

sub new {
    my($class, $iterator) = @_;
    return bless { iterator => $iterator }, $class;
}

sub iterator {
    return $_[0]->{iterator};
}

#---------------------------------------------------------------------
# Data Source Methods
#---------------------------------------------------------------------

# From - create query from array
sub From {
    my($class, $source) = @_;

    if (ref($source) eq 'ARRAY') {
        my $i = 0;
        return $class->new(sub {
            return undef if $i >= scalar(@$source);
            return $source->[$i++];
        });
    }

    die "From() requires ARRAY reference";
}

# FromLTSV - read from LTSV file
sub FromLTSV {
    my($class, $file) = @_;

    my $fh = do { local *FH; *FH };
    open($fh, "< $file") or die "Cannot open '$file': $!";

    return $class->new(sub {
        while (my $line = <$fh>) {
            chomp $line;
            next unless length $line;

            my %record = map {
                /\A(.+?):(.*)\z/ ? ($1, $2) : ()
            } split /\t/, $line;

            return \%record if %record;
        }
        close $fh;
        return undef;
    });
}

# Range - generate sequence of integers
sub Range {
    my($class, $start, $count) = @_;

    my $current = $start;
    my $remaining = $count;

    return $class->new(sub {
        return undef if $remaining <= 0;
        $remaining--;
        return $current++;
    });
}

#---------------------------------------------------------------------
# Filtering Methods
#---------------------------------------------------------------------

# Where - filter elements
sub Where {
    my($self, @args) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);

    # Support both code reference and DSL form
    my $cond;
    if (@args == 1 && ref($args[0]) eq 'CODE') {
        $cond = $args[0];
    }
    else {
        # DSL form: Where(key => value, ...)
        my %match = @args;
        $cond = sub {
            my $row = shift;
            for my $k (keys %match) {
                return 0 unless defined $row->{$k};
                return 0 unless $row->{$k} eq $match{$k};
            }
            return 1;
        };
    }

    return $class->new(sub {
        while (1) {
            my $item = $iter->();
            return undef unless defined $item;
            return $item if $cond->($item);
        }
    });
}

#---------------------------------------------------------------------
# Projection Methods
#---------------------------------------------------------------------

# Select - transform elements
sub Select {
    my($self, $selector) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);

    return $class->new(sub {
        my $item = $iter->();
        return undef unless defined $item;
        return $selector->($item);
    });
}

# SelectMany - flatten sequences
sub SelectMany {
    my($self, $selector) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);

    my @buffer;

    return $class->new(sub {
        while (1) {
            if (@buffer) {
                return shift @buffer;
            }

            my $item = $iter->();
            return undef unless defined $item;

            my $result = $selector->($item);
            if (ref($result) eq 'ARRAY') {
                @buffer = @$result;
            }
            else {
                return $result;
            }
        }
    });
}

# Concat - concatenate two sequences
sub Concat {
    my($self, $second) = @_;
    my $class = ref($self);

    my $first_iter = $self->iterator;
    my $second_iter;
    my $first_done = 0;

    return $class->new(sub {
        if (!$first_done) {
            my $item = $first_iter->();
            if (defined $item) {
                return $item;
            }
            $first_done = 1;
            $second_iter = $second->iterator;
        }

        return $second_iter ? $second_iter->() : undef;
    });
}

#---------------------------------------------------------------------
# Partitioning Methods
#---------------------------------------------------------------------

# Take - take first N elements
sub Take {
    my($self, $count) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);
    my $taken = 0;

    return $class->new(sub {
        return undef if $taken >= $count;
        my $item = $iter->();
        return undef unless defined $item;
        $taken++;
        return $item;
    });
}

# Skip - skip first N elements
sub Skip {
    my($self, $count) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);
    my $skipped = 0;

    return $class->new(sub {
        while ($skipped < $count) {
            my $item = $iter->();
            return undef unless defined $item;
            $skipped++;
        }
        return $iter->();
    });
}

# TakeWhile - take while condition is true
sub TakeWhile {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);
    my $done = 0;

    return $class->new(sub {
        return undef if $done;
        my $item = $iter->();
        return undef unless defined $item;

        if ($predicate->($item)) {
            return $item;
        }
        else {
            $done = 1;
            return undef;
        }
    });
}

# SkipWhile - skip elements while predicate is true
sub SkipWhile {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);
    my $skipping = 1;

    return $class->new(sub {
        while (1) {
            my $item = $iter->();
            return undef unless defined $item;

            if ($skipping) {
                if (!$predicate->($item)) {
                    $skipping = 0;
                    return $item;
                }
            }
            else {
                return $item;
            }
        }
    });
}

#---------------------------------------------------------------------
# Ordering Methods
#---------------------------------------------------------------------

# OrderBy - sort ascending
sub OrderBy {
    my($self, $key_selector) = @_;
    my @items = $self->ToArray();
    my @sorted = sort {
        my $ka = $key_selector->($a);
        my $kb = $key_selector->($b);
        $ka = '' unless defined $ka;
        $kb = '' unless defined $kb;

        # Smart numeric/string comparison
        # Supports: integers, decimals, negative numbers, exponential notation
        # Handles leading/trailing whitespace
        my $ka_trimmed = $ka;
        my $kb_trimmed = $kb;
        $ka_trimmed =~ s/^\s+|\s+$//g;
        $kb_trimmed =~ s/^\s+|\s+$//g;
        
        if ($ka_trimmed =~ /^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$/ && 
            $kb_trimmed =~ /^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$/) {
            return $ka_trimmed <=> $kb_trimmed;
        }
        else {
            return $ka cmp $kb;
        }
    } @items;

    my $class = ref($self);
    return $class->From(\@sorted);
}

# OrderByDescending - sort descending
sub OrderByDescending {
    my($self, $key_selector) = @_;
    my @items = $self->ToArray();
    my @sorted = sort {
        my $ka = $key_selector->($a);
        my $kb = $key_selector->($b);
        $ka = '' unless defined $ka;
        $kb = '' unless defined $kb;

        # Smart numeric/string comparison
        # Supports: integers, decimals, negative numbers, exponential notation
        # Handles leading/trailing whitespace
        my $ka_trimmed = $ka;
        my $kb_trimmed = $kb;
        $ka_trimmed =~ s/^\s+|\s+$//g;
        $kb_trimmed =~ s/^\s+|\s+$//g;
        
        if ($ka_trimmed =~ /^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$/ && 
            $kb_trimmed =~ /^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$/) {
            return $kb_trimmed <=> $ka_trimmed;
        }
        else {
            return $kb cmp $ka;
        }
    } @items;

    my $class = ref($self);
    return $class->From(\@sorted);
}

# Reverse - reverse order
sub Reverse {
    my($self) = @_;
    my @items = reverse $self->ToArray();
    my $class = ref($self);
    return $class->From(\@items);
}

#---------------------------------------------------------------------
# Grouping Methods
#---------------------------------------------------------------------

# GroupBy - group elements by key
sub GroupBy {
    my($self, $key_selector, $element_selector) = @_;
    $element_selector ||= sub { $_[0] };

    my %groups;
    $self->ForEach(sub {
        my $item = shift;
        my $key = $key_selector->($item);
        $key = '' unless defined $key;
        push @{$groups{$key}}, $element_selector->($item);
    });

    my @result;
    for my $key (sort keys %groups) {
        push @result, {
            Key => $key,
            Elements => $groups{$key},
        };
    }

    my $class = ref($self);
    return $class->From(\@result);
}

#---------------------------------------------------------------------
# Set Operations
#---------------------------------------------------------------------

# Distinct - remove duplicates
sub Distinct {
    my($self, $comparer) = @_;
    my $iter = $self->iterator;
    my $class = ref($self);
    my %seen;

    return $class->new(sub {
        while (1) {
            my $item = $iter->();
            return undef unless defined $item;

            my $key = $comparer ? $comparer->($item) : $item;
            $key = '' unless defined $key;

            unless ($seen{$key}++) {
                return $item;
            }
        }
    });
}

# Internal helper for set operations - make key from item
sub _make_key {
    my($item) = @_;
    
    return '' unless defined $item;
    
    if (ref($item) eq 'HASH') {
        # Hash to stable key
        my @pairs = ();
        for my $k (sort keys %$item) {
            my $v = defined($item->{$k}) ? $item->{$k} : '';
            push @pairs, "$k\x1F$v";  # \x1F = Unit Separator
        }
        return join("\x1E", @pairs);  # \x1E = Record Separator
    }
    elsif (ref($item) eq 'ARRAY') {
        # Array to key
        return join("\x1E", map { defined($_) ? $_ : '' } @$item);
    }
    else {
        # Scalar
        return $item;
    }
}

# Union - set union with distinct
sub Union {
    my($self, $second, $comparer) = @_;
    
    return $self->Concat($second)->Distinct($comparer);
}

# Intersect - set intersection
sub Intersect {
    my($self, $second, $comparer) = @_;
    
    # Build hash of second sequence
    my %second_set = ();
    $second->ForEach(sub {
        my $item = shift;
        my $key = $comparer ? $comparer->($item) : _make_key($item);
        $second_set{$key} = $item;
    });

    my $class = ref($self);
    my $iter = $self->iterator;
    my %seen = ();

    return $class->new(sub {
        while (defined(my $item = $iter->())) {
            my $key = $comparer ? $comparer->($item) : _make_key($item);
            
            next if $seen{$key}++;  # Skip duplicates
            return $item if exists $second_set{$key};
        }
        return undef;
    });
}

# Except - set difference
sub Except {
    my($self, $second, $comparer) = @_;
    
    # Build hash of second sequence
    my %second_set = ();
    $second->ForEach(sub {
        my $item = shift;
        my $key = $comparer ? $comparer->($item) : _make_key($item);
        $second_set{$key} = 1;
    });

    my $class = ref($self);
    my $iter = $self->iterator;
    my %seen = ();

    return $class->new(sub {
        while (defined(my $item = $iter->())) {
            my $key = $comparer ? $comparer->($item) : _make_key($item);
            
            next if $seen{$key}++;  # Skip duplicates
            return $item unless exists $second_set{$key};
        }
        return undef;
    });
}

#---------------------------------------------------------------------
# Quantifier Methods
#---------------------------------------------------------------------

# All - test if all elements satisfy condition
sub All {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;

    while (defined(my $item = $iter->())) {
        return 0 unless $predicate->($item);
    }
    return 1;
}

# Any - test if any element satisfies condition
sub Any {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;

    if ($predicate) {
        while (defined(my $item = $iter->())) {
            return 1 if $predicate->($item);
        }
        return 0;
    }
    else {
        my $item = $iter->();
        return defined($item) ? 1 : 0;
    }
}

# Contains - check if sequence contains element
sub Contains {
    my($self, $value, $comparer) = @_;
    
    if ($comparer) {
        return $self->Any(sub { $comparer->($_[0], $value) });
    }
    else {
        return $self->Any(sub {
            my $item = $_[0];
            return (!defined($item) && !defined($value)) ||
                   (defined($item) && defined($value) && $item eq $value);
        });
    }
}

# SequenceEqual - compare two sequences for equality
sub SequenceEqual {
    my($self, $second, $comparer) = @_;
    $comparer ||= sub { 
        my($a, $b) = @_;
        return (!defined($a) && !defined($b)) ||
               (defined($a) && defined($b) && $a eq $b);
    };

    my $iter1 = $self->iterator;
    my $iter2 = $second->iterator;

    while (1) {
        my $item1 = $iter1->();
        my $item2 = $iter2->();

        # Both ended - equal
        return 1 if !defined($item1) && !defined($item2);

        # One ended - not equal
        return 0 if !defined($item1) || !defined($item2);

        # Compare items
        return 0 unless $comparer->($item1, $item2);
    }
}

#---------------------------------------------------------------------
# Element Access Methods
#---------------------------------------------------------------------

# First - get first element
sub First {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;

    if ($predicate) {
        while (defined(my $item = $iter->())) {
            return $item if $predicate->($item);
        }
        die "No element satisfies the condition";
    }
    else {
        my $item = $iter->();
        return $item if defined $item;
        die "Sequence contains no elements";
    }
}

# FirstOrDefault - get first element or default
sub FirstOrDefault {
    my($self, $predicate, $default) = @_;

    my $result = eval { $self->First($predicate) };
    return $@ ? $default : $result;
}

# Last - get last element
sub Last {
    my($self, $predicate) = @_;
    my @items = $self->ToArray();

    if ($predicate) {
        for (my $i = $#items; $i >= 0; $i--) {
            return $items[$i] if $predicate->($items[$i]);
        }
        die "No element satisfies the condition";
    }
    else {
        die "Sequence contains no elements" unless @items;
        return $items[-1];
    }
}

# LastOrDefault - return last element or undef
sub LastOrDefault {
    my($self, $predicate) = @_;
    my @items = $self->ToArray();

    if ($predicate) {
        for (my $i = $#items; $i >= 0; $i--) {
            return $items[$i] if $predicate->($items[$i]);
        }
        return undef;
    }
    else {
        return @items ? $items[-1] : undef;
    }
}

# Single - return the only element
sub Single {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;
    my $found;
    my $count = 0;

    while (defined(my $item = $iter->())) {
        next if $predicate && !$predicate->($item);
        
        $count++;
        if ($count > 1) {
            die "Sequence contains more than one element";
        }
        $found = $item;
    }

    die "Sequence contains no elements" if $count == 0;
    return $found;
}

# SingleOrDefault - return the only element or undef
sub SingleOrDefault {
    my($self, $predicate) = @_;
    my $iter = $self->iterator;
    my $found;
    my $count = 0;

    while (defined(my $item = $iter->())) {
        next if $predicate && !$predicate->($item);
        
        $count++;
        if ($count > 1) {
            return undef;  # More than one element
        }
        $found = $item;
    }

    return $count == 1 ? $found : undef;
}

# ElementAt - return element at specified index
sub ElementAt {
    my($self, $index) = @_;
    die "Index must be non-negative" if $index < 0;

    my $iter = $self->iterator;
    my $current = 0;

    while (defined(my $item = $iter->())) {
        return $item if $current == $index;
        $current++;
    }

    die "Index out of range";
}

# ElementAtOrDefault - return element at index or undef
sub ElementAtOrDefault {
    my($self, $index) = @_;
    return undef if $index < 0;

    my $iter = $self->iterator;
    my $current = 0;

    while (defined(my $item = $iter->())) {
        return $item if $current == $index;
        $current++;
    }

    return undef;
}

#---------------------------------------------------------------------
# Aggregation Methods
#---------------------------------------------------------------------

# Count - count elements
sub Count {
    my($self, $predicate) = @_;

    if ($predicate) {
        return $self->Where($predicate)->Count();
    }

    my $count = 0;
    my $iter = $self->iterator;
    $count++ while defined $iter->();
    return $count;
}

# Sum - calculate sum
sub Sum {
    my($self, $selector) = @_;
    $selector ||= sub { $_[0] };

    my $sum = 0;
    $self->ForEach(sub {
        $sum += $selector->(shift);
    });
    return $sum;
}

# Min - find minimum
sub Min {
    my($self, $selector) = @_;
    $selector ||= sub { $_[0] };

    my $min;
    $self->ForEach(sub {
        my $val = $selector->(shift);
        $min = $val if !defined($min) || $val < $min;
    });
    return $min;
}

# Max - find maximum
sub Max {
    my($self, $selector) = @_;
    $selector ||= sub { $_[0] };

    my $max;
    $self->ForEach(sub {
        my $val = $selector->(shift);
        $max = $val if !defined($max) || $val > $max;
    });
    return $max;
}

# Average - calculate average
sub Average {
    my($self, $selector) = @_;
    $selector ||= sub { $_[0] };

    my $sum = 0;
    my $count = 0;
    $self->ForEach(sub {
        $sum += $selector->(shift);
        $count++;
    });

    die "Sequence contains no elements" if $count == 0;
    return $sum / $count;
}

# AverageOrDefault - calculate average or return undef if empty
sub AverageOrDefault {
    my($self, $selector) = @_;
    $selector ||= sub { $_[0] };

    my $sum = 0;
    my $count = 0;
    $self->ForEach(sub {
        $sum += $selector->(shift);
        $count++;
    });

    return undef if $count == 0;
    return $sum / $count;
}

# Aggregate - apply accumulator function over sequence
sub Aggregate {
    my($self, @args) = @_;
    
    my($seed, $func, $result_selector);
    
    if (@args == 1) {
        # Aggregate($func) - use first element as seed
        $func = $args[0];
        my $iter = $self->iterator;
        $seed = $iter->();
        die "Sequence contains no elements" unless defined $seed;
        
        # Continue with rest of elements
        while (defined(my $item = $iter->())) {
            $seed = $func->($seed, $item);
        }
    }
    elsif (@args == 2) {
        # Aggregate($seed, $func)
        ($seed, $func) = @args;
        $self->ForEach(sub {
            $seed = $func->($seed, shift);
        });
    }
    elsif (@args == 3) {
        # Aggregate($seed, $func, $result_selector)
        ($seed, $func, $result_selector) = @args;
        $self->ForEach(sub {
            $seed = $func->($seed, shift);
        });
    }
    else {
        die "Invalid number of arguments for Aggregate";
    }

    return $result_selector ? $result_selector->($seed) : $seed;
}

#---------------------------------------------------------------------
# Conversion Methods
#---------------------------------------------------------------------

# ToArray - convert to array
sub ToArray {
    my($self) = @_;
    my @result;
    my $iter = $self->iterator;

    while (defined(my $item = $iter->())) {
        push @result, $item;
    }
    return @result;
}

# ToList - convert to array reference
sub ToList {
    my($self) = @_;
    return [$self->ToArray()];
}

# DefaultIfEmpty - return default value if empty
sub DefaultIfEmpty {
    my($self, $default_value) = @_;
    # default_value のデフォルトは undef
    my $has_default_arg = @_ > 1;
    if (!$has_default_arg) {
        $default_value = undef;
    }

    my $class = ref($self);
    my $iter = $self->iterator;
    my $has_elements = 0;
    my $returned_default = 0;

    return $class->new(sub {
        my $item = $iter->();
        if (defined $item) {
            $has_elements = 1;
            return $item;
        }

        # EOF reached
        if (!$has_elements && !$returned_default) {
            $returned_default = 1;
            return $default_value;
        }

        return undef;
    });
}

# ToLTSV - write to LTSV file
sub ToLTSV {
    my($self, $filename) = @_;

    my $fh = do { local *FH; *FH };
    open($fh, "> $filename") or die "Cannot open '$filename': $!";

    $self->ForEach(sub {
        my $record = shift;
        my $line = join("\t", map { "$_:$record->{$_}" } sort keys %$record);
        print $fh $line, "\n";
    });

    close $fh;
    return 1;
}

#---------------------------------------------------------------------
# Utility Methods
#---------------------------------------------------------------------

# ForEach - execute action for each element
sub ForEach {
    my($self, $action) = @_;
    my $iter = $self->iterator;

    while (defined(my $item = $iter->())) {
        $action->($item);
    }
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

LTSV::LINQ - LINQ-style query interface for LTSV files

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

  use LTSV::LINQ;

  # Read LTSV file and query
  my @results = LTSV::LINQ->FromLTSV("access.log")
      ->Where(sub { $_[0]{status} eq '200' })
      ->Select(sub { $_[0]{url} })
      ->Distinct()
      ->ToArray();

  # DSL syntax for simple filtering
  my @errors = LTSV::LINQ->FromLTSV("access.log")
      ->Where(status => '404')
      ->ToArray();

  # Grouping and aggregation
  my @stats = LTSV::LINQ->FromLTSV("access.log")
      ->GroupBy(sub { $_[0]{status} })
      ->Select(sub {
          my $g = shift;
          return {
              Status => $g->{Key},
              Count => scalar(@{$g->{Elements}})
          };
      })
      ->OrderByDescending(sub { $_[0]{Count} })
      ->ToArray();

=head1 TABLE OF CONTENTS

=over 4

=item * L</DESCRIPTION>

=item * L</METHODS> - Complete method reference (30 methods)

=item * L</EXAMPLES> - 8 practical examples

=item * L</FEATURES> - Lazy evaluation, method chaining, DSL

=item * L</ARCHITECTURE> - Iterator design, execution flow

=item * L</PERFORMANCE> - Memory usage, optimization tips

=item * L</COMPATIBILITY> - Perl 5.005+ support, pure Perl

=item * L</DIAGNOSTICS> - Error messages

=item * L</FAQ> - Common questions and answers

=item * L</COOKBOOK> - Common patterns

=item * L</SEE ALSO> - Related resources

=item * L</AUTHOR>

=item * L</COPYRIGHT AND LICENSE>

=back

=head1 DESCRIPTION

LTSV::LINQ provides a LINQ-style query interface for LTSV (Labeled 
Tab-Separated Values) files. It offers a fluent, chainable API for 
filtering, transforming, and aggregating LTSV data.

Key features:

=over 4

=item * B<Lazy evaluation> - O(1) memory usage for most operations

=item * B<Method chaining> - Fluent, readable query composition

=item * B<DSL syntax> - Simple key-value filtering

=item * B<30+ LINQ methods> - Comprehensive query capabilities

=item * B<Pure Perl> - No XS dependencies

=item * B<Perl 5.5.3+> - Works on ancient and modern Perl

=back

=head2 What is LTSV?

LTSV (Labeled Tab-Separated Values) is a format for structured logs.
Each line contains tab-separated key:value pairs.

Example:

  time:2026-02-13T10:00:00	status:200	url:/index.html	bytes:1024

For more information:
  http://ltsv.org/

=head2 What is LINQ?

LINQ (Language Integrated Query) is a query syntax in C# and .NET.
This module brings LINQ-style querying to Perl for LTSV data.

For more information:
  https://learn.microsoft.com/en-us/dotnet/csharp/linq/

=head1 METHODS

=head2 Complete Method Reference

This module implements 30 LINQ-style methods organized into 12 categories:

=over 4

=item * B<Data Sources (3)>: From, FromLTSV, Range

=item * B<Filtering (1)>: Where (with DSL)

=item * B<Projection (2)>: Select, SelectMany

=item * B<Partitioning (3)>: Take, Skip, TakeWhile

=item * B<Ordering (3)>: OrderBy, OrderByDescending, Reverse

=item * B<Grouping (1)>: GroupBy

=item * B<Set Operations (1)>: Distinct

=item * B<Quantifiers (2)>: All, Any

=item * B<Element Access (3)>: First, FirstOrDefault, Last

=item * B<Aggregation (5)>: Count, Sum, Min, Max, Average

=item * B<Conversion (3)>: ToArray, ToList, ToLTSV

=item * B<Utility (1)>: ForEach

=back

B<Method Summary Table:>

  Method              Category        Lazy?  Returns
  ==================  ==============  =====  ================
  From                Data Source     Yes    Query
  FromLTSV            Data Source     Yes    Query
  Range               Data Source     Yes    Query
  Where               Filtering       Yes    Query
  Select              Projection      Yes    Query
  SelectMany          Projection      Yes    Query
  Concat              Concatenation   Yes    Query
  Take                Partitioning    Yes    Query
  Skip                Partitioning    Yes    Query
  TakeWhile           Partitioning    Yes    Query
  SkipWhile           Partitioning    Yes    Query
  OrderBy             Ordering        No*    Query
  OrderByDescending   Ordering        No*    Query
  Reverse             Ordering        No*    Query
  GroupBy             Grouping        No*    Query
  Distinct            Set Operation   Yes    Query
  Union               Set Operation   Yes    Query
  Intersect           Set Operation   Yes    Query
  Except              Set Operation   Yes    Query
  All                 Quantifier      No     Boolean
  Any                 Quantifier      No     Boolean
  Contains            Quantifier      No     Boolean
  SequenceEqual       Comparison      No     Boolean
  First               Element Access  No     Element
  FirstOrDefault      Element Access  No     Element
  Last                Element Access  No*    Element
  LastOrDefault       Element Access  No*    Element or undef
  Single              Element Access  No*    Element
  SingleOrDefault     Element Access  No*    Element or undef
  ElementAt           Element Access  No*    Element
  ElementAtOrDefault  Element Access  No*    Element or undef
  Count               Aggregation     No     Integer
  Sum                 Aggregation     No     Number
  Min                 Aggregation     No     Number
  Max                 Aggregation     No     Number
  Average             Aggregation     No     Number
  AverageOrDefault    Aggregation     No     Number or undef
  Aggregate           Aggregation     No     Any
  DefaultIfEmpty      Default Value   Yes    Query
  ToArray             Conversion      No     Array
  ToList              Conversion      No     ArrayRef
  ToLTSV              Conversion      No     Boolean
  ForEach             Utility         No     Void

  * Materializing operation (loads all data into memory)

=head2 Data Source Methods

=over 4

=item B<From(\@array)>

Create a query from an array.

  my $query = LTSV::LINQ->From([{name => 'Alice'}, {name => 'Bob'}]);

=item B<FromLTSV($filename)>

Create a query from an LTSV file.

  my $query = LTSV::LINQ->FromLTSV("access.log");

=item B<Range($start, $count)>

Generate a sequence of integers.

  my $query = LTSV::LINQ->Range(1, 10);  # 1, 2, ..., 10

=back

=head2 Filtering Methods

=over 4

=item B<Where($predicate)>

=item B<Where(key =E<gt> value, ...)>

Filter elements. Accepts either a code reference or DSL form.

B<Code Reference Form:>

  ->Where(sub { $_[0]{status} == 200 })
  ->Where(sub { $_[0]{status} >= 400 && $_[0]{bytes} > 1000 })

The code reference receives each element as C<$_[0]> and should return
true to include the element, false to exclude it.

B<DSL Form:>

The DSL (Domain Specific Language) form provides a concise syntax for
simple equality comparisons. All conditions are combined with AND logic.

  # Single condition
  ->Where(status => '200')

  # Multiple conditions (AND)
  ->Where(status => '200', method => 'GET')

  # Equivalent to:
  ->Where(sub { 
      $_[0]{status} eq '200' && $_[0]{method} eq 'GET' 
  })

B<DSL Specification:>

=over 4

=item * All comparisons are string equality (C<eq>)

=item * All conditions are combined with AND

=item * Undefined values are treated as failures

=item * For numeric or OR logic, use code reference form

=back

B<Examples:>

  # DSL: Simple and readable
  ->Where(status => '200')
  ->Where(user => 'alice', role => 'admin')

  # Code ref: Complex logic
  ->Where(sub { $_[0]{status} >= 400 && $_[0]{status} < 500 })
  ->Where(sub { $_[0]{user} eq 'alice' || $_[0]{user} eq 'bob' })

=back

=head2 Projection Methods

=over 4

=item B<Select($selector)>

Transform each element using the provided selector function.

The selector receives each element as C<$_[0]> and should return
the transformed value.

B<Parameters:>

=over 4

=item * C<$selector> - Code reference that transforms each element

=back

B<Returns:> New query with transformed elements (lazy)

B<Examples:>

  # Extract single field
  ->Select(sub { $_[0]{url} })

  # Transform to new structure
  ->Select(sub { 
      { 
          path => $_[0]{url}, 
          code => $_[0]{status} 
      } 
  })

  # Calculate derived values
  ->Select(sub { $_[0]{bytes} * 8 })  # bytes to bits

B<Note:> Select preserves one-to-one mapping. For one-to-many, use
SelectMany.

=item B<SelectMany($selector)>

Flatten nested sequences into a single sequence.

The selector should return an array reference. All arrays are flattened
into a single sequence.

B<Parameters:>

=over 4

=item * C<$selector> - Code reference returning array reference

=back

B<Returns:> New query with flattened elements (lazy)

B<Examples:>

  # Flatten array of arrays
  my @nested = ([1, 2], [3, 4], [5]);
  LTSV::LINQ->From(\@nested)
      ->SelectMany(sub { $_[0] })
      ->ToArray();  # (1, 2, 3, 4, 5)

  # Expand related records
  ->SelectMany(sub {
      my $user = shift;
      return [ map { 
          { user => $user->{name}, role => $_ } 
      } @{$user->{roles}} ];
  })

B<Use Cases:>

=over 4

=item * Flattening nested arrays

=item * Expanding one-to-many relationships

=item * Generating multiple outputs per input

=back

=back

=head2 Concatenation Methods

=over 4

=item B<Concat($second)>

Concatenate two sequences into one.

B<Parameters:>

=over 4

=item * C<$second> - Second sequence (LTSV::LINQ object)

=back

B<Returns:> New query with both sequences concatenated (lazy)

B<Examples:>

  # Combine two data sources
  my $q1 = LTSV::LINQ->From([1, 2, 3]);
  my $q2 = LTSV::LINQ->From([4, 5, 6]);
  $q1->Concat($q2)->ToArray();  # (1, 2, 3, 4, 5, 6)

  # Merge LTSV files
  LTSV::LINQ->FromLTSV("jan.log")
      ->Concat(LTSV::LINQ->FromLTSV("feb.log"))
      ->Where(status => '500')

B<Note:> This operation is lazy - sequences are read on-demand.

=back

=head2 Partitioning Methods

=over 4

=item B<Take($count)>

Take the first N elements from the sequence.

B<Parameters:>

=over 4

=item * C<$count> - Number of elements to take (integer >= 0)

=back

B<Returns:> New query limited to first N elements (lazy)

B<Examples:>

  # Top 10 results
  ->OrderByDescending(sub { $_[0]{score} })
    ->Take(10)

  # First record only
  ->Take(1)->ToArray()

  # Limit large file processing
  LTSV::LINQ->FromLTSV("huge.log")->Take(1000)

B<Note:> Take(0) returns empty sequence. Negative values treated as 0.

=item B<Skip($count)>

Skip the first N elements, return the rest.

B<Parameters:>

=over 4

=item * C<$count> - Number of elements to skip (integer >= 0)

=back

B<Returns:> New query skipping first N elements (lazy)

B<Examples:>

  # Skip header row
  ->Skip(1)

  # Pagination: page 3, size 20
  ->Skip(40)->Take(20)

  # Skip first batch
  ->Skip(1000)->ForEach(sub { ... })

B<Use Cases:>

=over 4

=item * Pagination

=item * Skipping header rows

=item * Processing in batches

=back

=item B<TakeWhile($predicate)>

Take elements while the predicate is true. Stops at first false.

B<Parameters:>

=over 4

=item * C<$predicate> - Code reference returning boolean

=back

B<Returns:> New query taking elements while predicate holds (lazy)

B<Examples:>

  # Take while value is small
  ->TakeWhile(sub { $_[0]{count} < 100 })

  # Take while timestamp is in range
  ->TakeWhile(sub { $_[0]{time} lt '2026-02-01' })

  # Process until error
  ->TakeWhile(sub { $_[0]{status} < 400 })

B<Important:> TakeWhile stops immediately when predicate returns false.
It does NOT filter - it terminates the sequence.

  # Different from Where:
  ->TakeWhile(sub { $_[0] < 5 })  # 1,2,3,4 then STOP
  ->Where(sub { $_[0] < 5 })      # 1,2,3,4 (checks all)

=item B<SkipWhile($predicate)>

Skip elements while the predicate is true. Returns rest after first false.

B<Parameters:>

=over 4

=item * C<$predicate> - Code reference returning boolean

=back

B<Returns:> New query skipping initial elements (lazy)

B<Examples:>

  # Skip header lines
  ->SkipWhile(sub { $_[0]{line} =~ /^#/ })

  # Skip while value is small
  ->SkipWhile(sub { $_[0]{count} < 100 })

  # Process after certain timestamp
  ->SkipWhile(sub { $_[0]{time} lt '2026-02-01' })

B<Important:> SkipWhile only skips initial elements. Once predicate is
false, all remaining elements are included.

  [1,2,3,4,5,2,1]->SkipWhile(sub { $_[0] < 4 })  # (4,5,2,1)

=back

=head2 Ordering Methods

=over 4

=item B<OrderBy($key_selector)>

Sort in ascending order.

  ->OrderBy(sub { $_[0]{timestamp} })

=item B<OrderByDescending($key_selector)>

Sort in descending order.

  ->OrderByDescending(sub { $_[0]{count} })

=item B<Reverse()>

Reverse the order.

  ->Reverse()

=back

=head2 Grouping Methods

=over 4

=item B<GroupBy($key_selector [, $element_selector])>

Group elements by key.

  ->GroupBy(sub { $_[0]{status} })

Returns array of hashrefs with 'Key' and 'Elements' fields.

=back

=head2 Set Operations

=over 4

=item B<Distinct([$comparer])>

Remove duplicate elements.

  ->Distinct()

=item B<Union($second [, $comparer])>

Produce set union of two sequences (no duplicates).

B<Parameters:>

=over 4

=item * C<$second> - Second sequence (LTSV::LINQ object)

=item * C<$comparer> - (Optional) Custom key selector for comparison

=back

B<Returns:> New query with elements from both sequences (lazy, distinct)

B<Examples:>

  # Simple union
  my $q1 = LTSV::LINQ->From([1, 2, 3]);
  my $q2 = LTSV::LINQ->From([3, 4, 5]);
  $q1->Union($q2)->ToArray();  # (1, 2, 3, 4, 5)

  # Union with custom comparer
  ->Union($other, sub { lc($_[0]) })  # Case-insensitive

B<Note:> Equivalent to Concat()->Distinct(). Automatically removes duplicates.

=item B<Intersect($second [, $comparer])>

Produce set intersection of two sequences.

B<Parameters:>

=over 4

=item * C<$second> - Second sequence (LTSV::LINQ object)

=item * C<$comparer> - (Optional) Custom key selector for comparison

=back

B<Returns:> New query with common elements only (lazy, distinct)

B<Examples:>

  # Common elements
  LTSV::LINQ->From([1, 2, 3])
      ->Intersect(LTSV::LINQ->From([2, 3, 4]))
      ->ToArray();  # (2, 3)

  # Find users in both lists
  $users1->Intersect($users2, sub { $_[0]{id} })

B<Note:> Only includes elements present in both sequences.

=item B<Except($second [, $comparer])>

Produce set difference (elements in first but not in second).

B<Parameters:>

=over 4

=item * C<$second> - Second sequence (LTSV::LINQ object)

=item * C<$comparer> - (Optional) Custom key selector for comparison

=back

B<Returns:> New query with elements only in first sequence (lazy, distinct)

B<Examples:>

  # Set difference
  LTSV::LINQ->From([1, 2, 3])
      ->Except(LTSV::LINQ->From([2, 3, 4]))
      ->ToArray();  # (1)

  # Find users in first list but not second
  $all_users->Except($inactive_users, sub { $_[0]{id} })

B<Note:> Returns elements from first sequence not present in second.

=back

=head2 Quantifier Methods

=over 4

=item B<All($predicate)>

Test if all elements satisfy condition.

  ->All(sub { $_[0]{status} == 200 })

=item B<Any([$predicate])>

Test if any element satisfies condition.

  ->Any(sub { $_[0]{status} >= 400 })
  ->Any()  # Test if sequence is non-empty

=item B<Contains($value [, $comparer])>

Check if sequence contains specified element.

B<Parameters:>

=over 4

=item * C<$value> - Value to search for

=item * C<$comparer> - (Optional) Custom comparison function

=back

B<Returns:> Boolean (1 or 0)

B<Examples:>

  # Simple search
  ->Contains(5)  # 1 if found, 0 otherwise

  # Case-insensitive search
  ->Contains('foo', sub { lc($_[0]) eq lc($_[1]) })

  # Check for undef
  ->Contains(undef)

=item B<SequenceEqual($second [, $comparer])>

Determine if two sequences are equal (same elements in same order).

B<Parameters:>

=over 4

=item * C<$second> - Second sequence (LTSV::LINQ object)

=item * C<$comparer> - (Optional) Comparison function ($a, $b) -> boolean

=back

B<Returns:> Boolean (1 if equal, 0 otherwise)

B<Examples:>

  # Same sequences
  LTSV::LINQ->From([1, 2, 3])
      ->SequenceEqual(LTSV::LINQ->From([1, 2, 3]))  # 1 (true)

  # Different elements
  LTSV::LINQ->From([1, 2, 3])
      ->SequenceEqual(LTSV::LINQ->From([1, 2, 4]))  # 0 (false)

  # Different lengths
  LTSV::LINQ->From([1, 2])
      ->SequenceEqual(LTSV::LINQ->From([1, 2, 3]))  # 0 (false)

  # Case-insensitive comparison
  $seq1->SequenceEqual($seq2, sub { lc($_[0]) eq lc($_[1]) })

B<Note:> Order matters. Both content AND order must match.

=back

=head2 Element Access Methods

=over 4

=item B<First([$predicate])>

Get first element. Dies if empty.

  ->First()
  ->First(sub { $_[0]{status} == 404 })

=item B<FirstOrDefault([$predicate,] $default)>

Get first element or default value.

  ->FirstOrDefault(undef, {})

=item B<Last([$predicate])>

Get last element. Dies if empty.

  ->Last()

=item B<LastOrDefault([$predicate])>

Get last element, or undef if empty. Never throws exceptions.

B<Parameters:>

=over 4

=item * C<$predicate> - (Optional) Condition

=back

B<Returns:> Last element or undef

B<Examples:>

  # Get last element
  ->LastOrDefault()  # 5

  # Empty sequence
  LTSV::LINQ->From([])->LastOrDefault()  # undef

  # With predicate
  ->LastOrDefault(sub { $_[0] % 2 == 0 })  # Last even number

=item B<Single([$predicate])>

Get the only element. Dies if sequence has zero or more than one element.

B<Parameters:>

=over 4

=item * C<$predicate> - (Optional) Condition

=back

B<Returns:> Single element

B<Exceptions:> 
- Dies with "Sequence contains no elements" if empty
- Dies with "Sequence contains more than one element" if multiple elements

B<.NET LINQ Compatibility:> Exception messages match .NET LINQ behavior exactly.

B<Performance:> Uses lazy evaluation. Stops iterating immediately when
second element is found (does not load entire sequence).

B<Examples:>

  # Exactly one element
  LTSV::LINQ->From([5])->Single()  # 5

  # With predicate
  ->Single(sub { $_[0] > 10 })
  
  # Memory-efficient: stops at 2nd element
  LTSV::LINQ->FromLTSV("huge.log")->Single(sub { $_[0]{id} eq '999' })

=item B<SingleOrDefault([$predicate])>

Get the only element, or undef if zero or multiple elements.

B<Returns:> Single element or undef (if 0 or 2+ elements)

B<.NET LINQ Compatibility:> Returns undef (null) for both empty and
multiple element cases, matching .NET behavior.

B<Performance:> Uses lazy evaluation. Memory-efficient.

B<Examples:>

  LTSV::LINQ->From([5])->SingleOrDefault()  # 5
  LTSV::LINQ->From([])->SingleOrDefault()   # undef (empty)
  LTSV::LINQ->From([1,2])->SingleOrDefault()  # undef (multiple)

=item B<ElementAt($index)>

Get element at specified index. Dies if out of range.

B<Parameters:>

=over 4

=item * C<$index> - Zero-based index

=back

B<Returns:> Element at index

B<Exceptions:> Dies if index is negative or out of range

B<Performance:> Uses lazy evaluation (iterator-based). Does NOT load
entire sequence into memory. Stops iterating once target index is reached.

B<Examples:>

  ->ElementAt(0)  # First element
  ->ElementAt(2)  # Third element
  
  # Memory-efficient for large files
  LTSV::LINQ->FromLTSV("huge.log")->ElementAt(10)  # Reads only 11 lines

=item B<ElementAtOrDefault($index)>

Get element at index, or undef if out of range.

B<Returns:> Element or undef

B<Performance:> Uses lazy evaluation (iterator-based). Memory-efficient.

B<Examples:>

  ->ElementAtOrDefault(0)   # First element
  ->ElementAtOrDefault(99)  # undef if out of range

=back

=head2 Aggregation Methods

All aggregation methods are B<terminal operations> - they consume the
entire sequence and return a scalar value.

=over 4

=item B<Count([$predicate])>

Count the number of elements.

B<Parameters:>

=over 4

=item * C<$predicate> - (Optional) Code reference to filter elements

=back

B<Returns:> Integer count

B<Examples:>

  # Count all
  ->Count()  # 1000

  # Count with condition
  ->Count(sub { $_[0]{status} >= 400 })  # 42

  # Equivalent to
  ->Where(sub { $_[0]{status} >= 400 })->Count()

B<Performance:> O(n) - must iterate entire sequence

=item B<Sum([$selector])>

Calculate sum of numeric values.

B<Parameters:>

=over 4

=item * C<$selector> - (Optional) Code reference to extract value.
Default: identity function

=back

B<Returns:> Numeric sum

B<Examples:>

  # Sum of values
  LTSV::LINQ->From([1, 2, 3, 4, 5])->Sum()  # 15

  # Sum of field
  ->Sum(sub { $_[0]{bytes} })

  # Sum with transformation
  ->Sum(sub { $_[0]{price} * $_[0]{quantity} })

B<Note:> Non-numeric values may produce warnings. Use numeric context.

=item B<Min([$selector])>

Find minimum value.

B<Parameters:>

=over 4

=item * C<$selector> - (Optional) Code reference to extract value

=back

B<Returns:> Minimum value (numeric comparison)

B<Examples:>

  # Minimum of values
  ->Min()

  # Minimum of field
  ->Min(sub { $_[0]{response_time} })

  # Oldest timestamp
  ->Min(sub { $_[0]{timestamp} })

B<Returns:> C<undef> if sequence is empty

=item B<Max([$selector])>

Find maximum value.

B<Parameters:>

=over 4

=item * C<$selector> - (Optional) Code reference to extract value

=back

B<Returns:> Maximum value (numeric comparison)

B<Examples:>

  # Maximum of values
  ->Max()

  # Maximum of field
  ->Max(sub { $_[0]{bytes} })

  # Latest timestamp
  ->Max(sub { $_[0]{timestamp} })

B<Returns:> C<undef> if sequence is empty

=item B<Average([$selector])>

Calculate arithmetic mean.

B<Parameters:>

=over 4

=item * C<$selector> - (Optional) Code reference to extract value

=back

B<Returns:> Numeric average (floating point)

B<Examples:>

  # Average of values
  LTSV::LINQ->From([1, 2, 3, 4, 5])->Average()  # 3

  # Average of field
  ->Average(sub { $_[0]{bytes} })

  # Average response time
  ->Average(sub { $_[0]{response_time} })

B<Throws:> Dies with "Sequence contains no elements" if empty

B<Note:> Returns floating point. Use C<int()> for integer result.

=item B<AverageOrDefault([$selector])>

Calculate arithmetic mean, or return undef if sequence is empty.

B<Parameters:>

=over 4

=item * C<$selector> - (Optional) Code reference to extract value

=back

B<Returns:> Numeric average (floating point), or undef if empty

B<Examples:>

  # Safe average - returns undef for empty sequence
  my @empty = ();
  my $avg = LTSV::LINQ->From(\@empty)->AverageOrDefault();  # undef

  # With data
  LTSV::LINQ->From([1, 2, 3])->AverageOrDefault();  # 2

  # With selector
  ->AverageOrDefault(sub { $_[0]{value} })

B<Note:> Unlike Average(), this method never throws an exception.

=item B<Aggregate([$seed,] $func [, $result_selector])>

Apply an accumulator function over a sequence.

B<Signatures:>

=over 4

=item * C<Aggregate($func)> - Use first element as seed

=item * C<Aggregate($seed, $func)> - Explicit seed value

=item * C<Aggregate($seed, $func, $result_selector)> - Transform result

=back

B<Parameters:>

=over 4

=item * C<$seed> - Initial accumulator value (optional for first signature)

=item * C<$func> - Code reference: ($accumulator, $element) -> $new_accumulator

=item * C<$result_selector> - (Optional) Transform final result

=back

B<Returns:> Accumulated value

B<Examples:>

  # Sum (without seed)
  LTSV::LINQ->From([1,2,3,4])->Aggregate(sub { $_[0] + $_[1] })  # 10

  # Product (with seed)
  LTSV::LINQ->From([2,3,4])->Aggregate(1, sub { $_[0] * $_[1] })  # 24

  # Concatenate strings
  LTSV::LINQ->From(['a','b','c'])
      ->Aggregate('', sub { $_[0] ? "$_[0],$_[1]" : $_[1] })  # 'a,b,c'

  # With result selector
  LTSV::LINQ->From([1,2,3])
      ->Aggregate(0, 
          sub { $_[0] + $_[1] },      # accumulate
          sub { "Sum: $_[0]" })       # transform result
  # "Sum: 6"

  # Build complex structure
  ->Aggregate([], sub {
      my($list, $item) = @_;
      push @$list, uc($item);
      return $list;
  })

B<.NET LINQ Compatibility:> Supports all three .NET signatures.

=back

=head2 Conversion Methods

=over 4

=item B<ToArray()>

Convert to array.

  my @array = $query->ToArray();

=item B<ToList()>

Convert to array reference.

  my $arrayref = $query->ToList();

=item B<DefaultIfEmpty([$default_value])>

Return default value if sequence is empty, otherwise return the sequence.

B<Parameters:>

=over 4

=item * C<$default_value> - (Optional) Default value, defaults to undef

=back

B<Returns:> New query with default value if empty (lazy)

B<Examples:>

  # Return 0 if empty
  ->DefaultIfEmpty(0)->ToArray()  # (0) if empty, or original data

  # With undef default
  ->DefaultIfEmpty()->First()  # undef if empty

  # Useful for left joins
  ->Where(condition)->DefaultIfEmpty({id => 0, name => 'None'})

B<Note:> This is useful for ensuring a sequence always has at least
one element.

=item B<ToLTSV($filename)>

Write to LTSV file.

  $query->ToLTSV("output.ltsv");

=back

=head2 Utility Methods

=over 4

=item B<ForEach($action)>

Execute action for each element.

  $query->ForEach(sub { print $_[0]{url}, "\n" });

=back

=head1 EXAMPLES

=head2 Basic Filtering

  use LTSV::LINQ;

  # DSL syntax
  my @successful = LTSV::LINQ->FromLTSV("access.log")
      ->Where(status => '200')
      ->ToArray();

  # Code reference
  my @errors = LTSV::LINQ->FromLTSV("access.log")
      ->Where(sub { $_[0]{status} >= 400 })
      ->ToArray();

=head2 Aggregation

  # Count errors
  my $error_count = LTSV::LINQ->FromLTSV("access.log")
      ->Where(sub { $_[0]{status} >= 400 })
      ->Count();

  # Average bytes for successful requests
  my $avg_bytes = LTSV::LINQ->FromLTSV("access.log")
      ->Where(status => '200')
      ->Average(sub { $_[0]{bytes} });

  print "Average bytes: $avg_bytes\n";

=head2 Grouping and Ordering

  # Top 10 URLs by request count
  my @top_urls = LTSV::LINQ->FromLTSV("access.log")
      ->Where(sub { $_[0]{status} eq '200' })
      ->GroupBy(sub { $_[0]{url} })
      ->Select(sub {
          my $g = shift;
          return {
              URL => $g->{Key},
              Count => scalar(@{$g->{Elements}}),
              TotalBytes => LTSV::LINQ->From($g->{Elements})
                  ->Sum(sub { $_[0]{bytes} })
          };
      })
      ->OrderByDescending(sub { $_[0]{Count} })
      ->Take(10)
      ->ToArray();

  for my $stat (@top_urls) {
      printf "%5d requests - %s (%d bytes)\n",
          $stat->{Count}, $stat->{URL}, $stat->{TotalBytes};
  }

=head2 Complex Query Chain

  # Multi-step analysis
  my @result = LTSV::LINQ->FromLTSV("access.log")
      ->Where(status => '200')              # Filter successful
      ->Select(sub { $_[0]{bytes} })         # Extract bytes
      ->Where(sub { $_[0] > 1000 })          # Large responses only
      ->OrderByDescending(sub { $_[0] })     # Sort descending
      ->Take(100)                             # Top 100
      ->ToArray();

  print "Largest 100 successful responses:\n";
  print "  ", join(", ", @result), "\n";

=head2 Lazy Processing of Large Files

  # Process huge file with constant memory
  LTSV::LINQ->FromLTSV("huge.log")
      ->Where(sub { $_[0]{level} eq 'ERROR' })
      ->ForEach(sub {
          my $rec = shift;
          print "ERROR at $rec->{time}: $rec->{message}\n";
      });

=head2 Quantifiers

  # Check if all requests are successful
  my $all_ok = LTSV::LINQ->FromLTSV("access.log")
      ->All(sub { $_[0]{status} < 400 });

  print $all_ok ? "All OK\n" : "Some errors\n";

  # Check if any errors exist
  my $has_errors = LTSV::LINQ->FromLTSV("access.log")
      ->Any(sub { $_[0]{status} >= 500 });

  print "Server errors detected\n" if $has_errors;

=head2 Data Transformation

  # Read LTSV, transform, write back
  LTSV::LINQ->FromLTSV("input.ltsv")
      ->Select(sub {
          my $rec = shift;
          return {
              %$rec,
              processed => 1,
              timestamp => time(),
          };
      })
      ->ToLTSV("output.ltsv");

=head2 Working with Arrays

  # Query in-memory data
  my @data = (
      {name => 'Alice', age => 30, city => 'Tokyo'},
      {name => 'Bob',   age => 25, city => 'Osaka'},
      {name => 'Carol', age => 35, city => 'Tokyo'},
  );

  my @tokyo_residents = LTSV::LINQ->From(\@data)
      ->Where(city => 'Tokyo')
      ->OrderBy(sub { $_[0]{age} })
      ->ToArray();

=head1 FEATURES

=head2 Lazy Evaluation

All query operations use lazy evaluation via iterators. Data is 
processed on-demand, not all at once.

  # Only reads 10 records from file
  my @top10 = LTSV::LINQ->FromLTSV("huge.log")
      ->Take(10)
      ->ToArray();

=head2 Method Chaining

All methods (except terminal operations like ToArray) return a new
query object, enabling fluent method chaining.

  ->Where(...)->Select(...)->OrderBy(...)->Take(10)

=head2 DSL Syntax

Simple key-value filtering without code references.

  # Readable and concise
  ->Where(status => '200', method => 'GET')

  # Instead of
  ->Where(sub { $_[0]{status} eq '200' && $_[0]{method} eq 'GET' })

=head1 ARCHITECTURE

=head2 Iterator-Based Design

LTSV::LINQ uses an iterator-based architecture for lazy evaluation.

B<Core Concept:>

Each query operation returns a new query object wrapping an iterator
(a code reference that produces one element per call).

  my $iter = sub {
      # Read next element
      # Apply transformation
      # Return element or undef
  };

  my $query = LTSV::LINQ->new($iter);

B<Benefits:>

=over 4

=item * B<Memory Efficiency> - O(1) memory for most operations

=item * B<Lazy Evaluation> - Elements computed on-demand

=item * B<Composability> - Iterators chain naturally

=item * B<Early Termination> - Stop processing when done

=back

=head2 Method Categories

B<Lazy Operations> (return new query):

These operations return immediately, creating a new query object.
No data processing occurs until a terminal operation is called.

=over 4

=item * Where, Select, SelectMany

=item * Take, Skip, TakeWhile

=item * Distinct

=back

B<Terminal Operations> (return value):

These operations consume the iterator and return a result.
All lazy operations are executed at this point.

=over 4

=item * ToArray, ToList, ToLTSV

=item * Count, Sum, Min, Max, Average

=item * First, FirstOrDefault, Last

=item * All, Any

=item * ForEach

=back

B<Materializing Operations> (return new query, but eager):

These operations must consume the entire input before proceeding.

=over 4

=item * OrderBy, OrderByDescending, Reverse

=item * GroupBy

=back

=head2 Query Execution Flow

  # Build query (lazy - no execution yet)
  my $query = LTSV::LINQ->FromLTSV("access.log")
      ->Where(status => '200')      # Lazy
      ->Select(sub { $_[0]{url} })  # Lazy
      ->Distinct();                  # Lazy

  # Execute query (terminal operation)
  my @results = $query->ToArray();  # Now executes entire chain

B<Execution Order:>

  1. FromLTSV opens file and creates iterator
  2. Where wraps iterator with filter
  3. Select wraps with transformation
  4. Distinct wraps with deduplication
  5. ToArray pulls elements through chain

Each element flows through the entire chain before the next element
is read.

=head2 Memory Characteristics

B<Constant Memory Operations:>

=over 4

=item * Where, Select, SelectMany

=item * Take, Skip, TakeWhile

=item * Distinct (with hash, O(unique elements))

=item * ForEach, Count, Sum, Min, Max, Average

=item * First, FirstOrDefault, Any, All

=back

B<Linear Memory Operations:>

=over 4

=item * ToArray, ToList (O(n))

=item * OrderBy, OrderByDescending, Reverse (O(n))

=item * GroupBy (O(n))

=item * Last, LastOrDefault (O(n))

=back

=head1 PERFORMANCE

=head2 Memory Efficiency

Lazy evaluation means memory usage is O(1) for most operations,
regardless of input size.

  # Processes 1GB file with constant memory
  LTSV::LINQ->FromLTSV("1gb.log")
      ->Where(status => '500')
      ->ForEach(sub { print $_[0]{url}, "\n" });

=head2 Terminal Operations

These operations materialize the entire result set:

=over 4

=item * ToArray, ToList

=item * OrderBy, OrderByDescending, Reverse

=item * GroupBy

=item * Last

=back

For large datasets, use these operations carefully.

=head2 Optimization Tips

=over 4

=item * Filter early: Place Where clauses first

  # Good: Filter before expensive operations
  ->Where(status => '200')->OrderBy(...)->Take(10)

  # Bad: Order all data, then filter
  ->OrderBy(...)->Where(status => '200')->Take(10)

=item * Limit early: Use Take to reduce processing

  # Process only what you need
  ->Take(1000)->GroupBy(...)

=item * Avoid repeated ToArray: Reuse results

  # Bad: Calls ToArray twice
  my $count = scalar($query->ToArray());
  my @items = $query->ToArray();

  # Good: Call once, reuse
  my @items = $query->ToArray();
  my $count = scalar(@items);

=back

=head1 COMPATIBILITY

=head2 Perl Version Support

This module is compatible with B<Perl 5.00503 and later>.

Tested on:

=over 4

=item * Perl 5.005_03 (released 1999)

=item * Perl 5.6.x

=item * Perl 5.8.x

=item * Perl 5.10.x - 5.42.x

=back

=head2 Compatibility Policy

B<Ancient Perl Support:>

This module maintains compatibility with Perl 5.005_03 through careful
coding practices:

=over 4

=item * No use of features introduced after 5.005

=item * C<use warnings> compatibility shim for pre-5.6

=item * C<our> keyword avoided (5.6+ feature)

=item * Three-argument C<open> avoided (uses Perl 5.005 compatible style)

=item * No Unicode features required

=item * No module dependencies beyond core

=back

B<Why Perl 5.005_03 Specification?:>

This module adheres to the B<Perl 5.005_03 specification>, which was the
final version of JPerl (Japanese Perl). This is not about using the old
interpreter, but about maintaining the B<simple, original programming model>
that made Perl enjoyable.

Key reasons:

=over 4

=item * B<Simplicity> - The original Perl approach keeps programming fun and easy

Perl 5.6 and later introduced character encoding complexity that made
programming harder. The confusion around character handling contributed
to Perl's decline. By staying with the 5.005_03 specification, we maintain
the simplicity that made Perl "rakuda" (camel) → "raku" (easy/fun).

=item * B<JPerl Compatibility> - Preserves the last JPerl version

Perl 5.005_03 was the final version of JPerl, which handled Japanese text
naturally. Later versions abandoned this approach for Unicode, adding
unnecessary complexity for many use cases.

=item * B<Universal Compatibility> - Runs on ANY Perl version

Code written to the 5.005_03 specification runs on B<all> Perl versions
from 5.005_03 through 5.42 and beyond. This maximizes compatibility across
two decades of Perl releases.

=item * B<Production Systems> - Real-world enterprise needs

Many production systems, embedded environments, and enterprise deployments
still run Perl 5.005, 5.6, or 5.8. This module provides modern query
capabilities without requiring upgrades.

=item * B<Philosophy> - Programming should be enjoyable

As readers of the "Camel Book" (Programming Perl) know, Perl was designed
to make programming enjoyable. The 5.005_03 specification preserves this
original vision.

=back

B<The ina CPAN Philosophy:>

All modules under the ina CPAN account (including mb, Jacode, UTF8-R2,
mb-JSON, and this module) follow this principle: Write to the Perl 5.005_03
specification, test on all versions, maintain programming joy.

This is not nostalgia—it's a commitment to:

=over 4

=item * Simple, maintainable code

=item * Maximum compatibility

=item * The original Perl philosophy

=item * Making programming "raku" (easy and fun)

=back

B<Build System:>

This module uses C<pmake.bat> instead of traditional make, since Perl 5.005_03
on Microsoft Windows lacks make. All tests pass on Perl 5.005_03 through
modern versions.

=head2 Pure Perl Implementation

B<No XS Dependencies:>

This module is implemented in Pure Perl with no XS (C extensions).
Benefits:

=over 4

=item * Works on any Perl installation

=item * No C compiler required

=item * Easy installation in restricted environments

=item * Consistent behavior across platforms

=item * Simpler debugging and maintenance

=back

=head2 Core Module Dependencies

B<None.> This module uses only Perl core features available since 5.005.

No CPAN dependencies required.

=head1 DIAGNOSTICS

=head2 Error Messages

This module may throw the following exceptions:

=over 4

=item C<From() requires ARRAY reference>

Thrown by From() when the argument is not an array reference.

Example:

  LTSV::LINQ->From("string");  # Dies
  LTSV::LINQ->From([1, 2, 3]); # OK

=item C<Sequence contains no elements>

Thrown by First(), Last(), or Average() when called on an empty sequence.

Methods that throw this error:

=over 4

=item * First()

=item * Last()

=item * Average()

=back

To avoid this error, use the OrDefault variants:

=over 4

=item * FirstOrDefault() - returns undef instead of dying

=item * LastOrDefault() - returns undef instead of dying

=item * AverageOrDefault() - returns undef instead of dying

=back

Example:

  my @empty = ();
  LTSV::LINQ->From(\@empty)->First();          # Dies
  LTSV::LINQ->From(\@empty)->FirstOrDefault(); # Returns undef

=item C<No element satisfies the condition>

Thrown by First() or Last() with a predicate when no element matches.

Example:

  my @data = (1, 2, 3);
  LTSV::LINQ->From(\@data)->First(sub { $_[0] > 10 });          # Dies
  LTSV::LINQ->From(\@data)->FirstOrDefault(sub { $_[0] > 10 }); # Returns undef

=item C<Cannot open 'filename': ...>

File I/O error when FromLTSV() cannot open the specified file.

Common causes:

=over 4

=item * File does not exist

=item * Insufficient permissions

=item * Invalid path

=back

Example:

  LTSV::LINQ->FromLTSV("/nonexistent/file.ltsv"); # Dies with this error

=back

=head2 Methods That May Throw Exceptions

=over 4

=item B<From($array_ref)>

Dies if argument is not an array reference.

=item B<FromLTSV($filename)>

Dies if file cannot be opened.

=item B<First([$predicate])>

Dies if sequence is empty or no element matches predicate.

Safe alternative: FirstOrDefault()

=item B<Last([$predicate])>

Dies if sequence is empty or no element matches predicate.

Safe alternative: LastOrDefault()

=item B<Average([$selector])>

Dies if sequence is empty.

Safe alternative: AverageOrDefault()

=back

=head2 Safe Alternatives

For methods that may throw exceptions, use the OrDefault variants:

  First()   → FirstOrDefault()   (returns undef)
  Last()    → LastOrDefault()    (returns undef)
  Average() → AverageOrDefault() (returns undef)

Example:

  # Unsafe - may die
  my $first = LTSV::LINQ->From(\@data)->First();

  # Safe - returns undef if empty
  my $first = LTSV::LINQ->From(\@data)->FirstOrDefault();
  if (defined $first) {
      # Process $first
  }

=head1 FAQ

=head2 General Questions

=over 4

=item B<Q: Why LINQ-style instead of SQL-style?>

A: LINQ provides:

=over 4

=item * Method chaining (more Perl-like)

=item * Type safety through code

=item * No string parsing required

=item * Composable queries

=back

=item B<Q: Can I reuse a query object?>

A: No. Query objects use iterators that can only be consumed once.

  # Wrong - iterator consumed by first ToArray
  my $query = LTSV::LINQ->FromLTSV("file.ltsv");
  my @first = $query->ToArray();   # OK
  my @second = $query->ToArray();  # Empty! Iterator exhausted

  # Right - create new query for each use
  my $query1 = LTSV::LINQ->FromLTSV("file.ltsv");
  my @first = $query1->ToArray();

  my $query2 = LTSV::LINQ->FromLTSV("file.ltsv");
  my @second = $query2->ToArray();

=item B<Q: How do I do OR conditions in Where?>

A: Use code reference form with C<||>:

  # OR condition requires code reference
  ->Where(sub { 
      $_[0]{status} == 200 || $_[0]{status} == 304 
  })

  # DSL only supports AND
  ->Where(status => '200')  # Single condition only

=item B<Q: Why does my query seem to run multiple times?>

A: Some operations require multiple passes:

  # This reads the file TWICE
  my $avg = $query->Average(...);    # Pass 1: Calculate
  my @all = $query->ToArray();       # Pass 2: Collect (iterator reset!)

  # Save result instead
  my @all = $query->ToArray();
  my $avg = LTSV::LINQ->From(\@all)->Average(...);

=back

=head2 Performance Questions

=over 4

=item B<Q: How can I process a huge file efficiently?>

A: Use lazy operations and avoid materializing:

  # Good - constant memory
  LTSV::LINQ->FromLTSV("huge.log")
      ->Where(status => '500')
      ->ForEach(sub { print $_[0]{message}, "\n" });

  # Bad - loads everything into memory
  my @all = LTSV::LINQ->FromLTSV("huge.log")->ToArray();

=item B<Q: Why is OrderBy slow on large files?>

A: OrderBy must load all elements into memory to sort them.

  # Slow on 1GB file - loads everything
  ->OrderBy(sub { $_[0]{timestamp} })->Take(10)

  # Faster - limit before sorting (if possible)
  ->Where(status => '500')->OrderBy(...)->Take(10)

=item B<Q: How do I process files larger than memory?>

A: Use ForEach or streaming terminal operations:

  # Process 100GB file with 1KB memory
  my $error_count = 0;
  LTSV::LINQ->FromLTSV("100gb.log")
      ->Where(sub { $_[0]{level} eq 'ERROR' })
      ->ForEach(sub { $error_count++ });

  print "Errors: $error_count\n";

=back

=head2 DSL Questions

=over 4

=item B<Q: Can DSL do numeric comparisons?>

A: No. DSL uses string equality (C<eq>). Use code reference for numeric:

  # DSL - string comparison
  ->Where(status => '200')  # $_[0]{status} eq '200'

  # Code ref - numeric comparison
  ->Where(sub { $_[0]{status} == 200 })
  ->Where(sub { $_[0]{bytes} > 1000 })

=item B<Q: How do I do case-insensitive matching in DSL?>

A: DSL doesn't support it. Use code reference:

  # Case-insensitive requires code reference
  ->Where(sub { lc($_[0]{method}) eq 'get' })

=item B<Q: Can I use regular expressions in DSL?>

A: No. Use code reference:

  # Regex requires code reference
  ->Where(sub { $_[0]{url} =~ m{^/api/} })

=back

=head2 Compatibility Questions

=over 4

=item B<Q: Does this work on Perl 5.6?>

A: Yes. Tested on Perl 5.005_03 through 5.40+.

=item B<Q: Do I need to install any CPAN modules?>

A: No. Pure Perl with no dependencies beyond core.

=item B<Q: Can I use this on Windows?>

A: Yes. Pure Perl works on all platforms.

=item B<Q: Why support such old Perl versions?>

A: Many production systems cannot upgrade. This module provides
modern query capabilities without requiring upgrades.

=back

=head1 COOKBOOK

=head2 Common Patterns

=over 4

=item B<Find top N by value>

  ->OrderByDescending(sub { $_[0]{score} })
    ->Take(10)
    ->ToArray()

=item B<Group and count>

  ->GroupBy(sub { $_[0]{category} })
    ->Select(sub {
        { 
            Category => $_[0]{Key},
            Count => scalar(@{$_[0]{Elements}})
        }
    })
    ->ToArray()

=item B<Running total>

  my $total = 0;
  ->Select(sub {
      $total += $_[0]{amount};
      { %{$_[0]}, running_total => $total }
  })

=item B<Pagination>

  # Page 3, size 20
  ->Skip(40)->Take(20)->ToArray()

=item B<Unique values>

  ->Select(sub { $_[0]{category} })
    ->Distinct()
    ->ToArray()

=item B<Conditional aggregation>

  my $success_avg = $query
      ->Where(status => '200')
      ->Average(sub { $_[0]{response_time} });

  my $error_avg = $query
      ->Where(sub { $_[0]{status} >= 400 })
      ->Average(sub { $_[0]{response_time} });

=back

=head1 LIMITATIONS AND KNOWN ISSUES

=head2 Current Limitations

=over 4

=item * B<Iterator Consumption>

Query objects can only be consumed once. The iterator is exhausted
after terminal operations.

Workaround: Create new query object or save ToArray() result.

=item * B<Undef Values in Sequences>

Due to iterator-based design, undef cannot be distinguished from end-of-sequence.
Sequences containing undef values may not work correctly with all operations.

This is not a practical limitation for LTSV data (which uses hash references),
but affects operations on plain arrays containing undef.

  # Works fine (LTSV data - hash references)
  LTSV::LINQ->FromLTSV("file.ltsv")->Contains({status => '200'})
  
  # Limitation (plain array with undef)
  LTSV::LINQ->From([1, undef, 3])->Contains(undef)  # May not work

=item * B<No Parallel Execution>

All operations execute sequentially in a single thread.

=item * B<No Index Support>

All filtering requires full scan. No index optimization.

=item * B<GroupBy Sorts Keys>

GroupBy returns groups in sorted key order. Original order is not
preserved.

=item * B<Distinct Uses String Keys>

Distinct with custom comparer uses stringified keys. May not work
correctly for complex objects.

=back

=head2 Not Implemented

The following LINQ methods are NOT implemented in this version:

=over 4

=item * Join, GroupJoin - Relational operations

=item * Zip - Combine two sequences

=item * OfType - Type filtering

=item * Cast - Type conversion

=item * LongCount - 64-bit count

=back

These may be added in future versions if there is demand.

=head1 BUGS

Please report any bugs or feature requests to:

=over 4

=item * Email: C<ina@cpan.org>

=back

=head1 SUPPORT

=head2 Documentation

Full documentation is available via:

  perldoc LTSV::LINQ

=head2 CPAN

  https://metacpan.org/pod/LTSV::LINQ

=head1 SEE ALSO

=over 4

=item * LTSV specification

http://ltsv.org/

=item * Microsoft LINQ documentation

https://learn.microsoft.com/en-us/dotnet/csharp/linq/

=back

=head1 AUTHOR

INABA Hitoshi E<lt>ina@cpan.orgE<gt>

=head2 Contributors

Contributions are welcome! See file: CONTRIBUTING.

=head1 ACKNOWLEDGEMENTS

=head2 LINQ Technology

This module is inspired by LINQ (Language Integrated Query), which was 
developed by Microsoft Corporation for the .NET Framework.

LINQ(R) is a registered trademark of Microsoft Corporation.

We are grateful to Microsoft for pioneering the LINQ technology and 
making it a widely recognized programming pattern. The elegance and 
power of LINQ has influenced query interfaces across many programming 
languages, and this module brings that same capability to LTSV data 
processing in Perl.

This module is not affiliated with, endorsed by, or sponsored by 
Microsoft Corporation.

=head2 References

This module was inspired by:

=over 4

=item * Microsoft LINQ (Language Integrated Query)

L<https://learn.microsoft.com/en-us/dotnet/csharp/linq/>

=item * LTSV specification

L<http://ltsv.org/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2026 INABA Hitoshi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head2 License Details

This module is released under the same license as Perl itself:

=over 4

=item * Artistic License 1.0

L<http://dev.perl.org/licenses/artistic.html>

=item * GNU General Public License version 1 or later

L<http://www.gnu.org/licenses/gpl-1.0.html>

=back

You may choose either license.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS
WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut
