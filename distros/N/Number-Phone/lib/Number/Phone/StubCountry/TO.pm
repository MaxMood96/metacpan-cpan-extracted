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
package Number::Phone::StubCountry::TO;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135859;

my $formatters = [
                {
                  'format' => '$1-$2',
                  'leading_digits' => '
            [2-4]|
            50|
            6[09]|
            7[0-24-69]|
            8[05]
          ',
                  'pattern' => '(\\d{2})(\\d{3})'
                },
                {
                  'format' => '$1 $2',
                  'pattern' => '(\\d{4})(\\d{3})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[5-9]',
                  'pattern' => '(\\d{3})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            2\\d|
            3[0-8]|
            4[0-4]|
            50|
            6[09]|
            7[0-24-69]|
            8[05]
          )\\d{3}
        ',
                'geographic' => '
          (?:
            2\\d|
            3[0-8]|
            4[0-4]|
            50|
            6[09]|
            7[0-24-69]|
            8[05]
          )\\d{3}
        ',
                'mobile' => '
          (?:
            5(?:
              4[0-5]|
              5[4-6]
            )|
            6(?:
              [09]\\d|
              3[02]|
              8[15-9]
            )|
            (?:
              7\\d|
              8[46-9]
            )\\d|
            999
          )\\d{4}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '0800\\d{3}',
                'voip' => '55[0-37-9]\\d{4}'
              };
my %areanames = ();
$areanames{en} = {"67635", "Nakolo",
"67632", "Muʻa",
"67631", "Muʻa",
"67637", "Vaini",
"67680", "Niuas",
"67629", "Pea",
"67638", "Vaini",
"67636", "Nakolo",
"67633", "Kolonga",
"67674", "Vava\’u",
"67671", "Vava\’u",
"67672", "Vava\’u",
"67675", "Vava\’u",
"67650", "\‘Eua",
"67676", "Vava\’u",
"67640", "Kolovai",
"67634", "Kolonga",
"67679", "Vava\’u",
"67660", "Ha\’apai",
"67643", "Matangiake",
"67669", "Ha\’apai",
"67670", "Vava\’u",
"67642", "Masilamea",
"67641", "Masilamea",
"67630", "Pea",
"6762", "Nuku\'alofa",
"67685", "Niuas",};
my $timezones = {
               '' => [
                       'Pacific/Tongatapu'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+676|\D)//g;
      my $self = bless({ country_code => '676', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;