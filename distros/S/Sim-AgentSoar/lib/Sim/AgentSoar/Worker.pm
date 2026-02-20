package Sim::AgentSoar::Worker;

use strict;
use warnings;

our $VERSION = '0.06';

use JSON::PP qw(decode_json);
use Sim::AgentSoar::Engine ();
use File::Temp qw(tempfile);

sub new 
{
    my ($class, %args) = @_;

    my $self = 
    {
        model => $args{model} // 'llama3.2:1b',
    };

    return bless $self, $class;
}

# --------------------------------------------------

sub propose 
{
    my ($self, %args) = @_;

    my $prompt   = $self->_build_propose_prompt(%args);
    my $response = $self->_call_ollama($prompt);

    return $self->_extract_and_validate_operator($response);
}

sub correct 
{
    my ($self, %args) = @_;

    my $prompt   = $self->_build_correct_prompt(%args);
    my $response = $self->_call_ollama($prompt);

    return $self->_extract_and_validate_operator($response);
}

# --------------------------------------------------

sub _call_ollama 
{
    my ($self, $prompt) = @_;

    my $model = $self->{model};

    my ($pfh, $prompt_file) = tempfile();
    my ($ofh, $output_file) = tempfile();
    my ($efh, $err_file)    = tempfile();

    print {$pfh} $prompt;
    close $pfh;

    close $ofh; # written by ollama
    close $efh; # written by shell redirection

    my $cmd = join ' ',
        'ollama', 'run', $self->_sh_quote($model),
        '--format', 'json',
        '--nowordwrap',
        '<',  $self->_sh_quote($prompt_file),
        '>',  $self->_sh_quote($output_file),
        '2>', $self->_sh_quote($err_file);

    system($cmd);

    my $raw_status = $?;
    my $exit_code  = ($raw_status == -1) ? -1 : ($raw_status >> 8);
    my $signal     = ($raw_status & 127);

    my $stderr = $self->_slurp_file($err_file);

    if ($raw_status != 0) 
    {
        my $extra = (defined $stderr && length $stderr) ? " stderr=$stderr" : "";
        die "Ollama call failed (exit_code=$exit_code signal=$signal).$extra";
    }

    my $output = $self->_slurp_file($output_file);

    unlink $prompt_file;
    unlink $output_file;
    unlink $err_file;

    die "Empty response from Ollama" unless defined $output && length $output;

    return $output;
}

sub _slurp_file 
{
    my ($self, $path) = @_;

    open my $fh, '<', $path or return '';
    local $/;
    my $s = <$fh>;
    close $fh;

    return defined($s) ? $s : '';
}

sub _extract_and_validate_operator 
{
    my ($self, $json_text) = @_;

    my $decoded;

    eval 
    {
        $decoded = decode_json($json_text);
    };

    die "Invalid JSON from model: $json_text" if $@;

    my $operator = $decoded->{operator}
        or die "No operator field in response: $json_text";

    my %allowed = map { $_ => 1 }
        Sim::AgentSoar::Engine->allowed_operators;

    die "Invalid operator returned: $operator"
        unless $allowed{$operator};

    return $operator;
}

sub _extract_inner_hash 
{
    my ($self, $raw_text) = @_;

    # 1) single JSON object in full output
    my $obj = $self->_try_decode_json($raw_text);
    if (defined $obj) 
    {
        my $inner = $self->_inner_from_decoded_obj($obj);
        return $inner if defined $inner;
    }

    # 2) streaming NDJSON (one JSON object per line)
    my @lines = grep { /\S/ } split /\R/, $raw_text;
    my $accum = '';
    my $last_hash;

    for my $line (@lines) {
        my $o = $self->_try_decode_json($line);
        next unless defined $o && ref($o) eq 'HASH';

        $last_hash = $o;

        die "Ollama error: $o->{error}" if exists $o->{error};

        if (exists $o->{response} && defined $o->{response}) 
        {
            $accum .= $o->{response};
            next;
        }

        if (exists $o->{message} && ref($o->{message}) eq 'HASH') 
        {
            my $c = $o->{message}{content};
            $accum .= $c if defined $c;
            next;
        }
    }

    if (length $accum) 
    {
        my $inner = $self->_try_decode_json($accum);
        die "Invalid model JSON (from streaming): $accum"
            unless defined $inner && ref($inner) eq 'HASH';
        return $inner;
    }

    if (defined $last_hash) 
    {
        my $inner = $self->_inner_from_decoded_obj($last_hash);
        return $inner if defined $inner;
    }

    die "Could not extract model JSON from Ollama output: $raw_text";
}

