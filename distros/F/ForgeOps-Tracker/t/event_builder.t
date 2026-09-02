use strict;
use warnings;
use Test::More;
use Carp qw(confess);
use FindBin qw($Bin);
use lib "$Bin/../lib";
use ForgeOps::Tracker::Configuration;
use ForgeOps::Tracker::EventBuilder;

sub new_configuration {
    my $config = ForgeOps::Tracker::Configuration->new;
    $config->{environment} = 'production';
    $config->{release} = 'abc123';
    $config->{server_name} = 'web-1';
    return $config;
}

subtest 'builds a payload with exception class, message, and configured metadata from a plain die' => sub {
    my $builder = ForgeOps::Tracker::EventBuilder->new(new_configuration());
    eval { die "boom" };
    my $payload = $builder->build($@, { url => 'https://example.com' });

    is($payload->{exception_class}, 'RuntimeError');
    is($payload->{message}, 'boom');
    is($payload->{environment}, 'production');
    is($payload->{release}, 'abc123');
    is($payload->{server_name}, 'web-1');
    is_deeply($payload->{context}, { url => 'https://example.com' });
    like($payload->{occurred_at}, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
};

subtest 'parses the file/line Perl itself appends to a plain die' => sub {
    my $builder = ForgeOps::Tracker::EventBuilder->new(new_configuration());
    eval { die "boom" };
    my $line_of_die = __LINE__ - 1;
    my $frames = $builder->build($@)->{backtrace};

    ok(scalar(@$frames) >= 1);
    is($frames->[0]{file}, __FILE__);
    is($frames->[0]{line}, $line_of_die);
};

subtest 'parses a full Carp::confess call chain into multiple frames' => sub {
    my $builder = ForgeOps::Tracker::EventBuilder->new(new_configuration());

    my $error = do {
        local $@;
        eval { inner_confess() };
        $@;
    };
    my $frames = $builder->build($error)->{backtrace};

    ok(scalar(@$frames) >= 2, 'has at least the confess-site frame and one caller frame');
    ok((grep { defined $_->{method} && $_->{method} =~ /inner_confess/ } @$frames), 'a frame names inner_confess as the calling sub');
};

sub inner_confess { confess('deep failure') }

subtest 'marks a frame under app_root as in_app' => sub {
    my $config = new_configuration();
    eval { die 'boom' };
    my $error = $@;

    # die's auto-appended file location can come back either absolute or relative to the cwd
    # `prove` was invoked from -- confirmed directly (it's relative here, not $Bin, when run via
    # `prove`), so app_root is derived from a real captured frame's own file value rather than
    # assumed to be $Bin (an absolute path FindBin computes independently of how die reports it).
    my $probe = ForgeOps::Tracker::EventBuilder->new($config)->build($error)->{backtrace};
    my ($observed_dir) = $probe->[0]{file} =~ m{^(.*)/[^/]+$};
    ok(defined $observed_dir, 'captured a real frame to derive app_root from') or return;

    $config->{app_root} = $observed_dir;
    my $frames = ForgeOps::Tracker::EventBuilder->new($config)->build($error)->{backtrace};

    ok((grep { $_->{in_app} } @$frames));
};

subtest 'marks every frame as not in_app when app_root does not match' => sub {
    my $config = new_configuration();
    $config->{app_root} = '/definitely/not/here';
    eval { die 'boom' };
    my $frames = ForgeOps::Tracker::EventBuilder->new($config)->build($@)->{backtrace};

    ok(!(grep { $_->{in_app} } @$frames));
};

subtest 'scrubs likely PII out of the message and context by default' => sub {
    my $builder = ForgeOps::Tracker::EventBuilder->new(new_configuration());
    eval { die 'failed for user@example.com' };
    my $payload = $builder->build($@, { user => { email => 'ada@example.com', password => 'hunter2' } });

    is($payload->{message}, 'failed for [EMAIL FILTERED]');
    is_deeply($payload->{context}, { user => { email => '[EMAIL FILTERED]', password => '[FILTERED]' } });
};

subtest 'leaves the payload untouched when scrub_pii is disabled' => sub {
    my $config = new_configuration();
    $config->{scrub_pii} = 0;
    my $builder = ForgeOps::Tracker::EventBuilder->new($config);
    eval { die 'failed for user@example.com' };
    my $payload = $builder->build($@, { email => 'ada@example.com' });

    is($payload->{message}, 'failed for user@example.com');
    is_deeply($payload->{context}, { email => 'ada@example.com' });
};

done_testing;
