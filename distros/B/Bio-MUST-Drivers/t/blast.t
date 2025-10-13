#!/usr/bin/env perl

use Test::Most;
use Test::Files;

use autodie;
use feature qw(say);

use Const::Fast;
use List::AllUtils;
use Module::Runtime qw(use_module);
use Path::Class qw(file);

use Bio::MUST::Core;
use Bio::MUST::Drivers;


const my $NET_VAR => 'BMD_TEST_NETWORK';

say <<'EOT';
Note: tests designed for:
- blast 2.8.1, build Nov 26 2018 11:55:45
- blast 2.10.0, build Jan  8 2020 22:00:09
- blast 2.11.0, build Nov  3 2020 16:32:26
- blast 2.16.0, build Jun 25 2024 12:36:54
- blast 2.17.0, build Jul  1 2025 12:49:33
EOT

my $qr_class = 'Bio::MUST::Core::Ali::Temporary';
my $db_class = 'Bio::MUST::Drivers::Blast::Database';
my $db_tmp_class = 'Bio::MUST::Drivers::Blast::Database::Temporary';

# Note: provisioning system is not enabled to help tests to pass on CPANTS
my $app = use_module('Bio::MUST::Provision::Blast')->new;
unless ( $app->condition ) {
    plan skip_all => <<"EOT";
skipped all NCBI-BLAST+ tests!
If you want to use this module you need to install NCBI-BLAST+ executables:
ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/
If you --force installation, I will eventually try to install NCBI-BLAST+ with brew:
https://brew.sh/
EOT
}

my $basename;
my $filename;
my $report_m6;
my $report_xml;

{
    my $db = $db_tmp_class->new(
        seqs => file('test', 'protdb.fasta'),
        args => { prefix_id => 'seq' }
    );
    cmp_ok $db->type, 'eq', 'prot', 'got expected -db_type';
    $basename = $db->filename;
    ok(-e "$basename.$_", "wrote db file with expected suffix: $_")
        for qw(phr pin psq);
    #   for qw(pdb phr pin pjs pog pos pot psq ptf pto);    # too stringent!
    explain $basename;

    # 1. prebuilt query file (need selecting BLAST program)
    my $query_file = file('test', 'ready_protquery.fasta');
    my $parser = $db->blastp($query_file);
    isa_ok($parser, 'Bio::FastParsers::Blast::Table');

    my $report = $parser->filename;
    explain $report;
    compare_filter_ok $report, file('test', 'ready_report.blastp.m6'),
        \&filter, 'wrote expected BLASTP report for pre-existing query file';
    $parser->remove;

    # 2. temporary query file (queries have to be degapped first)
    my $query = $qr_class->new( seqs => file('test', 'protquery.fasta') );
    $filename = $query->filename;
    explain $filename;

    # 2a. HTML format
    my $report_html = $db->blast($query, {
        -html   => undef,
        -evalue => 1e-50,
    } );
    ok $report_html =~ m/\.html\z/xms, "wrote HTML report: $report_html";

    # 2b. tabular format
    my $tab_parser = $db->blast($query, {
        -evalue => 1e-10,
    } );
    isa_ok($tab_parser, 'Bio::FastParsers::Blast::Table');

    $report_m6 = $tab_parser->filename;
    explain $report_m6;
    compare_filter_ok $report_m6, file('test', 'report.blastp.m6'),
        \&filter, 'wrote expected tabular BLASTP report';
    $tab_parser->remove;

    # 2c. XML format
    my $xml_parser = $db->blast($query, {
        -evalue => 1e-10,
        -outfmt => 5,
    } );
    isa_ok($xml_parser, 'Bio::FastParsers::Blast::Xml');

    cmp_ok $xml_parser->blast_output->count_iterations, '==', 7,
        'got expected number of iterations';

    $report_xml = $xml_parser->filename;
    explain $report_xml;
    compare_filter_ok $report_xml, file('test', 'report.blastp.xml'),
        \&filter, 'wrote expected XML BLASTP report';
    $xml_parser->remove;

    # blastdbcmd from temporary database
    my @ids = qw(seq2 seq4 seq6);
    my $seqs = $db->blastdbcmd( \@ids );
    cmp_ok $seqs->count_seqs, '==', 3,
        'fetched expected number of seqs from temporary database';
}
ok(!-e "$basename.$_", "deleted db file with expected suffix: $_")
    for qw(phr pin psq);
#   for qw(pdb phr pin pjs pog pos pot psq ptf pto);    # too stringent!
ok(!-e $filename,   'deleted query file');
ok(!-e $report_m6,  'deleted tabular report file');
ok(!-e $report_xml, 'deleted XML report file');

SKIP: {
    skip <<"EOT", 5 unless $ENV{$NET_VAR};
remote BLAST tests!
These tests are long to run and can hang if NCBI servers are too busy.
To enable them use:
\$ $NET_VAR=1 make test
EOT

    my $db = $db_class->new( file => 'core_nt', remote => 1 );
    cmp_ok $db->type, 'eq', 'nucl', 'got expected -db_type';
    $basename = $db->filename;
    explain $basename;

    my $query = $qr_class->new( seqs => file('test', 'nuclquery.fasta') );
    $filename = $query->filename;
    explain $filename;

    my $parser = $db->blast($query, {
        '-entrez_query'    => q{'Euglenozoa[ORGN]'},
        '-evalue'          => 1e-250,
        '-outfmt'          => 7,
    } );
    isa_ok($parser, 'Bio::FastParsers::Blast::Table');

    my $hsp_count = 0;
    while ($parser->next_hsp) {
        $hsp_count++;
    }

    cmp_ok $hsp_count, '>', 5, 'got expected number of remote HSPs';

    SKIP: {
        skip 'due to unstable remote BLASTN results', 2;
        cmp_ok $hsp_count, '==', 7, 'got expected number of remote HSPs';

        my $report = $parser->filename;
        explain $report;
        compare_filter_ok $report, file('test', 'report.blastn.m7'),
            \&filter, 'wrote expected tabular report after remote BLASTN';
        $parser->remove;
    }
}

{
    my $db = $db_class->new( file => file('test', 'prebuiltdb') );
    cmp_ok $db->type, 'eq', 'prot', 'got expected -db_type';
    $basename = $db->filename;
    ok(-e "$basename.$_", "found db file with expected suffix: $_")
        for qw(phr pin psq);
    #   for qw(pdb phr pin pjs pog pos pot psq ptf pto);    # too stringent!
    explain $basename;

    # blastdbcmd from prebuilt database
    my @ids = qw(gnl|Ca|29376464 gnl|Mg|16801896 gnl|Cu|29375460);
    my $seqs = $db->blastdbcmd( \@ids );
    cmp_ok $seqs->count_seqs, '==', 3,
        'fetched expected number of seqs from prebuilt database';
}

# TODO: test other BLAST variants and options?

sub filter {
    my $line = shift;
    $line =~ s{\t\ +}{\t}xmsg;      # normalize whitespace
    $line =~ s{\ +\t}{\t}xmsg;      # normalize whitespace

    # version- and job-dependent tags
    return q{} if $line =~ m/xml \s version/xms;
    return q{} if $line =~ m/BlastOutput_version/xms;
    return q{} if $line =~ m/BlastOutput_db/xms;
    return q{} if $line =~ m/RID:/xms;

    # unstable attr values for specific hit in tabular report
    return q{} if m{gi\|29377108\|ref\|NP_816262.1\| \s+ seq17}xms;

    # unstable gap positions in XML report alignments
    return q{} if $line =~ m/<Hsp_qseq>/xms;
    return q{} if $line =~ m/<Hsp_midline>/xms;

    # unstable evalue (and bitscore) in tabular (and XML) reports
    return q{} if $line =~ m/\bseq52\b/xms;
    return q{} if $line =~ m/<Hsp_evalue>/xms;
    return q{} if $line =~ m/<Hsp_bit-score>/xms;
    return q{} if $line =~ m/<Hsp_score>22[89]/xms;

    # unstable hits in XML reports
    return if $line =~ m/<Hit_num>3[45]/xms .. $line =~ m{</Hit>}xms;

    return $line;
}

done_testing;
