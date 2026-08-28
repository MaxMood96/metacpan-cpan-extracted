use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available(); use TCTL;
use File::Temp qw(tempdir);
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Fingerprint;
plan skip_all => 'web-process extension not built' unless EV::WebKit::Fingerprint::available();

# frames() and frame => { url => ... } have to work over the socket too: a
# client driving a remote browser cannot see the frame tree any other way, and
# a qr// cannot cross JSON, so the string form is the one that has to carry.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/fr.sock";

my $b = EV::WebKit->new(window => [400,300], ephemeral => 1);
$b->mock_scheme('fr', sub {
    my $uri = shift;
    return ('<html><body><h1 id=top>TOP</h1><iframe src="fr://inner"></iframe></body></html>', 'text/html')
        if $uri =~ m{fr://start};
    return ('<html><body><p id=p>IN-FRAME</p></body></html>', 'text/html');
});
my $ctl = EV::WebKit::Control->listen($b, path => $path);
my $cl  = TCTL->new($path);
$cl->pump(1);   # hello

sub reply { $cl->reply(@_) }

reply({ i => 1, m => 'go', a => ['fr://start'] }, 25);
reply({ i => 2, m => 'wait_for_js', a => ['document.querySelectorAll("iframe").length === 1'] }, 25);

my $r = reply({ i => 3, m => 'frames' }, 25);
is($r->{e}, undef, 'frames answers over the socket') or diag $r->{e};
my $f = $r->{r};
is(ref $f, 'ARRAY', 'frames answers with a list');
is(scalar @$f, 2, 'both frames are listed');
is(scalar(grep { $_->{main} } @$f), 1, 'one of them is the main frame');
is(scalar(grep { $_->{url} eq 'fr://inner' } @$f), 1, 'the child frame is named by url');

# the frame option survives the socket, and the handle it yields still reads
# from inside the frame
$r = reply({ i => 4, m => 'find', a => ['#p'], o => { frame => { url => 'fr://inner' } } }, 25);
is($r->{e}, undef, 'find with a frame option is accepted') or diag $r->{e};
my $h = $r->{r}{h};
ok(defined $h, 'it answers with a handle');
is(reply({ i => 5, m => 'el.text', h => $h }, 25)->{r}, 'IN-FRAME',
   'the handle reads the element inside the frame');

# an unmatched frame is an error, not a null result -- same contract as in-process
$r = reply({ i => 6, m => 'find', a => ['#p'], o => { frame => { url => 'fr://nope' } } }, 25);
like($r->{e} // '', qr/no frame matched/, 'an unmatched frame is an error over the socket');

$cl->close;
$ctl->close;
$b->quit;
done_testing;
