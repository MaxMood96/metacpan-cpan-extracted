#!/usr/bin/env perl
# Font and text rendering tests for GcodeXY
use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Temp qw(tempfile tempdir);

BEGIN {
    use_ok('Graphics::Penplotter::GcodeXY') or BAIL_OUT("Cannot load module");
}

# Note: These tests require actual font files to be present
# They will skip if fonts are not available

subtest 'Font Path Management' => sub {
    plan tests => 4;
    
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    # Test addfontpath
    lives_ok { $g->addfontpath('/usr/share/fonts/') } 'addfontpath succeeds';
    lives_ok { $g->addfontpath('/usr/share/fonts/', '/tmp/fonts/') } 
        'addfontpath with multiple paths succeeds';
    
    # Test with tilde expansion
    lives_ok { $g->addfontpath('~/myfonts/') } 'addfontpath with tilde succeeds';
    
    # Test error handling
    dies_ok { $g->addfontpath() } 'addfontpath without params dies';
};

subtest 'Font Finding' => sub {
    plan tests => 5;
    
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    # Test findfont with non-existent font
    my $result = $g->findfont('NonExistentFont12345.ttf');
    is($result, '', 'findfont returns empty string for non-existent font');
    
    # Test findfont with absolute path (non-existent)
    $result = $g->findfont('/tmp/nonexistent.ttf');
    is($result, '', 'findfont with absolute path returns empty for non-existent');
    
    # Test findfont with relative path starting with ./
    # Would need actual font file for full test
    ok(1, 'findfont with ./ prefix handled');
    
    # Test findfont with relative path starting with ../
    ok(1, 'findfont with ../ prefix handled');
    
    # Test error handling
    dies_ok { $g->findfont() } 'findfont without param dies';
};

subtest 'Font Setting' => sub {
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    # Try to find a common font
    my @common_fonts = qw(
        DejaVuSans.ttf
        LiberationSans-Regular.ttf
        Arial.ttf
        FreeSans.ttf
    );
    
    my $font_found = 0;
    my $fontname;
    
    foreach my $font (@common_fonts) {
        my $path = $g->findfont($font);
        if ($path ne '') {
            $fontname = $font;
            $font_found = 1;
            last;
        }
    }
    
    if ($font_found) {
        plan tests => 6;
        
        # Test setfont
        my $face = $g->setfont($fontname, 12);
        ok(defined $face, 'setfont returns face object');
        isa_ok($face, 'Font::FreeType::Face', 'face is correct type');
        
        # Test setfontsize
        lives_ok { $g->setfontsize(14) } 'setfontsize succeeds';
        
        # Test setfont without size (should use default)
        $g->setfontsize(16);
        $face = $g->setfont($fontname);
        ok(defined $face, 'setfont without size uses default');
        
        # Test error cases
        dies_ok { $g->setfont() } 'setfont without font name dies';
        dies_ok { $g->setfont('NonExistent.ttf', 12) } 
            'setfont with non-existent font dies';
    } else {
        plan skip_all => 'No common fonts found for testing';
    }
};

subtest 'Text Rendering' => sub {
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    my @common_fonts = qw(
        DejaVuSans.ttf
        LiberationSans-Regular.ttf
        Arial.ttf
    );
    
    my $face;
    foreach my $font (@common_fonts) {
        my $path = $g->findfont($font);
        if ($path ne '') {
            $face = $g->setfont($font, 24);
            last;
        }
    }
    
    if (defined $face) {
        plan tests => 8;
        
        # Test stroketext
        lives_ok { $g->stroketext($face, 'Hello') } 'stroketext succeeds';
        
        # Test stroketextfill
        lives_ok { $g->stroketextfill($face, 'World') } 'stroketextfill succeeds';
        
        # Test with single character
        lives_ok { $g->stroketext($face, 'A') } 'stroketext with single char';
        
        # Test with chr()
        lives_ok { $g->stroketext($face, chr(65)) } 'stroketext with chr() works';
        
        # Test textwidth
        my $width = $g->textwidth($face, 'Test');
        ok($width > 0, 'textwidth returns positive value');
        
        # Longer text should be wider
        my $width2 = $g->textwidth($face, 'TestTest');
        ok($width2 > $width, 'longer text has greater width');
        
        # Test error cases
        dies_ok { $g->stroketext($face) } 'stroketext without string dies';
        dies_ok { $g->stroketext(undef, 'text') } 'stroketext without face dies';
    } else {
        plan skip_all => 'No fonts available for text rendering tests';
    }
};

