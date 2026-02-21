#!/usr/bin/env perl
use strict;
use warnings;

use Test2::V0;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use Path::Tiny;

# Load your module
use lib 'lib';
use Plack::Middleware::DirListing;

# 1. Setup Temp Directory and Files for Sorting
my $temp_dir = Path::Tiny->tempdir;

# Create files named specifically to test alphabetical sorting
$temp_dir->child('alpha.txt')->spew("content");
$temp_dir->child('charlie.txt')->spew("content");
$temp_dir->child('bravo.txt')->spew("content");
$temp_dir->child('20_small.txt')->spew("x" x 20);
$temp_dir->child('100_large.txt')->spew("x" x 100);

# 2. Define App
my $app = builder {
    enable "DirListing", root => $temp_dir->stringify;
    sub { [ 404, [], ['Not Found'] ] };
};

# Helper to extract filenames from the HTML table
sub extract_filenames {
    my $html = shift;

    # Regex matches: <td class="name"><a href="...">FILENAME</a></td>
    my @names = $html =~ m{<td class="name"><a href="[^"]+">([^<]+)</a></td>}g;

    # Remove "Parent Directory" from the list as it is always injected at the top
    @names = grep { $_ ne 'Parent Directory' } @names;

    return \@names;
}

# 3. Run Tests
test_psgi $app, sub {
    my $cb = shift;

    subtest 'Default Sort (Should be Name Ascending)' => sub {
        my $res = $cb->(GET '/');
        ok $res->is_success, 'Response successful';

        my $files = extract_filenames($res->content);

        # Expected: alpha, bravo, charlie
        is $files, ['100_large.txt', '20_small.txt', 'alpha.txt', 'bravo.txt', 'charlie.txt'],
            "Default sort order is correct";
    };

    subtest 'Sort by Name Ascending (Explicit)' => sub {
        # C=N (Name), O=A (Ascending)
        my $res = $cb->(GET '/?C=N;O=A');
        ok $res->is_success;

        my $files = extract_filenames($res->content);

        is $files, ['100_large.txt', '20_small.txt', 'alpha.txt', 'bravo.txt', 'charlie.txt'],
            "Explicit Name Ascending sort is correct";
    };

    subtest 'Sort by Name Descending' => sub {
        # C=N (Name), O=D (Descending)
        my $res = $cb->(GET '/?C=N;O=D');
        ok $res->is_success;

        my $files = extract_filenames($res->content);

        # Expected: charlie, bravo, alpha
        is $files, ['charlie.txt', 'bravo.txt', 'alpha.txt', '20_small.txt', '100_large.txt'],
            "Name Descending sort is correct";
    };

    subtest 'Sort by Size' => sub {
        # Create files with sizes that differ in string vs numeric sort
        # "100" comes before "20" in string sort, but after in numeric.

        my $res = $cb->(GET '/?C=S;O=D');

        my $files = extract_filenames($res->content);

        # Filter to just our size test files
        my $size_files = [ grep { /small|large/ } @$files ];

        is $size_files, ['100_large.txt', '20_small.txt'],
            "Check sorting by size";
    };
};

done_testing;
