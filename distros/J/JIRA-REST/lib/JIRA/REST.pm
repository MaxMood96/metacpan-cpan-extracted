package JIRA::REST;
# ABSTRACT: Thin wrapper around Jira's REST API
$JIRA::REST::VERSION = '0.024';
use 5.016;
use utf8;
use warnings;

use Carp;
use URI;
use Encode;
use MIME::Base64;
use URI::Escape;
use JSON 2.23;
use REST::Client;
use HTTP::CookieJar::LWP;

sub new {
    my ($class, %args) = &_grok_args;

    my ($path, $api) = ($args{url}->path, '/rest/api/latest');
    # See if the user wants a default REST API:
    if ($path =~ s:(/rest/.*)$::) {
        $api = $1;
        $args{url}->path($path);
    }
    # Strip trailing slashes from $path. For some reason they cause 404
    # errors down the road.
    if ($path =~ s:/+$::) {
        $args{url}->path($path);
    }

    unless ($args{anonymous} || $args{pat}) {
        # If username and password are not set we try to lookup the credentials
        if (! defined $args{username} || ! defined $args{password}) {
            ($args{username}, $args{password}) =
                _search_for_credentials($args{url}, $args{username});
        }

        foreach (qw/username password/) {
            croak __PACKAGE__ . "::new: '$_' argument must be a non-empty string.\n"
                if ! defined $args{$_} || ref $args{$_} || length $args{$_} == 0;
        }
    }

    my $rest = REST::Client->new($args{rest_client_config});

    # Set default base URL
    $rest->setHost($args{url});

    # Follow redirects/authentication by default
    $rest->setFollow(1);

    unless ($args{anonymous} || $args{session}) {
        # Since Jira doesn't send an authentication challenge, we force the
        # sending of the authentication header.
        $rest->addHeader(
            Authorization =>
                $args{pat}
                ? "Bearer $args{pat}"
                : 'Basic ' . encode_base64("$args{username}:$args{password}", '')
            );
    }

    for my $ua ($rest->getUseragent) {
        # Configure UserAgent name
        $ua->agent(__PACKAGE__);

        # Set proxy to be used
        $ua->proxy(['http','https'] => $args{proxy}) if $args{proxy};

        # Turn off SSL verification if requested
        $ua->ssl_opts(SSL_verify_mode => 0, verify_hostname => 0) if $args{ssl_verify_none};

        # Configure a cookie_jar so that we can send Cookie headers
        $ua->cookie_jar(HTTP::CookieJar::LWP->new());
    }

    my $jira = bless {
        rest => $rest,
        json => JSON->new->utf8->allow_nonref,
        api  => $api,
    } => $class;

    $jira->{_session} = $jira->POST('/rest/auth/1/session', undef, {
        username => $args{username},
        password => $args{password},
    }) if $args{session};

    return $jira;
}

sub _grok_args {
    my ($class, @args) = @_;

    # Valid option names in the order expected by the old-form constructor
    my @opts = qw/url username password rest_client_config proxy ssl_verify_none anonymous pat session/;

    my %args;

    if (@args == 1 && ref $args[0] && ref $args[0] eq 'HASH') {
        # The new-form constructor expects a single hash reference.
        @args{@opts} = delete @{$args[0]}{@opts};
        croak __PACKAGE__ . "::new: unknown arguments: '", join("', '", sort keys %{$args[0]}), "'.\n"
            if keys %{$args[0]};
    } else {
        # The old-form constructor expects a list of positional parameters.
        @args{@opts} = @args;
    }

    # Turn the url into a URI object
    if (! $args{url}) {
        croak __PACKAGE__ . "::new: 'url' argument must be defined.\n";
    } elsif (! ref $args{url}) {
        $args{url} = URI->new($args{url});
    } elsif (! $args{url}->isa('URI')) {
        croak __PACKAGE__ . "::new: 'url' argument must be a URI object.\n";
    }

    if (!!$args{anonymous} + !!$args{pat} + !!$args{session} > 1) {
        croak __PACKAGE__ . "::new: 'anonymous', 'pat', and 'session' are mutually exclusive options.\n"
    }

    for ($args{rest_client_config}) {
        $_ //= {};
        croak __PACKAGE__ . "::new: 'rest_client_config' argument must be a hash reference.\n"
            unless defined && ref && ref eq 'HASH';
    }

    # remove the REST::Client faux config 'proxy' if set and use it later.
    # This is deprecated since v0.017
    if (my $proxy = delete $args{rest_client_config}{proxy}) {
        carp __PACKAGE__ . "::new: passing 'proxy' in the 'rest_client_config' hash is deprecated. Please, use the corresponding argument instead.\n";
        $args{proxy} //= $proxy;
    }

    return ($class, %args);
}

