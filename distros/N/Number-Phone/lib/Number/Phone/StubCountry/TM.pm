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
package Number::Phone::StubCountry::TM;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135859;

my $formatters = [
                {
                  'format' => '$1 $2-$3-$4',
                  'leading_digits' => '12',
                  'national_rule' => '(8 $1)',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2-$3-$4',
                  'leading_digits' => '[1-5]',
                  'national_rule' => '(8 $1)',
                  'pattern' => '(\\d{3})(\\d)(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[67]',
                  'national_rule' => '8 $1',
                  'pattern' => '(\\d{2})(\\d{6})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1(?:
              2\\d|
              3[1-9]
            )|
            2(?:
              22|
              4[0-35-8]
            )|
            3(?:
              22|
              4[03-9]
            )|
            4(?:
              22|
              3[128]|
              4\\d|
              6[15]
            )|
            5(?:
              22|
              5[7-9]|
              6[014-689]
            )
          )\\d{5}
        ',
                'geographic' => '
          (?:
            1(?:
              2\\d|
              3[1-9]
            )|
            2(?:
              22|
              4[0-35-8]
            )|
            3(?:
              22|
              4[03-9]
            )|
            4(?:
              22|
              3[128]|
              4\\d|
              6[15]
            )|
            5(?:
              22|
              5[7-9]|
              6[014-689]
            )
          )\\d{5}
        ',
                'mobile' => '
          (?:
            6\\d|
            71
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"9935", "Mary",
"9931", "Ahal",
"9932", "Balkan",
"9933", "Daşoguz",
"9934", "Lebap",};
my $timezones = {
               '' => [
                       'Asia/Ashgabat'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+993|\D)//g;
      my $self = bless({ country_code => '993', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:8)//;
      $self = bless({ country_code => '993', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;