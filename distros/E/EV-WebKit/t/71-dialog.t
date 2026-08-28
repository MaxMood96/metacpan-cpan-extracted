use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my @seen;
my $b = EV::WebKit->new(window=>[300,200], on_dialog => sub { my ($d)=@_; push @seen, [$d->type, $d->message]; $d->accept('typed') });
my ($prompt_val, $confirm_val);
my $flush_timer;
$b->load_html('<script>alert("A"); window.__p = prompt("Q","def"); window.__c = confirm("C?")</script>', sub {
    $flush_timer = EV::timer(0.4, 0, sub {
        $b->script('return window.__p', sub {
            $prompt_val = $_[0];
            $b->script('return window.__c', sub { $confirm_val=$_[0]; EV::break });
        });
    });
});
TWK::run_with_timeout(10);
ok((grep { $_->[0] eq 'alert' && $_->[1] eq 'A' } @seen), 'alert dialog seen');
ok((grep { $_->[0] eq 'confirm' && $_->[1] eq 'C?' } @seen), 'confirm dialog seen');
is($prompt_val, 'typed', 'prompt accept() returned typed text');
ok($confirm_val, 'confirm() returned true when accepted');
done_testing;
