#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use Crypt::OpenSSL::Guess ();

sub main {
    
    my( $os_major, $os_minor, $os_letter ) = Crypt::OpenSSL::Guess::openssl_version;
        
    my $HAS_OPEN_SSL_3 = ( $os_major && $os_major >= 3.0 && $os_major =~ m!^3\.!) ? 1 : 0;
    
    # Target the local 'blib' directory created by the running Makefile
    my $blib_dir = File::Spec->catdir(File::Spec->curdir, 'blib');
    
    unless (-d $blib_dir) {
        die "Error: 'blib' directory does not exist yet. Run 'make' first.\n";
    }

    # Safely path-join down to your target subfolder (e.g., blib/lib or blib/arch)
    my $target_dir = File::Spec->catdir($blib_dir, 'lib', 'Crypt', 'JWS', 'OpenSSL');
    
    # Create the directories securely if they don't exist
    unless (-d $target_dir) {
        require File::Path;
        File::Path::make_path($target_dir);
    }
    
    # Read the template file
    my $infilepath = 'inc/template/jws_local.pm';
    open(my $infh, '<:encoding(UTF-8)', $infilepath) or die "Could not open $infilepath : $!";
    my $content = do { local $/; <$infh> };
    close($infh);
    
    # Update the template
    $content =~ s!HASOPENSSL3ANSWER!$HAS_OPEN_SSL_3!;

    # 4. Generate your external content
    my $output_file = File::Spec->catfile($target_dir, 'Local.pm');
    
    open(my $fh, '>:encoding(UTF-8)', $output_file) or die "Cannot write to $output_file: $!";
    print $fh $content;
    close($fh);

    print "Successfully populated external content in blib!\n";
}

main();

1;
