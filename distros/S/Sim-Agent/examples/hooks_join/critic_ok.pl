use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $name  = $agent->{name} // '';
    my $pkt   = $ctx->{input_packet} || {};
    my $out   = defined $pkt->{output} ? $pkt->{output} : '';

    # Keep Critic1 permissive (seed context is allowed to be a bit fuzzy)
    if ($name eq 'Critic1') {
        return { status => 'ok' };
    }

    $out =~ s/\r\n/\n/g;

    # Fast fail if the worker explicitly emitted FAIL:
    if ($out =~ /\AFAIL:\s*(.+?)\s*\z/s) {
        my $why = $1;
        $why =~ s/\s+/ /g;
        return { status => 'fail', critique => "Worker returned FAIL: $why" };
    }

    my @lines = split /\n/, $out, -1;
    for (@lines) { s/\s+$//; }
    @lines = grep { $_ ne '' } @lines;

    return { status => 'fail', critique => "Empty output" } unless @lines;
    return { status => 'fail', critique => "Too many lines (cap 30)" } if @lines > 30;

    my ($want_title, $want_s1, $want_s2, $want_s3);
    if ($name eq 'Critic2') {
        ($want_title, $want_s1, $want_s2, $want_s3) = ('TRACK_A', 'STATS:', 'TRENDS:', 'CAVEATS:');
    } elsif ($name eq 'Critic3') {
        ($want_title, $want_s1, $want_s2, $want_s3) = ('TRACK_B', 'ANOMALIES:', 'RISKS:', 'CHECKS:');
    } else {
        return { status => 'fail', critique => "Unexpected critic name '$name'" };
    }

    return { status => 'fail', critique => "Line 1 must be '$want_title'" }
        unless $lines[0] eq $want_title;

    my %sec;
    my $cur = '';
    for my $i (1 .. $#lines) {
        my $ln = $lines[$i];

        if ($ln eq $want_s1 || $ln eq $want_s2 || $ln eq $want_s3) {
            $cur = $ln;
            $sec{$cur} ||= [];
            next;
        }

        return { status => 'fail', critique => "Unexpected content before any section at line " . ($i+1) }
            unless $cur;

        if ($ln =~ /\A-\s+\S/) {
            push @{ $sec{$cur} }, $ln;
            next;
        }

        return { status => 'fail', critique => "Bad line format at line " . ($i+1) . " (expected section header or '- ' bullet)" };
    }

    for my $required ($want_s1, $want_s2, $want_s3) {
        return { status => 'fail', critique => "Missing section '$required'" }
            unless exists $sec{$required};
        return { status => 'fail', critique => "Section '$required' has no bullets" }
            unless @{ $sec{$required} } >= 1;
    }

    return { status => 'ok' };
}
