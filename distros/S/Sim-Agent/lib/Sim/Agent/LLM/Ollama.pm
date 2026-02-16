package Sim::Agent::LLM::Ollama;

use strict;
use warnings;

sub call_model 
{

    my (%args) = @_;

    my $model     = $args{model}     or die "model required";
    my $prompt    = $args{prompt}    or die "prompt required";
    my $agent_dir = $args{agent_dir} or die "agent_dir required";
    my $call_id   = $args{call_id}   or die "call_id required";

    # SECURITY: validate model
    die "Invalid model name"
        unless $model =~ /^[\w\.\:\-]+$/;

    my $prompt_file = sprintf("%s/%03d_prompt.txt", $agent_dir, $call_id);
    my $output_file = sprintf("%s/%03d_output.txt", $agent_dir, $call_id);

    open my $pfh, '>', $prompt_file
        or die "Cannot write $prompt_file";
    print {$pfh} $prompt;
    close $pfh;

    my $cmd = "ollama run $model < $prompt_file > $output_file";

    my $exit = system($cmd);
    die "Ollama call failed (exit=$exit)" if $exit != 0;

    open my $ofh, '<', $output_file
        or die "Cannot read $output_file";
    local $/;
    my $output = <$ofh>;
    close $ofh;

    return $output;
}

1;

=pod

=head1 NAME

Sim::Agent::LLM::Ollama - LLM adapter using the 'ollama' CLI

=head1 DESCRIPTION

Invokes C<ollama run MODEL> using prompt/output text files stored under the run directory.

This adapter is intentionally minimal and avoids SDK dependencies.

See L<Sim::Agent>.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut

