# -*- cperl -*-
# ABSTRACT: BeamerFrame object


package BeamerReveal::Object::BeamerFrame;
our $VERSION = '20260205.0754'; # VERSION

use parent 'BeamerReveal::Object';
use Carp;

use Data::Dumper;

use BeamerReveal::TemplateStore;
use BeamerReveal::MediaManager;

use BeamerReveal::Log;

use Digest::SHA;


our $maxRawPage;
our $maxNotePage = 0;
our $embeddedID;

sub nofdigits { length( "$_[0]" ) }

sub new {
  my $class = shift;
  my ( $chunkData, $lines, $lineCtr, $rawpage ) = @_;
  
  $class = (ref $class ? ref $class : $class );
  my $self = {};
  bless $self, $class;

  my $logger = $BeamerReveal::Log::logger;
  
  $self->{videos}     = [];
  $self->{audios}     = [];
  $self->{images}     = [];
  $self->{iframes}    = [];
  $self->{animations} = [];
  $self->{stills}     = [];
  $self->{hasnotes}   = 0;

  ++$lineCtr;
  for ( my $i = 0; $i < @$lines; ++$i ) {
    ( $lines->[$i] =~ /^-(?<command>\w+):(?<payload>.*)$/ )
      or $logger->fatal( "Error: syntax incorrect in rvl file on line $lineCtr '$lines->[$i]'\n" );
    if ( $+{command} eq 'parameters' ) {
      $self->{parameters} = BeamerReveal::Object::readParameterLine( $+{payload} );
      # The correctness of this relies on the pages appearing in order in the .rvl file
      # however, the rawpage counter of LaTeX is not all cases a true arabic counter and
      # therefore not reliable
      $self->{parameters}->{rawpage} = $rawpage;
      $maxRawPage = $rawpage;
    } elsif ( $+{command} eq 'video' ) {
      push @{$self->{videos}}, BeamerReveal::Object::readParameterLine( $+{payload} );
    } elsif ( $+{command} eq 'audio' ) {
      push @{$self->{audios}}, BeamerReveal::Object::readParameterLine( $+{payload} );
    } elsif ( $+{command} eq 'image' ) {
      push @{$self->{images}}, BeamerReveal::Object::readParameterLine( $+{payload} );
    } elsif ( $+{command} eq 'iframe' ) {
      push @{$self->{iframes}}, BeamerReveal::Object::readParameterLine( $+{payload} );
    } elsif ( $+{command} eq 'animation' ) {
      push @{$self->{animations}}, BeamerReveal::Object::readParameterLine( $+{payload} );
      $self->{animations}->[-1]->{tex} = $lines->[++$i];
    } elsif ( $+{command} eq 'still' ) {
      push @{$self->{stills}}, BeamerReveal::Object::readParameterLine( $+{payload} );
      $self->{stills}->[-1]->{tex} = $lines->[++$i];
    } elsif ( $+{command} eq 'hasnote' ) {
      $self->{hasnotes} = 1;
    } else {
      $logger->fatal( "Error: unknown BeamerFrame data on line @{[ $lineCtr + $i ]} '$lines->[$i]'\n" );
    }
  }
  ++$maxNotePage if $self->{hasnotes};
  
  $embeddedID = 0 unless defined( $embeddedID );
  
  return $self;
}


