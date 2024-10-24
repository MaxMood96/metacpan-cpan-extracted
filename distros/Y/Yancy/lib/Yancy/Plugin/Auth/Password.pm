package Yancy::Plugin::Auth::Password;
our $VERSION = '1.088';
# ABSTRACT: A simple password-based auth

#pod =encoding utf8
#pod
#pod =head1 SYNOPSIS
#pod
#pod     use Mojolicious::Lite;
#pod     plugin Yancy => {
#pod         backend => 'sqlite://myapp.db',
#pod         schema => {
#pod             users => {
#pod                 'x-id-field' => 'username',
#pod                 properties => {
#pod                     username => { type => 'string' },
#pod                     password => { type => 'string', format => 'password' },
#pod                 },
#pod             },
#pod         },
#pod     };
#pod     app->yancy->plugin( 'Auth::Password' => {
#pod         schema => 'users',
#pod         username_field => 'username',
#pod         password_field => 'password',
#pod         password_digest => {
#pod             type => 'SHA-1',
#pod         },
#pod     } );
#pod
#pod =head1 DESCRIPTION
#pod
#pod B<Note:> This module is C<EXPERIMENTAL> and its API may change before
#pod Yancy v2.000 is released.
#pod
#pod This plugin provides a basic password-based authentication scheme for
#pod a site.
#pod
#pod This module composes the L<Yancy::Auth::Plugin::Role::RequireUser> role
#pod to provide the
#pod L<require_user|Yancy::Auth::Plugin::Role::RequireUser/require_user>
#pod authorization method.
#pod
#pod =head2 Adding Users
#pod
#pod To add the initial user (or any user), use the L<C<mojo eval>
#pod command|Mojolicious::Command::eval>:
#pod
#pod     ./myapp.pl eval 'yancy->create( users => { username => "dbell", password => "123qwe" } )'
#pod
#pod This plugin adds the L</auth.digest> filter to the C<password> field, so
#pod the password passed to C<< yancy->create >> will be properly hashed in
#pod the database.
#pod
#pod You can use this same technique to edit users from the command-line if
#pod someone gets locked out:
#pod
#pod     ./myapp.pl eval 'yancy->update( users => "dbell", { password => "123qwe" } )'
#pod
#pod =head2 Migrate from Auth::Basic
#pod
#pod To migrate from the deprecated L<Yancy::Plugin::Auth::Basic> module, you
#pod should set the C<migrate_digest> config setting to the C<password_digest>
#pod settings from your Auth::Basic configuration. If they are the same as your
#pod current password digest settings, you don't need to do anything at all.
#pod
#pod     # Migrate from Auth::Basic, which had SHA-1 passwords, to
#pod     # Auth::Password using SHA-256 passwords
#pod     app->yancy->plugin( 'Auth::Password' => {
#pod         schema => 'users',
#pod         username_field => 'username',
#pod         password_field => 'password',
#pod         migrate_digest => {
#pod             type => 'SHA-1',
#pod         },
#pod         password_digest => {
#pod             type => 'SHA-256',
#pod         },
#pod     } );
#pod
#pod     # Migrate from Auth::Basic, which had SHA-1 passwords, to
#pod     # Auth::Password using SHA-1 passwords
#pod     app->yancy->plugin( 'Auth::Password' => {
#pod         schema => 'users',
#pod         username_field => 'username',
#pod         password_field => 'password',
#pod         password_digest => {
#pod             type => 'SHA-1',
#pod         },
#pod     } );
#pod
#pod =head2 Verifying Yancy Passwords in SQL (or other languages)
#pod
#pod Passwords are stored as base64. The Perl L<Digest> module's removes the
#pod trailing padding from a base64 string. This means that if you try to use
#pod another method to verify passwords, you must also remove any trailing
#pod C<=> from the base64 hash you generate.
#pod
#pod Here are some examples for how to generate the same password hash in
#pod different databases/languages:
#pod
#pod * Perl:
#pod
#pod     $ perl -MDigest -E'say Digest->new( "SHA-1" )->add( "password" )->b64digest'
#pod     W6ph5Mm5Pz8GgiULbPgzG37mj9g
#pod
#pod * MySQL:
#pod
#pod     mysql> SELECT TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) );
#pod     +--------------------------------------------------------------------+
#pod     | TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) ) |
#pod     +--------------------------------------------------------------------+
#pod     | W6ph5Mm5Pz8GgiULbPgzG37mj9g                                        |
#pod     +--------------------------------------------------------------------+
#pod
#pod * Postgres:
#pod
#pod     yancy=# CREATE EXTENSION pgcrypto;
#pod     CREATE EXTENSION
#pod     yancy=# SELECT TRIM( TRAILING '=' FROM encode( digest( 'password', 'sha1' ), 'base64' ) );
#pod                 rtrim
#pod     -----------------------------
#pod      W6ph5Mm5Pz8GgiULbPgzG37mj9g
#pod     (1 row)
#pod
#pod =head1 CONFIGURATION
#pod
#pod This plugin has the following configuration options.
#pod
#pod =head2 schema
#pod
#pod The name of the Yancy schema that holds users. Required.
#pod
#pod =head2 username_field
#pod
#pod The name of the field in the schema which is the user's identifier.
#pod This can be a user name, ID, or e-mail address, and is provided by the
#pod user during login.
#pod
#pod This field is optional. If not specified, the schema's ID field will
#pod be used. For example, if the schema uses the C<username> field as
#pod a unique identifier, we don't need to provide a C<username_field>.
#pod
#pod     plugin Yancy => {
#pod         schema => {
#pod             users => {
#pod                 'x-id-field' => 'username',
#pod                 properties => {
#pod                     username => { type => 'string' },
#pod                     password => { type => 'string' },
#pod                 },
#pod             },
#pod         },
#pod     };
#pod     app->yancy->plugin( 'Auth::Password' => {
#pod         schema => 'users',
#pod         password_digest => { type => 'SHA-1' },
#pod     } );
#pod
#pod =head2 password_field
#pod
#pod The name of the field to use for the password. Defaults to C<password>.
#pod
#pod This field will automatically be set up to use the L</auth.digest> filter to
#pod properly hash the password when updating it.
#pod
#pod =head2 password_digest
#pod
#pod This is the hashing mechanism that should be used for hashing passwords.
#pod This value should be a hash of digest configuration. The one required
#pod field is C<type>, and should be a type supported by the L<Digest> module:
#pod
#pod =over
#pod
#pod =item * MD5 (part of core Perl)
#pod
#pod =item * SHA-1 (part of core Perl)
#pod
#pod =item * SHA-256 (part of core Perl)
#pod
#pod =item * SHA-512 (part of core Perl)
#pod
#pod =item * Bcrypt (recommended)
#pod
#pod =back
#pod
#pod Additional fields are given as configuration to the L<Digest> module.
#pod Not all Digest types require additional configuration.
#pod
#pod There is no default: Perl core provides SHA-1 hashes, but those aren't good
#pod enough. We recommend installing L<Digest::Bcrypt> for password hashing.
#pod
#pod     # Use Bcrypt for passwords
#pod     # Install the Digest::Bcrypt module first!
#pod     app->yancy->plugin( 'Auth::Basic' => {
#pod         password_digest => {
#pod             type => 'Bcrypt',
#pod             cost => 12,
#pod             salt => 'abcdefgh♥stuff',
#pod         },
#pod     } );
#pod
#pod Digest information is stored with the password so that password digests
#pod can be updated transparently when necessary. Changing the digest
#pod configuration will result in a user's password being upgraded the next
#pod time they log in.
#pod
#pod =head2 allow_register
#pod
#pod If true, allow the visitor to register their own user account.
#pod
#pod =head2 register_fields
#pod
#pod An array of fields to show to the user when registering an account. By
#pod default, all required fields from the schema will be presented in the
#pod form to register.
#pod
#pod =head2 Sessions
#pod
#pod This module uses L<Mojolicious
#pod sessions|https://mojolicious.org/perldoc/Mojolicious/Controller#session>
#pod to store the login information in a secure, signed cookie.
#pod
#pod To configure the default expiration of a session, use
#pod L<Mojolicious::Sessions
#pod default_expiration|https://mojolicious.org/perldoc/Mojolicious/Sessions#default_expiration>.
#pod
#pod     use Mojolicious::Lite;
#pod     # Expire a session after 1 day of inactivity
#pod     app->sessions->default_expiration( 24 * 60 * 60 );
#pod
#pod =head1 FILTERS
#pod
#pod This module provides the following filters. See L<Yancy/Extended Field
#pod Configuration> for how to use filters.
#pod
#pod =head2 auth.digest
#pod
#pod Run the field value through the configured password L<Digest> object and
#pod store the Base64-encoded result instead.
#pod
#pod =head1 HELPERS
#pod
#pod This plugin has the following helpers.
#pod
#pod =head2 yancy.auth.current_user
#pod
#pod Get the current user from the session, if any. Returns C<undef> if no
#pod user was found in the session.
#pod
#pod     my $user = $c->yancy->auth->current_user
#pod         || return $c->render( status => 401, text => 'Unauthorized' );
#pod
#pod =head2 yancy.auth.require_user
#pod
#pod Validate there is a logged-in user and optionally that the user data has
#pod certain values. See L<Yancy::Plugin::Auth::Role::RequireUser/require_user>.
#pod
#pod     # Display the user dashboard, but only to logged-in users
#pod     my $auth_route = $app->routes->under( '/user', $app->yancy->auth->require_user );
#pod     $auth_route->get( '' )->to( 'user#dashboard' );
#pod
#pod =head2 yancy.auth.login_form
#pod
#pod Return an HTML string containing the rendered login form.
#pod
#pod     %# Display a login form to an unauthenticated visitor
#pod     % if ( !$c->yancy->auth->current_user ) {
#pod         %= $c->yancy->auth->login_form
#pod     % }
#pod
#pod The login form will create a C<return_to> hidden field to try to bring
#pod the user back to what they were doing when they were asked to log in.
#pod This field defaults to the value of the C<return_to> parameter or the
#pod value of the C<return_to> flash value. If neither is set, it defaults to
#pod the HTTP referrer if the form is displayed on the login page (under the
#pod URL C</yancy/auth/password>) or the current page.
#pod
#pod     # Redirect user to login page, and return them here
#pod     under sub( $c ) {
#pod         return 1 if $c->yancy->auth->current_user;
#pod         $c->flash({ return_to => $c->req->url });
#pod         $c->redirect_to('yancy.auth.password.login');
#pod         return undef;
#pod     }
#pod
#pod     # Build a link to log in and then redirect to the dashboard
#pod     $c->url_for( 'yancy.auth.password.login' )
#pod         ->query({ return_to => $c->url_for( 'dashboard' ) });
#pod
#pod =head2 yancy.auth.logout
#pod
#pod Log out any current account. Use this in your own controller actions to
#pod perform a logout.
#pod
#pod =head1 ROUTES
#pod
#pod This plugin creates the following L<named
#pod routes|https://mojolicious.org/perldoc/Mojolicious/Guides/Routing#Named-routes>.
#pod Use named routes with helpers like
#pod L<url_for|Mojolicious::Plugin::DefaultHelpers/url_for>,
#pod L<link_to|Mojolicious::Plugin::TagHelpers/link_to>, and
#pod L<form_for|Mojolicious::Plugin::TagHelpers/form_for>.
#pod
#pod =head2 yancy.auth.password.login_form
#pod
#pod Display the login form using the L</yancy/auth/password/login_form.html.ep> template. This route handles C<GET>
#pod requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
#pod L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
#pod and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.
#pod
#pod     %= link_to Login => 'yancy.auth.password.login_form'
#pod     <%= link_to 'yancy.auth.password.login_form', begin %>Login<% end %>
#pod     <p>Login here: <%= url_for 'yancy.auth.password.login_form' %></p>
#pod
#pod =head2 yancy.auth.password.login
#pod
#pod Handle login by checking the user's username and password. This route
#pod handles C<POST> requests and can be used with the
#pod L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>
#pod and L<form_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#form_for>
#pod helpers.
#pod
#pod     %= form_for 'yancy.auth.password.login' => begin
#pod         %= text_field 'username', placeholder => 'Username'
#pod         %= text_field 'password', placeholder => 'Password'
#pod         %= submit_button
#pod     % end
#pod
#pod =head2 yancy.auth.password.logout
#pod
#pod Clear the current login and allow the user to log in again. This route handles C<GET>
#pod requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
#pod L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
#pod and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.
#pod
#pod     %= link_to Logout => 'yancy.auth.password.logout'
#pod     <%= link_to 'yancy.auth.password.logout', begin %>Logout<% end %>
#pod     <p>Logout here: <%= url_for 'yancy.auth.password.logout' %></p>
#pod
#pod =head2 yancy.auth.password.register_form
#pod
#pod Display the form to register a new user, if registration is enabled. This route handles C<GET>
#pod requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
#pod L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
#pod and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.
#pod
#pod     %= link_to Register => 'yancy.auth.password.register_form'
#pod     <%= link_to 'yancy.auth.password.register_form', begin %>Register<% end %>
#pod     <p>Register here: <%= url_for 'yancy.auth.password.register_form' %></p>
#pod
#pod =head2 yancy.auth.password.register
#pod
#pod Register a new user, if registration is enabled. This route
#pod handles C<POST> requests and can be used with the
#pod L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>
#pod and L<form_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#form_for>
#pod helpers.
#pod
#pod     %= form_for 'yancy.auth.password.register' => begin
#pod         %= text_field 'username', placeholder => 'Username'
#pod         %= text_field 'password', placeholder => 'Password'
#pod         %= text_field 'password-verify', placeholder => 'Password (again)'
#pod         %# ... Display other fields required for registration
#pod         %= submit_button
#pod     % end
#pod
#pod =head1 TEMPLATES
#pod
#pod To override these templates, add your own at the designated path inside
#pod your app's C<templates/> directory.
#pod
#pod =head2 yancy/auth/password/login_form.html.ep
#pod
#pod The form to log in.
#pod
#pod =head2 yancy/auth/password/login_page.html.ep
#pod
#pod The page containing the form to log in. Uses the C<login_form.html.ep>
#pod template for the form itself.
#pod
#pod =head2 yancy/auth/unauthorized.html.ep
#pod
#pod This template displays an error message that the user is not authorized
#pod to view this page. This most-often appears when the user is not logged
#pod in.
#pod
#pod =head2 yancy/auth/unauthorized.json.ep
#pod
#pod This template renders a JSON object with an "errors" array explaining
#pod the error.
#pod
#pod =head2 layouts/yancy/auth.html.ep
#pod
#pod The layout that Yancy uses when displaying the login form, the
#pod unauthorized error message, and other auth-related pages.
#pod
#pod =head2 yancy/auth/password/register.html.ep
#pod
#pod The page containing the form to register a new user. Will display all of the
#pod L</register_fields>.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Yancy::Plugin::Auth>
#pod
#pod =cut

