#!perl
# PODNAME: es-storage-overview.pl
# ABSTRACT: Index Storage Overview by Index Name without Dates
use strict;
use warnings;
use feature qw(state);

use App::ElasticSearch::Utilities qw(es_request es_index_strip_date es_index_bases);
use CHI;
use CLI::Helpers qw(:output);
use Getopt::Long::Descriptive;
use Pod::Usage;

#------------------------------------------------------------------------#
# Argument Collection
my ($opt,$usage) = describe_options('%c %o',
    ['sort=s',  "sort by name or size, default: name",
            { default => 'name', callbacks => { 'must be name or size' => sub { $_[0] =~ /^name|size$/ } } }
    ],
    ['asc',     "Sort ascending  (default by name)"],
    ['desc',    "Sort descending (default by size)"],
    ['limit=i', "Limit to showing only this many, ie top N", { default => 0 }],
    ['raw',     "Display numeric data without rollups"],
    [],
    ['clear-cache', "Clear the _cat/indices cache"],
    [],
    ['help|h',  "Display this help", { shortcircuit => 1 }],
    ['manual|m',"Display the full manual", { shortcircuit => 1 }],
);

#------------------------------------------------------------------------#
# Documentations!
if( $opt->help ) {
    print $usage->text;
    exit;
}
pod2usage(-exitstatus => 0, -verbose => 2) if $opt->manual;

my $cache = CHI->new(
    driver    => 'File',
    root_dir  => "$ENV{HOME}/.es-utils/cache",
    namespace => 'storage',
    expires_in => '10min',
);

$cache->clear if $opt->clear_cache;

my %indices = ();
my %bases = ();
my %overview = (
    shards  => 0,
    indices => 0,
    docs    => 0,
    size    => 0,
    memory  => 0,
);

my %fields = qw(
    index index
    pri   primary
    rep   replica
    docs.count docs
    store.size size
    memory.total memory
);
my $result = $cache->get('_cat/indices');
if( !defined $result ) {
    output({color=>'cyan'}, "Fetching Index Meta-Data");
    $result  ||= es_request('_cat/indices',
            {
                uri_param => {
                    h      => join(',', sort keys %fields),
                    bytes  => 'b',
                    format => 'json'
                }
            }
    );
    $cache->set('_cat/indices', $result);
}

foreach my $row (@{ $result }) {
    # Index Name
    my $index = delete $row->{index};

    $overview{indices}++;
    verbose({color=>'green'}, "$index - Gathering statistics");

    my @bases = es_index_strip_date($index);
    foreach my $base ( @bases ) {
        # Count Indexes
        $bases{$base}->{indices} ||= 0;
        $bases{$base}->{indices}++;
        # Handle keys
        foreach my $k (keys %{ $row }) {
            next unless exists $fields{$k};
            my $dk = $fields{$k};
            # Grab Overview Data
            $overview{$dk} += $row->{$k};
            # Counts against bases
            $bases{$base} ||=  {};
            $bases{$base}->{$dk} ||= 0;
            $bases{$base}->{$dk} += $row->{$k};
        }
    }
}

output({color=>'white'}, "Storage Overview");
my $displayed = 0;
foreach my $index (sort indices_by keys %bases) {
    output({color=>"magenta",indent=>1}, $index);
    output({color=>"cyan",kv=>1,indent=>2}, 'size',    pretty_size( $bases{$index}->{size}));
    output({color=>"cyan",kv=>1,indent=>2}, 'indices', $bases{$index}->{indices});
    output({color=>"cyan",kv=>1,indent=>2}, 'avgsize', pretty_size( $bases{$index}->{size} / $bases{$index}->{indices} ));
    output({color=>"cyan",kv=>1,indent=>2}, 'primary', $bases{$index}->{primary});
    output({color=>"cyan",kv=>1,indent=>2}, 'replica', $bases{$index}->{replica});
    output({color=>"cyan",kv=>1,indent=>2}, 'docs',    $bases{$index}->{docs});
    output({color=>"cyan",kv=>1,indent=>2}, 'memory',  pretty_size( $bases{$index}->{memory}));
    $displayed++;
    last if $opt->limit > 0 && $displayed >= $opt->limit;
}
output({color=>'white',clear=>1},"Total for scanned data");
    output({color=>"cyan",kv=>1,indent=>1}, 'size',    pretty_size( $overview{size}));
    output({color=>"cyan",kv=>1,indent=>1}, 'indices', $overview{indices});
    output({color=>"cyan",kv=>1,indent=>1}, 'shards',  $overview{primary} + $overview{replica});
    output({color=>"cyan",kv=>1,indent=>1}, 'docs',    $overview{docs});
    output({color=>"cyan",kv=>1,indent=>1}, 'memory',  pretty_size( $overview{memory}));


exit (0);

sub pretty_size {
    my ($size)=@_;
    state $warned = 0;

    my $value = $size;
    if( !$opt->raw ) {
        my @indicators = qw(kb mb gb tb);
        my $indicator = '';

        while( $size > 1024 && @indicators ) {
            $indicator = shift @indicators;
            $size /= 1024;
        }
        $value = sprintf('%0.2f %s', $size, $indicator);
    }

    return $value;
}

sub indices_by {
    if( $opt->sort eq 'size' ) {
        return $opt->asc ?
            $bases{$a}->{size} <=> $bases{$b}->{size} :
            $bases{$b}->{size} <=> $bases{$a}->{size} ;
    }
    return $opt->desc ? $b cmp $a : $a cmp $b;
}

__END__

=pod

=head1 NAME

es-storage-overview.pl - Index Storage Overview by Index Name without Dates

=head1 VERSION

version 8.8

=head1 SYNOPSIS

es-storage-overview.pl --local

Options:

    --help              print help
    --manual            print full manual
    --clear-cache       Clear the cached statistics, they only live for a few
    --format            Output format for numeric data, pretty(default) or raw
    --sort              Sort by, name(default) or size
    --limit             Show only the top N, default no limit
    --asc               Sort ascending
    --desc              Sort descending (default)

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

This script allows you view the storage statistics of the ElasticSearch cluster.

Usage:

    # Show usage data for nodes with logstash indices
    $ es-storage-overview.pl --local

=head1 OPTIONS

=over 8

=item B<help>

Print this message and exit

=item B<manual>

Print this message and exit

=item B<sort>

How to sort the data, by it's name (the default) or size

=item B<limit>

Show only the first N items, or everything is N == 0

=item B<asc>

Sort ascending, the default for name

=item B<desc>

Sort descending, the default for size

=back

=head1 AUTHOR

Brad Lhotsky <brad@divisionbyzero.net>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Brad Lhotsky.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