sub new_session {
    my ($class, @args) = @_;

    if (@args == 1 && ref $args[0] && ref $args[0] eq 'HASH') {
        $args[0]{session} = 1;
    } else {
        $args[8] = 1;
    }

    return $class->new(@args);
}

sub DESTROY {
    my $self = shift;
    $self->DELETE('/rest/auth/1/session') if exists $self->{_session};
    return;
}

sub _search_for_credentials {
    my ($URL, $username) = @_;
    my (@errors, $password);

    # Try .netrc first
    ($username, $password) = eval { _user_pass_from_netrc($URL, $username) };
    push @errors, "Net::Netrc: $@" if $@;
    return ($username, $password) if defined $username && defined $password;

    # Fallback to Config::Identity
    my $stub = $ENV{JIRA_REST_IDENTITY} || "jira";
    ($username, $password) = eval { _user_pass_from_config_identity($stub) };
    push @errors, "Config::Identity: $@" if $@;
    return ($username, $password) if defined $username && defined $password;

    # Still not defined, so we report errors
    for (@errors) {
        chomp;
        s/\n//g;
        s/ at \S+ line \d+.*//;
    }
    croak __PACKAGE__ . "::new: Could not locate credentials. Tried these modules:\n"
        . join("", map { "* $_\n" } @errors)
        . "Please specify the USERNAME and PASSWORD as arguments to new";
}

sub _user_pass_from_config_identity {
    my ($stub) = @_;
    my ($username, $password);
    eval {require Config::Identity; Config::Identity->VERSION(0.0019) }
        or croak "Can't load Config::Identity 0.0019 or later.\n";
    my %id = Config::Identity->load_check( $stub, [qw/username password/] );
    return ($id{username}, $id{password});
}

sub _user_pass_from_netrc {
    my ($URL, $username) = @_;
    my $password;
    eval {require Net::Netrc; 1}
        or croak "Can't require Net::Netrc module.";
    if (my $machine = Net::Netrc->lookup($URL->host, $username)) { # $username may be undef
        $username = $machine->login;
        $password = $machine->password;
    } else {
        croak "No credentials found in the .netrc file.\n";
    }
    return ($username, $password);
}

sub _error {
    my ($self, $content, $type, $code) = @_;

    $type = 'text/plain' unless $type;
    $code = 500          unless $code;

    my $msg = __PACKAGE__ . " Error[$code";

    if (eval {require HTTP::Status}) {
        if (my $status = HTTP::Status::status_message($code)) {
            $msg .= " - $status";
        }
    }

    $msg .= "]:\n";

    if ($type =~ m:text/plain:i) {
        $msg .= $content;
    } elsif ($type =~ m:application/json:) {
        # Jira errors may be laid out in all sorts of ways. You have to look
        # them up from the scant documentation at
        # https://docs.atlassian.com/jira/REST/latest/.  Previously, I tried to
        # grok the actual message inside this JSON structure but I failed
        # miserably. So, I decided to give up and simply show the actual JSON
        # string as a message. It won't be as readable, but it will be complete
        # and correct!
        $msg .= $content;
    } elsif ($type =~ m:text/html:i && eval {require HTML::TreeBuilder}) {
        $msg .= HTML::TreeBuilder->new_from_content($content)->as_text;
    } elsif ($type =~ m:^(text/|application|xml):i) {
        $msg .= "<Content-Type: $type>$content</Content-Type>";
    } else {
        $msg .= "<Content-Type: $type>(binary content not shown)</Content-Type>";
    };
    $msg =~ s/\n*$/\n/s;       # end message with a single newline
    return $msg;
}

sub _content {
    my ($self) = @_;

    my $rest    = $self->{rest};
    my $code    = $rest->responseCode();
    my $type    = $rest->responseHeader('Content-Type');
    my $content = $rest->responseContent();

    $code =~ /^2/
        or croak $self->_error($content, $type, $code);

    return unless $content;

    if (! defined $type) {
        croak $self->_error("Cannot convert response content with no Content-Type specified.");
    } elsif ($type =~ m:^application/json:i) {
        return $self->{json}->decode($content);
    } elsif ($type =~ m:^text/plain:i) {
        return $content;
    } else {
        croak $self->_error("I don't understand content with Content-Type '$type'.");
    }
}

sub _build_path {
    my ($self, $path, $query) = @_;

    # Prefix $path with the default API prefix unless it already specifies
    # one or it's an absolute URL.
    $path = $self->{api} . $path unless $path =~ m@^(?:/rest/|(?i)https?:)@;

    if (defined $query) {
        croak $self->_error("The QUERY argument must be a hash reference.")
            unless ref $query && ref $query eq 'HASH';
        return $path . '?'. join('&', map {$_ . '=' . uri_escape($query->{$_})} keys %$query);
    } else {
        return $path;
    }
}

sub GET {
    my ($self, $path, $query) = @_;

    $self->{rest}->GET($self->_build_path($path, $query));

    return $self->_content();
}

sub DELETE {
    my ($self, $path, $query) = @_;

    $self->{rest}->DELETE($self->_build_path($path, $query));

    return $self->_content();
}

sub PUT {
    my ($self, $path, $query, $value, $headers) = @_;

    $path = $self->_build_path($path, $query);

    $headers                   ||= {};
    $headers->{'Content-Type'} //= 'application/json;charset=UTF-8';

    $self->{rest}->PUT($path, $self->{json}->encode($value), $headers);

    return $self->_content();
}

sub POST {
    my ($self, $path, $query, $value, $headers) = @_;

    $path = $self->_build_path($path, $query);

    $headers                   ||= {};
    $headers->{'Content-Type'} //= 'application/json;charset=UTF-8';

    $self->{rest}->POST($path, $self->{json}->encode($value), $headers);

    return $self->_content();
}

sub rest_client {
    my ($self) = @_;
    return $self->{rest};
}

sub set_search_iterator {
    my ($self, $params) = @_;

    my %params = ( %$params );  # rebuild the hash to own it

    $params{startAt} = 0;

    $self->{iter} = {
        params  => \%params,    # params hash to be used in the next call
        offset  => 0,           # offset of the next issue to be fetched
        results => {            # results of the last call (this one is fake)
            startAt => 0,
            total   => -1,
            issues  => [],
        },
    };

    return;
}

sub next_issue {
    my ($self) = @_;

    my $iter = $self->{iter}
        or croak $self->_error("You must call set_search_iterator before calling next_issue");

    if ($iter->{offset} == $iter->{results}{total}) {
        # This is the end of the search results
        $self->{iter} = undef;
        return;
    } elsif ($iter->{offset} == $iter->{results}{startAt} + @{$iter->{results}{issues}}) {
        # Time to get the next bunch of issues
        $iter->{params}{startAt} = $iter->{offset};
        $iter->{results}         = $self->POST('/search', undef, $iter->{params});
    }

    return $iter->{results}{issues}[$iter->{offset}++ - $iter->{results}{startAt}];
}

