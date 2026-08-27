package Demo::Cards;

use strict;
use warnings;
use Punk;
use Punk::Plugin::OpenTelemetry;

our $VERSION = '0.01';

config 'config/punk.yml';

# A SECOND SERVICE, and a second service.name. That is what makes the demo's
# service map a map rather than a single box: the shop calls this over real
# HTTP, Fetch injects `traceparent` on the way out, and the two halves of the
# call are joined into one trace.
otel service_name => 'cards',
     resource_attributes => { 'deployment.environment' => 'demo' };

plugin 'OpenTelemetry';

# DEBUG, so the demo has something to filter.
#
# A line below the configured level costs nothing - the threshold is read
# before anything is formatted - so this is the demo deliberately turning the
# quiet ones on. It is also what makes `log | where severity >= warn` a
# filter that removes something rather than a filter over one severity.
#
# The logger is the LOGS SIGNAL. Nothing below calls a telemetry-specific
# logging function: the plugin taps this logger, so every line here is
# exported carrying the trace id of the request that wrote it - and still
# goes to the log as well.
logging level => 'debug';

# DELTA, not cumulative.
#
# A cumulative exporter re-sends the WHOLE series on every collection: the
# same histogram bucket, with a new timestamp, every five seconds for as long
# as the process runs. The receiver stores records, so it stores every one of
# them - a fifty-second demo run wrote four hundred thousand metric points
# describing about three thousand requests, and one bucket appeared fifty-four
# thousand times.
#
# Delta sends only what changed since the last collection, which is what a
# store of records wants. Cumulative is right for a backend that keeps the
# last value per series and can afford to be told it repeatedly; this one is
# not that, and the demo should not pretend otherwise.
otel temporality_preference => 'delta';

# The thing that breaks. Toggled at runtime rather than at boot, so the demo
# can show a healthy system, break it, and watch it recover - which is the
# only way to see what an alert transition and a service map actually do.
# A FILE, NOT A PACKAGE VARIABLE.
#
# `our $BROKEN` is per PROCESS, and this runs as a prefork pool. `PUT
# /incident` reaches exactly one worker, so three quarters of the traffic
# never saw the incident at all - the demo produced a handful of errors where
# it should have produced dozens, and the shape on the screen was of a service
# that is mostly fine rather than one that is broken.
#
# A file every worker can stat is the smallest thing that is actually shared.
# It is also the honest shape of a runtime flag in a pool: somebody has to
# publish the change somewhere every process can see it, and "somewhere" is
# either the filesystem, a shared mapping, or a round trip to a database.
our $INCIDENT_FILE = $ENV{DEMO_INCIDENT} || 'var/incident';

sub incident_on  { -e $INCIDENT_FILE ? 1 : 0 }

sub set_incident {
    my ($on) = @_;
    if ($on) {
        require File::Basename;
        my $dir = File::Basename::dirname($INCIDENT_FILE);
        unless (-d $dir) { require File::Path; File::Path::make_path($dir) }
        open my $fh, '>', $INCIDENT_FILE or return 0;
        close $fh;
    }
    else { unlink $INCIDENT_FILE }
    return incident_on();
}

post '/authorize' => 'Api#authorize', { name => 'authorize' };
put  '/incident'  => 'Api#incident',  { name => 'incident'  };
get  '/health'    => sub { $_[0]->json({ ok => 1, broken => incident_on() }) };

1;