use Mojo::Base 'Mojolicious::Plugin';
use Role::Tiny::With;
with 'Yancy::Plugin::Auth::Role::RequireUser';
use Yancy::Util qw( currym derp );
use Digest;

has log =>;
has schema =>;
has username_field =>;
has password_field => 'password';
has allow_register => 0;
has plugin_field => undef;
has register_fields => sub { [] };
has moniker => 'password';
has default_digest =>;
has route =>;
has logout_route =>;

# The Auth::Basic digest configuration to migrate from. Auth::Basic did
# not store the digest information in the password, so we need to fix
# it.
has migrate_digest =>;

sub register {
    my ( $self, $app, $config ) = @_;
    $self->init( $app, $config );
    $app->helper(
        'yancy.auth.current_user' => currym( $self, 'current_user' ),
    );
    $app->helper(
        'yancy.auth.logout' => currym( $self, 'logout' ),
    );
    $app->helper(
        'yancy.auth.login_form' => currym( $self, 'login_form' ),
    );
}

sub init {
    my ( $self, $app, $config ) = @_;
    my $schema_name = $config->{schema} || $config->{collection}
        || die "Error configuring Auth::Password plugin: No schema defined\n";
    derp "'collection' configuration in Auth::Token is now 'schema'. Please fix your configuration.\n"
        if $config->{collection};
    my $schema = $app->yancy->schema( $schema_name );
    die sprintf(
        q{Error configuring Auth::Password plugin: Collection "%s" not found}."\n",
        $schema_name,
    ) unless $schema;

    $self->log( $app->log );
    $self->schema( $schema_name );
    $self->username_field( $config->{username_field} );
    $self->password_field( $config->{password_field} || 'password' );
    $self->default_digest( $config->{password_digest} );
    $self->migrate_digest( $config->{migrate_digest} );
    $self->allow_register( $config->{allow_register} );
    $self->register_fields(
        $config->{register_fields} || $app->yancy->schema( $schema_name )->{required} || []
    );
    $app->yancy->filter->add( 'yancy.plugin.auth.password' => sub {
        my ( $key, $value, $schema, @params ) = @_;
        return $self->_digest_password( $value );
    } );

    # Update the schema to digest the password correctly
    my $field = $schema->{properties}{ $self->password_field };
    if ( !grep { $_ eq 'yancy.plugin.auth.password' } @{ $field->{'x-filter'} || [] } ) {
        push @{ $field->{ 'x-filter' } ||= [] },
            'yancy.plugin.auth.password';
    }
    $field->{ format } = 'password';
    $app->yancy->schema( $schema_name, $schema );

    # Add fields that may not technically be required by the schema, but
    # are required for registration
    my @user_fields = (
        $self->username_field || $schema->{'x-id-field'} || 'id',
        $self->password_field,
    );
    for my $field ( @user_fields ) {
        if ( !grep { $_ eq $field } @{ $self->register_fields } ) {
            unshift @{ $self->register_fields }, $field;
        }
    }

    my $route = $app->yancy->routify( $config->{route}, '/yancy/auth/' . $self->moniker );
    $self->route( $route );
    $route->get( 'register' )->to( cb => currym( $self, '_get_register' ) )->name( 'yancy.auth.password.register_form' );
    $route->post( 'register' )->to( cb => currym( $self, '_post_register' ) )->name( 'yancy.auth.password.register' );
    $self->logout_route(
        $route->get( 'logout' )->to( cb => currym( $self, '_get_logout' ) )->name( 'yancy.auth.password.logout' )
    );
    $route->get( '' )->to( cb => currym( $self, '_get_login' ) )->name( 'yancy.auth.password.login_form' );
    $route->post( '' )->to( cb => currym( $self, '_post_login' ) )->name( 'yancy.auth.password.login' );
}

