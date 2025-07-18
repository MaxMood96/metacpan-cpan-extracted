use utf8;
use strict;
use warnings;
use Test::More 1.302195;
use List::Util                     qw/max/;
use List::MoreUtils                qw/all/;
use Scalar::Util                   qw/looks_like_number/;
use Clone                          qw/clone/;
use Module::Load::Conditional 0.66 qw/check_install/;
use Iterator::Simple               qw/list/;
use Excel::ValueReader::XLSX;


note "testing Excel::ValueReader::XLSX version $Excel::ValueReader::XLSX::VERSION";

(my $tst_dir = $0) =~ s/valuereader\.t$//;
$tst_dir       ||= "./";
my $xl_file      = $tst_dir . "valuereader.xlsx";
my $xl_1904      = $tst_dir . "valuereader1904.xlsx";
my $xl_ulibuck   = $tst_dir . "ulibuck.xlsx";
my $xl_mappe     = $tst_dir . "Mappe1.xlsx";
my $xl_without_r = $tst_dir . "cells_without_r_attr.xlsx";

my @expected_sheet_names = qw/Test Empty Entities Tab_entities Dates Tables RemoteCells/;
my @expected_values      = (  ["Hello", undef, undef, 22, 33, 55],
                              [123, undef, '<>'],
                              ["This is bold text", undef, '&'],
                              ["This is a Unicode string €", undef, '&<>'],
                              [],
                              [undef, "after an empty row and col",
                               undef, undef, undef,
                               "Hello after an empty row and col"],
                              ["cell\r\nwith\r\nembedded newlines"],
                             );
my $expected_active_sheet = 6;

