#!/usr/bin/perl

use strict;
use warnings;

use Yote::SQLObjectStore;
use Getopt::Long;

my %opts;
GetOptions(
    \%opts,
    'dbname=s', 
    'username=s',
    'password=s',
    'root_package=s',
) or die "Error in command line arguments\n";

for my $arg (qw(dbname username password)) {
    die "--$arg is required" unless $opts{$arg};
}

my @INC_PATH = @ARGV;
push @INC, @INC_PATH;

my $store = Yote::SQLObjectStore->new( 'MariaDB', %opts );
if (my @updates = $store->make_all_tables_sql(@INC_PATH)) {
    printf "got %d updates: \n", scalar(@updates);
    for my $up (@updates) {
        my ($q, @params) = @$up;
        print "$q\n\t".join("\n\t",map { "'$_'" } @params)."\n\n";
    }
    print "apply updates (yes/NO)?";
    my $in = <STDIN>;
    chop $in;
    if ($in eq 'yes') {
        $store->start_transaction;
        for my $up (@updates) {
            my ($q, @params) = @$up;
            $store->query_do( $q, @params );
        }
        $store->commit_transaction;
    } else {
        print "cancelled - no updates applied\n";
    }
} else {
    print "no updates needed\n";
}

__END__


my %args = (
    dbname       => 'madyote',
    username     => 'webapp',
    password     => 'boogers',
    root_package => 'Madyote',
);

my @INC_PATH = qw(
    /home/wolf/proj/madyote/lib
    /hom/proj/Yote-SQL-ObjectStore/lib
);
