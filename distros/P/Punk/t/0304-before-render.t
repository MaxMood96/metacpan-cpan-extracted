#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use Test::More;
use File::Temp ();
use Punk::Test;

# hook before_render: the phase a plugin uses to put something into the data
# every template is rendered with, so a value the application never passes
# still resolves. It runs after Punk's own binds (url, csp_nonce, locale),
# with the hashref the engine is about to receive, and whatever it returns is
# dropped - a hook that could replace the response would be a second
# dispatcher.

my $DIR = File::Temp::tempdir(CLEANUP => 1);
_spew("$DIR/plain.tmpl",  '[{% a %}|{% b %}]');
_spew("$DIR/passed.tmpl", '[{% a %}]');

{
    package App::Render;
    use Punk;
    views Stencil => { template_dir => $DIR };

    hook before_render => sub {
        my ($c, $template, $data) = @_;
        $data->{a} = "first:$template";
        $data->{b} = 'from-first';
        return 'ignored';           # a return value is not a response
    };
    hook before_render => sub {
        my ($c, $template, $data) = @_;
        $data->{b} = 'from-second';  # chained, in registration order
    };

    get '/'       => sub { $_[0]->render('plain') };
    get '/passed' => sub { $_[0]->render('passed', { a => 'from-handler' }) };
}

my $t = Punk::Test->new('App::Render');

$t->get_ok('/')->status_is(200)
  ->content_is('[first:plain|from-second]',
      'both hooks ran, in order, and the template got what they bound');

$t->get_ok('/passed')->status_is(200)
  ->content_is('[first:passed]',
      'the hook has the last word over the handler - it runs after the data '
    . 'is built, and the POD says so');

# An application with no hook must be untouched: the chain is stored only when
# there is one, so the ordinary render pays one hv_fetch that misses.
{
    package App::NoHook;
    use Punk;
    views Stencil => { template_dir => $DIR };
    get '/' => sub { $_[0]->render('passed', { a => 'plain' }) };
}
Punk::Test->new('App::NoHook')->get_ok('/')->status_is(200)
  ->content_is('[plain]', 'an application without the hook renders as before');

# The phase is spelled in the croak, so a typo names what it should have been.
{
    my $err;
    eval q{
        package App::BadHook;
        use Punk;
        hook after_render => sub { };
        1;
    } or $err = $@;
    like($err, qr/unknown hook 'after_render'/, 'an unknown phase croaks');
    like($err, qr/before_render/, 'and the message lists this one');
}

# A hook resolves like any other target, so 'Controller#method' works.
{
    package App::Target::Controller::Web::Bind;
    sub bind_it {
        my ($c, $template, $data) = @_;   # a controller target takes $c first
        $data->{a} = 'from-controller';
    }
    package App::Target;
    use Punk;
    views Stencil => { template_dir => $DIR };
    hook before_render => 'Web::Bind#bind_it';
    get '/' => sub { $_[0]->render('passed') };
}
Punk::Test->new('App::Target')->get_ok('/')->status_is(200)
  ->content_is('[from-controller]',
      "a hook takes 'Controller#method' like every other target");

sub _spew {
    my ($f, $c) = @_;
    open my $fh, '>', $f or die "cannot write $f: $!";
    print $fh $c;
    close $fh;
}

done_testing();
