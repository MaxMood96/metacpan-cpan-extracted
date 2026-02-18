use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $name = $agent->{name} // '';
    my $pkt  = $ctx->{input_packet} || {};
    my $out  = defined $pkt->{output} ? $pkt->{output} : '';

    my @lines = _normalize_lines($out);

    return { status => 'fail', critique => "Empty output" } unless @lines;

    # If worker explicitly emitted FAIL:, treat as fail (keeps the gating deterministic).
    if (@lines == 1 && $lines[0] =~ /\AFAIL:\s*(.+?)\s*\z/s) {
        my $why = $1; $why =~ s/\s+/ /g;
        return { status => 'fail', critique => "Worker returned FAIL: $why" };
    }

    # Hard reject if output still contains code-fence markers or looks like code.
    for my $ln (@lines) {
        return { status => 'fail', critique => "Contains markdown/code fences" } if $ln =~ /```/;
        return { status => 'fail', critique => "Looks like code" }
            if $ln =~ /\A(?:\#|import\s|def\s|class\s|from\s|package\s|use\s+strict\b|use\s+warnings\b)\b/;
        return { status => 'fail', critique => "Looks like JSON/object output" }
            if $ln =~ /\A\s*[\{\[]/;
    }

    if ($name eq 'Critic1') {
        return _check_context(\@lines);
    }
    if ($name eq 'Critic2') {
        return _check_track_a(\@lines);
    }
    if ($name eq 'Critic3') {
        return _check_track_b(\@lines);
    }

    return { status => 'fail', critique => "Unexpected critic name '$name'" };
};

sub _normalize_lines {
    my ($s) = @_;
    $s = "" unless defined $s;

    $s =~ s/\r\n/\n/g;
    $s =~ s/\r/\n/g;

    my @lines = split /\n/, $s, -1;

    # trim trailing whitespace
    for (@lines) { s/\s+$//; }

    # drop leading empty lines
    shift @lines while @lines && $lines[0] eq '';

    # drop leading "WorkerX"/"CriticX"/"ChiefX" label line (llama often adds it)
    if (@lines && $lines[0] =~ /\A(?:Worker\d+|Critic\d+|Chief\d+)\z/) {
        shift @lines;
        shift @lines while @lines && $lines[0] eq '';
    }

    # strip outer code fences if the model wrapped the whole thing
    if (@lines && $lines[0] =~ /\A```/) {
        shift @lines;
        shift @lines while @lines && $lines[0] eq '';
    }
    if (@lines && $lines[-1] =~ /\A```/) {
        pop @lines;
    }

    # remove empty lines anywhere (keeps schema checks stable)
    @lines = grep { $_ ne '' } @lines;

    return @lines;
}

sub _check_context {
    my ($lines) = @_;

    return { status => 'fail', critique => "Bad CONTEXT length (expected 14 non-empty lines)" }
        unless @$lines == 14;

    return { status => 'fail', critique => "Line 1 must be 'CONTEXT'" }
        unless $lines->[0] eq 'CONTEXT';

    return { status => 'fail', critique => "Line 2 must start with 'FILE: '" }
        unless $lines->[1] =~ /\AFILE:\s+\S/;

    return { status => 'fail', critique => "Line 3 must start with 'COLUMNS: '" }
        unless $lines->[2] =~ /\ACOLUMNS:\s+\S/;

    return { status => 'fail', critique => "Line 4 must start with 'PROBLEM_STATEMENT: '" }
        unless $lines->[3] =~ /\APROBLEM_STATEMENT:\s+\S/;

    return { status => 'fail', critique => "Line 5 must start with 'TARGET_QUESTION: '" }
        unless $lines->[4] =~ /\ATARGET_QUESTION:\s+\S/;

    return { status => 'fail', critique => "Line 6 must be 'EXCERPT:'" }
        unless $lines->[5] eq 'EXCERPT:';

    for my $i (1..8) {
        my $ln = $lines->[5 + $i];
        return { status => 'fail', critique => "Excerpt line $i must start with '$i|'" }
            unless defined $ln && $ln =~ /\A\Q$i|\E.+/;
    }

    return { status => 'ok' };
}

sub _check_track_a {
    my ($lines) = @_;

    return { status => 'fail', critique => "Bad TRACK_A length (expected 14 non-empty lines)" }
        unless @$lines == 14;

    return { status => 'fail', critique => "Line 1 must be 'TRACK_A'" }
        unless $lines->[0] eq 'TRACK_A';

    return { status => 'fail', critique => "Line 2 must be 'STATS:'" }
        unless $lines->[1] eq 'STATS:';

    for my $i (2..6) {
        return { status => 'fail', critique => "STATS line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "STATS line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'fail', critique => "Line 8 must be 'TRENDS:'" }
        unless $lines->[7] eq 'TRENDS:';

    for my $i (8..10) {
        return { status => 'fail', critique => "TRENDS line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "TRENDS line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'fail', critique => "Line 12 must be 'CAVEATS:'" }
        unless $lines->[11] eq 'CAVEATS:';

    for my $i (12..13) {
        return { status => 'fail', critique => "CAVEATS line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "CAVEATS line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'ok' };
}

sub _check_track_b {
    my ($lines) = @_;

    return { status => 'fail', critique => "Bad TRACK_B length (expected 14 non-empty lines)" }
        unless @$lines == 14;

    return { status => 'fail', critique => "Line 1 must be 'TRACK_B'" }
        unless $lines->[0] eq 'TRACK_B';

    return { status => 'fail', critique => "Line 2 must be 'ANOMALIES:'" }
        unless $lines->[1] eq 'ANOMALIES:';

    for my $i (2..6) {
        return { status => 'fail', critique => "ANOMALIES line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "ANOMALIES line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'fail', critique => "Line 8 must be 'RISKS:'" }
        unless $lines->[7] eq 'RISKS:';

    for my $i (8..10) {
        return { status => 'fail', critique => "RISKS line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "RISKS line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'fail', critique => "Line 12 must be 'CHECKS:'" }
        unless $lines->[11] eq 'CHECKS:';

    for my $i (12..13) {
        return { status => 'fail', critique => "CHECKS line ".($i+1)." must be a '- ' bullet" }
            unless $lines->[$i] =~ /\A-\s+\S/;
        return { status => 'fail', critique => "CHECKS line ".($i+1)." too long" }
            if length($lines->[$i]) > 110;
    }

    return { status => 'ok' };
}
