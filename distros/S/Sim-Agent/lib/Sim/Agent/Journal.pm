package Sim::Agent::Journal;

use strict;
use warnings;

sub new 
{
    my ($class, %opts) = @_;

    my $self = {};
    bless $self, $class;

    my $run_dir = $self->_create_run_dir;

    open my $fh, '>', "$run_dir/journal.log"
        or die "Cannot open journal.log";

    $self->{run_dir} = $run_dir;
    $self->{fh}      = $fh;

    return $self;
}

# ------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------

sub log 
{
    my ($self, $message) = @_;

    my $ts = $self->_timestamp;

    print { $self->{fh} } "[$ts] $message\n";
}

sub archive_plan 
{
    my ($self, $plan_file) = @_;

    open my $in,  '<', $plan_file
        or die "Cannot read plan file: $plan_file";

    open my $out, '>', "$self->{run_dir}/plan.sexpr"
        or die "Cannot write archived plan";

    while (<$in>) 
    {
        print {$out} $_;
    }

    close $in;
    close $out;
}

sub agent_dir 
{
    my ($self, $agent) = @_;

    my $dir = "$self->{run_dir}/agents/$agent";

    unless (-d $dir) 
    {
        mkdir $dir
            or die "Cannot create agent directory: $dir";
    }

    return $dir;
}

# ------------------------------------------------------------
# Private Helpers
# ------------------------------------------------------------

sub _create_run_dir 
{
    my ($self) = @_;

    my $base = "run_" . $self->_timestamp;

    mkdir $base
        or die "Cannot create run dir $base";

    mkdir "$base/agents"
        or die "Cannot create agents dir";

    return $base;
}

sub _timestamp 
{
    my ($self) = @_;

    my @t = localtime();

    return sprintf(
        "%04d%02d%02d_%02d%02d%02d",
        $t[5] + 1900,
        $t[4] + 1,
        $t[3],
        $t[2],
        $t[1],
        $t[0],
    );
}

1;

=pod

=head1 NAME

Sim::Agent::Journal - File-backed journaling and run directory management

=head1 DESCRIPTION

Creates the per-run directory, writes journal.log entries, archives the plan, and provides per-agent directories used by LLM adapters.

See L<Sim::Agent>.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut

