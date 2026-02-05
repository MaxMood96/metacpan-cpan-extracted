#!/usr/bin/env perl
use strict;
use warnings;
use Plack::Builder;

# Example application demonstrating Plack::Middleware::ProofOfWork
# HTML content is in external file: example-protected.html

my $app = sub {
    my $env = shift;
    
    # Load external HTML file
    my $html_file = 'example-protected.html';
    
    # Try to find the file in common locations
    my @search_paths = (
        $html_file,              # Current directory
        "./$html_file",          # Explicit current
    );
    
    my $html_path;
    for my $path (@search_paths) {
        if (-f $path && -r $path) {
            $html_path = $path;
            last;
        }
    }
    
    unless ($html_path) {
        return [
            500,
            ['Content-Type' => 'text/plain; charset=utf-8'],
            ["Error: Could not find $html_file\n\nPlease ensure $html_file is in the current directory."]
        ];
    }
    
    # Read HTML file
    open my $fh, '<:encoding(UTF-8)', $html_path
        or return [
            500,
            ['Content-Type' => 'text/plain; charset=utf-8'],
            ["Error: Could not open $html_path: $!"]
        ];
    
    my $html = do { local $/; <$fh> };
    close $fh;
    
    return [
        200,
        ['Content-Type' => 'text/html; charset=utf-8'],
        [$html]
    ];
};

# Build middleware stack
builder {
    # Enable access log (optional)
    enable "AccessLog", format => "combined";
    
    # Proof-of-Work middleware
    enable "ProofOfWork",
        difficulty => 4,           # 4 leading zeros (approx. 1-2 seconds)
        cookie_name => 'pow',      # Cookie name
        cookie_duration => 5,      # 5 days validity
        allow_bots => 1;           # Allow search engines
        # js_file => '/path/to/custom.js';        # Optional: custom JavaScript
        # html_file => '/path/to/custom.html';    # Optional: custom HTML template
    
    $app;
};

__END__

=head1 NAME

example.psgi - Example application for Plack::Middleware::ProofOfWork

=head1 SYNOPSIS

    plackup example.psgi

=head1 DESCRIPTION

This example application demonstrates Plack::Middleware::ProofOfWork.

The application loads its HTML content from an external file 
(example-protected.html) for better separation of concerns.

=head2 Files

=over 4

=item example.psgi

This PSGI application file

=item example-protected.html

Protected content page (must be in current directory)

=back

=head1 USAGE

    # Start server
    plackup example.psgi
    
    # With specific port
    plackup -p 8080 example.psgi
    
    # Production with Starman
    starman example.psgi

=head1 TESTING

=head2 Browser Test

Visit http://localhost:5000/ in your browser.

You should see:
1. Challenge page with spinner
2. Proof-of-Work calculation
3. Automatic page reload
4. Protected content

=head2 curl Tests

    # Without JavaScript (gets challenge)
    curl http://localhost:5000/
    
    # As bot (bypasses PoW)
    curl -A "Googlebot" http://localhost:5000/
    
    # With valid cookie (bypasses PoW)
    curl -H "Cookie: pow=VALID_COOKIE" http://localhost:5000/
    
    # With invalid cookie (gets challenge)
    curl -H "Cookie: pow=invalid" http://localhost:5000/

=head1 CUSTOMIZATION

Edit the middleware configuration:

    enable "ProofOfWork",
        difficulty => 4.5,         # Harder challenge
        cookie_name => 'bot_check',
        cookie_duration => 7,      # 7 days
        allow_bots => 0;           # Block all bots

Edit example-protected.html to customize the protected page.

=head1 SEE ALSO

L<Plack::Middleware::ProofOfWork>

=cut