sub _get_user {
    my ( $self, $c, $username ) = @_;
    my $schema_name = $self->schema;
    my $username_field = $self->username_field;
    my %search;
    if ( my $field = $self->plugin_field ) {
        $search{ $field } = $self->moniker;
    }
    if ( $username_field ) {
        $search{ $username_field } = $username;
        my ( $user ) = @{ $c->yancy->backend->list( $schema_name, \%search, { limit => 1 } )->{items} };
        return $user;
    }
    return $c->yancy->backend->get( $schema_name, $username );
}

sub _digest_password {
    my ( $self, $password ) = @_;
    my $config = $self->default_digest;
    my $digest_config_string = _build_digest_config_string( $config );
    my $digest = _get_digest_by_config_string( $digest_config_string );
    my $password_string = join '$', $digest->add( $password )->b64digest, $digest_config_string;
    return $password_string;
}

sub _set_password {
    my ( $self, $c, $username, $password ) = @_;
    my $password_string = eval { $self->_digest_password( $password ) };
    if ( $@ ) {
        $self->log->error(
            sprintf 'Error setting password for user "%s": %s', $username, $@,
        );
    }

    my $id = $self->_get_id_for_username( $c, $username );
    $c->yancy->backend->set( $self->schema, $id, { $self->password_field => $password_string } );
}

