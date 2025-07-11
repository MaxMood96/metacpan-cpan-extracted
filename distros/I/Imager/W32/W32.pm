package Imager::Font::W32;
use 5.006;
use strict;
use Imager;
our @ISA = qw(Imager::Font);

BEGIN {
  our $VERSION = "0.96";

  require XSLoader;
  XSLoader::load('Imager::Font::W32', $VERSION);
}

# called by Imager::Font::new()
# since Win32's HFONTs include the size information this
# is just a stub
sub new {
  my $class = shift;
  my %opts =
      (
       color => Imager::Color->new(255, 0, 0),
       size => 15,
       @_,
      );

  return bless \%opts, $class;
}

sub _bounding_box {
  my ($self, %opts) = @_;
  
  my @bbox = i_wf_bbox($self->{face}, $opts{size}, $opts{string}, $opts{utf8});
  unless (@bbox) {
    Imager->_set_error(Imager->_error_as_msg);
    return;
  }

  return @bbox;
}

sub _draw {
  my $self = shift;

  my %input = @_;
  if (exists $input{channel}) {
    return i_wf_cp($self->{face}, $input{image}{IMG}, $input{x}, $input{'y'},
	    $input{channel}, $input{size},
	    $input{string}, $input{align}, $input{aa}, $input{utf8});
  }
  else {
    return i_wf_text($self->{face}, $input{image}{IMG}, $input{x}, 
	      $input{'y'}, $input{color}, $input{size}, 
	      $input{string}, $input{align}, $input{aa}, $input{utf8});
  }
}


sub utf8 {
  return 1;
}

sub can_glyph_names {
  return;
}

1;

__END__

=head1 NAME

Imager::Font::W32 - font support using C<GDI> on Win32

=head1 SYNOPSIS

  use Imager;

  my $img = Imager->new;
  my $font = Imager::Font->new(face => "Arial", type => "w32");

  $img->string(... font => $font);

=head1 DESCRIPTION

This provides font support on Win32.

=head1 CAVEATS

Unfortunately, older versions of Imager would install
Imager::Font::Win32 even if Win32 wasn't available, and if no font was
created would succeed in loading the module.  This means that an
existing Win32.pm could cause a probe success for Win32 fonts, so I've
renamed it.

=head1 AUTHOR

Tony Cook <tonyc@cpan.org>

=head1 SEE ALSO

Imager, Imager::Font.

=cut
