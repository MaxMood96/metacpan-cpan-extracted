package Exporter::Handy::Util;

# ABSTRACT: Routines useful when exporting symbols thru Exporter and friends
our $VERSION = '1.000004';

use utf8;
use strict;
use warnings;

# Automatically fall back to pure perl for older versions of List::Util (circa Perl version < 5.20)
use List::Util::MaybeXS qw( pairs unpairs uniq );
use Exporter::Extensible -exporter_setup => 1;

export(qw(
    =cxtags
    =xtags
    =expand_xtags
));


# Generators for exported functions
sub _generate_cxtags {
  my ($exporter, $symbol, $opts) = @_;
  sub {; xtags({+ sig => ':',  %{; $opts // {} }}, @_ ) } # curried
}

sub _generate_xtags {
  my ($exporter, $symbol, $opts) = @_;
  sub {; xtags($opts // {}, @_ ) } # curried
}

sub _generate_expand_xtags {
  my ($exporter, $symbol, $opts) = @_;
  sub {; expand_xtags(@_, $opts // { }) } # curried
}


sub xtags { # useful for building export tags
  # say STDERR 'xtag ARGS: ' . np(@_);

  my %opt;   %opt  = ( %opt,  %{; shift   } ) while _is_plain_hashref($_[0]);  # merge options given by any leading hash-refs
  my @res;


  for (pairs @_) {
    my ($k ,$v) = @$_;

    if ( ref($v) =~ /^HASH$/ ) {
      push @res, _xtag_group( \%opt, $k => $v );
    } else {
      push @res, _xtag_group( \%opt, '' => { $k => $v } );
    }
  }
  wantarray ? @res : \@res; ## no critic
}


sub expand_xtags {
  local $_;
  my %tags;  %tags = ( %tags, %{; shift } ) while _is_plain_hashref($_[0]);   # tags at start

  # Handle special requests given via options
  unshift @_,  _flat( delete $tags{-key} // (), delete $tags{-keys} // () );
  # unshift @_, \'*' unless @_; # no arguments => ALL keys.

  @_ = uniq(@_);

  my %seen;
  my @res;

  while (@_) {
    $_ = shift;
    next unless defined;
    ref($_) eq 'ARRAY' and do { unshift @_, @$_; next };

    ref($_) eq 'SCALAR' && ($$_ =~  /[*]|ALL/i ) and do {
      # A scalar ref indicates special handling!
      # If it deferences to '*' (or 'ALL'), it means "ALL KEYS".
      unshift @_, values %tags;
      next
    };

    next if ref($_);
    next if exists $seen{$_} && ( $seen{$_} // 0 );
    $seen{$_} = 1;

    m/^([:](.*))$/ and do {
      unshift @_, delete $tags{$1} // (), delete $tags{$2} // ();
      next;
    };

    push @res, $_;
  }
  @res
}

# PRIVATE routines
sub _xtag_group {
  # say STDERR '_xtag_group ARGS: ' . np(@_);

  # options may be given by one or more leading hash-refs (that we merge)
  my %opt;  %opt = ( %opt, %{; shift } ) while _is_plain_hashref($_[0]);

  my $group = ( @_ && !ref( $_[0] ) ) ? shift : undef;
  my %items = %{; shift };
     %opt   = ( %opt, %{; delete $items{'%'} // {} } );

  $group    = $group // delete $opt{group} // delete $opt{name} // '';
  $group    =~ s/^([:])//;

  my %subopt= %opt;
  my $sig   = delete $opt{sig} // $1 // '';  # like a sigil... It's typically either ':' or empty string.
  my $sep   = delete $opt{sep} // '_';
  my $nogroup   = delete $opt{nogroup} // 0;

  my @pfx   = _flat( delete $opt{pfx} // ( $group ? "${group}${sep}" : "" ));

  my %tags;
  for my $pfx (@pfx) {
    $pfx = $sig . $pfx if $sig && ($pfx !~ /^\Q$sig\E/);

    for my $k (sort keys %items) {
      my $v  = $items{$k};
      $k =~ s/^\Q$sig\E//;
      my $key = "${pfx}${k}";
      my %subtags = ( ref($v) =~ /^HASH$/ ) ? ( _xtag_group(\%subopt, $key => $v) ) : ( $key => $v);
      %tags = (%tags, %subtags);
    }
  }
  # umbrella entry (that encompasses all subtags)
  if (!$nogroup && defined $group && $group) {
    my $g = $group;
    $g = $sig . $g if $sig && ($g !~ /^\Q$sig\E/);
    $tags{$g} = [
      map {;
        my $item = $_;
        $item = ':' . $_ if defined $_ && $_ && !m/^[:]/;
        $item // ()
      } ( sort keys %tags ) ]
  }

  my @tags = _kv_sort(%tags);  # sort on keys
  wantarray ? @tags : \@tags; ## no critic
}

# PRIVATE utilities
# ref
sub _is_plain_arrayref  { ref( $_[0] ) eq 'ARRAY'  }
sub _is_plain_hashref   { ref( $_[0] ) eq 'HASH'   }
sub _is_plain_scalarref { ref( $_[0] ) eq 'SCALAR' }
sub _is_plain_scalar    { !ref( $_[0] ) }

# List
sub _flat  { # shamelessly copied from: [List::_flat](https://metacpan.org/pod/List::_flat)
  my @results;

  while (@_) {
    if ( _is_plain_arrayref( my $element = shift @_ ) ) {
        unshift @_, @{$element};
    }
    else {
        push @results, $element;
    }
  }
  return wantarray ? @results : \@results;  ## no critic
}

sub _kv_sort {
  unpairs sort { $a->[0] cmp $b->[0] } pairs(@_)
}

1;

__END__

=pod

=encoding UTF-8

=for :stopwords Tabulo[n] cxtags sig

=head1 NAME

Exporter::Handy::Util - Routines useful when exporting symbols thru Exporter and friends

=head1 VERSION

version 1.000004

=head1 SYNOPSIS

Define a module with exports

  package My::Utils;
  use Exporter::Handy -exporter_setup => 1;

  export(qw( foo $x @STUFF -strict_and_warnings ), ':baz' => ['foo'] );

  sub foo { ... }

  sub strict_and_warnings {
    strict->import;
    warnings->import;
  }

Create a new module which exports all that, and more

  package My::MoreUtils;
  use My::Utils -exporter_setup => 1;
  sub util_fn3 : Export(:baz) { ... }

Use the module

  use My::MoreUtils qw( -strict_and_warnings :baz @STUFF );
  # Use the exported things
  push @STUFF, foo(), util_fn3();

=head1 DESCRIPTION

This module is currently EXPERIMENTAL. You are advised to restrain from using it.

You have been warned.

=head1 FUNCTIONS

=head2 cxtags

Same as C<xtags()> described below, except that this one assumes {sig => ':'} as part of the options.

Hence, this one is more suitable to be used in conjunction with L<Exporter::Extensible> and descendants,
such as L<Exporter::Handy>, like below:

    use Exporter::Handy::Util qw(cxtags);
    use Exporter::Handy -exporter_setup => 1

    export(
        foo
        goo
        cxtags (
          bar => [qw( $bozo @baza boom )],
          util => {
            io   => [qw(slurp)],
            text => [qw(ltrim rtrim trim)],
          },
        )
    );

which is the same as:

    use Exporter::Handy -exporter_setup => 1

    export(
        foo
        goo
        ':bar'       => [qw( $bozo @baza boom )],
        ':util_io'   => [qw(slurp)],
        ':util_text' => [qw(ltrim rtrim trim)],
    );

=head2 xtags

Build one or more B<export tags> suitable for L<Exporter> and friends, such as:
L<Exporter::Extensible>, L<Exporter::Handy>, L<Exporter::Tiny>, L<Exporter::Shiny>, L<Exporter::Almighty>, ...

Compared to C<cxtags()> described above, this one does not prefix tag keys by a colon (':').

Hence it's quite suitable for populating C<%EXPORT_TAGS>, recognized by
L<Exporter> and many others, such as: L<Exporter::Tiny>, L<Exporter::Shiny>, L<Exporter::Almighty>, ...

Note that although L<Exporter::Extensible> and L<Exporter::Handy> do recognize C<%EXPORT_TAGS>, their preferred API
involves a call to the C<export()> function, which requires a colon (:) prefix for tag names... See C<cxtags()> that does
just that.

    use Exporter::Handy::Util qw(xtags);
    use parent Exporter;

    our %EXPORT_TAGS = (
      xtags (
        bar => [qw( $bozo @baza boom )],
        util => {
          io   => [qw(slurp)],
          text => [qw(ltrim rtrim trim)],
        },
      )
    );

is the same as:

    use parent Exporter;

    our %EXPORT_TAGS = (
        bar => [qw( $bozo @baza boom )],
        util_io   => [qw(slurp)],
        util_text => [qw(ltrim rtrim trim)],
    );

=head2 expand_xtags

Expand B<tags> in a manner compatible with L<Exporter> and friends, such as:
L<Exporter::Extensible>, L<Exporter::Handy>, L<Exporter::Tiny>, L<Exporter::Shiny>, L<Exporter::Almighty>, ...

    use Exporter::Handy::Util qw(expand_xtags);

    our @EXPORT = qw( slurp uniq );
    our %EXPORT_TAGS = (
      file    => [qw( slurp spew )],
      io      => [qw( :file open4 ) ],
      list    => [qw( uniq zip )],
      default => \@EXPORT,
    );
    say expand_xtags(\%EXPORT_TAGS, qw(file) );                  # prints: file
    say expand_xtags(\%EXPORT_TAGS, qw(:file open4) );           # prints: slurp, spew, open4

    say expand_xtags(\%EXPORT_TAGS, @EXPORT_TAGS{qw(io list)} ); # prints: slurp, spew, open4, uniq, zip

    our @EXPORT_OK = expand_xtags(\%EXPORT_TAGS, values %EXPORT_TAGS);
    @EXPORT_OK     = expand_xtags(\%EXPORT_TAGS, { keys => \'*' });

=head1 AUTHORS

Tabulo[n] <dev@tabulo.net>

=head1 LEGAL

This software is copyright (c) 2023 by Tabulo[n].

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
