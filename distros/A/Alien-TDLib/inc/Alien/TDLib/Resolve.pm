package Alien::TDLib::Resolve;

use strict;
use warnings;

# The offline fallback, not a pin: an install must not fail because npm is
# unreachable. See ALIEN_TDLIB_VERSION in the POD for how a release is chosen.
our $FALLBACK_NPM     = '0.1008066.0';
our $FALLBACK_VERSION = '1.8.66';
our $FALLBACK_COMMIT  = '022d60202e446ad1287b9fb68e687c8a0760788b';
our $FALLBACK_SHA256  = 'b0837cd880a6de8d45abdfd5024fe0f042c100eb5f241a5f185ba65579acfc32';

# The oldest TDLib whose wire shapes this family has been checked against.
our $MIN_VERSION = '1.8.66';

sub is_commit { defined $_[0] && $_[0] =~ /^[0-9a-f]{40}$/i }

sub parse_spec {
    my ($spec) = @_;
    return { mode => 'latest' }
        if !defined $spec || $spec eq '' || lc $spec eq 'latest';
    return { mode => 'commit', commit => lc $spec } if is_commit($spec);
    return { mode => 'version', version => $spec }  if $spec =~ /^[0-9]+(?:\.[0-9]+){1,2}$/;
    die "ALIEN_TDLIB_VERSION: expected 'latest', a version like 1.8.66, or a "
      . "40-character commit sha (got '$spec')\n";
}

# Pure: the caller fetches, this decides, so t/ can drive it offline.
sub pick {
    my ($meta, $spec) = @_;
    my $versions = $meta->{versions} || {};
    my $tags     = $meta->{'dist-tags'} || {};

    my $from = sub {
        my ($npm) = @_;
        return undef unless $npm && $versions->{$npm};
        my $td = $versions->{$npm}{tdlib} or return undef;
        return { npm => $npm, version => $td->{version}, commit => $td->{commit} };
    };

    if ($spec->{mode} eq 'latest') {
        return $from->($tags->{latest});
    }
    if ($spec->{mode} eq 'version') {
        my $hit = $from->($tags->{"td-$spec->{version}"});
        return $hit if $hit;
        for my $npm (sort keys %$versions) {
            my $td = $versions->{$npm}{tdlib} or next;
            return $from->($npm) if ($td->{version} // '') eq $spec->{version};
        }
        return undef;
    }
    for my $npm (sort keys %$versions) {
        my $td = $versions->{$npm}{tdlib} or next;
        return $from->($npm) if lc($td->{commit} // '') eq $spec->{commit};
    }
    # an unpublished commit is still buildable from source, just not prebuilt
    return { npm => undef, version => undef, commit => $spec->{commit} };
}

sub fallback {
    return { npm => $FALLBACK_NPM, version => $FALLBACK_VERSION,
             commit => $FALLBACK_COMMIT, fallback => 1 };
}

sub resolve {
    my ($spec_string, $platform, $log) = @_;
    $log ||= sub {};
    my $spec = parse_spec($spec_string);

    my $pkg = $platform || 'linux-x64-glibc';
    my $url = "https://registry.npmjs.org/\@prebuilt-tdlib/$pkg";

    my $meta = eval {
        require HTTP::Tiny;
        require JSON::PP;
        my $r = HTTP::Tiny->new(timeout => 60)->get($url);
        die "$r->{status} $r->{reason}\n" unless $r->{success};
        JSON::PP->new->decode($r->{content});
    };
    if (!$meta) {
        my $err = $@ || 'unknown error';
        chomp $err;
        if ($spec->{mode} eq 'commit') {
            $log->("cannot reach the npm registry ($err); building the requested commit from source");
            return { npm => undef, version => undef, commit => $spec->{commit} };
        }
        $log->("cannot reach the npm registry ($err); falling back to TDLib $FALLBACK_VERSION");
        return fallback();
    }

    my $hit = pick($meta, $spec);
    if (!$hit) {
        my $want = $spec->{version} // $spec->{mode};
        die "ALIEN_TDLIB_VERSION: no prebuilt-tdlib release provides TDLib $want\n";
    }
    return $hit;
}

1;
