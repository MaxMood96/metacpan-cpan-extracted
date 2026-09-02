use Test2::V1
  -pragmas,
  -target => { MODULE => 'Version::Semantic' },
  qw( dies is isa_ok lives like ok plan subtest );

use constant CLASS => 'Version::Core'; ## no critic ( ProhibitConstantPragma )

plan 10;

like dies { CLASS->new( major => 0, 'minor' ) }, qr/\AOdd number of arguments passed to "${ \CLASS }" constructor/,
  'Odd number of arguments';

## no critic ( ProhibitComplexRegexes )
like dies { CLASS->new( undef, 0 ) }, qr/\AParameter with undefined name passed to "${ \CLASS }" constructor/,
  'Parameter name cannot be undefined';

like dies { CLASS->new( major => 1, minor => 2, patch => 3, trial => 'TRIAL1' ) },
  qr/\AUnrecognised parameters for "${ \CLASS }" constructor: trial/,
  'Unknown parameter name';

like dies { CLASS->new( major => '01', minor => 2, patch => 3 ) }, qr/\AParameter 'major' has invalid value '01'/,
  'Invalid parameter value';

like dies { CLASS->new( major => 1 ) }, qr/\ARequired parameter 'minor' is missing for "${ \CLASS }" constructor/,
  'Missing required parameter';

like dies { CLASS->parse( undef, { fatal => 1 } ) }, qr/is not a core version/,
  'The undef value is an invalid core version';

like dies { CLASS->parse( '1.2', { fatal => 1 } ) }, qr/is not a core version/, 'Invalid core version';

like dies { CLASS->parse( '1.1.2-prerelease+meta', { fatal => 1 } ) }, qr/is not a core version/,
  'Is a semantic version but not a core version';

subtest 'Valid core versions' => sub {
  plan 7;

  my @versions = qw(
    v0.1.0
    0.0.4
    1.2.3
    10.20.30
    v1.0.0
    2.0.0
    1.1.7
  );
  ok lives { CLASS->parse( $_, { fatal => 1 } ) }, "$_" for @versions
};

subtest 'Test named capture group accessors: "v" prefixed core version' => sub {
  plan 8;

  isa_ok my $self = CLASS->parse( 'v0.0.4' ), CLASS;
  ok $self->has_prefix, 'prefix is defined';
  is $self->prefix,       'v',      'prefix';
  is $self->major,        0,        'major';
  is $self->minor,        0,        'minor';
  is $self->patch,        4,        'patch';
  is $self->version_core, 'v0.0.4', 'version_core';
  is "$self",             'v0.0.4', 'Stringification'
};

