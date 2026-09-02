package Local::BrowserProbe;

use strict;
use warnings;
use utf8;

use Exporter qw(import);
use Capture::Tiny qw(capture);
use IO::Socket::INET;

use Local::BoundedCommand qw(run_bounded);

our @EXPORT_OK = qw(browser_can_fetch_loopback);

my $MARKER = 'dd-loopback-probe-ok';

# browser_can_fetch_loopback(%args)
# Purpose: establish whether this host's browser can fetch anything at all over
# loopback, so a host that cannot is skipped with a reason rather than reported
# as a failure of the code under test.
# Input: browser path, browser argv arrayref, optional seconds bound.
# Output: list of (boolean ok, reason string when not ok).
#
# WHY PLAIN HTTP AND NOT THE PRODUCT
#   The probe must fail only when the BROWSER cannot fetch. Serving the page from
#   a nine-line socket server rather than the dashboard is what makes this a
#   diagnosis instead of a second copy of the test: if plain HTTP succeeds and the
#   real fetch then fails, that is a genuine failure of the thing under test and
#   must NOT be skipped.
#
# WHY IT LIVES HERE RATHER THAN IN ONE TEST FILE
#   It was written inside t/33 first, and t/38 - which drives a browser exactly
#   the same way - was left behind and failed the very next full suite run. A
#   check that has to be remembered separately by every caller is one that will be
#   missed by one of them.
sub browser_can_fetch_loopback {
    my (%args) = @_;
    my $browser = $args{browser} or die 'browser_can_fetch_loopback requires a browser path';
    my @browser_args = @{ $args{args} || [] };
    my $seconds = $args{seconds} || 30;

    my $listener = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto     => 'tcp',
        Listen    => 5,
        ReuseAddr => 1,
    ) or return ( 0, "the probe could not open a local listening socket: $!" );
    my $port = $listener->sockport;

    my $pid = fork();
    return ( 0, "the probe could not fork its server: $!" ) if !defined $pid;
    if ( !$pid ) {
        my $body = "<html><body>$MARKER</body></html>";
        while ( my $client = $listener->accept ) {
            my $request = <$client>;
            print {$client} "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n"
              . 'Content-Length: ' . length($body) . "\r\nConnection: close\r\n\r\n$body";
            close $client;
        }
        exit 0;
    }

    my $url = "http://127.0.0.1:$port/";
    my ( $stdout, $stderr, $result ) = capture {
        run_bounded(
            command => [ $browser, @browser_args, '--dump-dom', $url ],
            seconds => $seconds,
            label   => "loopback probe fetch of $url",
        );
    };

    kill 'TERM', $pid;
    waitpid $pid, 0;
    close $listener;

    return ( 1, '' ) if !$result->{timed_out} && $result->{exit} == 0 && $stdout =~ /\Q$MARKER\E/;

    my $why =
        $result->{timed_out} ? "the fetch exceeded its bound: $result->{message}"
      : $result->{exit} != 0 ? "the browser exited $result->{exit}"
      :                        'the browser returned a page not containing the probe marker';

    return (
        0,
        "browser smoke SKIPPED: this host's browser cannot fetch a page that is definitely being served. "
          . "Probed $url over plain HTTP with a minimal local server and $why. "
          . 'The product is not implicated - a browser that cannot reach loopback at all cannot test anything here. '
          . 'CI runs this test for real, and the release runner has passed this suite. See DD-534.'
    );
}

1;

__END__

=head1 NAME

Local::BrowserProbe - ask whether this host's browser can fetch over loopback

=head1 PURPOSE

Let a browser-driving test establish, before it does any real work, that the
browser it is about to use can fetch a page at all - so a host where it cannot
skips with a printed reason instead of reporting a failure of the code.

=head1 WHY IT EXISTS

Chromium on one development host cannot complete any fetch from loopback. Before
the bound was added the browser smoke hung indefinitely - a coverage run sat on
it for one day and twenty hours - and after the bound it failed in seconds. Both
outcomes stopped every gate on that machine, for a fault in neither the product
nor the test.

It lives in a shared module rather than in a test file because the first version
was written inside C<t/33-web-server-ssl-browser.t> alone, and
C<t/38-web-no-editor-browser.t> - which drives a browser in exactly the same way -
was left behind and failed the very next full-suite run. A precaution each caller
has to remember separately is one that some caller will forget.

=head1 WHEN TO USE

At the top of any test that drives a real browser, before C<plan>.

=head1 HOW TO USE

    use Local::BrowserProbe qw(browser_can_fetch_loopback);

    my ( $ok, $reason ) = browser_can_fetch_loopback(
        browser => $chromium_bin,
        args    => \@chromium_base_args,
    );
    plan skip_all => $reason if !$ok;

=head1 WHAT USES IT

C<t/33-web-server-ssl-browser.t> and C<t/38-web-no-editor-browser.t>.

=head1 EXAMPLES

On a host whose browser works the probe is invisible; on one where it does not,
the test skips with the probe URL and the browser's own behaviour named, so the
reader can tell a broken host from a broken product.

=cut