sub makeSlide {
  my $self = shift;
  my ( $i, $mediaManager, $presentation ) = @_;

  my $logger = $BeamerReveal::Log::logger;
  $logger->log( 2, "- making slide $i" );
  
  my $templateStore = BeamerReveal::TemplateStore->new();
  my $content = '';

  my $slideEmbed =
    exists $self->{parameters}->{embed} or exists $presentation->{parameters}->{embed};
  
  ###############################################
  # process all video material / can be embedded
  foreach my $video (@{$self->{videos}}) {
    my %commonStamps = ( X => _topercent( $video->{x} ),
			 Y => _topercent( $video->{y} ),
			 W => _topercent( $video->{width} ),
			 H => _topercent( $video->{height} ),
			 VIDEOID          => 'embedded-id-' . $embeddedID++,
			 VIDEOEMBEDDEDB64 => $videoContent,
			 MIMETYPE         => $mimeType,
			 FIT => $video->{fit},
			 AUTOPLAY => exists $video->{autoplay} ? 'data-autoplay' : '',
			 CONTROLS => exists $video->{controls} ? 'controls' : '',
			 MUTED => exists $video->{muted} ? 'muted' : '',
			 LOOP => exists $video->{loop} ? 'loop' : '',
		       );
    my $vStamps;
    my $vTemplate;
    if ( exists $video->{embed} or $slideEmbed ) {
      $logger->log( 4, "- adding embedded video" );
      $vTemplate = $templateStore->fetch( 'html', 'video-embedded.html' );
      my ( $mimeType ) = $mediaManager->videoFromStore( $video->{file},
								       to_embed => 1 );
      $vStamps = { %commonStamps,
		   VIDEOID          => 'embedded-id-' . $embeddedID++,
		   VIDEOEMBEDDEDB64 => $videoContent,
		   MIMETYPE         => $mimeType,
		 };
    } else {
      $logger->log( 4, "- adding video" );
      $vTemplate = $templateStore->fetch( 'html', 'video.html' );
      my ( $mimeType, $videoFile ) = $mediaManager->videoFromStore( $video->{file} );
      $vStamps = { %commonStamps,
		   VIDEO => $videoFile
		 };
    }
    $content .= BeamerReveal::TemplateStore::stampTemplate( $vTemplate, $vStamps);
  }

  ###############################################
  # process all audio material / can be embedded
  foreach my $audio (@{$self->{audios}}) {
    my %commonStamps = ( X => _topercent( $audio->{x} ),
			 Y => _topercent( $audio->{y} ),
			 W => _topercent( $audio->{width} ),
			 H => _topercent( $audio->{height} ),
			 FIT => $audio->{fit},
			 AUTOPLAY => exists $audio->{autoplay} ? 'data-autoplay' : '',
			 CONTROLS => exists $audio->{controls} ? 'controls' : '',
			 MUTED => exists $audio->{muted} ? 'muted' : '',
			 LOOP => exists $audio->{loop} ? 'loop' : '' );
    my $aStamps;
    my $aTemplate;
    if ( exists $audio->{embed} or $slideEmbed ) {
      $logger->log( 4, "- adding embedded audio" );
      $aTemplate = $templateStore->fetch( 'html', 'audio-embedded.html' );
      my ( $mimeType, $audioContent ) = $mediaManager->audioFromStore( $audio->{file},
								       to_embed => 1 );
      $aStamps = { %commonStamps,
		   AUDIOID          => 'embedded-id-' . $embeddedID++,
		   AUDIOEMBEDDEDB64 => $audioContent,
		   MIMETYPE         => $mimeType,
		 };
    } else {
      $logger->log( 4, "- adding audio" );
      $aTemplate = $templateStore->fetch( 'html', 'audio.html' );
      my ( $mimeType, $audioFile ) = $mediaManager->audioFromStore( $audio->{file} );
      $aStamps = { %commonStamps,
		   AUDIO => $audioFile,
		 };
    }
    $content .= BeamerReveal::TemplateStore::stampTemplate( $aTemplate, $aStamps );
  }

  ###############################################
  # process all image material / can be embedded
  foreach my $image (@{$self->{images}}) {
    my %commonStamps = ( X => _topercent( $image->{x} ),
			 Y => _topercent( $image->{y} ),
			 W => _topercent( $image->{width} ),
			 H => _topercent( $image->{height} ),
			 IMAGEID          => 'embedded-id-' . $embeddedID++,
			 IMAGEEMBEDDEDB64 => $imageContent,
			 MIMETYPE         => $mimeType,
			 FIT              => $image->{fit}
		       );
    my $iStamps;
    my $iTemplate;
    if ( exists $image->{embed} or $slideEmbed ) {
      $logger->log( 4, "- adding embedded image" );
      $iTemplate = $templateStore->fetch( 'html', 'image-embedded.html' );
      my( $mimeType, $imageContent ) = $mediaManager->imageFromStore( $image->{file},
								      to_embed => 1 );
      $iStamps = { %commonStamps,
		   IMAGEID          => 'embedded-id-' . $embeddedID++,
		   IMAGEEMBEDDEDB64 => $imageContent,
		   MIMETYPE         => $mimeType,
		 };
    } else {
      $logger->log( 4, "- adding image" );
      $iTemplate = $templateStore->fetch( 'html', 'image.html' );
      my( $mimeType, $imageFile ) = $mediaManager->imageFromStore( $image->{file} );
      $iStamps = { %commonStamps,
		   IMAGE => $imageFile };
    }
    $content .= BeamerReveal::TemplateStore::stampTemplate( $iTemplate,
							    $iStamps );
  }

  ################################################
  # process all iframe material / can be embedded
  foreach my $iframe (@{$self->{iframes}}) {
    my %commonStamps = ( X => _topercent( $iframe->{x} ),
			 Y => _topercent( $iframe->{y} ),
			 W => _topercent( $iframe->{width} ),
			 H => _topercent( $iframe->{height} ),
			 FIT => $iframe->{fit}
		       );
    my $iStamps;
    my $iTemplate;
    if ( exists $iframe->{embed} or exists $presentation->{parameters}->{embed} ) {
      $logger->log( 4, "- adding embedded iframe" );
      $iTemplate = $templateStore->fetch( 'html', 'iframe-embedded.html' );
      my ( $mimeType, $iframeContent ) = $mediaManager->iframeFromStore( $iframe->{file},
									 to_embed => 1 );
      $iStamps = { %commonStamps,
		   IFRAMEID          => 'embedded-id-' . $embeddedID++,
		   IFRAMEEMBEDDEDB64 => $iframeContent,
		 };
    } else {
      $logger->log( 4, "- adding iframe" );
      $iTemplate = $templateStore->fetch( 'html', 'iframe.html' );
      my ( $mimeType, $iframeFile ) = $mediaManager->iframeFromStore( $iframe->{file} );
      $iStamps = { %commonStamps,
		   IFRAME => $iframeFile,
		 };
    }
    $content .= BeamerReveal::TemplateStore::stampTemplate( $iTemplate,
							    $iStamps );
  }

  ##################################################
  # process all animations / cannot yet be embedded
  foreach my $animation (@{$self->{animations}}) {
    $logger->log( 4, "- adding animation" );
    
    my $aTemplate;
    my $aStamps;

    # 1. Generate the animation
    my $file = $mediaManager->animationFromStore( $animation );
    
    # 2. Embed it into the html
    $aTemplate = $templateStore->fetch( 'html', 'animation.html' );
    $aStamps =
      { X => _topercent( $animation->{x} ),
	Y => _topercent( $animation->{y} ),
	W => _topercent( $animation->{width} ),
	H => _topercent( $animation->{height} ),
	AUTOPLAY  => exists $animation->{autoplay} ? 'data-autoplay' : '',
	CONTROLS  => exists $animation->{controls} ? 'controls' : '',
	LOOP      => exists $animation->{loop} ? 'loop' : '',
	ANIMATION => $file,
	FIT       => $animation->{fit}
      };
    $content .= BeamerReveal::TemplateStore::stampTemplate( $aTemplate,
							    $aStamps );
  }

  ##############################################
  # process all stills / cannot yet be embedded
  foreach my $still (@{$self->{stills}}) {
    $logger->log( 4, "- adding still" );

    # 1. Generate the animation
    my $file = $mediaManager->stillFromStore( $still );
    
    # 2. Embed it into the html
    my $sTemplate = $templateStore->fetch( 'html', 'still.html' );
    my $sStamps =
      { X => _topercent( $still->{x} ),
	Y => _topercent( $still->{y} ),
	W => _topercent( $still->{width} ),
	H => _topercent( $still->{height} ),
	STILL => $file,
	FIT       => $still->{fit}
      };
    $content .= BeamerReveal::TemplateStore::stampTemplate( $sTemplate,
							    $sStamps );
  }

  ###########################
  # process the frame itself

  # title
  my $title = _modernize( $self->{parameters}->{title} );
  if ( $title =~ /\\/ ) {
    $logger->fatal( "Error: the title of slide $i contains TeX-like code (observe below between <<< >>>); provide a clean version using \\frametitle[clean-version]{TeX-like code}\n" .
   		    "<<< $self->{parameters}->{title} >>>" );
  } else {
    $self->{parameters}->{title} = $title;
  }
  ;

  # menu entries
  my $menuTitle;
  if ( exists $self->{parameters}->{toc} ) {
    if ( $self->{parameters}->{toc} eq 'titlepage' ) {
      $menuTitle = "<span class='menu-title'>%s</span>";
    } elsif ( $self->{parameters}->{toc} eq 'section' ) {
      $menuTitle = "<span class='menu-section'>&bull; %s</span>";
    } elsif ( $self->{parameters}->{toc} eq 'subsection' ) {
      $menuTitle = "<span class='menu-subsection'>&SmallCircle; %s</span>";
    } else {
      $logger->fatal( "Error: invalid toc parameter in rvl file" );
    }
  } else {
    $menuTitle = "<span class='menu-slide'>&bullet; %s</span>";
  }
  $menuTitle = sprintf( $menuTitle,
			$self->{parameters}->{title} );

  # autoSlide
  my $autoSlide = '';
  if( exists $self->{parameters}->{autoslide} ) {
    $autoSlide = 'data-autoslide="' . $self->{parameters}->{autoslide} . '"';
  }
  
  # notes
  my $notes = ' '; # the space is important as default, if you remove it, the notes will be sticky!
  
  if ( $self->{hasnotes} ) {
    if ( $slideEmbed ) {
      my $nTemplate = $templateStore->fetch( 'html', 'note-embedded.html' );
      
      # remember: the hasnote entry holds the note number
      my ( $mimeType, $notesImage ) = $mediaManager->noteFromStore( $self->{hasnotes},
								to_embed => 1 );
      
      my $nStamps =
	{
	 NOTEID          => 'embedded-id-' . $embeddedID++,
	 NOTEEMBEDDEDB64 => $notesImage,	
	 MIMETYPE        => $mimeType,
	};
      
      $notes = BeamerReveal::TemplateStore::stampTemplate( $nTemplate, $nStamps );
    }
    else {
      my $nTemplate = $templateStore->fetch( 'html', 'note.html' );
      
      # remember: the hasnote entry holds the note number
      my ( undef, $notesImage ) = $mediaManager->noteFromStore( $self->{hasnotes} );
      
      my $nStamps =
	{
	 NOTESIMAGE   => $notesImage
	};
      
      $notes = BeamerReveal::TemplateStore::stampTemplate( $nTemplate, $nStamps );
    }
  }

  # generate slide itself
  if ( $slideEmbed ) {
    my $fTemplate = $templateStore->fetch( 'html', 'beamerframe-embedded.html' );
    
    my ( $mimeType, $slideImage ) = $mediaManager->slideFromStore( $self->{parameters}->{rawpage},
								   to_embed => 1 );
    my $fStamps =
      {
       DATAMENUTITLE    => $menuTitle,
       SLIDEID          => 'embedded-id-' . $embeddedID++,
       SLIDEEMBEDDEDB64 => $slideImage,
       MIMETYPE         => $mimeType,
       SLIDECONTENT     => $content,
       TRANSITION       => $self->{parameters}->{transition} || 'fade',
       AUTOSLIDE        => $autoSlide,
       NOTESIMAGE       => $notes
      };
    
    return BeamerReveal::TemplateStore::stampTemplate( $fTemplate, $fStamps );
    
  } else {
    my $fTemplate = $templateStore->fetch( 'html', 'beamerframe.html' );
    
    my ( undef, $slideImage ) = $mediaManager->slideFromStore( $self->{parameters}->{rawpage} );
    
    my $fStamps =
      {
       DATAMENUTITLE => $menuTitle,
       SLIDEIMAGE    => $slideImage,
       SLIDECONTENT  => $content,
       TRANSITION    => $self->{parameters}->{transition} || 'fade',
       AUTOSLIDE     => $autoSlide,
       NOTESIMAGE    => $notes
      };
    
    return BeamerReveal::TemplateStore::stampTemplate( $fTemplate, $fStamps );
  }
}

