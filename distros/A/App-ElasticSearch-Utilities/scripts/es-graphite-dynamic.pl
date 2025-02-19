#!perl
# PODNAME: es-graphite-dynamic.pl
# ABSTRACT: Dynamically gather metrics and send to graphite
use strict;
use warnings;

use App::ElasticSearch::Utilities qw(es_connect);
use App::ElasticSearch::Utilities::Metrics;
use CLI::Helpers qw(:all);
use Getopt::Long qw(:config no_ignore_case no_ignore_case_always);
use IO::Socket::INET;
use Pod::Usage;
use Ref::Util qw(is_hashref is_arrayref);

#------------------------------------------------------------------------#
# Argument Collection
my %opt;
GetOptions(\%opt,
    'ignore=s',
    'carbon-base=s',
    'carbon-proto=s',
    'carbon-server=s',
    'carbon-port=i',
    'prefix=s',
    'no-prefix',
    'help|h',
    'manual|m',
);

#------------------------------------------------------------------------#
# Documentations!
pod2usage(1) if $opt{help};
pod2usage(-exitstatus => 0, -verbose => 2) if $opt{manual};

#------------------------------------------------------------------------#
# Argument Sanitazation


# Ignore uninteresting metrics
my @_IGNORE = ();
push @_IGNORE, split(/,/, $opt{ignore}) if exists $opt{ignore};
my %_IGNORE = map { $_ => 1 } @_IGNORE;
# Merge options into config
my %cfg = (
    'carbon-proto' => 'tcp',
    'carbon-base'  => 'general.es',
    %opt,
);

#------------------------------------------------------------------------#
# Globals
my $TIME = time;
my $Fetcher = App::ElasticSearch::Utilities::Metrics->new(
    connection => es_connect(),
    %_IGNORE ? (
        ignore => [ sort keys %_IGNORE ]
    ) : (),
);

#------------------------------------------------------------------------#
# Carbon Socket Creation
my $carbon_socket;
if( exists $cfg{'carbon-server'} and length $cfg{'carbon-server'} ) {
    my %valid_protos = ( tcp => 1, udp => 1 );
    die "invalid protocol specified: $cfg{'carbon-proto'}\n" unless exists $valid_protos{$cfg{'carbon-proto'}};
    $carbon_socket = IO::Socket::INET->new(
        PeerAddr    => $cfg{'carbon-server'},
        PeerPort    => $cfg{'carbon-port'} || 2003,
        Proto       => $cfg{'carbon-proto'},
    );
    die "unable to connect to carbon server: $!" unless defined $carbon_socket && $carbon_socket->connected;
}

#------------------------------------------------------------------------#
# Collect and Decode the Cluster Statistics
my @metrics = sort map { "$_->{key} $_->{value}" } @{ $Fetcher->get_metrics };
if( !@metrics ) {
    output({color=>'red'}, "Error retrieving metrics");
    exit 1;
}

#------------------------------------------------------------------------#
# Send output to appropriate channels
for ( @metrics ) {
    # Format
    my $prefix = exists $cfg{prefix} ? $cfg{prefix} : join('.', $cfg{'carbon-base'}, $Fetcher->node_details->{name});
    s/^/$prefix./ unless $cfg{'no-prefix'};
    s/$/ $TIME\n/;

    # Send the Data
    if( defined $carbon_socket && $carbon_socket->connected) {
        $carbon_socket->send( $_ );
        verbose($_);
    }
    else {
        output({data=>1},$_);
    }
}

__END__

=pod

=head1 NAME

es-graphite-dynamic.pl - Dynamically gather metrics and send to graphite

=head1 VERSION

version 8.8

=head1 SYNOPSIS

es-graphite-dynamic.pl --host [host] [options]

Options:

    --help              print help
    --manual            print full manual
    --carbon-base       The prefix to use for carbon metrics (Default: general.es)
    --carbon-server     Send Graphite stats to Carbon Server (Automatically sets format=graphite)
    --carbon-port       Port for to use for Carbon (Default: 2003)
    --carbon-proto      Protocol for to use for Carbon (Default: tcp)
    --with-indices      Also send individual index stats
    --ignore            Comma separated list of keys to ignore in collection
    --prefix            A metric path to prefix stats, defaults to (--carbon-base).(hostname)
    --no-prefix         Don't prefix the metrics at all