sub _get_id_for_username {
    my ( $self, $c, $username ) = @_;
    my $schema_name = $self->schema;
    my $schema = $c->yancy->schema( $schema_name );
    my $id = $username;
    my $id_field = $schema->{'x-id-field'} || 'id';
    my $username_field = $self->username_field;
    if ( $username_field && $username_field ne $id_field ) {
        $id = $self->_get_user( $c, $username )->{ $id_field };
    }
    return $id;
}

sub current_user {
    my ( $self, $c ) = @_;
    return undef unless my $session = $c->session;
    my $yancy    = $session->{yancy} or return undef;
    my $auth     = $yancy->{auth}    or return undef;
    my $username = $auth->{password} or return undef;
    my $user = $self->_get_user( $c, $username );
    delete $user->{ $self->password_field };
    return $user;
}

sub login_form {
    my ( $self, $c ) = @_;
    my $return_to
        # If we've specified one, go there directly
        = $c->req->param( 'return_to' )
        ? $c->req->param( 'return_to' )
        # Check flash storage, perhaps from a redirect to the login form
        : $c->flash('return_to') ? $c->flash('return_to')
        # If this is the login page, go back to referer
        : $c->current_route =~ /^yancy\.auth/
            && $c->req->headers->referrer
            && $c->req->headers->referrer !~ m{^(?:\w+:|//)}
        ? $c->req->headers->referrer
        # Otherwise, return the user here
        : ( $c->req->url->path || '/' )
        ;
    if ( $return_to =~ m{^(?:\w+:|//)} ) {
        return $c->reply->exception(
            q{`return_to` can not contain URL scheme or host},
        );
    }
    return $c->render_to_string(
        'yancy/auth/password/login_form',
        plugin => $self,
        return_to => $return_to,
    );
}

sub _get_login {
    my ( $self, $c ) = @_;
    return $c->render( 'yancy/auth/password/login_page',
        plugin => $self,
    );
}

sub _post_login {
    my ( $self, $c ) = @_;
    my $user = $c->param( 'username' );
    my $pass = $c->param( 'password' );
    if ( $self->_check_pass( $c, $user, $pass ) ) {
        $c->session->{yancy}{auth}{password} = $user;
        my $to = $c->req->param( 'return_to' ) || '/';

        # Do not allow return_to to redirect the user to another site.
        # http://cwe.mitre.org/data/definitions/601.html
        if ( $to =~ m{^(?:\w+:|//)} ) {
            return $c->reply->exception(
                q{`return_to` can not contain URL scheme or host},
            );
        }

        $c->res->headers->location( $to );
        return $c->rendered( 303 );
    }
    $c->flash( error => 'Username or password incorrect' );
    return $c->render( 'yancy/auth/password/login_page',
        status => 400,
        plugin => $self,
        user => $user,
        login_failed => 1,
    );
}

sub _get_register {
    my ( $self, $c ) = @_;
    if ( !$self->allow_register ) {
        $c->app->log->error( 'Registration not allowed (set allow_register)' );
        $c->reply->not_found;
        return;
    }
    return $c->render( 'yancy/auth/password/register',
        plugin => $self,
    );
}

sub _post_register {
    my ( $self, $c ) = @_;
    if ( !$self->allow_register ) {
        $c->app->log->error( 'Registration not allowed (set allow_register)' );
        $c->reply->not_found;
        return;
    }

    my $schema_name = $self->schema;
    my $schema = $c->yancy->schema( $schema_name );
    my $username_field = $self->username_field || $schema->{'x-id-field'} || 'id';
    my $password_field = $self->password_field;

    my $username = $c->param( $username_field );
    my $pass = $c->param( $self->password_field );
    if ( $pass ne $c->param( $self->password_field . '-verify' ) ) {
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => 'password_verify',
        );
    }
    if ( $self->_get_user( $c, $username ) ) {
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => 'user_exists',
        );
    }

    # Create new user
    my $item = {
        $username_field => $username,
        $password_field => $pass,
        (
            map { $_ => $c->param( $_ ) }
            grep { !/^(?:$username_field|$password_field)$/ }
            @{ $self->register_fields }
        ),
    };
    my $id = eval { $c->yancy->create( $schema_name, $item ) };
    if ( my $exception = $@ ) {
        my $error = ref $exception eq 'ARRAY' ? 'validation' : 'create';
        $c->app->log->error( 'Error creating user: ' . $exception );
        return $c->render( 'yancy/auth/password/register',
            status => 400,
            plugin => $self,
            user => $username,
            error => $error,
            exception => $exception,
        );
    }

    # Get them to log in
    $c->flash( info => 'user_created' );
    return $c->redirect_to( 'yancy.auth.password.login' );
}

sub _get_digest {
    my ( $type, @config ) = @_;
    my $digest = eval {
        Digest->new( $type, @config )
    };
    if ( my $error = $@ ) {
        if ( $error =~ m{Can't locate Digest/${type}\.pm in \@INC} ) {
            die sprintf q{Password digest type "%s" not found}."\n", $type;
        }
        die sprintf "Error loading Digest module: %s\n", $@;
    }
    return $digest;
}

sub _get_digest_by_config_string {
    my ( $config_string ) = @_;
    my @digest_parts = split /\$/, $config_string;
    return _get_digest( @digest_parts );
}

sub _build_digest_config_string {
    my ( $config ) = @_;
    my @config_parts = (
        map { $_, $config->{$_} } grep !/^type$/, keys %$config
    );
    return join '$', $config->{type}, @config_parts;
}

sub _check_pass {
    my ( $self, $c, $username, $input_password ) = @_;
    my $user = $self->_get_user( $c, $username );

    if ( !$user ) {
        $self->log->error(
            sprintf 'Error checking password for user "%s": User does not exist',
            $username
        );
        return undef;
    }

    my ( $user_password, $user_digest_config_string )
        = split /\$/, $user->{ $self->password_field }, 2;

    my $force_upgrade = 0;
    if ( !$user_digest_config_string ) {
        # This password must have come from the Auth::Basic module,
        # which did not have digest configuration stored with the
        # password. So, we need to know what kind of digest to use, and
        # we need to fix the password.
        $user_digest_config_string = _build_digest_config_string(
            $self->migrate_digest || $self->default_digest
        );
        $force_upgrade = 1;
    }

    my $digest = eval { _get_digest_by_config_string( $user_digest_config_string ) };
    if ( $@ ) {
        die sprintf 'Error checking password for user "%s": %s', $username, $@;
    }
    my $check_password = $digest->add( $input_password )->b64digest;

    my $success = $check_password eq $user_password;

    my $default_config_string = _build_digest_config_string( $self->default_digest );
    if ( $success && ( $force_upgrade || $user_digest_config_string ne $default_config_string ) ) {
        # We need to re-create the user's password field using the new
        # settings
        $self->_set_password( $c, $username, $input_password );
    }

    return $success;
}

sub logout {
    my ( $self, $c ) = @_;
    delete $c->session->{yancy}{auth}{password};
}

sub _get_logout {
    my ( $self, $c ) = @_;
    $self->logout( $c );
    $c->res->code( 303 );
    my $redirect_to = $c->param( 'redirect_to' ) // $c->req->headers->referrer // '/';
    if ( $redirect_to eq $c->req->url->path ) {
        $redirect_to = '/';
    }
    return $c->redirect_to( $redirect_to );
}

1;

__END__

=pod

=head1 NAME

Yancy::Plugin::Auth::Password - A simple password-based auth

=head1 VERSION

version 1.088

=head1 SYNOPSIS

    use Mojolicious::Lite;
    plugin Yancy => {
        backend => 'sqlite://myapp.db',
        schema => {
            users => {
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string' },
                    password => { type => 'string', format => 'password' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head1 DESCRIPTION

B<Note:> This module is C<EXPERIMENTAL> and its API may change before
Yancy v2.000 is released.

This plugin provides a basic password-based authentication scheme for
a site.

This module composes the L<Yancy::Auth::Plugin::Role::RequireUser> role
to provide the
L<require_user|Yancy::Auth::Plugin::Role::RequireUser/require_user>
authorization method.

=head2 Adding Users

To add the initial user (or any user), use the L<C<mojo eval>
command|Mojolicious::Command::eval>:

    ./myapp.pl eval 'yancy->create( users => { username => "dbell", password => "123qwe" } )'

This plugin adds the L</auth.digest> filter to the C<password> field, so
the password passed to C<< yancy->create >> will be properly hashed in
the database.

You can use this same technique to edit users from the command-line if
someone gets locked out:

    ./myapp.pl eval 'yancy->update( users => "dbell", { password => "123qwe" } )'

=head2 Migrate from Auth::Basic

To migrate from the deprecated L<Yancy::Plugin::Auth::Basic> module, you
should set the C<migrate_digest> config setting to the C<password_digest>
settings from your Auth::Basic configuration. If they are the same as your
current password digest settings, you don't need to do anything at all.

    # Migrate from Auth::Basic, which had SHA-1 passwords, to
    # Auth::Password using SHA-256 passwords
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        migrate_digest => {
            type => 'SHA-1',
        },
        password_digest => {
            type => 'SHA-256',
        },
    } );

    # Migrate from Auth::Basic, which had SHA-1 passwords, to
    # Auth::Password using SHA-1 passwords
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        username_field => 'username',
        password_field => 'password',
        password_digest => {
            type => 'SHA-1',
        },
    } );

=head2 Verifying Yancy Passwords in SQL (or other languages)

Passwords are stored as base64. The Perl L<Digest> module's removes the
trailing padding from a base64 string. This means that if you try to use
another method to verify passwords, you must also remove any trailing
C<=> from the base64 hash you generate.

Here are some examples for how to generate the same password hash in
different databases/languages:

* Perl:

    $ perl -MDigest -E'say Digest->new( "SHA-1" )->add( "password" )->b64digest'
    W6ph5Mm5Pz8GgiULbPgzG37mj9g

* MySQL:

    mysql> SELECT TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) );
    +--------------------------------------------------------------------+
    | TRIM( TRAILING "=" FROM TO_BASE64( UNHEX( SHA1( "password" ) ) ) ) |
    +--------------------------------------------------------------------+
    | W6ph5Mm5Pz8GgiULbPgzG37mj9g                                        |
    +--------------------------------------------------------------------+

* Postgres:

    yancy=# CREATE EXTENSION pgcrypto;
    CREATE EXTENSION
    yancy=# SELECT TRIM( TRAILING '=' FROM encode( digest( 'password', 'sha1' ), 'base64' ) );
                rtrim
    -----------------------------
     W6ph5Mm5Pz8GgiULbPgzG37mj9g
    (1 row)

=encoding utf8

=head1 CONFIGURATION

This plugin has the following configuration options.

=head2 schema

The name of the Yancy schema that holds users. Required.

=head2 username_field

The name of the field in the schema which is the user's identifier.
This can be a user name, ID, or e-mail address, and is provided by the
user during login.

This field is optional. If not specified, the schema's ID field will
be used. For example, if the schema uses the C<username> field as
a unique identifier, we don't need to provide a C<username_field>.

    plugin Yancy => {
        schema => {
            users => {
                'x-id-field' => 'username',
                properties => {
                    username => { type => 'string' },
                    password => { type => 'string' },
                },
            },
        },
    };
    app->yancy->plugin( 'Auth::Password' => {
        schema => 'users',
        password_digest => { type => 'SHA-1' },
    } );

=head2 password_field

The name of the field to use for the password. Defaults to C<password>.

This field will automatically be set up to use the L</auth.digest> filter to
properly hash the password when updating it.

=head2 password_digest

This is the hashing mechanism that should be used for hashing passwords.
This value should be a hash of digest configuration. The one required
field is C<type>, and should be a type supported by the L<Digest> module:

=over

=item * MD5 (part of core Perl)

=item * SHA-1 (part of core Perl)

=item * SHA-256 (part of core Perl)

=item * SHA-512 (part of core Perl)

=item * Bcrypt (recommended)

=back

Additional fields are given as configuration to the L<Digest> module.
Not all Digest types require additional configuration.

There is no default: Perl core provides SHA-1 hashes, but those aren't good
enough. We recommend installing L<Digest::Bcrypt> for password hashing.

    # Use Bcrypt for passwords
    # Install the Digest::Bcrypt module first!
    app->yancy->plugin( 'Auth::Basic' => {
        password_digest => {
            type => 'Bcrypt',
            cost => 12,
            salt => 'abcdefgh♥stuff',
        },
    } );

Digest information is stored with the password so that password digests
can be updated transparently when necessary. Changing the digest
configuration will result in a user's password being upgraded the next
time they log in.

=head2 allow_register

If true, allow the visitor to register their own user account.

=head2 register_fields

An array of fields to show to the user when registering an account. By
default, all required fields from the schema will be presented in the
form to register.

=head2 Sessions

This module uses L<Mojolicious
sessions|https://mojolicious.org/perldoc/Mojolicious/Controller#session>
to store the login information in a secure, signed cookie.

To configure the default expiration of a session, use
L<Mojolicious::Sessions
default_expiration|https://mojolicious.org/perldoc/Mojolicious/Sessions#default_expiration>.

    use Mojolicious::Lite;
    # Expire a session after 1 day of inactivity
    app->sessions->default_expiration( 24 * 60 * 60 );

=head1 FILTERS

This module provides the following filters. See L<Yancy/Extended Field
Configuration> for how to use filters.

=head2 auth.digest

Run the field value through the configured password L<Digest> object and
store the Base64-encoded result instead.

=head1 HELPERS

This plugin has the following helpers.

=head2 yancy.auth.current_user

Get the current user from the session, if any. Returns C<undef> if no
user was found in the session.

    my $user = $c->yancy->auth->current_user
        || return $c->render( status => 401, text => 'Unauthorized' );

=head2 yancy.auth.require_user

Validate there is a logged-in user and optionally that the user data has
certain values. See L<Yancy::Plugin::Auth::Role::RequireUser/require_user>.

    # Display the user dashboard, but only to logged-in users
    my $auth_route = $app->routes->under( '/user', $app->yancy->auth->require_user );
    $auth_route->get( '' )->to( 'user#dashboard' );

=head2 yancy.auth.login_form

Return an HTML string containing the rendered login form.

    %# Display a login form to an unauthenticated visitor
    % if ( !$c->yancy->auth->current_user ) {
        %= $c->yancy->auth->login_form
    % }

The login form will create a C<return_to> hidden field to try to bring
the user back to what they were doing when they were asked to log in.
This field defaults to the value of the C<return_to> parameter or the
value of the C<return_to> flash value. If neither is set, it defaults to
the HTTP referrer if the form is displayed on the login page (under the
URL C</yancy/auth/password>) or the current page.

    # Redirect user to login page, and return them here
    under sub( $c ) {
        return 1 if $c->yancy->auth->current_user;
        $c->flash({ return_to => $c->req->url });
        $c->redirect_to('yancy.auth.password.login');
        return undef;
    }

    # Build a link to log in and then redirect to the dashboard
    $c->url_for( 'yancy.auth.password.login' )
        ->query({ return_to => $c->url_for( 'dashboard' ) });

=head2 yancy.auth.logout

Log out any current account. Use this in your own controller actions to
perform a logout.

=head1 ROUTES

This plugin creates the following L<named
routes|https://mojolicious.org/perldoc/Mojolicious/Guides/Routing#Named-routes>.
Use named routes with helpers like
L<url_for|Mojolicious::Plugin::DefaultHelpers/url_for>,
L<link_to|Mojolicious::Plugin::TagHelpers/link_to>, and
L<form_for|Mojolicious::Plugin::TagHelpers/form_for>.

=head2 yancy.auth.password.login_form

Display the login form using the L</yancy/auth/password/login_form.html.ep> template. This route handles C<GET>
requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.

    %= link_to Login => 'yancy.auth.password.login_form'
    <%= link_to 'yancy.auth.password.login_form', begin %>Login<% end %>
    <p>Login here: <%= url_for 'yancy.auth.password.login_form' %></p>

=head2 yancy.auth.password.login

Handle login by checking the user's username and password. This route
handles C<POST> requests and can be used with the
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>
and L<form_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#form_for>
helpers.

    %= form_for 'yancy.auth.password.login' => begin
        %= text_field 'username', placeholder => 'Username'
        %= text_field 'password', placeholder => 'Password'
        %= submit_button
    % end

=head2 yancy.auth.password.logout

Clear the current login and allow the user to log in again. This route handles C<GET>
requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.

    %= link_to Logout => 'yancy.auth.password.logout'
    <%= link_to 'yancy.auth.password.logout', begin %>Logout<% end %>
    <p>Logout here: <%= url_for 'yancy.auth.password.logout' %></p>

=head2 yancy.auth.password.register_form

Display the form to register a new user, if registration is enabled. This route handles C<GET>
requests and can be used with the L<redirect_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#redirect_to>,
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>,
and L<link_to|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#link_to> helpers.

    %= link_to Register => 'yancy.auth.password.register_form'
    <%= link_to 'yancy.auth.password.register_form', begin %>Register<% end %>
    <p>Register here: <%= url_for 'yancy.auth.password.register_form' %></p>

=head2 yancy.auth.password.register

Register a new user, if registration is enabled. This route
handles C<POST> requests and can be used with the
L<url_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers#url_for>
and L<form_for|https://mojolicious.org/perldoc/Mojolicious/Plugin/TagHelpers#form_for>
helpers.

    %= form_for 'yancy.auth.password.register' => begin
        %= text_field 'username', placeholder => 'Username'
        %= text_field 'password', placeholder => 'Password'
        %= text_field 'password-verify', placeholder => 'Password (again)'
        %# ... Display other fields required for registration
        %= submit_button
    % end

=head1 TEMPLATES

To override these templates, add your own at the designated path inside
your app's C<templates/> directory.

=head2 yancy/auth/password/login_form.html.ep

The form to log in.

=head2 yancy/auth/password/login_page.html.ep

The page containing the form to log in. Uses the C<login_form.html.ep>
template for the form itself.

=head2 yancy/auth/unauthorized.html.ep

This template displays an error message that the user is not authorized
to view this page. This most-often appears when the user is not logged
in.

=head2 yancy/auth/unauthorized.json.ep

This template renders a JSON object with an "errors" array explaining
the error.

=head2 layouts/yancy/auth.html.ep

The layout that Yancy uses when displaying the login form, the
unauthorized error message, and other auth-related pages.

=head2 yancy/auth/password/register.html.ep

The page containing the form to register a new user. Will display all of the
L</register_fields>.

=head1 SEE ALSO

L<Yancy::Plugin::Auth>

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