sub attach_files {
    my ($self, $issueIdOrKey, @files) = @_;

    # We need to violate the REST::Client class encapsulation to implement
    # the HTTP POST method necessary to invoke the /issue/key/attachments
    # REST endpoint because it has to use the form-data Content-Type.

    my $rest = $self->{rest};

    # FIXME: How to attach all files at once?
    foreach my $file (@files) {
        my $response = $rest->getUseragent()->post(
            $rest->getHost . "/rest/api/latest/issue/$issueIdOrKey/attachments",
            %{$rest->{_headers}},
            'X-Atlassian-Token' => 'nocheck',
            'Content-Type'      => 'form-data',
            'Content'           => [ file => [$file, encode_utf8( $file )] ],
        );

        $response->is_success
            or croak $self->_error("attach_files($file): " . $response->status_line);
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

JIRA::REST - Thin wrapper around Jira's REST API

=head1 VERSION

version 0.024

=head1 SYNOPSIS

    use JIRA::REST;

    my $jira = JIRA::REST->new({
        url      => 'https://jira.example.net',
        username => 'myuser',
        password => 'mypass',
    });

    my $jira_with_session = JIRA::REST->new({
        url      => 'https://jira.example.net',
        username => 'myuser',
        password => 'mypass',
        session  => 1,
    });

    my $jira_with_pat = JIRA::REST->new({
        url => 'https://jira.example.net',
        pat => 'NDc4NDkyNDg3ODE3OstHYSeYC1GnuqRacSqvUbookcZk',
    });

    my $jira_anonymous = JIRA::REST->new({
        url => 'https://jira.example.net',
        anonymous => 1,
    });

    # File a bug
    my $issue = $jira->POST('/issue', undef, {
        fields => {
            project   => { key => 'PRJ' },
            issuetype => { name => 'Bug' },
            summary   => 'Cannot login',
            description => 'Bla bla bla',
        },
    });

    # Get issue
    $issue = $jira->GET("/issue/TST-101");

    # Iterate on issues
    my $search = $jira->POST('/search', undef, {
        jql        => 'project = "TST" and status = "open"',
        startAt    => 0,
        maxResults => 16,
        fields     => [ qw/summary status assignee/ ],
    });

    foreach my $issue (@{$search->{issues}}) {
        print "Found issue $issue->{key}\n";
    }

    # Iterate using utility methods
    $jira->set_search_iterator({
        jql        => 'project = "TST" and status = "open"',
        maxResults => 16,
        fields     => [ qw/summary status assignee/ ],
    });

    while (my $issue = $jira->next_issue) {
        print "Found issue $issue->{key}\n";
    }

    # Attach files using an utility method
    $jira->attach_files('TST-123', '/path/to/doc.txt', 'image.png');

=head1 DESCRIPTION

L<Jira|http://www.atlassian.com/software/jira/> is a proprietary bug
tracking system from Atlassian.

This module implements a very thin wrapper around Jira's REST APIs:

=over

=item * L<Jira Core REST API|https://docs.atlassian.com/software/jira/docs/api/REST/latest/>

This rich API superseded the old L<Jira SOAP
API|http://docs.atlassian.com/software/jira/docs/api/rpc-jira-plugin/latest/com/atlassian/jira/rpc/soap/JiraSoapService.html>
which isn't supported anymore as of Jira version 7.

The endpoints of this API have a path prefix of C</rest/api/VERSION>.

=item * L<Jira Service Desk REST API|https://docs.atlassian.com/jira-servicedesk/REST/server/>

This API deals with the objects of the Jira Service Desk application. Its
endpoints have a path prefix of C</rest/servicedeskapi>.

=item * L<Jira Software REST API|https://docs.atlassian.com/jira-software/REST/server/>

This API deals with the objects of the Jira Software application. Its
endpoints have a path prefix of C</rest/agile/VERSION>.

=back

=head1 CONSTRUCTORS

=head2 new HASHREF

=head2 new URL, USERNAME, PASSWORD, REST_CLIENT_CONFIG, PROXY, SSL_VERIFY_NONE, ANONYMOUS, PAT, SESSION

The default constructor can take its arguments from a single hash reference or
from a list of positional parameters. The first form is preferred because it
lets you specify only the arguments you need. The second form forces you to pass
undefined values if you need to pass a specific value to an argument further to
the right.

The arguments are described below with the names which must be used as the
hash keys:

=over 4

=item * B<url>

A string or a URI object denoting the base URL of the Jira server. This is a
required argument.

The REST methods described below all accept as a first argument the
endpoint's path of the specific API method to call. In general you can pass
the complete path, beginning with the prefix denoting the particular API to
use (C</rest/api/VERSION>, C</rest/servicedeskapi>, or
C</rest/agile/VERSION>). However, you may specify a default API prefix by
suffixing the URL with it. For example:

    my $jira = JIRA::REST->new({
        url      => 'https://jira.example.net/jira/rest/api/1',
        username => 'myuser',
        password => 'mypass'
    });

    $jira->GET('/rest/api/1/issue/TST-1');
    $jira->GET('/issue/TST-1');

With this constructor call both GET methods are the same, because the second
one does not specify an API prefix. This is useful if you mainly want to use
a particular API or if you want to specify a particular version of an API
during construction.

=item * B<username>

=item * B<password>

The username and password of a Jira user to use for authentication.

If B<anonymous> is false and no B<pat> given, then, if either B<username> or
B<password> isn't defined the module looks them up in either the C<.netrc> file
or via L<Config::Identity> (which allows C<gpg> encrypted credentials).

L<Config::Identity> will look for F<~/.jira-identity> or F<~/.jira>.
You can change the filename stub from C<jira> to a custom stub with the
C<JIRA_REST_IDENTITY> environment variable.

=item * B<rest_client_config>

A JIRA::REST object uses a L<REST::Client> object to make the REST
invocations. This optional argument must be a hash reference that can be fed
to the REST::Client constructor. Note that the C<url> argument
overwrites any value associated with the C<host> key in this hash.

As an extension, the hash reference also accepts one additional argument
called B<proxy> that is an extension to the REST::Client configuration and
will be removed from the hash before passing it on to the REST::Client
constructor. However, this argument is deprecated since v0.017 and you
should avoid it. Use the following argument instead.

=item * B<proxy>

To use a network proxy set this argument to the string or URI object
describing the fully qualified URL (including port) to your network proxy.

=item * B<ssl_verify_none>

Sets the C<SSL_verify_mode> and C<verify_hostname ssl> options on the
underlying L<REST::Client>'s user agent to 0, thus disabling them. This
allows access to Jira servers that have self-signed certificates that don't
pass L<LWP::UserAgent>'s verification methods.

=item * B<anonymous>

=item * B<pat>

=item * B<session>

These three arguments are mutually exclusive, i.e., you can use at most one of
them. By default, they are all undefined.

The boolean B<anonymous> argument tells the module if you want to connect to the
specified Jira with no authentication. This allows you to get some information
from open or public Jira servers. If enabled, the B<username> and B<password>
arguments are disregarded.

The B<pat> argument maps to a string which should be a personal access token
that can be used for authentication instead of a username and a password.  This
option is available since Jira version 8.14.  Please refer to
L<https://confluence.atlassian.com/enterprise/using-personal-access-tokens-1026032365.html>
for details. If enabled, the B<username> and B<password> arguments are
disregarded.

The booleal B<session> argument tells the module if you want it to acquire a
session cookie by making a C<POST /rest/auth/1/session> call to login to
Jira. This is particularly useful when interacting with Jira Data Center,
because it can use the session cookie to maintain affinity with one of the
redundant servers. Upon destruction, the object makes a C<DELETE
/rest/auth/1/session> call to logout from Jira. If enabled, the B<username> and
B<password> arguments are required.

=back

=head2 new_session OPTIONS

This alternative constructor simply invokes the default constructor with the
same options, adding to them the B<session> option. New code should use the
default constructor with the B<session> option because this constructor may be
deprecated in the future.

=head1 REST METHODS

Jira's REST API documentation lists dozens of "resources" which can be
operated via the standard HTTP requests: GET, DELETE, PUT, and
POST. JIRA::REST objects implement four methods called GET, DELETE,
PUT, and POST to make it easier to invoke and get results from Jira's
REST endpoints.

All four methods need two arguments:

=over

=item * RESOURCE

This is the resource's 'path'. For example, in order to GET the list of all
fields, you pass C</rest/api/latest/field>, and in order to get SLA
information about an issue you pass
C</rest/servicedeskapi/request/$key/sla>.

If you're using a method from Jira Core REST API you may omit the prefix
C</rest/api/VERSION>. For example, to GET the list of all fields you may
pass just C</field>.

This argument is required.

=item * QUERY

Some resource methods require or admit parameters which are passed as
a C<query-string> appended to the resource's path. You may construct
the query string and append it to the RESOURCE argument yourself, but
it's easier and safer to pass the arguments in a hash. This way the
query string is constructed for you and its values are properly
L<percent-encoded|http://en.wikipedia.org/wiki/Percent-encoding> to
avoid errors.

This argument is optional for GET and DELETE. For PUT and POST it must
be passed explicitly as C<undef> if not needed.

=back

The PUT and POST methods accept two more arguments:

=over

=item * VALUE

This is the "entity" being PUT or POSTed. It can be any value, but
usually is a hash reference. The value is encoded as a
L<JSON|http://www.json.org/> string using the C<JSON::encode> method
and sent with a Content-Type of C<application/json>.

It's usually easy to infer from the Jira REST API documentation which
kind of value you should pass to each resource.

This argument is required.

=item * HEADERS

This optional argument allows you to specify extra HTTP headers that
should be sent with the request. Each header is specified as a
key/value pair in a hash.

=back

All four methods return the value returned by the associated
resource's method, as specified in the documentation, decoded
according to its content type as follows:

=over

=item * application/json

The majority of the API's resources return JSON values. Those are
decoded using the C<decode> method of a C<JSON> object. Most of the
endpoints return hashes, which are returned as a Perl hash reference.

=item * text/plain

Those values are returned as simple strings.

=back

Some endpoints don't return anything. In those cases, the methods
return C<undef>. The methods croak if they get any other type of
values in return.

In case of errors (i.e., if the underlying HTTP method return an error
code different from 2xx) the methods croak with a multi-line string
like this:

    ERROR: <CODE> - <MESSAGE>
    <CONTENT-TYPE>
    <CONTENT>

So, in order to treat errors you must invoke the methods in an eval
block or use any of the exception handling Perl modules, such as
C<Try::Tiny> and C<Try::Catch>.

=head2 GET RESOURCE [, QUERY]

Returns the RESOURCE as a Perl data structure.

=head2 DELETE RESOURCE [, QUERY]

Deletes the RESOURCE.

=head2 PUT RESOURCE, QUERY, VALUE [, HEADERS]

Creates RESOURCE based on VALUE.

=head2 POST RESOURCE, QUERY, VALUE [, HEADERS]

Updates RESOURCE based on VALUE.

=head1 UTILITY METHODS

This module provides a few utility methods.

=head2 B<rest_client>

Returns the L<REST::Client> object used to interact with Jira. It may be useful
when the Jira API isn't enough and you have to go deeper.

=head2 B<set_search_iterator> PARAMS

Sets up an iterator for the search specified by the hash reference PARAMS.
It must be called before calls to B<next_issue>.

PARAMS must conform with the query parameters allowed for the
C</rest/api/2/search> Jira REST endpoint.

=head2 B<next_issue>

This must be called after a call to B<set_search_iterator>. Each call
returns a reference to the next issue from the filter. When there are no
more issues it returns undef.

Using the set_search_iterator/next_issue utility methods you can iterate
through large sets of issues without worrying about the startAt/total/offset
attributes in the response from the /search REST endpoint. These methods
implement the "paging" algorithm needed to work with those attributes.

=head2 B<attach_files> ISSUE FILE...

The C</issue/KEY/attachments> REST endpoint, used to attach files to issues,
requires a specific content type encoding which is difficult to come up with
just the C<REST::Client> interface. This utility method offers an easier
interface to attach files to issues.

=head1 PERL AND JIRA COMPATIBILITY POLICY

Currently L<JIRA::REST> requires Perl 5.16 and is tested on Jira Data Center
8.13.

We try to be compatible with the Perl native packages of the oldest L<Ubuntu
LTS|https://www.ubuntu.com/info/release-end-of-life> and
L<CentOS|https://wiki.centos.org/About/Product> Linux distributions still
getting maintainance updates.

  +-------------+-----------------------+------+
  | End of Life | Distro                | Perl |
  +-------------+-----------------------+------+
  |   2023-04   | Ubuntu 18.04 (bionic) | 5.26 |
  |   2024-07   | CentOS 7              | 5.16 |
  |   2025-04   | Ubuntu 20.04 (focal)  | 5.30 |
  |   2027-04   | Ubuntu 22.04 (jammy)  | 5.34 |
  |   2029-05   | CentOS 8              | 5.26 |
  +-------------+-----------------------+------+

As you can see, we're kept behind mostly by the slow pace of CentOS (actually,
RHEL) releases.

As for Jira, the policy is very lax. I (the author) only test L<JIRA::REST> on
the Jira server installed in the company I work for, which is usually (but not
always) at most one year older than the newest released version. I don't have
yet an easy way to test it on different versions.

=head1 SEE ALSO

=over

=item * C<REST::Client>

JIRA::REST uses a REST::Client object to perform the low-level interactions.

=item * C<JIRA::REST::OAuth>

This module Sub Classes JIRA::REST providing OAuth 1.0 support.

=item * C<JIRA::Client::REST>

This is another module implementing Jira's REST API using
L<SPORE|https://github.com/SPORE/specifications/blob/master/spore_description.pod>.
I got a message from the author saying that he doesn't intend to keep
it going.

=back

=head1 REPOSITORY

L<https://github.com/gnustavo/JIRA-REST>

=head1 AUTHOR

Gustavo L. de M. Chaves <gnustavo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by CPQD <www.cpqd.com.br>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
