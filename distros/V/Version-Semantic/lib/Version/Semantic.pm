# Prefer numeric version for backwards compatibility
BEGIN { require 5.010000 }; ## no critic ( RequireUseStrict, RequireUseWarnings )
use strict;
use warnings;

my $croak = sub {
  require Carp;
  goto &Carp::croak
};

my $prefix_re = qr/v/;

# <numeric identifier>
my $num_id_re = qr/0 | [1-9] [0-9]*/x;

# <build identifier>
my $build_id_re = qr/[0-9a-zA-Z-]+/;

# <build>
my $build_re = qr/$build_id_re (?: \. $build_id_re )*/x;

# <pre-release identifier>
my $pre_release_id_re = qr/$num_id_re | [0-9A-Za-z-]* [A-Za-z-] [0-9A-Za-z-]*/x;

# <pre-release>
my $pre_release_re = qr/$pre_release_id_re (?: \. $pre_release_id_re )*/x;

## no critic ( ProhibitComplexRegexes )
my $corever_re = qr/
  (?<prefix> $prefix_re)?
  (?<major> $num_id_re) \. (?<minor> $num_id_re) \. (?<patch> $num_id_re)
/x;

# On purpose use "build" (the BNF symbol name) instead of "buildmetadata" as
# the name of the last named capture group
# <valid semver>
my $semver_re = qr/
  $corever_re
  (?: -  (?<pre_release> $pre_release_re) )?
  (?: \+ (?<build> $build_re) )?
/x;

#<<<
package Version::Core; ## no critic ( RequireFilenameMatchesPackage )
BEGIN {
our $VERSION = 'v2.2.0';
}
#>>>

use overload '<=>' => 'compare_to', '""' => 'to_string';

sub prefix { shift->{ prefix } }
sub major  { shift->{ major } }
sub minor  { shift->{ minor } }
sub patch  { shift->{ patch } }

# Derived attribute
sub version_core { shift->{ version_core } }

sub has_prefix { exists shift->{ prefix } }

sub corever_re { $corever_re }

# Constructor as factory method
sub parse {
  my $options = ( ref $_[ -1 ] eq 'HASH' ) ? pop : {};
  my ( $class, $version ) = @_;
  $version //= '';

  my $ver_re = $class ne __PACKAGE__ ? $semver_re : $corever_re;
  unless ( $version =~ m/\A$ver_re\z/ ) {
    $croak->( "Version '$version' is not a ${ \( $class ne __PACKAGE__ ? 'semantic': 'core' ) } version" )
      if $options->{ fatal };
    return
  }

  $class->new( %+ )
}