sub _inner_from_decoded_obj 
{
    my ($self, $obj) = @_;

    return undef unless ref($obj) eq 'HASH';

    # CLI may print inner JSON directly
    return $obj if exists $obj->{operator};

    die "Ollama error: $obj->{error}" if exists $obj->{error};

    # API-ish envelope: { response: "<json>" } or { response: {..} }
    if (exists $obj->{response} && defined $obj->{response}) 
    {
        my $r = $obj->{response};

        return $r if ref($r) eq 'HASH';

        my $inner = $self->_try_decode_json($r);
        die "Invalid model JSON in response field: $r"
            unless defined $inner && ref($inner) eq 'HASH';

        return $inner;
    }

    # Chat envelope: { message: { content: "<json>" } }
    if (exists $obj->{message} && ref($obj->{message}) eq 'HASH') 
    {
        my $c = $obj->{message}{content};
        return undef unless defined $c;

        my $inner = $self->_try_decode_json($c);
        die "Invalid model JSON in message.content: $c"
            unless defined $inner && ref($inner) eq 'HASH';

        return $inner;
    }

    return undef;
}

sub _try_decode_json 
{
    my ($self, $text) = @_;

    my $decoded;
    eval { $decoded = decode_json($text); 1 } or return undef;

    return $decoded;
}

sub _sh_quote 
{
    my ($self, $s) = @_;
    $s = '' unless defined $s;
    $s =~ s/'/'"'"'/g;
    return "'$s'";
}

# --------------------------------------------------

sub _build_propose_prompt 
{
    my ($self, %args) = @_;

    my $value  = $args{value};
    my $target = $args{target};
    my $metric = $args{metric};

    return <<"PROMPT";
Output ONLY this JSON object and nothing else.

{"operator":"add_1"}

Replace add_1 with exactly one of:
add_1
sub_1
add_3
sub_3
mul_2
div_2_if_even

Current value: $value
Target value: $target
Current distance: $metric
PROMPT
}

sub _build_correct_prompt 
{
    my ($self, %args) = @_;

    return <<"PROMPT";
Output ONLY this JSON object and nothing else.

{"operator":"add_1"}

Replace add_1 with exactly one of:
add_1
sub_1
add_3
sub_3
mul_2
div_2_if_even

Current value: $args{value}
Target value: $args{target}
Proposed operator: $args{operator}
Old distance: $args{old_metric}
New distance: $args{new_metric}
Regression tolerance: $args{regression_tolerance}
PROMPT
}

1;

=pod

=head1 NAME

Sim::AgentSoar::Worker - Constrained LLM-backed heuristic proposal engine

=head1 SYNOPSIS

  use Sim::AgentSoar::Worker;

  my $worker = Sim::AgentSoar::Worker->new(
      model => 'llama3.2:1b',
  );

  my $operator = $worker->propose(
      value  => 8,
      target => 19,
      metric => 11,
  );

=head1 DESCRIPTION

Sim::AgentSoar::Worker provides a strictly constrained interface between
the deterministic search controller and a locally hosted Large Language Model
(LLM) via Ollama.

The Worker does not perform search, evaluation, or structural reasoning.
It is limited to proposing candidate operators under tightly controlled prompts.

=head2 Design Constraints

The Worker is intentionally restricted:

=over 4

=item * It may only propose operators from the Engine's allowed list.

=item * It does not evaluate goal satisfaction.

=item * It cannot alter search ordering.

=item * It cannot introduce new operators.

=item * It cannot mutate search topology.

=back

All outputs are validated against deterministic constraints before being
accepted by the search controller.

=head2 Interaction Model

The Worker operates in two phases:

=over 4

=item 1. Proposal phase (propose)

Given current state and target, the model proposes one operator.

=item 2. Optional correction phase (correct)

If regression exceeds a specified tolerance, the model may revise the proposal
once. This constitutes bounded internal recursion.

=back

The recursion is strictly limited to one correction pass to prevent
narrative drift or uncontrolled self-reflection.

=head2 LLM Containment Philosophy

This module embodies a containment model:

=over 4

=item * Structural recursion lives in C<AgentSoar>.

=item * Deterministic evaluation lives in C<Engine>.

=item * Heuristic intuition lives in the LLM.

=back

The LLM is treated as a stochastic heuristic oracle, not as a controller.
All invariant enforcement remains deterministic.

=head1 METHODS

=head2 new

  my $worker = Sim::AgentSoar::Worker->new(
      model => 'llama3.2:1b',
  );

Creates a new worker instance.

=head2 propose

  my $op = $worker->propose(
      value  => $value,
      target => $target,
      metric => $metric,
  );

Returns a single operator string.

=head2 correct

  my $op = $worker->correct(
      value                => $value,
      target               => $target,
      operator             => $previous_op,
      old_metric           => $old_metric,
      new_metric           => $new_metric,
      regression_tolerance => $tolerance,
  );

Performs a single bounded correction pass.

=head1 DEPENDENCIES

Requires:

=over 4

=item * Ollama installed locally

=item * A running Ollama daemon (C<ollama serve>)

=item * A local model compatible with JSON output

=back

=head1 SECURITY AND VALIDATION

All LLM output is parsed as strict JSON and validated against the
Engine's operator list. Invalid or unexpected output causes immediate failure.

=head1 RESEARCH NOTES

This module explores a hybrid architecture in which LLMs serve as
heuristic bias mechanisms within deterministic symbolic search.

The design explicitly prevents:

=over 4

=item * Topological mutation

=item * Self-modifying search logic

=item * Operator invention

=item * Unbounded recursive reflection

=back

The containment boundary is intentional and architectural.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=cut
