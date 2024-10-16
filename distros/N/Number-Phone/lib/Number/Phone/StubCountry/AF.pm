# automatically generated file, don't edit



# Copyright 2024 David Cantrell, derived from data from libphonenumber
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
package Number::Phone::StubCountry::AF;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20240910191013;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'intl_format' => 'NA',
                  'leading_digits' => '[1-9]',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[2-7]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            [25][0-8]|
            [34][0-4]|
            6[0-5]
          )[2-9]\\d{6}
        ',
                'geographic' => '
          (?:
            [25][0-8]|
            [34][0-4]|
            6[0-5]
          )[2-9]\\d{6}
        ',
                'mobile' => '7\\d{8}',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"9340", "Heart",
"9352", "Badkhshan",
"9327", "Khost",
"9330", "Kandahar",
"9320", "Kabul",
"9362", "Kunarha",
"9350", "Balkh",
"9342", "Ghowr",
"9322", "Kapisa",
"9360", "Nangarhar",
"9357", "Faryab",
"9332", "Uruzgan",
"9326", "Dorkondi",
"9324", "Wardak",
"9341", "Badghis",
"9333", "Zabol",
"9323", "Bamian",
"9334", "Helmand",
"9325", "Logar",
"9331", "Ghazni",
"9358", "Baghlan",
"9343", "Farah",
"9321", "Parwan",
"9344", "Nimruz",
"9365", "Paktika",
"9328", "Panjshar",
"9363", "Laghman",
"9364", "Paktia",
"9351", "Kunduz",
"9356", "Sar\-E\ Pol",
"9361", "Nurestan",
"9354", "Jowzjan",
"9355", "Samangan",
"9353", "Takhar",};
$areanames{fa} = {"9344", "نیمروز",
"9321", "پروان",
"9331", "غزنی",
"9358", "بغلان",
"9343", "فراه",
"9334", "هلمند",
"9325", "لوگر",
"9323", "بامیان",
"9341", "بادغیس",
"9333", "زابل",
"9326", "دایکندی",
"9324", "وردک",
"9353", "تخار",
"9355", "سمنگان",
"9356", "سر\ پل",
"9361", "نورستان",
"9354", "جوزجان",
"9364", "پکتیا",
"9351", "قندوز",
"9363", "لغمان",
"9365", "پکتیکا",
"9328", "پنجشیر",
"9320", "کابل",
"9362", "کنرها",
"9330", "قندهار",
"9327", "خوست",
"9352", "بدخشان",
"9340", "هرات",
"9332", "ارزگان",
"9357", "فاریاب",
"9322", "کاپیسا",
"9360", "ننگرهار",
"9342", "غور",
"9350", "بلخ",};
my $timezones = {
               '' => [
                       'Asia/Kabul'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+93|\D)//g;
      my $self = bless({ country_code => '93', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '93', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;