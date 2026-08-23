use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.29+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
    plan skip_all => 'Punk::Queue and DBD::SQLite required for the later tests'
        unless eval { require Punk::Plugin::Queue; require DBD::SQLite; 1 };
    plan skip_all => 'Template::Stencil 0.10+ required'
        unless eval { require Template::Stencil; Template::Stencil->VERSION('0.10'); 1 };
}

# later: the message is rendered in the request, made durable, queued
# as (class, spec), and the task body sends it through the engine the
# class registered - with each Result status mapped onto the job.

my $dir = File::Temp->newdir;
my %probe;
{
    package T22;
    use Punk;
    use Punk::Plugin::Queue;

    plugin 'Queue' => { dsn => "dbi:SQLite:dbname=$dir/q.db" };
    plugin 'Mailer' => {
        transport => 'capture', from => 'Ops <ops@example.com>',
        base => 'https://t22.example', mail_dir => 't/mail',
        later => { queue => 'mail', attempts => 3 },
        later_inline_max => 2000,
    };

    get '/probe' => sub {
        my ($c) = @_;
        $probe{later} = sub { $c->mail_later(@_) };
        $probe{mail}  = sub { $c->mail(@_) };
        $probe{queue} = $c->queue;
        return $c->text('ok');
    };
}

require Punk::Test;
Punk::Test->new('T22')->get_ok('/probe')->status_is(200);
my $q   = $probe{queue};
my $cap = Punk::Plugin::Mailer->engine_for('T22')->transport;

{
    package FakeUpload;
    sub new { my ($c, %a) = @_; bless {%a}, $c }
    sub path { $_[0]{path} }
    sub filename { $_[0]{filename} }
    sub type { $_[0]{type} }
    sub content { $_[0]{content} }
}

# ---- enqueue: rendered now, sent by the job ---------------------------------------
{
    my $id = $probe{later}->(to => 'a@example.com', subject => 'queued', template => 'verify',
                             data => { name => 'Ann', link => 'https://t22.example/v' });
    ok($id, 'mail_later returns a job id');
    is(scalar @{ $cap->messages }, 0, 'nothing was sent in the request');

    my $info = $q->job_info($id);
    is($info->{task}, 'mail.send', 'the mail.send task');
    is($info->{queue}, 'mail', '  on the configured queue');
    my ($class, $spec) = @{ $info->{args} };
    is($class, 'T22', 'the job carries the application class');
    like($spec->{text}, qr/Hello Ann,/, '  and the rendered text - the template ran in the request');
    like($spec->{html}, qr/Hello Ann,/, '  and html');
    ok(!exists $spec->{template} && !exists $spec->{data}, '  with the plugin keys stripped');
    is($spec->{from}, undef, '  but not the engine defaults, which send adds in the worker');

    my $job = $q->dequeue(queues => 'mail');
    ok($job, 'a worker can claim it');
    ok($q->perform($job), 'and perform it');
    is(scalar @{ $cap->messages }, 1, 'the job sent the message');
    my $m = MIMERead::parse($cap->messages->[0]{bytes});
    like($m->{parts}[0]{body}, qr/Hello Ann,/, '  as rendered');
    $info = $q->job_info($id);
    is($info->{state}, 'finished', 'the job finished');
    like($info->{result}{id}, qr/^<.*>\z/, '  with the Message-ID as its result');
}

# ---- later => 1 on mail is the same thing ---------------------------------------------
{
    my $id = $probe{mail}->(to => 'a@example.com', subject => 'flag', text => "x\n", later => 1);
    ok($id && !ref $id, 'later => 1 returns a job id, not a Result');
    $q->perform($q->dequeue(queues => 'mail'));
    is(scalar @{ $cap->messages }, 2, '  and the job sent it');
}

# ---- durable attachments ----------------------------------------------------------------
{
    open my $fh, '>', "$dir/small.txt" or die $!; print $fh "small file\n"; close $fh;
    my $id = $probe{later}->(to => 'a@example.com', subject => 'att', text => "see\n",
        attachments => [ FakeUpload->new(path => "$dir/small.txt", filename => 'small.txt', type => 'text/plain') ]);
    my ($class, $spec) = @{ $q->job_info($id)->{args} };
    is($spec->{attachments}[0]{content}, "small file\n", 'an upload object was read into the job');
    is($spec->{attachments}[0]{filename}, 'small.txt', '  keeping its filename');
    is($spec->{attachments}[0]{type}, 'text/plain', '  and type');
    unlink "$dir/small.txt";                      # gone, as a request's temp file would be
    $q->perform($q->dequeue(queues => 'mail'));
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    is($m->{parts}[1]{body}, "small file\n", 'and the job still had the bytes');

    open $fh, '>', "$dir/big.txt" or die $!; print $fh 'x' x 5000; close $fh;
    ok(!eval { $probe{later}->(to => 'a@example.com', subject => 'att', text => "see\n",
        attachments => [ FakeUpload->new(path => "$dir/big.txt", filename => 'big.txt') ]); 1 },
        'an upload over later_inline_max croaks');
    like($@, qr/over later_inline_max.*Punk::Plugin::Blob/, '  naming the limit and the Blob plugin');

    $id = $probe{later}->(to => 'a@example.com', subject => 'att', text => "see\n",
        attachments => [ { path => "$dir/big.txt", filename => 'big.txt' } ]);
    ($class, $spec) = @{ $q->job_info($id)->{args} };
    is($spec->{attachments}[0]{path}, "$dir/big.txt", 'a path given as a hashref is left alone');
    $q->perform($q->dequeue(queues => 'mail'));
}

# ---- each Result status on the job -----------------------------------------------------------
{
    for my $case ([ deferred => 'failed', 1 ], [ failed => 'failed', 1 ], [ rejected => 'failed', 1 ]) {
        my ($scripted, $state, $retry) = @$case;
        $cap->{result} = $scripted;                     # the live state hash: script the verdict
        my $id = $probe{later}->(to => 'a@example.com', subject => $scripted, text => "x\n");
        my $ok = $q->perform($q->dequeue(queues => 'mail'));
        ok(!$ok, "a $scripted Result fails the job");
        my $info = $q->job_info($id);
        like($info->{result} // $info->{error} // '', qr/$scripted/, '  with the status in the job');
        if ($scripted eq 'rejected') {
            is($info->{notes}{final}, 1, '  rejected notes final, so the operator can see no retry will help');
        }
    }
    $cap->{result} = 'accepted';
}

done_testing;
