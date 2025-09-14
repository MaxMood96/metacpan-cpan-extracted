# automatically generated file, don't edit



# Copyright 2025 David Cantrell, derived from data from libphonenumber
# http://code.google.com/p/libphonenumber/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
package Number::Phone::StubCountry::MZ;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            2|
            8[2-79]
          ',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '8',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '
          2(?:
            [1346]\\d|
            5[0-2]|
            [78][12]|
            93
          )\\d{5}
        ',
                'geographic' => '
          2(?:
            [1346]\\d|
            5[0-2]|
            [78][12]|
            93
          )\\d{5}
        ',
                'mobile' => '8[2-79]\\d{7}',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '800\\d{6}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"258272", "Pemba",
"25821", "Maputo",
"258271", "Lichinga",
"25829", "Inhambane",
"258282", "Xai\-Xai",
"258281", "Chokwe",
"25823", "Beira",
"25826", "Nampula",
"25824", "Quelimane",
"258251", "Manica",
"258252", "Tete",};
$areanames{pt} = {"258281", "Chokwé",};
my $timezones = {
               '' => [
                       'Africa/Maputo'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+258|\D)//g;
      my $self = bless({ country_code => '258', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;