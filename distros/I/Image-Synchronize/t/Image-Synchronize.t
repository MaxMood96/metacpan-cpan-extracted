# -*- perl -*-
use Modern::Perl;

use Carp;
use Image::Synchronize qw(normalize_options);
use Image::Synchronize::GroupedInfo;
use Image::Synchronize::Logger;
use Image::Synchronize::Timestamp;
use Test::More;
use YAML::Any qw(Dump Load);

# We need to mock the timezone offset of the local system, because it
# varies from one system to the next.
my $TZ = 3600;                  # default: UTC+1
sub settz {
  $TZ = $_[0];
}
sub gettz {
  return $TZ;
}
{
  no warnings qw(redefine);
  sub Image::Synchronize::Timestamp::local_timezone_offset {
    gettz();
  }
}

sub insert_image_info {
  my ($s, $filename, %info) = @_;
  my $g = $s->{original_info}->{$filename}
    = Image::Synchronize::GroupedInfo->new;
  $g->set('CameraID',
          ($info{make} // 'make') . '|'
          . ($info{model} // 'model') . '|'
          . ($info{serialnumber} // ''))
    ->set('EXIF', 'CreateDate',
          Image::Synchronize::Timestamp->new($info{createdate}))
    ->set('EXIF', 'DateTimeOriginal',
          Image::Synchronize::Timestamp->new($info{datetimeoriginal}
                                             // $info{createdate}))
    ->set('File', 'FileModifyDate',
          Image::Synchronize::Timestamp->new($info{filemodifydate}
                                             // '2020-08-02 10:45:51+02:00'))
    ->set('File', 'MIMEType', 'image/jpeg')
    ->set('EXIF', 'Make', $info{make} // 'make')
    ->set('EXIF', 'Model', $info{model} // 'model')
    ->set('EXIF', 'SerialNumber', $info{serialnumber});
  my $num = $1 if $filename =~ /(\d+)[^0-9]*$/;
  $g->set('camera_id', Image::Synchronize::camera_id($g))
    ->set('createdate_was_embedded', defined($g->get('CreateDate')))
    ->set('fallback_camera_id',
          Image::Synchronize::fallback_camera_id($filename))
    ->set('file_type', 'image')
    ->set('image_number', $num);
  $s;
}

sub trf {
  my ($text) = @_;
  $text =~ s/^(ImsyncVersion \(XMP\) +:)(.*)$/$1 VERSION/m;
  return $text;
}

sub giformat {
  my (%data) = @_;
  my @lines;
  foreach my $key (sort keys %data) {
    push @lines, sprintf('%-35s : ', $key) . $data{$key};
  }
  return join("\n", @lines);
}

# If a test fails then we want to see where the newlines in the dumped
# YAML are
sub shownl {
  croak "shownl only works on single scalars"
    if @_ > 1;
  my ($text) = @_;
  return $text =~ s/\n/<\n/gr;
}

Image::Synchronize::Logger->new({name => '',
                                 min_level => 0,
                                 action => sub {}})->set_as_default;

my $s = Image::Synchronize->new;

insert_image_info($s, 'IMG0002.jpg',
                 createdate => '2020-08-02 10:45:51');
is($s->determine_new_values_for_file('IMG0002.jpg'), 1, 'first image');
is(trf($s->{new_info}->{'IMG0002.jpg'}->stringify),
   giformat(
            'CameraID (XMP)'          => 'make|model|',
            'CreateDate'              => '2020:08:02 10:45:51',
            'DateTimeOriginal'        => '2020:08:02 10:45:51',
            'DateTimeOriginal (XMP)'  => '2020:08:02 10:45:51+01:00',
            'FileModifyDate'          => '2020:08:02 10:45:51+01:00',
            'ImsyncVersion (XMP)'     => 'VERSION',
            'TimeSource (XMP)'        => 'Other',
          ),
   'first image -- new values');
is(shownl($s->{gps_offsets}->stringify),
   shownl(Dump(
               {
                'make|model|' =>
                { '2020-08-02T10:45:51' =>  '+00:00+01:00' },
              }
             )),
   'first image -- offsets');

insert_image_info($s, 'IMG0004.jpg',
                 createdate => '2020-08-02 10:48:04');
is($s->determine_new_values_for_file('IMG0004.jpg'), 1, 'second image');
is(trf($s->{new_info}->{'IMG0004.jpg'}->stringify),
   giformat(
            'CameraID (XMP)'         => 'make|model|',
            'CreateDate'             => '2020:08:02 10:48:04',
            'DateTimeOriginal'       => '2020:08:02 10:48:04',
            'DateTimeOriginal (XMP)' => '2020:08:02 10:48:04+01:00',
            'FileModifyDate'         => '2020:08:02 10:48:04+01:00',
            'ImsyncVersion (XMP)'    => 'VERSION',
            'TimeSource (XMP)'       => 'Other',
          ),
   'second image -- new values');
is(shownl($s->{gps_offsets}->stringify),
   shownl(Dump(
               {
                'make|model|' =>
                {
                 '2020-08-02T10:45:51' => '+00:00+01:00',
                 '2020-08-02T10:48:04' => '+00:00+01:00',
               }
              }
             )),
   'second image -- offsets');

# tests of normalize_options
is(Dump([normalize_options('a', 'b', 'c')]),
   Dump(['a', 'b', 'c']), 'normalize_options b');

is(Dump([normalize_options('a', '-b', 'c')]),
   Dump(['a', '-b', 'c']), 'normalize_options -b');

is(Dump(normalize_options('--b')), Dump('--b'), 'normalize_options --b');

is(Dump(normalize_options('---b')), Dump('---b'),
   'normalize_options ---b');

is(Dump(normalize_options('--b_o-O')), Dump('--boO'),
   'normalize_options --b_o-O');

is(Dump(normalize_options('--b_-O')), Dump('--bO'),
   'normalize_options --b_-O');

is(Dump(normalize_options('--b=f--o__O')), Dump('--b=f--o__O'),
   'normalize_options --b=f--o__O');

is(Dump(normalize_options('--b:f--o__O')), Dump('--b:f--o__O'),
   'normalize_options --b:f--o__O');

is(Dump(normalize_options('--b f--o__O')), Dump('--b f--o__O'),
   'normalize_options --b f--o__O');

done_testing();