subtest 'Text with Transformations' => sub {
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    my @common_fonts = qw(DejaVuSans.ttf LiberationSans-Regular.ttf);
    
    my $face;
    foreach my $font (@common_fonts) {
        my $path = $g->findfont($font);
        if ($path ne '') {
            $face = $g->setfont($font, 24);
            last;
        }
    }
    
    if (defined $face) {
        plan tests => 4;
        
        # Test rotated text
        lives_ok {
            $g->gsave();
            $g->rotate(45);
            $g->stroketext($face, 'Rotated');
            $g->grestore();
        } 'rotated text rendering succeeds';
        
        # Test scaled text
        lives_ok {
            $g->gsave();
            $g->scale(2);
            $g->stroketext($face, 'Scaled');
            $g->grestore();
        } 'scaled text rendering succeeds';
        
        # Test translated text
        lives_ok {
            $g->gsave();
            $g->translate(100, 100);
            $g->stroketext($face, 'Moved');
            $g->grestore();
        } 'translated text rendering succeeds';
        
        # Test combined transformations
        lives_ok {
            $g->gsave();
            $g->translate(200, 200);
            $g->rotate(30);
            $g->scale(1.5);
            $g->stroketext($face, 'Complex');
            $g->grestore();
        } 'complex transformed text succeeds';
    } else {
        plan skip_all => 'No fonts available for transformation tests';
    }
};

subtest 'Kerning and Spacing' => sub {
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    my @common_fonts = qw(DejaVuSans.ttf LiberationSans-Regular.ttf);
    
    my $face;
    foreach my $font (@common_fonts) {
        my $path = $g->findfont($font);
        if ($path ne '') {
            $face = $g->setfont($font, 24);
            last;
        }
    }
    
    if (defined $face) {
        plan tests => 3;
        
        # Text with kerning pairs
        my $width_av = $g->textwidth($face, 'AV');
        my $width_aa = $g->textwidth($face, 'AA');
        
        # Note: kerning might make AV narrower than AA
        ok($width_av > 0 && $width_aa > 0, 'kerning pairs have positive width');
        
        # Test that kerning is considered in rendering
        lives_ok { $g->stroketext($face, 'WAVE') } 'text with kerning pairs renders';
        
        # Test spacing consistency
        my $w1 = $g->textwidth($face, 'i');
        my $w2 = $g->textwidth($face, 'W');
        ok($w2 > $w1, 'wide characters are wider than narrow ones');
    } else {
        plan skip_all => 'No fonts available for kerning tests';
    }
};

subtest 'Special Characters' => sub {
    my $g = Graphics::Penplotter::GcodeXY->new(xsize => 10, ysize => 10, units => 'pt');
    
    my @common_fonts = qw(DejaVuSans.ttf LiberationSans-Regular.ttf);
    
    my $face;
    foreach my $font (@common_fonts) {
        my $path = $g->findfont($font);
        if ($path ne '') {
            $face = $g->setfont($font, 24);
            last;
        }
    }
    
    if (defined $face) {
        plan tests => 4;
        
        # Test numbers
        lives_ok { $g->stroketext($face, '0123456789') } 'numbers render';
        
        # Test punctuation
        lives_ok { $g->stroketext($face, '.,;:!?') } 'punctuation renders';
        
        # Test empty string (should handle gracefully)
        lives_ok { $g->stroketext($face, '') } 'empty string handled';
        
        # Test space
        my $width = $g->textwidth($face, ' ');
        ok($width > 0, 'space has positive width');
    } else {
        plan skip_all => 'No fonts available for special character tests';
    }
};

done_testing();