my @expected_tab_entities  = (
  [],
  [],
  ['Nombre de Name', "\x{c9}tiquettes de colonnes" ],
  ["\x{c9}tiquettes de lignes", 'capital', 'small', '(vide)',
   "Total g\x{e9}n\x{e9}ral"],
  ['A',                        '6',      '6',    undef, '12'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['circumflex accent',        '1',      '1',    undef,  '2'],
  ['grave accent',             '1',      '1',    undef,  '2'],
  ['ring',                     '1',      '1',    undef,  '2'],
  ['tilde',                    '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  '1',      '1',    undef,  '2'],
  ['AE diphthong (ligature)',  '1',      '1',    undef,  '2'],
  ['(vide)',                   '1',      '1',    undef,  '2'],
  ['C',                        '1',      '1',    undef,  '2'],
  ['cedilla',                  '1',      '1',    undef,  '2'],
  ['E',                        '4',      '4',    undef,  '8'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['circumflex accent',        '1',      '1',    undef,  '2'],
  ['grave accent',             '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  '1',      '1',    undef,  '2'],
  ['Eth',                      '1',      '1',    undef,  '2'],
  ['Icelandic',                '1',      '1',    undef,  '2'],
  ['greater than',             undef,    undef,    '1',  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ['I',                        '4',      '4',    undef,  '8'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['circumflex accent',        '1',      '1',    undef,  '2'],
  ['grave accent',             '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  '1',      '1',    undef,  '2'],
  ['less than',                undef,    undef,    '1',  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ['N',                        '1',      '1',    undef,  '2'],
  ['tilde',                    '1',      '1',    undef,  '2'],
  ['O',                        '6',      '6',    undef, '12'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['circumflex accent',        '1',      '1',    undef,  '2'],
  ['grave accent',             '1',      '1',    undef,  '2'],
  ['tilde',                    '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  '1',      '1',    undef,  '2'],
  ['slash',                    '1',      '1',    undef,  '2'],
  ['sharp s',                  undef,    '1',    undef,  '1'],
  ['German (sz ligature)',     undef,    '1',    undef,  '1'],
  ['single quote',             undef,    undef,    '1',  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ['THORN',                    '1',      '1',    undef,  '2'],
  ['Icelandic',                '1',      '1',    undef,  '2'],
  ['U',                        '4',      '4',    undef,  '8'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['circumflex accent',        '1',      '1',    undef,  '2'],
  ['grave accent',             '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  '1',      '1',    undef,  '2'],
  ['Y',                        '1',      '2',    undef,  '3'],
  ['acute accent',             '1',      '1',    undef,  '2'],
  ['dieresis or umlaut mark',  undef,    '1',    undef,  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ['ampersand',                undef,    undef,    '1',  '1'],
  ['(vide)',                   undef,    undef,    '1',  '1'],
  ["Total g\x{e9}n\x{e9}ral",  '30',     '32',     '5', '67'],
 );

my @expected_dates_and_times = (
  [ '10.07.2020',  '10.07.2020',  '01.02.1989', '10.07.2020 02:57:00', '02:57:59'],
  [ '10.07.2020',  '10.07.2020',  '31.12.1999', '10.07.2020 02:57:59', '01:23:00'],
  [ '10.07.2020',         undef,  '01.01.1900',                 undef, '01:26:18'],
  [ '10.07.2020',         undef,  '02.01.1900',                                  ],
  [ '10.07.2020',         undef,  '28.02.1900'                                   ],
  [ '10.07.2020',         undef,  '01.03.1900'                                   ],
  [ '10.07.2020',         undef,  '01.03.1900'                                   ],
  [ '10.07.2020',         undef,  '04.04.4444'                                   ],
  [ '10.07.2020'                                                                 ],
  [ '10.07.2020'                                                                 ],
  [ '10.07.2020'                                                                 ],
 );
# NOTE : cell C6 displays "29.02.1900" in Excel, but that date does not exist, so
# this module gets 01.03.1900 instead.

my @expected_dates_1904 = (
  ['11.07.2024', '11.07.2024', '01.02.1989',],
  ['11.07.2024', '11.07.2024', '31.12.1999',],
  ['11.07.2024',        undef, '02.01.1904',],
  ['11.07.2024',        undef, '03.01.1904',],
  ['11.07.2024',        undef, '29.02.1904',],
  ['11.07.2024',        undef, '01.03.1904',],
  ['11.07.2024',        undef, '02.03.1904',],
  ['11.07.2024',        undef, '05.04.4448',],
  ['11.07.2024',                            ],
  ['11.07.2024',                            ],
  ['11.07.2024',                            ],
);


my @expected_mappe = (
  [qw/a	b	c	d	e	a                                           /],
  [qw/a	b	c	d	e	b                                           /],
  [qw/a	b	c	d	e	c                                           /],
  [qw/a	b	c	d	e	d                                           /],
  [qw/a	b	c	d	e	e                                           /],
  [qw/a	b	bla-bla-bla	bla-bla-bla	bla-bla-bla	f                   /],
  [qw/a	b	bla-bla-bla	bla-bla-bla	bla-bla-bla	1                   /],
  [qw/a	b	bla-bla-bla	bla-bla-bla	bla-bla-bla	2                   /],
  [qw/a	b	bla-bla-bla	d	e	3                                   /],
  [qw/a	b	bla-bla-bla	d	e	5                                   /],
  [qw/a	b	c	d	e	6                                           /],
  [qw/1	11	bla-bla-bla	bla-bla-bla	bla-bla-bla	z                   /],
  [qw/2	12	bla-bla-bla	bla-bla-bla	bla-bla-bla	v                   /],
  [qw/3	13	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla         /],
  [qw/4	14	c	d	e	bla-bla-bla                                 /],
  [qw/5	15	c	d	e	bla-bla-bla                                 /],
  [qw/6	16	c	d	e	bla-bla-bla                                 /],
  [qw/7	17	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla         /],
  [qw/8	18	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla         /],
  [qw/9	19	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla         /],
  [qw/10	20	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla /],
  [qw/11	21	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla /],
  [qw/12	22	bla-bla-bla	bla-bla-bla	bla-bla-bla	bla-bla-bla /],
);


my @expected_tab_names = qw(Entities tab_foobar tab_in_middle_of_sheet tab_without_headers
                            Cols_with_entities HasTotals);


my @expected_tab_foobar = (
  {foo => 11, bar => 22},
  {foo => 33, bar => 44},
 );

my @expected_tab_badambum = (
  {badam => 99, bum => 88},
  {badam => 77, bum => 66},
 );

my @expected_tab_no_headers = (
  {col1 => 'aa', col2 => 'bb',  col3 => 'cc'},
  {col1 => 'dd', col2 => undef, col3 => undef},
  {col1 => 'ee', col2 => 'ff',  col3 => 'gg'},
 );

my @expected_tab_cols_with_entities = (
  {'col<' => 'foo', 'col&' => 'bar', 'col>' => 'bim'},
);


my @expected_tab_HasTotals = (
  {x => 11, y => 22, z => 33},
  {x => 44, y => 55, z => 66},
  {x => 77, y => 88, z => 99},
);

my @expected_tab_HasTotals_incl_totals = (
  @expected_tab_HasTotals,
  {x => 77, y =>  3, z => 198},
 );


my @expected_tab_by_ref = (
  {Name => 'amp', Char => '&'},
  {Name => 'gt',  Char => '>'},
  {Name => 'lt',  Char => '<'},
 );


my @expected_without_r = (
  [qw/One      two      three/],
  [qw/four     five     six  /],
  [qw/seven    eight    nine /],
  [11, 22],
  [],
  [33, 44],
 );


my @backends = ('Regex');
push @backends, 'LibXML' if check_install(module => 'XML::LibXML::Reader');

foreach my $backend (@backends) { 

  # regular tests on values and tables
  run_tests($xl_file, $backend, qw/values table/);

  # iterator tests 
  run_tests($xl_file, $backend, sub {list(scalar shift->ivalues(@_))},
                                sub {my ($cols, $it) = shift->itable(@_); ($cols, list($it))});
}

sub run_tests {
  my ($xl_source, $backend, $values_meth, $table_meth) = @_;

  my $context = $backend;
  $context   .= "--iterator" if ref $values_meth;

  # dirty hack when testing with LibXML, because \r\n are silently transformed into \n
  local $expected_values[-1][0] = "cell\nwith\nembedded newlines"
    if $backend eq 'LibXML';

  # instantiate the reader
  my $reader = Excel::ValueReader::XLSX->new(xlsx => $xl_source, using => $backend);

  # check sheet names
  my @sheet_names = $reader->sheet_names;
  is_deeply(\@sheet_names, \@expected_sheet_names, "sheet names using $context");

  # check active_sheet
  is($reader->active_sheet, $expected_active_sheet, "active_sheet using $context");

  # check a regular sheet
  my $values = $reader->$values_meth('Test');
  is_deeply($values, \@expected_values, "values using $context");
  my $nb_cols = max map {scalar @$_} @$values;
  is ($nb_cols, 6, "nb_cols using $context");

  # check an empty sheet
  my $empty  = $reader->$values_meth('Empty');
  is_deeply($empty, [], "empty values using $context");

  # sheet with holes
  my $shallow  = $reader->$values_meth('RemoteCells');
  is $shallow->[0][707],  'aaf1',     'remote horizontal cell';
  is $shallow->[2555][0], 'a2556',    'remote vertical cell';

  # tables
  my ($entity_columns, $entities) = $reader->$table_meth('Entities');
  is_deeply($entity_columns, [qw(Num Name Char Cap/small Letter Variant)],
                                           "column names, using $context");
  is $entities->[0]{Name},   'amp'       , "1st table row, name, using $context";
  is $entities->[0]{Letter}, 'ampersand' , "1st table row, letter, using $context";
  is $entities->[-1]{Name},  'yuml' ,      "last table row, name, using $context";

  is_deeply([$reader->table_names], \@expected_tab_names, "table names, using $context");

  my $tab_foobar = $reader->$table_meth('tab_foobar', want_records => 1); # arg useless, this is the default
  is_deeply($tab_foobar, \@expected_tab_foobar, "tab_foobar, using $context");

  my $rows_foobar = $reader->$table_meth('tab_foobar', want_records => 0);
  is_deeply($rows_foobar, [map {[@{$_}{qw/foo bar/}]} @expected_tab_foobar], "rows_foobar, using $context");

  my $tab_badambum = $reader->$table_meth('tab_in_middle_of_sheet');
  is_deeply($tab_badambum, \@expected_tab_badambum, "tab_badambum, using $context");

  my ($col_headers, $tab_no_headers) = $reader->$table_meth('tab_without_headers');
  is_deeply($tab_no_headers, \@expected_tab_no_headers, "tab_no_headers, using $context");

  my $tab_cols_with_entities = $reader->$table_meth('Cols_with_entities');
  is_deeply($tab_cols_with_entities, \@expected_tab_cols_with_entities, "tab_cols_with_entities, using $context");

  my $tab_has_totals = $reader->$table_meth('HasTotals');
  is_deeply($tab_has_totals, \@expected_tab_HasTotals, "tab_HasTotals, using $context");

  my $tab_has_totals_incl_totals = $reader->$table_meth('HasTotals', with_totals => 1);
  is_deeply($tab_has_totals_incl_totals, \@expected_tab_HasTotals_incl_totals, "tab_HasTotals with_totals=>1, using $context");

  my $tab_by_ref = $reader->$table_meth(sheet => "Entities", ref => "B1:C4");
  is_deeply($tab_by_ref, \@expected_tab_by_ref, "tab_by_ref");

  # access a table by sheet number
  $entities = $reader->$table_meth(sheet => 3); # 3=Entities
  is $entities->[0]{Name},   'amp'       , "by sheet num, 1st table row, name, using $context";
  is $entities->[0]{Letter}, 'ampersand' , "by sheet num, 1st table row, letter, using $context";
  is $entities->[-1]{Name},  'yuml' ,      "by sheet num, last table row, name, using $context";

  # check a pivot table
  my $tab_entities = $reader->$values_meth('Tab_entities');
  is_deeply($tab_entities, \@expected_tab_entities, "tab_entities using $context");

  # check date conversions
  my $dates = $reader->$values_meth('Dates');
  is_deeply($dates, \@expected_dates_and_times, "dates using $context");

  # check time conversions with rounding hack
  my $t1 = $reader->formatted_date("44022.123599537037", "[h]:mm:ss");
  is($t1, '02:57:59', 'time conversion 1');
  my $t2 = $reader->formatted_date("0.123599537037", "[h]:mm:ss");
  is($t2, '02:57:59', 'time conversion 2');

  # other date format
  my $expected_other_format = clone \@expected_dates_and_times;
  foreach my $row (@$expected_other_format) {
    $_ and s/^(\d\d)\.(\d\d)\.\d\d(\d\d)/$2-$1-$3/ foreach @$row;
  }
  my $other_reader = Excel::ValueReader::XLSX->new(xlsx => $xl_source, using => $backend,
                                                   date_format => "%m-%d-%y");
  my $other_dates = $other_reader->$values_meth('Dates');
  is_deeply($other_dates, $expected_other_format, "dates with other format, using $context");


  # no date format
  my $reader_no_date = Excel::ValueReader::XLSX->new(xlsx => $xl_source, using => $backend,
                                                     date_formatter => undef);
  my $dates_raw_nums  = $reader_no_date->$values_meth('Dates');
  my @all_vals_flat   = grep {$_} map {@$_} @$dates_raw_nums;
  my $are_all_numbers = all {looks_like_number($_)} @all_vals_flat;
  ok($are_all_numbers, "dates with no format, using $context");


  # Excel file in 1904 date format
  my $reader_1904 = Excel::ValueReader::XLSX->new(xlsx => $xl_1904, using => $backend);
  my $dates_1904  = $reader_1904->$values_meth('Dates');
  is_deeply($dates_1904, \@expected_dates_1904, "dates in 1904 format, using $context");

  # some edge cases provided by https://github.com/ulibuck
  my $reader_ulibuck = Excel::ValueReader::XLSX->new(xlsx => $xl_ulibuck, using => $backend);
  my $example1       = $reader_ulibuck->$values_meth('Example');
  is($example1->[3][2], '30.12.2021', "date1904=\"false\", using $context");
  my $example2       = $reader_ulibuck->$values_meth('Example two');
  is($example2->[12][2], '# Dummy', "# Dummy, using $context");

  # in this workbook the active_sheet is deliberately empty
  ok(! defined $reader_ulibuck->active_sheet, "empty active_sheet, using $context");

  # https://github.com/damil/Excel-ValueReader-XLSX/issues/2 : empty string (ulibuck++)
  my $reader_mappe = Excel::ValueReader::XLSX->new(xlsx => $xl_mappe, using => $backend);
  my $strings      = $reader_mappe->$values_meth('Tabelle2');
  is_deeply $strings, \@expected_mappe, "empty string nodes, using $context";

  # cells do not always have a 'r' attribute
  my $reader_without_r = Excel::ValueReader::XLSX->new(xlsx => $xl_without_r, using => $backend);
  my $vals = $reader_without_r->$values_meth(1);
  is_deeply $vals, \@expected_without_r, "cells without 'r' attribute, using $context";
}



done_testing();

