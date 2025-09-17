package EBook::Ishmael::EBook::zTXT;
use 5.016;
our $VERSION = '1.09';
use strict;
use warnings;

use Encode qw(decode);

use EBook::Ishmael::EBook::Metadata;
use EBook::Ishmael::PDB;
use EBook::Ishmael::TextToHtml;

my $TYPE = 'zTXT';

# Minimum version we support is 1.40. Pre-1.40 is de-standardized.
my $MINVER = 0x0128;

my $RANDOM_ACCESS = 0x1;

# Checks to see if the PDB type is 'zTXT'. The creator is ignored, as that can
# differ between zTXT creators.
sub heuristic {

    my $class = shift;
    my $file  = shift;
    my $fh    = shift;

    return 0 unless -s $file >= 68;

    seek $fh, 32, 0;
    read $fh, my ($null), 1;

    # Last byte in title must be null
    unless ($null eq "\0") {
        return 0;
    }

    seek $fh, 60, 0;
    read $fh, my ($type), 4;

    return $type eq $TYPE;

}

# Should be called with record #1 first.
sub _decode_record {

    my $self = shift;
    my $rec  = shift;

    $rec++;

    my $out = $self->{_inflate}->inflate($self->{_pdb}->record($rec)->data);

    unless (defined $out) {
        die "Error decompressing zTXT stream in $self->{Source}\n";
    }

    return $out;

}

sub _text {

    my $self = shift;

    require Compress::Zlib;

    $self->{_inflate} = Compress::Zlib::inflateInit(-WindowBits => 15)
        or die "Failed to initialize zlib inflator\n";

    my $text = join('', map { $self->_decode_record($_) } 0 .. $self->{_recnum} - 1);

    $self->{_inflate} = undef;

    return $text;

}

sub new {

    my $class = shift;
    my $file  = shift;
    my $enc   = shift // 'UTF-8';

    my $self = {
        Source       => undef,
        Metadata     => EBook::Ishmael::EBook::Metadata->new,
        Encoding     => $enc,
        _pdb         => undef,
        _version     => undef,
        _recnum      => undef,
        _size        => undef,
        _recsize     => undef,
        _bookmarknum => undef,
        _bookmarkrec => undef,
        _annotnum    => undef,
        _annotrec    => undef,
        _flags       => undef,
        _reserved    => undef,
        _crc32       => undef,
    };

    bless $self, $class;

    $self->{Source} = File::Spec->rel2abs($file);

    $self->{_pdb} = EBook::Ishmael::PDB->new($file);

    my $hdr = $self->{_pdb}->record(0)->data;

    (
        $self->{_version},
        $self->{_recnum},
        $self->{_size},
        $self->{_recsize},
        $self->{_bookmarknum},
        $self->{_bookmarkrec},
        $self->{_annotnum},
        $self->{_annotrec},
        $self->{_flags},
        $self->{_reserved},
        $self->{_crc32},
        undef
    ) = unpack "n n N n n n n n C C N C4", $hdr;

    if ($self->{_version} < $MINVER) {
        die sprintf
            "%s zTXT is of an unsupported version, %d.%d (%d.%d and above are supported).\n",
            $self->{Source},
            ($self->{_version} >> 8) & 0xff, $self->{_version} & 0xff,
            ($MINVER           >> 8) & 0xff, $MINVER           & 0xff;
    }

    unless ($self->{_flags} & $RANDOM_ACCESS) {
        die "$self->{Source} zTXT uses unsupported compression method\n";
    }

    $self->{Metadata}->title([ $self->{_pdb}->name ]);

    if ($self->{_pdb}->cdate) {
        $self->{Metadata}->created([ scalar gmtime $self->{_pdb}->cdate ]);
    }
    if ($self->{_pdb}->mdate) {
        $self->{Metadata}->modified([ scalar gmtime $self->{_pdb}->mdate ]);
    }

    $self->{Metadata}->format([
        sprintf
            "zTXT %s.%s",
            ($self->{_version} >> 8) & 0xff,
            $self->{_version}        & 0xff
    ]);

    return $self;

}

sub html {

    my $self = shift;
    my $out  = shift;

    my $html = decode($self->{Encoding}, text2html($self->_text));

    if (defined $out) {
        open my $fh, '>', $out
            or die "Failed to open $out for writing: $!\n";
        binmode $fh, ':utf8';
        print { $fh } $html;
        close $fh;
        return $out;
    } else {
        return $html;
    }

}

sub raw {

    my $self = shift;
    my $out  = shift;

    my $raw = decode($self->{Encoding}, $self->_text);

    if (defined $out) {
        open my $fh, '>', $out
            or die "Failed to open $out for writing: $!\n";
        binmode $fh, ':utf8';
        print { $fh } $raw;
        close $fh;
        return $out;
    } else {
        return $raw;
    }

}

sub metadata {

    my $self = shift;

    return $self->{Metadata}->hash;

}

sub has_cover { 0 }

sub cover { undef }

sub image_num { 0 }

sub image { undef }

1;