From App::ElasticSearch::Utilities:

    --local         Use localhost as the elasticsearch host
    --host          ElasticSearch host to connect to
    --port          HTTP port for your cluster
    --proto         Defaults to 'http', can also be 'https'
    --http-username HTTP Basic Auth username
    --password-exec Script to run to get the users password
    --insecure      Don't verify TLS certificates
    --cacert        Specify the TLS CA file
    --capath        Specify the directory with TLS CAs
    --cert          Specify the path to the client certificate
    --key           Specify the path to the client private key file
    --noop          Any operations other than GET are disabled, can be negated with --no-noop
    --timeout       Timeout to ElasticSearch, default 10
    --keep-proxy    Do not remove any proxy settings from %ENV
    --index         Index to run commands against
    --base          For daily indexes, reference only those starting with "logstash"
                     (same as --pattern logstash-* or logstash-DATE)
    --pattern       Use a pattern to operate on the indexes
    --days          If using a pattern or base, how many days back to go, default: 1

See also the "CONNECTION ARGUMENTS" and "INDEX SELECTION ARGUMENTS" sections from App::ElasticSearch::Utilities.

From CLI::Helpers:

    --data-file         Path to a file to write lines tagged with 'data => 1'
    --tags              A comma separated list of tags to display
    --color             Boolean, enable/disable color, default use git settings
    --verbose           Incremental, increase verbosity (Alias is -v)
    --debug             Show developer output
    --debug-class       Show debug messages originating from a specific package, default: main
    --quiet             Show no output (for cron)
    --syslog            Generate messages to syslog as well
    --syslog-facility   Default "local0"
    --syslog-tag        The program name, default is the script name
    --syslog-debug      Enable debug messages to syslog if in use, default false
    --nopaste           Use App::Nopaste to paste output to configured paste service
    --nopaste-public    Defaults to false, specify to use public paste services
    --nopaste-service   Comma-separated App::Nopaste service, defaults to Shadowcat

=head1 DESCRIPTION

This script collects interesting monitoring data from the ElasticSearch cluster and maps
that data directly into Graphite.  If ElasticSearch changes the names of data, those changes
will be reflected in the metric path immediately.

=head1 OPTIONS

=over 8

=item B<help>

Print this message and exit

=item B<manual>

Print this message and exit

=item B<carbon-base>

The prefix to use for metrics sent to carbon.  The default is "general.es".  Please note, the host name
of the ElasticSearch node will be appended, followed by the metric name.

=item B<carbon-server>

Send stats to the carbon server specified.  This automatically forces --format=graphite
and does not produce stats on STDOUT

=item B<carbon-port>

Use this port for the carbon server, useless without --carbon-server

=item B<ignore>

A comma separated list of keys to ignore when parsing the tree.  This is in addition to the
default ignore list: attributes,id,timestamp,upms,_all,_shards

Examples:

    es-graphite-dynamic.pl --with-indices --ignore primaries,get,warmer

=item B<prefix>

A metric path to prefix the collected stats with.  This is useful for using es-graphite-dynamic.pl with another
collector such as Diamond which expects metrics in a certain format.  To use with diamond's userscripts or files collector
you could:

    #!/bin/sh
    # userscripts

    es-graphite-dynamic.pl --local --prefix elasticsearch

Or with the file collector, you could cron this:

    es-graphite-dynamic.pl --local --prefix elasticsearch --data-file /tmp/diamond/elasticsearch.out --quiet

If not specified, the assumption is data will be going directly to graphite and the metric path will be set as:

    'general.es.$HOSTNAME'

=item B<no-prefix>

Don't set the prefix to the metric names.

=back

=head1 AUTHOR

Brad Lhotsky <brad@divisionbyzero.net>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Brad Lhotsky.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