sub _topercent {
  confess() unless defined $_[0];
  return sprintf( "%.2f%%", $_[0] * 100 );
}

sub _modernize {
  my $string = shift;
  defined( $string ) or die();
  my $dictionary = {
		    qr/\\`\{?a\}?/ => 'à',
		    qr/\\'\{?a\}?/ => 'á',
		    qr/\\"\{?a\}?/ => 'ä',
		    qr/\\\^\{?a\}?/ => 'â',
		    qr/\\~\{?a\}?/ => 'ã',
		    qr/\\=\{?a\}?/ => 'ā',
		    qr/\\\.\{?a\}?/ => 'ȧ',
		    qr/\\u\{?a\}?/ => 'ă',
		    qr/\\v\{?a\}?/ => 'ǎ',
		    qr/\\c\{?a\}?/ => 'ą',
		    qr/\\r\{?a\}?/ => 'å',
		    qr/\\`\{?e\}?/ => 'è',
		    qr/\\'\{?e\}?/ => 'é',
		    qr/\\"\{?e\}?/ => 'ë',
		    qr/\\\^\{?e\}?/ => 'ê',
		    qr/\\~\{?e\}?/ => 'ẽ',
		    qr/\\=\{?e\}?/ => 'ē',
		    qr/\\\.\{?e\}?/ => 'ė',
		    qr/\\u\{?e\}?/ => 'ĕ',
		    qr/\\v\{?e\}?/ => 'ě',
		    qr/\\c\{?e\}?/ => 'ę',
		    qr/\\`\{?\\?i(?:\{\})?\}?/ => 'ì',
		    qr/\\'\{?\\?i(?:\{\})?\}?/ => 'í',
		    qr/\\"\{?\\?i(?:\{\})?\}?/ => 'ï',
		    qr/\\\^\{?\\?i(?:\{\})?\}?/ => 'î',
		    qr/\\~\{?\\?i(?:\{\})?\}?/ => 'ĩ',
		    qr/\\=\{?\\?i(?:\{\})?\}?/ => 'ī',
		    qr/\\u\{?\\?i(?:\{\})?\}?/ => 'ĭ',
		    qr/\\v\{?\\?i(?:\{\})?\}?/ => 'ǐ',
		    qr/\\c\{?\\?i(?:\{\})?\}?/ => 'į',
		    qr/\\`\{?o\}?/ => 'ò',
		    qr/\\'\{?o\}?/ => 'ó',
		    qr/\\"\{?o\}?/ => 'ö',
		    qr/\\\^\{?o\}?/ => 'ô',
		    qr/\\~\{?o\}?/ => 'õ',
		    qr/\\=\{?o\}?/ => 'ō',
		    qr/\\\.\{?o\}?/ => 'ȯ',
		    qr/\\u\{?o\}?/ => 'ŏ',
		    qr/\\v\{?o\}?/ => 'ǒ',
		    qr/\\c\{?o\}?/ => 'ǫ',
		    qr/\\`\{?u\}?/ => 'ù',
		    qr/\\'\{?u\}?/ => 'ú',
		    qr/\\"\{?u\}?/ => 'ü',
		    qr/\\\^\{?u\}?/ => 'û',
		    qr/\\~\{?u\}?/ => 'ũ',
		    qr/\\=\{?u\}?/ => 'ū',
		    qr/\\u\{?u\}?/ => 'ŭ',
		    qr/\\v\{?u\}?/ => 'ǔ',
		    qr/\\c\{?u\}?/ => 'ų',
		    qr/\\r\{?u\}?/ => 'ů',
		    qr/\\c\{?c\}?/ => 'ç',
		    qr/\\~\{?n\}?/ => 'ñ',
		    qr/\\oe/ => 'œ',
		    qr/\\OE/ => 'Œ',
		    qr/\\&/ => '&',
		   };
  while ( my ( $regexp, $rep ) = each ( %$dictionary ) ) {
    $string =~ s/$regexp/$rep/g;
  }
  return $string;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

BeamerReveal::Object::BeamerFrame - BeamerFrame object

=head1 VERSION

version 20260205.0754

=head1 SYNOPSIS

Represents a BeamerFrame

=head1 METHODS

=head2 new()

  $bf = BeamerReveal::Object::BeamerFrame->new( $data, $lines, $linectr )

Generates a beamerframe from the correspond chunk data in the C<.rvl> file.

=over 4

=item . C<$data>

chunkdata to parse

=item . C<$lines>

body lines to parse

=item . C<$lineCtr>

starting line of the chunk (used for error reporting)

=item . C<$bf>

the beamerframe object

=back

=head2 makeSlide()

  $html = $bf->makeSlide( $i, $mediaManager, $nofNotes )

generate a HTML slides from this beamerframe.

=over 4

=item . C<$i>

the number of the slide that is generated; needed because slide number in LaTeX is dubious.

=item . C<$mediaManager>

mediamanager to use, to access all media files (and geneate animations when needed)

=item . C<$nofNotes>

total number of notes attached to the presentation; needed to zero-pad the node count in the
filenames of the note-images that are linked.

=item . C<$html>

HTML of the beamer frame, ready to be interpolated in the reveal framework.

=back

=head1 AUTHOR

Walter Daems <wdaems@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2025 by Walter Daems.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=head1 CONTRIBUTOR

=for stopwords Paul Levrie

Paul Levrie

=cut
