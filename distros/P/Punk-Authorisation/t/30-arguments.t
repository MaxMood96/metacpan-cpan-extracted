#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}
use TFake ();
use Punk::Plugin::Authorisation ();

# What every helper does when it is called wrongly.
#
# t/10 asserts the decisions; this asserts the arguments, which is the half a
# test suite usually skips and the half a caller meets first. Each of these
# is a croak in the C with a message naming what was missing - and a croak
# that stops saying what it means is a regression nobody notices until they
# are reading a stack trace at the wrong end of a deploy.
#
# The helpers are closures installed on the application, so they are reached
# through ->can and called directly: that is the only way to hand one fewer
# argument than a method call ever supplies.

{
    package TArgs;
    use Punk::Plugin::Authorisation;
    rule 'thing.read' => sub { 1 };
    1;
}

require Punk::App;
my @RANK = Punk::App->can('auth_config') ? ()
         : (rank => [qw(member admin)], roles => sub { $_[1]->{role} });

{
    package App;
    use Punk;

    session secret => 'x' x 32;
    auth model => 'TFake::Model::User', rank => [qw(member admin)],
         roles => sub { my ($c, $u) = @_; $u->{role} };
    database backend => 'TFake::UserBackend';
    model 'TFake::Model::User';
    model 'Punk::Model::Grant';

    plugin 'Authorisation' => { policy => 'TArgs',
                                grants => 'Punk::Model::Grant', @RANK };

    # Every call the test wants to make, made inside a request and reported
    # as text: a helper is a closure over the plugin's configuration and does
    # not exist outside one.
    our $CALL = sub { };
    get '/call' => sub {
        my ($c) = @_;
        my $err = '';
        eval { $CALL->($c); 1 } or $err = $@;
        return $c->text($err eq '' ? 'no croak' : $err);
    };
}

my $app = App->to_app;

sub croaked {
    my ($code) = @_;
    local $App::CALL = $code;
    my $r = $app->({ REQUEST_METHOD => 'GET', PATH_INFO => '/call',
                     QUERY_STRING => '', SERVER_NAME => 'x', SERVER_PORT => 80,
                     HTTP_HOST => 'x', 'psgi.url_scheme' => 'http' });
    return join '', map { defined $_ ? $_ : '' } @{ $r->[2] };
}

# A helper as a plain code reference, so it can be called with no invocant.
sub bare { my ($c, $name) = @_; return $c->can($name) }

# ---- the context methods, called with nothing ----------------------------------

like(croaked(sub { bare($_[0], 'forbidden')->() }),
     qr/forbidden is a context method/,
     'forbidden with no context says so');

like(croaked(sub { bare($_[0], 'not_yours')->() }),
     qr/not_yours is a context method/,
     'and not_yours');

like(croaked(sub { bare($_[0], 'deny')->() }),
     qr/deny is a context method/,
     'and deny');

# ---- may ------------------------------------------------------------------------

like(croaked(sub { $_[0]->may }),
     qr/may needs an action name/,
     'may with no action name croaks rather than deciding');

like(croaked(sub { $_[0]->may(undef) }),
     qr/may needs an action name/,
     'and undef is not an action name either');

# ---- rank_at_least --------------------------------------------------------------

like(croaked(sub { $_[0]->rank_at_least }),
     qr/rank_at_least needs a role name/,
     'rank_at_least with no role croaks');

# ---- the grants helpers ---------------------------------------------------------
#
# The arity and the named argument are checked before the model is touched,
# so none of these reaches a database.

like(croaked(sub { $_[0]->granted('doc.edit') }),
     qr/granted needs an action and an object/,
     'granted needs both halves of the question');

like(croaked(sub { $_[0]->grant('doc.edit') }),
     qr/grant needs an action and an object/,
     'so does grant');

like(croaked(sub { $_[0]->grant('doc.edit', 7) }),
     qr/grant needs to => \$user_id/,
     'and grant will not guess who it is for');

like(croaked(sub { $_[0]->grant('doc.edit', 7, from => 2) }),
     qr/grant needs to => \$user_id/,
     'the wrong name for it is no name at all');

like(croaked(sub { $_[0]->revoke_grant('doc.edit') }),
     qr/revoke_grant needs an action and an object/,
     'revoke_grant needs both halves too');

like(croaked(sub { $_[0]->revoke_grant('doc.edit', 7) }),
     qr/revoke_grant needs from => \$user_id/,
     'and will not guess whose grant to remove');

like(croaked(sub { $_[0]->revoke_grant('doc.edit', 7, to => 2) }),
     qr/revoke_grant needs from => \$user_id/,
     'to is grant\'s word, not revoke_grant\'s');

# ---- and the shapes that are NOT errors -----------------------------------------
#
# `granted` answers a question and the answer to an unanswerable one is no,
# not a croak: a signed-out request asking whether it holds a grant is
# ordinary, and every rule would need an eval around it otherwise.

is(croaked(sub { die "granted said: " . $_[0]->granted('doc.edit', 7) . "\n" }),
   "granted said: 0\n",
   'granted with nobody signed in is 0, not an error');

done_testing();
