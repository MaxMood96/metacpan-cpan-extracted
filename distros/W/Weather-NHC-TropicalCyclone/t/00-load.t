use strict;
use warnings;
use Test::More;

use_ok 'Weather::NHC::TropicalCyclone';
use_ok 'Weather::NHC::TropicalCyclone::HTTP';
use_ok 'Weather::NHC::TropicalCyclone::Validation';
use_ok 'Weather::NHC::TropicalCyclone::Resource';
use_ok 'Weather::NHC::TropicalCyclone::Storm';
use_ok 'Weather::NHC::TropicalCyclone::ForecastAdvisory';
use_ok 'Weather::NHC::TropicalCyclone::StormTable';

is $Weather::NHC::TropicalCyclone::VERSION, '0.36', 'version is 0.36';

done_testing;