sub new {
  my $invocant = shift;
  my $class    = ref $invocant || $invocant;

  my $self = do {

    # Validate @_
    my $length;
    my @tmp = @_;
    while ( ( $length = scalar( my ( $name, $value ) = splice @tmp, 0, 2 ) ) == 2 ) {
      $croak->( "Parameter with undefined name passed to \"$class\" constructor" )
        unless defined $name
    }
    $croak->( "Odd number of arguments passed to \"$class\" constructor" )
      if $length == 1;

    # Remove parameters that have undef values
    my %tmp = @_;
    for ( keys %tmp ) {
      delete $tmp{ $_ } unless defined $tmp{ $_ }
    }

    bless { ref $invocant ? %$invocant : (), %tmp } => $class
  };

  delete $self->{ version_core };

  my %params         = map  { $_ => 1 } $self->_init;
  my @unknown_params = grep { not exists $params{ $_ } } keys %$self;
  # Diagnostic message is copied from 'class' feature
  $croak->( "Unrecognised parameters for \"$class\" constructor: " . join( ', ', @unknown_params ) )
    if @unknown_params;

  $self->{ version_core } = ( $self->{ prefix } // '' ) . join( '.', map { $self->{ $_ } } qw( major minor patch ) );

  $self
}

{
  my %isa = (
    prefix => $prefix_re,
    major  => $num_id_re,
    minor  => $num_id_re,
    patch  => $num_id_re,
  );

  sub _init {
    my $self = shift;

    foreach ( qw( major minor patch ) ) {
      # Diagnostic message is copied from 'class' feature
      $croak->( "Required parameter '$_' is missing for \"${ \ __PACKAGE__ }\" constructor" )
        unless exists $self->{ $_ }
    }

    foreach ( keys %isa ) {
      next unless exists $self->{ $_ };
      $croak->( "Parameter '$_' has invalid value '$self->{ $_ }'" )
        unless $self->{ $_ } =~ m/\A $isa{ $_ } \z/x
    }

    qw( prefix major minor patch )
  }
}

sub increment {
  # Obvious strategies are major, minor, and patch
  my ( $self, $strategy ) = @_;
  $strategy //= 'patch';

  return $self->new( patch => $self->patch + 1 )
    if $strategy eq 'patch';
  return $self->new( minor => $self->minor + 1, patch => 0 )
    if $strategy eq 'minor';
  return $self->new( major => $self->major + 1, minor => 0, patch => 0 )
    if $strategy eq 'major';

  $croak->( "Version incrementation strategy '$strategy' is not implemented" )
}

# https://semver.org/spec/v2.0.0.html#spec-item-11
sub compare_to {
  my ( $self, $other ) = @_;

  # 11.2
  for ( qw( major minor patch ) ) {
    return $self->$_ <=> $other->$_ if $self->$_ != $other->$_
  }

  0
}

{
  no warnings 'once';
  *to_string = \&version_core
}

#<<<
package Version::Semantic; ## no critic ( ProhibitMultiplePackages )
BEGIN {
our $VERSION = 'v2.2.0';
}
#>>>

use parent -norequire, 'Version::Core';

use overload '<=>' => 'compare_to', '""' => 'to_string';

sub _croakf ( $@ );

sub pre_release { shift->{ pre_release } }
sub build       { shift->{ build } }

sub has_pre_release { exists shift->{ pre_release } }
sub has_build       { exists shift->{ build } }

sub is_core {
  my $self = shift;

  not( $self->has_pre_release ) and not( $self->has_build )
}

sub semver_re { $semver_re }

{
  my %isa = (
    pre_release => $pre_release_re,
    build       => $build_re
  );

  sub _init {
    my $self = shift;

    my @params = $self->SUPER::_init;

    foreach ( qw( pre_release build ) ) {
      next unless exists $self->{ $_ };
      $croak->( "Parameter '$_' has invalid value '$self->{ $_ }'" )
        unless $self->{ $_ } =~ m/\A $isa{ $_ } \z/x
    }

    ( @params, qw( pre_release build ) )
  }
}

{
  my $trial_pre_release = qr/\A ( TRIAL ) ( [0-9]* ) \z/x;

  sub increment {
    # Obvious strategies are major, minor, and patch
    my ( $self, $strategy, $pre_release ) = @_;

    if ( defined $strategy and $strategy eq 'trial' ) {
      if ( $self->has_pre_release ) {
        if ( my ( $string, $number ) = $self->pre_release =~ $trial_pre_release ) {
          return $self->new( pre_release => $string . ( ( $number eq '' ? 0 : $number ) + 1 ) )
        } else {
          $croak->( "Pre-release extension '${ \( $self->pre_release ) }' does not match '$trial_pre_release'" )
        }
      } else {
        $croak->( "Cannot apply '$strategy' version incrementation strategy to non pre-release version '$self'" )
      }
    }

    my $other = $self->SUPER::increment( $strategy );
    $other->{ pre_release } = $pre_release
      if defined $pre_release;
    $other
  }
}

# https://semver.org/spec/v2.0.0.html#spec-item-11
sub compare_to {
  my ( $self, $other ) = @_;

  # 11.2
  {
    my $sign = $self->SUPER::compare_to( $other );
    return $sign unless $sign == 0;
  }

  # Split pre-release into list of dot separated identifiers
  my @a = $self->has_pre_release  ? split /\./, $self->pre_release  : ();
  my @b = $other->has_pre_release ? split /\./, $other->pre_release : ();

  # 11.3
  if ( @a ) {
    return -1 if not @b
  } else {
    return ( @b ? 1 : 0 )
  }

  # 11.4
  my $len = @a < @b ? @a : @b;
  for ( my $i = 0 ; $i < $len ; $i++ ) {
    my $ai = $a[ $i ];
    my $bi = $b[ $i ];

    my $ai_is_num = $ai =~ m/\A $num_id_re \z/x;
    my $bi_is_num = $bi =~ m/\A $num_id_re \z/x;

    # 11.4.1
    my $sign;
    if ( $ai_is_num and $bi_is_num ) {
      $sign = $ai <=> $bi;
      return $sign if $sign != 0
      # 11.4.3
    } elsif ( $ai_is_num and not $bi_is_num ) {
      return -1
      # 11.4.3
    } elsif ( not $ai_is_num and $bi_is_num ) {
      return 1
    } else {
      $sign = $ai cmp $bi;
      return $sign if $sign != 0
    }
  }

  # 11.4.4
  @a <=> @b
}

sub to_string {
  my ( $self ) = @_;

  my $string = $self->SUPER::to_string;
  $string .= '-' . $self->pre_release if $self->has_pre_release;
  $string .= '+' . $self->build       if $self->has_build;
  $string
}

1
