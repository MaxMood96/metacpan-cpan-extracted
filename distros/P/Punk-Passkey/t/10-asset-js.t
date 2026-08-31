#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use Punk::Passkey ();
use Punk::Plugin::Passkey ();

# The browser helper, exercised rather than only inspected.
#
# Everything else this distribution tests is Perl or C, and the
# JavaScript was getting only "does it mention the right words", which
# is not a test - it missed a real bug that made the login button do
# nothing while the passkey sat visibly in the user's password manager:
#
#   a browser allows ONE outstanding credential request. Conditional
#   mediation leaves one pending from page load, so a button press has
#   to abort it first, or the second call is refused outright.
#
# So the helper is run against a fake browser that enforces that rule.
# node is not a dependency of this distribution and the test skips
# without it; the assertions that need no runtime are below and always
# run.

my $js = Punk::Plugin::Passkey::_asset();

# ---- what can be checked without a runtime ----------------------------------

ok(length $js > 500, 'the helper is served');
unlike($js, qr{https?://}i,
    'referencing no external origin, so a Content-Security-Policy does '
  . 'not have to be widened to let sign-in work');
like($js, qr/AbortController/,
    'it uses an AbortController - the one outstanding credential request '
  . 'has to be cancellable');
like($js, qr/\babort\(\)/,
    'and actually aborts, rather than only holding a controller');
like($js, qr/isConditionalMediationAvailable/,
    'conditional UI is feature-detected');

# ---- and what needs one -----------------------------------------------------

my $node = `sh -c 'command -v node' 2>/dev/null`;
chomp $node;
plan skip_all => 'node is not installed; the runtime assertions are skipped'
    unless $node && -x $node;

my $dir = File::Temp->newdir;
open my $fh, '>', "$dir/asset.js" or die $!;
print {$fh} $js;
close $fh;

my $harness = "$FindBin::Bin/js/request-handling.js";
ok(-f $harness, 'the fake browser is shipped') or done_testing, exit;

my $out = `"$node" "$harness" "$dir/asset.js" 2>&1`;
my $ok  = $? == 0;

like($out, qr/PASS:/, 'the helper drives a login correctly under the rule')
    or diag $out;
ok($ok, 'and the harness exited clean') or diag $out;

unlike($out, qr/REFUSED-CONCURRENT/,
    'no second credential request was made while one was outstanding - '
  . 'which is exactly the failure a user sees as a button that does '
  . 'nothing');

like($out, qr/abort \| fetch:[^|]*options \| get:modal/,
    'the sequence is: abort the autofill request, THEN ask for options '
  . 'and open the modal - in that order, so the challenge the modal '
  . 'gets is the one it will be checked against');

done_testing;
