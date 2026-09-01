package
	AuthzDemo;

use strict;
use warnings;

use Punk;
use Punk::Authorisation ();

our $VERSION = '0.01';

config 'config/punk.yml';

session secret => 'authz-demo-secret-not-for-anything-real-0123';

# The ladder and the roles hook belong to `auth`, and the plugin reads them
# back through $app->auth_config. Writing `rank` twice - here and again in the
# plugin's options - is how the two drift apart, so it is written once.
#
# sqitch => 1 registers punk_auth's own users table as a schema project, so
# `punk sqitch deploy` creates it before this application's changes, which
# add the `role` column to it.
auth model      => 'User',
     login_path => '/',
     sqitch     => 1,
     rank       => [qw(member editor admin)],
     roles      => sub { my ($c, $user) = @_; $user->{role} };

# The grants table. Punk::Model::Grant ships with this distribution; naming it
# by its full class is what tells Punk it is a class and not a name in this
# application's namespace. The table itself is the punk_authz Sqitch project,
# which the plugin registers when it is given `grants`.
model 'Punk::Model::Grant';

# HERE, and not in config/punk.yml's `plugins:` block, for one reason worth
# knowing: `config` registers the plugins it names as it reads the file, which
# is BEFORE the `auth` line above has run. The plugin reads the ladder out of
# `auth` at registration, so from there it sees no ladder and refuses to boot:
#
#   Punk::Plugin::Authorisation: no rank ladder - `auth rank => [...]`
#   declares one, or pass rank => [...] to the plugin
#
# It refuses at to_app rather than per request, which is the plugin working as
# intended - but the fix is ordering, not passing `rank` twice.
plugin 'Authorisation' => {
    # The default is <AppClass>::Authorisation; named here only because the
    # demo is about being able to see where the rules live.
    policy => 'AuthzDemo::Authorisation',

    # Runtime grants, off unless asked for. Without this, `granted`, `grant`
    # and `revoke_grant` are not installed at all, the rules that call them
    # croak, and the punk_authz project is not registered either: an
    # application with no grants should not carry the table.
    grants => 'Punk::Model::Grant',
};

helper page => sub {
    my ($c, $template, $vars) = @_;
    my $flash = $c->flash || {};
    return $c->render($template, {
        user   => $c->current_user,
        users  => $c->model('User')->all->{rows},
        notice => $flash->{notice},
        kind   => $flash->{kind} // 'ok',
        %{ $vars || {} },
    });
};

# Signing in is a click, because this demo is about authorisation and a
# password form would be the only thing on the page that is not.
get  '/'                 => 'Web::Root#home';
post '/signin'           => 'Web::Root#signin';
post '/logout'           => 'Web::Root#logout';

get  '/doc/:id'          => 'Web::Doc#show';
post '/doc/:id/edit'     => 'Web::Doc#edit';
post '/doc/:id/publish'  => 'Web::Doc#publish';
post '/doc/:id/delete'   => 'Web::Doc#remove';
post '/doc/:id/share'    => 'Web::Doc#share';
post '/doc/:id/unshare'  => 'Web::Doc#unshare';

1;

__END__
