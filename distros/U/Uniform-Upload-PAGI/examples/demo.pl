use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Uniform::Upload::PAGI;

# The PAGI entry point coderef expected by pagi-server
my $app = sub {
    my ($scope, $receive, $send) = @_;

    # Only handle HTTP POST requests
    if ($scope->{type} eq 'http' && $scope->{method} eq 'POST') {

        # Instantiate Uniform::Upload::PAGI with the real server scope
        my $uploader = Uniform::Upload::PAGI->new(
            $scope,
            max_size      => '5M',
            allowed_types => [qw( image/png image/jpeg application/pdf )],
        );

        # Extract upload payload asynchronously from the server's receive stream
        return $uploader->extract_async($receive)->then(sub {
            my ($files) = @_;

            my $body = "=== Uniform::Upload::PAGI Processing Result ===\n\n";
            $body .= "Extracted " . scalar(@$files) . " file(s):\n";

            for my $file (@$files) {
                $body .= sprintf(
                    " - Field: %s | File: %s | Valid: %s | Error: %s\n",
                    $file->name,
                    $file->sanitized_filename,
                    $file->is_valid ? 'Yes' : 'No',
                    $file->error || 'None'
                );
            }

            return $send->({
                type    => 'http.response.start',
                status  => 200,
                headers => [ ['content-type', 'text/plain'] ],
            })->then(sub {
                return $send->({
                    type => 'http.response.body',
                    body => $body,
                });
            });
        });
    }

    # Default fallback response for non-POST or root requests
    return $send->({
        type    => 'http.response.start',
        status  => 200,
        headers => [ ['content-type', 'text/html'] ],
    })->then(sub {
        my $html = <<'HTML';
<!DOCTYPE html>
<html>
<body>
  <h2>Uniform::Upload::PAGI Live Upload Demo</h2>
  <form action="/" method="POST" enctype="multipart/form-data">
    <input type="file" name="avatar" /><br/><br/>
    <button type="submit">Upload File</button>
  </form>
</body>
</html>
HTML
        return $send->({
            type => 'http.response.body',
            body => $html,
        });
    });
};

# Return the application code ref to the server runner
$app;
