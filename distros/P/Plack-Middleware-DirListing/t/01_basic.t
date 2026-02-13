use strict;
use warnings;
use Test::More;
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
        is_deeply $files, ['alpha.txt', 'bravo.txt', 'charlie.txt'],
            "Default sort order is correct";
    };

    subtest 'Sort by Name Ascending (Explicit)' => sub {
        # C=N (Name), O=A (Ascending)
        my $res = $cb->(GET '/?C=N;O=A');
        ok $res->is_success;

        my $files = extract_filenames($res->content);

        is_deeply $files, ['alpha.txt', 'bravo.txt', 'charlie.txt'],
            "Explicit Name Ascending sort is correct";
    };

    subtest 'Sort by Name Descending' => sub {
        # C=N (Name), O=D (Descending)
        my $res = $cb->(GET '/?C=N;O=D');
        ok $res->is_success;

        my $files = extract_filenames($res->content);

        # Expected: charlie, bravo, alpha
        is_deeply $files, ['charlie.txt', 'bravo.txt', 'alpha.txt'],
            "Name Descending sort is correct";
    };

    # Note: Based on your provided code, the 'Size' (D) and 'Date' (S) sorting
    # logic in %col_sort might behave unexpectedly because:
    # 1. 'SA' sorts on index 3 (Formatted Date String) using <=> (Numeric comparison).
    # 2. 'DA' sorts on index 4 (Size) using cmp (String comparison).
    #
    # The test below checks Size sorting based on how your code is currently written
    # (String comparison of size), not necessarily mathematical correctness.

    subtest 'Sort by Size (DA - String Comparison)' => sub {
        # Create files with sizes that differ in string vs numeric sort
        # "100" comes before "20" in string sort, but after in numeric.
        $temp_dir->child('small_20.txt')->spew("x" x 20);
        $temp_dir->child('large_100.txt')->spew("x" x 100);

        # C=D (Size/Description column?), O=A (Ascending)
        # Your code maps 'DA' to index 4 (Size) using 'cmp'
        my $res = $cb->(GET '/?C=D;O=A');

        my $files = extract_filenames($res->content);

        # Filter to just our size test files
        my @size_files = grep { /small|large/ } @$files;

        # Since your code uses 'cmp' (string compare) for size:
        # "100" lt "20" is TRUE. So large_100 should come first.
        is_deeply \@size_files, ['large_100.txt', 'small_20.txt'],
            "Size sorts as string (based on current implementation)";
    };
};

done_testing;
