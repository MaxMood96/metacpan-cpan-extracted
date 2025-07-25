# NAME

Firefox::Marionette - Automate the Firefox browser with the Marionette protocol

# VERSION

Version 1.67

# SYNOPSIS

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    say $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

    say $firefox->html();

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    say "Height of page-content div is " . $firefox->find_class('page-content')->css('height');

    my $file_handle = $firefox->selfie();

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

# DESCRIPTION

This is a client module to automate the Mozilla Firefox browser via the [Marionette protocol](https://developer.mozilla.org/en-US/docs/Mozilla/QA/Marionette/Protocol)

# CONSTANTS

## BCD\_PATH

returns the local path used for storing the brower compability data for the [agent](#agent) method when the `stealth` parameter is supplied to the [new](#new) method.  This database is built by the [build-bcd-for-firefox](https://metacpan.org/pod/build-bcd-for-firefox) binary.

# SUBROUTINES/METHODS

## accept\_alert

accepts a currently displayed modal message box

## accept\_connections

Enables or disables accepting new socket connections.  By calling this method with false the server will not accept any further connections, but existing connections will not be forcible closed. Use true to re-enable accepting connections.

Please note that when closing the connection via the client you can end-up in a non-recoverable state if it hasn't been enabled before.

## active\_element

returns the active element of the current browsing context's document element, if the document element is non-null.

## add\_bookmark

accepts a [bookmark](https://metacpan.org/pod/Firefox::Marionette::Bookmark) as a parameter and adds the specified bookmark to the Firefox places database.

    use Firefox::Marionette();

    my $bookmark = Firefox::Marionette::Bookmark->new(
                     url   => 'https://metacpan.org',
                     title => 'This is MetaCPAN!'
                             );
    my $firefox = Firefox::Marionette->new()->add_bookmark($bookmark);

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## add\_certificate

accepts a hash as a parameter and adds the specified certificate to the Firefox database with the supplied or default trust.  Allowed keys are below;

- path - a file system path to a single [PEM encoded X.509 certificate](https://datatracker.ietf.org/doc/html/rfc7468#section-5).
- string - a string containing a single [PEM encoded X.509 certificate](https://datatracker.ietf.org/doc/html/rfc7468#section-5)
- trust - This is the [trustargs](https://www.mankier.com/1/certutil#-t) value for [NSS](https://wiki.mozilla.org/NSS).  If defaults to 'C,,';

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();

    my $pem_encoded_string = <<'_PEM_';
    -----BEGIN CERTIFICATE-----
    MII..
    -----END CERTIFICATE-----
    _PEM_
    my $firefox = Firefox::Marionette->new()->add_certificate(string => $pem_encoded_string);

## add\_cookie

accepts a single [cookie](https://metacpan.org/pod/Firefox::Marionette::Cookie) object as the first parameter and adds it to the current cookie jar.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

This method throws an exception if you try to [add a cookie for a different domain than the current document](https://developer.mozilla.org/en-US/docs/Web/WebDriver/Errors/InvalidCookieDomain).

## add\_header

accepts a hash of HTTP headers to include in every future HTTP Request.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_header( 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers.  To clear headers, see the [delete\_header](#delete_header) method

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->delete_header( 'Accept' )->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

will only send out an [Accept](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept) header that looks like `Accept: text/perl`.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->add_header( 'Accept' => 'text/perl' )->go('https://metacpan.org/');

by itself, will send out an [Accept](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept) header that may resemble `Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8, text/perl`. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## add\_login

accepts a hash of the following keys;

- host - The scheme + hostname of the page where the login applies, for example 'https://www.example.org'.
- user - The username for the login.
- password - The password for the login.
- origin - The scheme + hostname that the form-based login [was submitted to](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action).  Forms with no [action attribute](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action) default to submitting to the URL of the page containing the login form, so that is stored here. This field should be omitted (it will be set to undef) for http auth type authentications and "" means to match against any form action.
- realm - The HTTP Realm for which the login was requested. When an HTTP server sends a 401 result, the WWW-Authenticate header includes a realm. See [RFC 2617](https://datatracker.ietf.org/doc/html/rfc2617).  If the realm is not specified, or it was blank, the hostname is used instead. For HTML form logins, this field should not be specified.
- user\_field - The name attribute for the username input in a form. Non-form logins should not specify this field.
- password\_field - The name attribute for the password input in a form. Non-form logins should not specify this field.

or a [Firefox::Marionette::Login](https://metacpan.org/pod/Firefox::Marionette::Login) object as the first parameter and adds the login to the Firefox login database.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();

    # for http auth logins

    my $http_auth_login = Firefox::Marionette::Login->new(host => 'https://pause.perl.org', user => 'AUSER', password => 'qwerty', realm => 'PAUSE');
    $firefox->add_login($http_auth_login);
    $firefox->go('https://pause.perl.org/pause/authenquery')->accept_alert(); # this goes to the page and submits the http auth popup

    # for form based login

    my $form_login = Firefox::Marionette::Login(host => 'https://github.com', user => 'me2@example.org', password => 'uiop[]', user_field => 'login', password_field => 'password');
    $firefox->add_login($form_login);

    # or just directly

    $firefox->add_login(host => 'https://github.com', user => 'me2@example.org', password => 'uiop[]', user_field => 'login', password_field => 'password');

Note for HTTP Authentication, the [realm](https://datatracker.ietf.org/doc/html/rfc2617#section-2) must perfectly match the correct [realm](https://datatracker.ietf.org/doc/html/rfc2617#section-2) supplied by the server.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## add\_site\_header

accepts a host name and a hash of HTTP headers to include in every future HTTP Request that is being sent to that particular host.

    use Firefox::Marionette();
    use UUID();

    my $firefox = Firefox::Marionette->new();
    my $uuid = UUID::uuid();
    $firefox->add_site_header( 'metacpan.org', 'Track-my-automated-tests' => $uuid );
    $firefox->go('https://metacpan.org/');

these headers are added to any existing headers going to the metacpan.org site, but no other site.  To clear site headers, see the [delete\_site\_header](#delete_site_header) method

## add\_webauthn\_authenticator

accepts a hash of the following keys;

- has\_resident\_key - boolean value to indicate if the authenticator will support [client side discoverable credentials](https://www.w3.org/TR/webauthn-2/#client-side-discoverable-credential)
- has\_user\_verification - boolean value to determine if the [authenticator](https://www.w3.org/TR/webauthn-2/#virtual-authenticators) supports [user verification](https://www.w3.org/TR/webauthn-2/#user-verification).
- is\_user\_consenting - boolean value to determine the result of all [user consent](https://www.w3.org/TR/webauthn-2/#user-consent) [authorization gestures](https://www.w3.org/TR/webauthn-2/#authorization-gesture), and by extension, any [test of user presence](https://www.w3.org/TR/webauthn-2/#test-of-user-presence) performed on the [Virtual Authenticator](https://www.w3.org/TR/webauthn-2/#virtual-authenticators). If set to true, a [user consent](https://www.w3.org/TR/webauthn-2/#user-consent) will always be granted. If set to false, it will not be granted.
- is\_user\_verified - boolean value to determine the result of [User Verification](https://www.w3.org/TR/webauthn-2/#user-verification) performed on the [Virtual Authenticator](https://www.w3.org/TR/webauthn-2/#virtual-authenticators). If set to true, [User Verification](https://www.w3.org/TR/webauthn-2/#user-verification) will always succeed. If set to false, it will fail.
- protocol - the [protocol](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#protocol) spoken by the authenticator.  This may be [CTAP1\_U2F](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#CTAP1_U2F), [CTAP2](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#CTAP2) or [CTAP2\_1](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#CTAP2_1).
- transport - the [transport](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#transport) simulated by the authenticator.  This may be [BLE](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#BLE), [HYBRID](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#HYBRID), [INTERNAL](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#INTERNAL), [NFC](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#NFC), [SMART\_CARD](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#SMART_CARD) or [USB](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#USB).

It returns the newly created [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator).

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new( webauthn => 0 );
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

## add\_webauthn\_credential

accepts a hash of the following keys;

- authenticator - contains the [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator) that the credential will be added to.  If this parameter is not supplied, the credential will be added to the default authenticator, if one exists.
- host - contains the domain that this credential is to be used for.  In the language of [WebAuthn](https://www.w3.org/TR/webauthn-2), this field is referred to as the [relying party identifier](https://www.w3.org/TR/webauthn-2/#relying-party-identifier) or [RP ID](https://www.w3.org/TR/webauthn-2/#rp-id).
- id - contains the unique id for this credential, also known as the [Credential ID](https://www.w3.org/TR/webauthn-2/#credential-id).  If this is not supplied, one will be generated.
- is\_resident - contains a boolean that if set to true, a [client-side discoverable credential](https://w3c.github.io/webauthn/#client-side-discoverable-credential) is created. If set to false, a [server-side credential](https://w3c.github.io/webauthn/#server-side-credential) is created instead.
- private\_key - either a [RFC5958](https://www.rfc-editor.org/rfc/rfc5958) encoded private key encoded using [encode\_base64url](https://metacpan.org/pod/MIME::Base64::encode_base64url) or a hash containing the following keys;
    - name - contains the name of the private key algorithm, such as "RSA-PSS" (the default), "RSASSA-PKCS1-v1\_5", "ECDSA" or "ECDH".
    - size - contains the modulus length of the private key.  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1\_5" private keys.
    - hash - contains the name of the hash algorithm, such as "SHA-512" (the default).  This is only valid for "RSA-PSS" or "RSASSA-PKCS1-v1\_5" private keys.
    - curve - contains the name of the curve for the private key, such as "P-384" (the default).  This is only valid for "ECDSA" or "ECDH" private keys.
- sign\_count - contains the initial value for a [signature counter](https://w3c.github.io/webauthn/#signature-counter) associated to the [public key credential source](https://w3c.github.io/webauthn/#public-key-credential-source).  It will default to 0 (zero).
- user - contains the [userHandle](https://w3c.github.io/webauthn/#public-key-credential-source-userhandle) associated to the credential encoded using [encode\_base64url](https://metacpan.org/pod/MIME::Base64::encode_base64url).  This property is optional.

It returns the newly created [credential](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential).  If of course, the credential is just created, it probably won't be much good by itself.  However, you can use it to recreate a credential, so long as you know all the parameters.

    use Firefox::Marionette();
    use Crypt::URandom();

    my $user_name = MIME::Base64::encode_base64( Crypt::URandom::urandom( 10 ), q[] ) . q[@example.com];
    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('register-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('alert-success'); });
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });
    foreach my $credential ($firefox->webauthn_credentials()) {
        $firefox->delete_webauthn_credential($credential);

\# ... time passes ...

        $firefox->add_webauthn_credential(
                  id            => $credential->id(),
                  host          => $credential->host(),
                  user          => $credential->user(),
                  private_key   => $credential->private_key(),
                  is_resident   => $credential->is_resident(),
                  sign_count    => $credential->sign_count(),
                              );
    }
    $firefox->go('about:blank');
    $firefox->clear_cache(Firefox::Marionette::Cache::CLEAR_COOKIES());
    $firefox->go('https://webauthn.io');
    $firefox->find_id('input-email')->type($user_name);
    $firefox->find_id('login-button')->click();
    $firefox->await(sub { sleep 1; $firefox->find_class('hero confetti'); });

## addons

returns if pre-existing addons (extensions/themes) are allowed to run.  This will be true for Firefox versions less than 55, as [-safe-mode](http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29) cannot be automated.

## agent

accepts an optional value for the [User-Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent) header and sets this using the profile preferences and inserting [javascript](#script) into the current page. It returns the current value, such as 'Mozilla/5.0 (&lt;system-information>) &lt;platform> (&lt;platform-details>) &lt;extensions>'.  This value is retrieved with [navigator.userAgent](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/userAgent).

This method can be used to set a user agent string like so;

    use Firefox::Marionette();
    use strict;

    # useragents.me should only be queried once a month or less.
    # these UA strings should be cached locally.

    my %user_agent_strings = map { $_->{ua} => $_->{pct} } @{$firefox->json("https://www.useragents.me/api")->{data}};
    my ($user_agent) = reverse sort { $user_agent_strings{$a} <=> $user_agent_strings{$b} } keys %user_agent_strings;

    my $firefox = Firefox::Marionette->new();
    $firefox->agent($user_agent); # agent is now the most popular agent from useragents.me

If the user agent string that is passed as a parameter looks like a [Chrome](https://www.google.com/chrome/), [Edge](https://microsoft.com/edge) or [Safari](https://www.apple.com/safari/) user agent string, then this method will also try and change other profile preferences to match the new agent string.  These parameters are;

- general.appversion.override
- general.oscpu.override
- general.platform.override
- network.http.accept
- network.http.accept-encoding
- network.http.accept-encoding.secure
- privacy.donottrackheader.enabled

In addition, this method will accept a hash of values as parameters as well.  When a hash is provided, this method will alter specific parts of the normal Firefox User Agent.  These hash parameters are;

- os - The desired operating system, known values are "linux", "win32", "darwin", "freebsd", "netbsd", "openbsd" and "dragonfly"
- version - A specific version of firefox, such as 120.
- arch - A specific version of the architecture, such as "x86\_64" or "aarch64" or "s390x".
- increment - A specific offset from the actual version of firefox, such as -5

These parameters can be used to set a user agent string like so;

    use Firefox::Marionette();
    use strict;

    my $firefox = Firefox::Marionette->new();
    $firefox->agent(os => 'freebsd', version => 118);

    # user agent is now equal to
    # Mozilla/5.0 (X11; FreeBSD amd64; rv:109.0) Gecko/20100101 Firefox/118.0

    $firefox->agent(os => 'linux', arch => 's390x', version => 115);
    # user agent is now equal to
    # Mozilla/5.0 (X11; Linux s390x; rv:109.0) Gecko/20100101 Firefox/115.0

If the `stealth` parameter has supplied to the [new](#new) method, it will also attempt to create known specific javascript functions to imitate the required browser.  If the database built by [build-bcd-for-firefox](https://metacpan.org/pod/build-bcd-for-firefox) is accessible, then it will also attempt to delete/provide dummy implementations for the corresponding [javascript attributes](https://github.com/mdn/browser-compat-data) for the desired browser.  The following websites have been very useful in testing these ideas;

- [https://browserleaks.com/javascript](https://browserleaks.com/javascript)
- [https://www.amiunique.org/fingerprint](https://www.amiunique.org/fingerprint)
- [https://bot.sannysoft.com/](https://bot.sannysoft.com/)
- [https://lraj22.github.io/browserfeatcl/](https://lraj22.github.io/browserfeatcl/)

Importantly, this will break [feature detection](https://developer.mozilla.org/en-US/docs/Learn/Tools_and_testing/Cross_browser_testing/Feature_detection) for any website that relies on it.

See [IMITATING OTHER BROWSERS](#imitating-other-browsers) a discussion of these types of techniques.  These changes are not foolproof, but it is interesting to see what can be done with modern browsers.  All this behaviour should be regarded as extremely experimental and subject to change.  Feedback welcome.

## alert\_text

Returns the message shown in a currently displayed modal message box

## alive

This method returns true or false depending on if the Firefox process is still running.

## application\_type

returns the application type for the Marionette protocol.  Should be 'gecko'.

## arch

returns the architecture of the machine running firefox.  Should be something like 'x86\_64' or 'arm'.  This is only intended for test suite support.

## aria\_label

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the parameter.  It returns the [ARIA label](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-label) for the [element](https://metacpan.org/pod/Firefox::Marionette::Element).

## aria\_role

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the parameter.  It returns the [ARIA role](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles) for the [element](https://metacpan.org/pod/Firefox::Marionette::Element).

## async\_script 

accepts a scalar containing a javascript function that is executed in the browser.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

The executing javascript is subject to the [script](https://metacpan.org/pod/Firefox::Marionette::Timeouts#script) timeout, which, by default is 30 seconds.

## attribute 

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and a scalar attribute name as the second parameter.  It returns the initial value of the attribute with the supplied name.  This method will return the initial content from the HTML source code, the [property](#property) method will return the current content.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('metacpan_search-input');
    !defined $element->attribute('value') or die "attribute is defined but did not exist in the html source!";
    $element->type('Test::More');
    !defined $element->attribute('value') or die "attribute has changed but only the property should have changed!";

## await

accepts a subroutine reference as a parameter and then executes the subroutine.  If a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception is thrown, this method will sleep for [sleep\_time\_in\_ms](#sleep_time_in_ms) milliseconds and then execute the subroutine again.  When the subroutine executes successfully, it will return what the subroutine returns.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5)->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

## back

causes the browser to traverse one step backward in the joint history of the current browsing context.  The browser will wait for the one step backward to complete or the session's [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) duration to elapse before returning, which, by default is 5 minutes.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## debug

accept a boolean and return the current value of the debug setting.  This allows the dynamic setting of debug.

## default\_binary\_name

just returns the string 'firefox'.  Only of interest when sub-classing.

## download

accepts a [URI](https://metacpan.org/pod/URI) and an optional timeout in seconds (the default is 5 minutes) as parameters and downloads the [URI](https://metacpan.org/pod/URI) in the background and returns a handle to the downloaded file.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    my $handle = $firefox->download('https://raw.githubusercontent.com/david-dick/firefox-marionette/master/t/data/keepassxs.csv');

    foreach my $line (<$handle>) {
      print $line;
    }

## bookmarks

accepts either a scalar or a hash as a parameter.  The scalar may by the title of a bookmark or the [URL](https://metacpan.org/pod/URI::URL) of the bookmark.  The hash may have the following keys;

- title - The title of the bookmark.
- url - The url of the bookmark.

returns a list of all [Firefox::Marionette::Bookmark](https://metacpan.org/pod/Firefox::Marionette::Bookmark) objects that match the supplied parameters (if any).

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    foreach my $bookmark ($firefox->bookmarks(title => 'This is MetaCPAN!')) {
      say "Bookmark found";
    }

    # OR

    foreach my $bookmark ($firefox->bookmarks()) {
      say "Bookmark found with URL " . $bookmark->url();
    }

    # OR

    foreach my $bookmark ($firefox->bookmarks('https://metacpan.org')) {
      say "Bookmark found";
    }

## browser\_version

This method returns the current version of firefox.

## bye

accepts a subroutine reference as a parameter and then executes the subroutine.  If the subroutine executes successfully, this method will sleep for [sleep\_time\_in\_ms](#sleep_time_in_ms) milliseconds and then execute the subroutine again.  When a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception is thrown, this method will return [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->bye(sub { $firefox->find_name('metacpan_search-input') })->await(sub { $firefox->interactive() && $firefox->find_partial('Download') })->click();

## cache\_keys

returns the set of all cache keys from [Firefox::Marionette::Cache](https://metacpan.org/pod/Firefox::Marionette::Cache).

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $key_name ($firefox->cache_keys()) {
      my $key_value = $firefox->check_cache_key($key_name);
      if (Firefox::Marionette::Cache->$key_name() != $key_value) {
        warn "This module this the value of $key_name is " . Firefox::Marionette::Cache->$key_name();
        warn "Firefox thinks the value of   $key_name is $key_value";
      }
    }

## capabilities

returns the [capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities) of the current firefox binary.  You can retrieve [timeouts](https://metacpan.org/pod/Firefox::Marionette::Timeouts) or a [proxy](https://metacpan.org/pod/Firefox::Marionette::Proxy) with this method.

## certificate\_as\_pem

accepts a [certificate stored in the Firefox database](https://metacpan.org/pod/Firefox::Marionette::Certificate) as a parameter and returns a [PEM encoded X.509 certificate](https://datatracker.ietf.org/doc/html/rfc7468#section-5) as a string.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    # Generating a ca-bundle.crt to STDOUT from the current firefox instance

    foreach my $certificate (sort { $a->display_name() cmp $b->display_name } $firefox->certificates()) {
        if ($certificate->is_ca_cert()) {
            print '# ' . $certificate->display_name() . "\n" . $firefox->certificate_as_pem($certificate) . "\n";
        }
    }

The [ca-bundle-for-firefox](https://metacpan.org/pod/ca-bundle-for-firefox) command that is provided as part of this distribution does this.

## certificates

returns a list of all known [certificates in the Firefox database](https://metacpan.org/pod/Firefox::Marionette::Certificate).

    use Firefox::Marionette();
    use v5.10;

    # Sometimes firefox can neglect old certificates.  See https://bugzilla.mozilla.org/show_bug.cgi?id=1710716

    my $firefox = Firefox::Marionette->new();
    foreach my $certificate (grep { $_->is_ca_cert() && $_->not_valid_after() < time } $firefox->certificates()) {
        say "The " . $certificate->display_name() " . certificate has expired and should be removed";
        print 'PEM Encoded Certificate ' . "\n" . $firefox->certificate_as_pem($certificate) . "\n";
    }

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## check\_cache\_key

accepts a [cache\_key](https://metacpan.org/pod/Firefox::Marionette::Cache) as a parameter.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $key_name ($firefox->cache_keys()) {
      my $key_value = $firefox->check_cache_key($key_name);
      if (Firefox::Marionette::Cache->$key_name() != $key_value) {
        warn "This module this the value of $key_name is " . Firefox::Marionette::Cache->$key_name();
        warn "Firefox thinks the value of   $key_name is $key_value";
      }
    }

This method returns the [cache\_key](https://metacpan.org/pod/Firefox::Marionette::Cache)'s actual value from firefox as a number.  This may differ from the current value of the key from [Firefox::Marionette::Cache](https://metacpan.org/pod/Firefox::Marionette::Cache) as these values have changed as firefox has evolved.

## child\_error

This method returns the $? (CHILD\_ERROR) for the Firefox process, or undefined if the process has not yet exited.

## chrome

changes the scope of subsequent commands to chrome context.  This allows things like interacting with firefox menu's and buttons outside of the browser window.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->chrome();
    $firefox->script(...); # running script in chrome context
    $firefox->content();

See the [context](#context) method for an alternative methods for changing the context.

## chrome\_window\_handle

returns a [server-assigned identifier for the current chrome window that uniquely identifies it](https://metacpan.org/pod/Firefox::Marionette::WebWindow) within this Marionette instance.  This can be used to switch to this window at a later point. This corresponds to a window that may itself contain tabs.  This method is replaced by [window\_handle](#window_handle) and appropriate [context](#context) calls for [Firefox 94 and after](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/94#webdriver_conformance_marionette).

## chrome\_window\_handles

returns [identifiers](https://metacpan.org/pod/Firefox::Marionette::WebWindow) for each open chrome window for tests interested in managing a set of chrome windows and tabs separately.  This method is replaced by [window\_handles](#window_handles) and appropriate [context](#context) calls for [Firefox 94 and after](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/94#webdriver_conformance_marionette).

## clear

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and clears any user supplied input

## clear\_cache

accepts a single flag parameter, which can be an ORed set of keys from [Firefox::Marionette::Cache](https://metacpan.org/pod/Firefox::Marionette::Cache) and clears the appropriate sections of the cache.  If no flags parameter is supplied, the default is [CLEAR\_ALL](https://metacpan.org/pod/Firefox::Marionette::Cache#CLEAR_ALL).  Note that this method, unlike [delete\_cookies](#delete_cookies) will actually delete all cookies for all hosts, not just the current webpage.

    use Firefox::Marionette();
    use Firefox::Marionette::Cache qw(:all);

    my $firefox = Firefox::Marionette->new()->go('https://do.lots.of.evil/')->clear_cache(); # default clear all

    $firefox->go('https://cookies.r.us')->clear_cache(CLEAR_COOKIES());

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## clear\_pref

accepts a [preference](http://kb.mozillazine.org/About:config) name and restores it to the original value.  See the [get\_pref](#get_pref) and [set\_pref](#set_pref) methods to get a preference value and to set to it to a particular value.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();

    $firefox->clear_pref('browser.search.defaultenginename');

## click

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and sends a 'click' to it.  The browser will wait for any page load to complete or the session's [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) duration to elapse before returning, which, by default is 5 minutes.  The [click](#click) method is also used to choose an option in a select dropdown.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(visible => 1)->go('https://ebay.com');
    my $select = $firefox->find_tag('select');
    foreach my $option ($select->find_tag('option')) {
        if ($option->property('value') == 58058) { # Computers/Tablets & Networking
            $option->click();
        }
    }

## close\_current\_chrome\_window\_handle

closes the current chrome window (that is the entire window, not just the tabs).  It returns a list of still available [chrome window handles](https://metacpan.org/pod/Firefox::Marionette::WebWindow). You will need to [switch\_to\_window](#switch_to_window) to use another window.

## close\_current\_window\_handle

closes the current window/tab.  It returns a list of still available [window/tab handles](https://metacpan.org/pod/Firefox::Marionette::WebWindow).

## content

changes the scope of subsequent commands to browsing context.  This is the default for when firefox starts and restricts commands to operating in the browser window only.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->chrome();
    $firefox->script(...); # running script in chrome context
    $firefox->content();

See the [context](#context) method for an alternative methods for changing the context.

## context

accepts a string as the first parameter, which may be either 'content' or 'chrome'.  It returns the context type that is Marionette's current target for browsing context scoped commands.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    if ($firefox->context() eq 'content') {
       say "I knew that was going to happen";
    }
    my $old_context = $firefox->context('chrome');
    $firefox->script(...); # running script in chrome context
    $firefox->context($old_context);

See the [content](#content) and [chrome](#chrome) methods for alternative methods for changing the context.

## cookies

returns the [contents](https://metacpan.org/pod/Firefox::Marionette::Cookie) of the cookie jar in scalar or list context.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://github.com');
    foreach my $cookie ($firefox->cookies()) {
        if (defined $cookie->same_site()) {
            say "Cookie " . $cookie->name() . " has a SameSite of " . $cookie->same_site();
        } else {
            warn "Cookie " . $cookie->name() . " does not have the SameSite attribute defined";
        }
    }

## css

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and a scalar CSS property name as the second parameter.  It returns the value of the computed style for that property.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    say $firefox->find_id('metacpan_search-input')->css('height');

## current\_chrome\_window\_handle 

see [chrome\_window\_handle](#chrome_window_handle).

## delete\_bookmark

accepts a [bookmark](https://metacpan.org/pod/Firefox::Marionette::Bookmark) as a parameter and deletes the bookmark from the Firefox database.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $bookmark (reverse $firefox->bookmarks()) {
      if ($bookmark->parent_guid() ne Firefox::Marionette::Bookmark::ROOT()) {
        $firefox->delete_bookmark($bookmark);
      }
    }
    say "Bookmarks? We don't need no stinking bookmarks!";

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_certificate

accepts a [certificate stored in the Firefox database](https://metacpan.org/pod/Firefox::Marionette::Certificate) as a parameter and deletes/distrusts the certificate from the Firefox database.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $certificate ($firefox->certificates()) {
        if ($certificate->is_ca_cert()) {
            $firefox->delete_certificate($certificate);
        } else {
            say "This " . $certificate->display_name() " certificate is NOT a certificate authority, therefore it is not being deleted";
        }
    }
    say "Good luck visiting a HTTPS website!";

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_cookie

deletes a single cookie by name.  Accepts a scalar containing the cookie name as a parameter.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://github.com');
    foreach my $cookie ($firefox->cookies()) {
        warn "Cookie " . $cookie->name() . " is being deleted";
        $firefox->delete_cookie($cookie->name());
    }
    foreach my $cookie ($firefox->cookies()) {
        die "Should be no cookies here now";
    }

## delete\_cookies

Here be cookie monsters! Note that this method will only delete cookies for the current site.  See [clear\_cache](#clear_cache) for an alternative.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods. 

## delete\_header

accepts a list of HTTP header names to delete from future HTTP Requests.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_header( 'User-Agent', 'Accept', 'Accept-Encoding' );

will remove the [User-Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent), [Accept](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept) and [Accept-Encoding](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding) headers from all future requests

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_login

accepts a [login](https://metacpan.org/pod/Firefox::Marionette::Login) as a parameter.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    foreach my $login ($firefox->logins()) {
        if ($login->user() eq 'me@example.org') {
            $firefox->delete_login($login);
        }
    }

will remove the logins with the username matching 'me@example.org'.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_logins

This method empties the password database.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_logins();

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_session

deletes the current WebDriver session.

## delete\_site\_header

accepts a host name and a list of HTTP headers names to delete from future HTTP Requests.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->delete_header( 'metacpan.org', 'User-Agent', 'Accept', 'Accept-Encoding' );

will remove the [User-Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent), [Accept](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept) and [Accept-Encoding](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding) headers from all future requests to metacpan.org.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## delete\_webauthn\_all\_credentials

This method accepts an optional [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator), in which case it will delete all [credentials](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential) from this authenticator.  If no parameter is supplied, the default authenticator will have all credentials deleted.

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->delete_webauthn_all_credentials($authenticator);
    $firefox->delete_webauthn_all_credentials();

## delete\_webauthn\_authenticator

This method accepts an optional [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator), in which case it will delete this authenticator from the current Firefox instance.  If no parameter is supplied, the default authenticator will be deleted.

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    $firefox->delete_webauthn_authenticator($authenticator);
    $firefox->delete_webauthn_authenticator();

## delete\_webauthn\_credential

This method accepts either a [credential](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential) and an [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator), in which case it will remove the credential from the supplied authenticator or

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
        $firefox->delete_webauthn_credential($credential, $authenticator);
    }

just a [credential](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential), in which case it will remove the credential from the default authenticator.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    ...
    foreach my $credential ($firefox->webauthn_credentials()) {
        $firefox->delete_webauthn_credential($credential);
    }

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## developer

returns true if the [current version](#browser_version) of firefox is a [developer edition](https://www.mozilla.org/en-US/firefox/developer/) (does the minor version number end with an 'b\\d+'?) version.

## dismiss\_alert

dismisses a currently displayed modal message box

## displays

accepts an optional regex to filter against the [usage for the display](https://metacpan.org/pod/Firefox::Marionette::Display#usage) and returns a list of all the [known displays](https://en.wikipedia.org/wiki/List_of_common_resolutions) as a [Firefox::Marionette::Display](https://metacpan.org/pod/Firefox::Marionette::Display).

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    my $element = $firefox->find_id('metacpan_search-input');
    foreach my $display ($firefox->displays(qr/iphone/smxi)) {
        say 'Can Firefox resize for "' . Encode::encode('UTF-8', $display->usage(), 1) . '"?';
        if ($firefox->resize($display->width(), $display->height())) {
            say 'Now displaying with a Pixel aspect ratio of ' . $display->par();
            say 'Now displaying with a Storage aspect ratio of ' . $display->sar();
            say 'Now displaying with a Display aspect ratio of ' . $display->dar();
        } else {
            say 'Apparently NOT!';
        }
    }

## downloaded

accepts a filesystem path and returns a matching filehandle.  This is trivial for locally running firefox, but sufficiently complex to justify the method for a remote firefox running over ssh.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new( host => '10.1.2.3' )->go('https://metacpan.org/');

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {

        my $handle = $firefox->downloaded($path);

        # do something with downloaded file handle

    }

## downloading

returns true if any files in [downloads](#downloads) end in `.part`

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

    while(!$firefox->downloads()) { sleep 1 }

    while($firefox->downloading()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {
        say $path;
    }

## downloads

returns a list of file paths (including partial downloads) of downloads during this Firefox session.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_class('page-content')->find_id('metacpan_search-input')->type('Test::More');

    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    $firefox->find_partial('Download')->click();

    while(!$firefox->downloads()) { sleep 1 }

    foreach my $path ($firefox->downloads()) {
        say $path;
    }

## error\_message

This method returns a human readable error message describing how the Firefox process exited (assuming it started okay).  On Win32 platforms this information is restricted to exit code.

## execute

This utility method executes a command with arguments and returns STDOUT as a chomped string.  It is a simple method only intended for the Firefox::Marionette::\* modules.

## fill\_login

This method searches the [Password Manager](https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins) for an appropriate login for any form on the current page.  The form must match the host, the action attribute and the user and password field names.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new();

    my $firefox = Firefox::Marionette->new();

    my $url = 'https://github.com';

    my $user = 'me@example.org';

    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the $user account when logging into $url:");

    $firefox->add_login(host => $url, user => $user, password => 'qwerty', user_field => 'login', password_field => 'password');

    $firefox->go("$url/login");

    $firefox->fill_login();

## find

accepts an [xpath expression](https://en.wikipedia.org/wiki/XPath) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) that matches this expression.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find('//input[@id="metacpan_search-input"]')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find('//input[@id="metacpan_search-input"]')) {
        $element->type('Test::More');
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has](#has) method.

## find\_id

accepts an [id](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/id) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'id' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    $firefox->find_id('metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_id('metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_id](#has_id) method.

## find\_name

This method returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'name' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_name('q')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_name('q')) {
        $element->type('Test::More');
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_name](#has_name) method.

## find\_class

accepts a [class name](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'class' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_class('form-control home-metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_class('form-control home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_class](#has_class) method.

## find\_selector

accepts a [CSS Selector](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) that matches that selector.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_selector('input.home-metacpan_search-input')->type('Test::More');

    # OR in list context 

    foreach my $element ($firefox->find_selector('input.home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_selector](#has_selector) method.

## find\_tag

accepts a [tag name](https://developer.mozilla.org/en-US/docs/Web/API/Element/tagName) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with this tag name.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_tag('input');

    # OR in list context 

    foreach my $element ($firefox->find_tag('input')) {
        # do something
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown. For the same functionality that returns undef if no elements are found, see the [has\_tag](#has_tag) method.

## find\_link

accepts a text string as the first parameter and returns the first link [element](https://metacpan.org/pod/Firefox::Marionette::Element) that has a matching link text.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_link('API')->click();

    # OR in list context 

    foreach my $element ($firefox->find_link('API')) {
        $element->click();
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_link](#has_link) method.

## find\_partial

accepts a text string as the first parameter and returns the first link [element](https://metacpan.org/pod/Firefox::Marionette::Element) that has a partially matching link text.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_partial('AP')->click();

    # OR in list context 

    foreach my $element ($firefox->find_partial('AP')) {
        $element->click();
    }

If no elements are found, a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception will be thrown.  For the same functionality that returns undef if no elements are found, see the [has\_partial](#has_partial) method.

## forward

causes the browser to traverse one step forward in the joint history of the current browsing context. The browser will wait for the one step forward to complete or the session's [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) duration to elapse before returning, which, by default is 5 minutes.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## full\_screen

full screens the firefox window. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## geo

accepts an optional [geo location](https://metacpan.org/pod/Firefox::Marionette::GeoLocation) object or the parameters for a [geo location](https://metacpan.org/pod/Firefox::Marionette::GeoLocation) object, turns on the [Geolocation API](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API) and returns the current [value](https://metacpan.org/pod/Firefox::Marionette::GeoLocation) returned by calling the javascript [getCurrentPosition](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/getCurrentPosition) method.  This method is further discussed in the [GEO LOCATION](#geo-location) section.  If the current location cannot be determined, this method will return undef.

NOTE: firefox will only allow [Geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation) calls to be made from [secure contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts) and bizarrely, this does not include about:blank or similar.  Therefore, you will need to load a page before calling the [geo](#geo) method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( proxy => 'https://this.is.another.location:3128', geo => 1 );

    # Get geolocation for this.is.another.location (via proxy)

    $firefox->geo($firefox->json('https://freeipapi.com/api/json/'));

    # now google maps will show us in this.is.another.location

    $firefox->go('https://maps.google.com/');

    if (my $geo = $firefox->geo()) {
        warn "Apparently, we're now at " . join q[, ], $geo->latitude(), $geo->longitude();
    } else {
        warn "This computer is not allowing geolocation";
    }

    # OR the quicker setup (run this with perl -C)

    warn "Apparently, we're now at " . Firefox::Marionette->new( proxy => 'https://this.is.another.location:3128', geo => 'https://freeipapi.com/api/json/' )->go('https://maps.google.com/')->geo();

NOTE: currently this call sets the location to be exactly what is specified.  It will also attempt to modify the current timezone (if available in the [geo location](https://metacpan.org/pod/Firefox::Marionette::GeoLocation) parameter) to match the specified [timezone](https://metacpan.org/pod/Firefox::Marionette::GeoLocation#tz).  This function should be considered experimental.  Feedback welcome.

If particular, the [ipgeolocation API](https://ipgeolocation.io/documentation/ip-geolocation-api.html) is the only API that currently providing geolocation data and matching timezone data in one API call.  If anyone finds/develops another similar API, I would be delighted to include support for it in this module.

## go

Navigates the current browsing context to the given [URI](https://metacpan.org/pod/URI) and waits for the document to load or the session's [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) duration to elapse before returning, which, by default is 5 minutes.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->go('https://metacpan.org/'); # will only return when metacpan.org is FULLY loaded (including all images / js / css)

To make the [go](#go) method return quicker, you need to set the [page load strategy](https://metacpan.org/pod/Firefox::Marionette::Capabilities#page_load_strategy) [capability](https://metacpan.org/pod/Firefox::Marionette::Capabilities) to an appropriate value, such as below;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( page_load_strategy => 'eager' ));
    $firefox->go('https://metacpan.org/'); # will return once the main document has been loaded and parsed, but BEFORE sub-resources (images/stylesheets/frames) have been loaded.

When going directly to a URL that needs to be downloaded, please see [BUGS AND LIMITATIONS](#downloading-using-go-method) for a necessary workaround and the [download](#download) method for an alternative.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## get\_pref

accepts a [preference](http://kb.mozillazine.org/About:config) name.  See the [set\_pref](#set_pref) and [clear\_pref](#clear_pref) methods to set a preference value and to restore it to it's original value.  This method returns the current value of the preference.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();

    warn "Your browser's default search engine is set to " . $firefox->get_pref('browser.search.defaultenginename');

## har

returns a hashref representing the [http archive](https://en.wikipedia.org/wiki/HAR_\(file_format\)) of the session.  This function is subject to the [script](https://metacpan.org/pod/Firefox::Marionette::Timeouts#script) timeout, which, by default is 30 seconds.  It is also possible for the function to hang (until the [script](https://metacpan.org/pod/Firefox::Marionette::Timeouts#script) timeout) if the original [devtools](https://developer.mozilla.org/en-US/docs/Tools) window is closed.  The hashref has been designed to be accepted by the [Archive::Har](https://metacpan.org/pod/Archive::Har) module.

    use Firefox::Marionette();
    use Archive::Har();
    use v5.10;

    my $firefox = Firefox::Marionette->new(visible => 1, debug => 1, har => 1);

    $firefox->go("http://metacpan.org/");

    $firefox->find('//input[@id="metacpan_search-input"]')->type('Test::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();

    my $har = Archive::Har->new();
    $har->hashref($firefox->har());

    foreach my $entry ($har->entries()) {
        say $entry->request()->url() . " spent " . $entry->timings()->connect() . " ms establishing a TCP connection";
    }

## has

accepts an [xpath expression](https://en.wikipedia.org/wiki/XPath) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) that matches this expression.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->has('//input[@id="metacpan_search-input"]')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find](#find) method.

## has\_id

accepts an [id](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/id) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'id' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->has_id('metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_id](#find_id) method.

## has\_name

This method returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'name' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_name('q')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_name](#find_name) method.

## has\_class

accepts a [class name](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with a matching 'class' property.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_class('form-control home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_class](#find_class) method.

## has\_selector

accepts a [CSS Selector](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Selectors) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) that matches that selector.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_selector('input.home-metacpan_search-input')) {
        $element->type('Test::More');
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_selector](#find_selector) method.

## has\_tag

accepts a [tag name](https://developer.mozilla.org/en-US/docs/Web/API/Element/tagName) as the first parameter and returns the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) with this tag name.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_tag('input')) {
        # do something
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_tag](#find_tag) method.

## has\_link

accepts a text string as the first parameter and returns the first link [element](https://metacpan.org/pod/Firefox::Marionette::Element) that has a matching link text.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->has_link('API')) {
        $element->click();
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_link](#find_link) method.

## has\_partial

accepts a text string as the first parameter and returns the first link [element](https://metacpan.org/pod/Firefox::Marionette::Element) that has a partially matching link text.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $element = $firefox->find_partial('AP')) {
        $element->click();
    }

If no elements are found, this method will return undef.  For the same functionality that throws a [not found](https://metacpan.org/pod/Firefox::Marionette::Exception::NotFound) exception, see the [find\_partial](#find_partial) method.

## html

returns the page source of the content document.  This page source can be wrapped in html that firefox provides.  See the [json](#json) method for an alternative when dealing with response content types such as application/json and [strip](#strip) for an alternative when dealing with other non-html content types such as text/plain.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://metacpan.org/')->html();

## import\_bookmarks

accepts a filesystem path to a bookmarks file and imports all the [bookmarks](https://metacpan.org/pod/Firefox::Marionette::Bookmark) in that file.  It can deal with backups from [Firefox](https://support.mozilla.org/en-US/kb/export-firefox-bookmarks-to-backup-or-transfer), [Chrome](https://support.google.com/chrome/answer/96816?hl=en) or Edge.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->import_bookmarks('/path/to/bookmarks_file.html');

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## images

returns a list of all of the following elements;

- [img](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img)
- [image inputs](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/image)

as [Firefox::Marionette::Image](https://metacpan.org/pod/Firefox::Marionette::Image) objects.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $link = $firefox->images()) {
        say "Found a image with width " . $image->width() . "px and height " . $image->height() . "px from " . $image->URL();
    }

If no elements are found, this method will return undef.

## install

accepts the following as the first parameter;

- path to an [xpi file](https://developer.mozilla.org/en-US/docs/Mozilla/XPI).
- path to a directory containing [firefox extension source code](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension).  This directory will be packaged up as an unsigned xpi file.
- path to a top level file (such as [manifest.json](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Anatomy_of_a_WebExtension#manifest.json)) in a directory containing [firefox extension source code](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Your_first_WebExtension).  This directory will be packaged up as an unsigned xpi file.

and an optional true/false second parameter to indicate if the xpi file should be a [temporary extension](https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/) (just for the existence of this browser instance).  Unsigned xpi files [may only be loaded temporarily](https://wiki.mozilla.org/Add-ons/Extension_Signing) (except for [nightly firefox installations](https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly)).  It returns the GUID for the addon which may be used as a parameter to the [uninstall](#uninstall) method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $extension_id = $firefox->install('/full/path/to/gnu_terry_pratchett-0.4-an+fx.xpi');

    # OR downloading and installing source code

    system { 'git' } 'git', 'clone', 'https://github.com/kkapsner/CanvasBlocker.git';

    if ($firefox->nightly()) {

        $extension_id = $firefox->install('./CanvasBlocker'); # permanent install for unsigned packages in nightly firefox

    } else {

        $extension_id = $firefox->install('./CanvasBlocker', 1); # temp install for normal firefox

    }

## interactive

returns true if `document.readyState === "interactive"` or if [loaded](#loaded) is true

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('metacpan_search-input')->type('Type::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();
    while(!$firefox->interactive()) {
        # redirecting to Test::More page
    }

## is\_displayed

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter.  This method returns true or false depending on if the element [is displayed](https://firefox-source-docs.mozilla.org/testing/marionette/internals/interaction.html#interaction.isElementDisplayed).

## is\_enabled

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter.  This method returns true or false depending on if the element [is enabled](https://w3c.github.io/webdriver/#is-element-enabled).

## is\_selected

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter.  This method returns true or false depending on if the element [is selected](https://w3c.github.io/webdriver/#dfn-is-element-selected).  Note that this method only makes sense for [checkbox](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/checkbox) or [radio](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/radio) inputs or [option](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/option) elements in a [select](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/select) dropdown.

## is\_trusted

accepts an [certificate](https://metacpan.org/pod/Firefox::Marionette::Certificate) as the first parameter.  This method returns true or false depending on if the certificate is a trusted CA certificate in the current profile.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    foreach my $certificate ($firefox->certificates()) {
        if (($certificate->is_ca_cert()) && ($firefox->is_trusted($certificate))) {
            say $certificate->display_name() . " is a trusted CA cert in the current profile";
        } 
    } 

## json

returns a [JSON](https://metacpan.org/pod/JSON) object that has been parsed from the page source of the content document.  This is a convenience method that wraps the [strip](#strip) method.

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->go('https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->json()->{version};

In addition, this method can accept a [URI](https://metacpan.org/pod/URI) as a parameter and retrieve that URI via the firefox [fetch call](https://developer.mozilla.org/en-US/docs/Web/API/fetch) and transforming the body to [JSON via firefox](https://developer.mozilla.org/en-US/docs/Web/API/Response/json_static)

    use Firefox::Marionette();
    use v5.10;

    say Firefox::Marionette->new()->json('https://freeipapi.com/api/json/')->{ipAddress};

## key\_down

accepts a parameter describing a key and returns an action for use in the [perform](#perform) method that corresponding with that key being depressed.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                               )->release()->content();

## key\_up

accepts a parameter describing a key and returns an action for use in the [perform](#perform) method that corresponding with that key being released.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                                 $firefox->pause(20),
                                 $firefox->key_up('l'),
                                 $firefox->key_up(CONTROL())
                               )->content();

## languages

accepts an optional list of values for the [Accept-Language](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language) header and sets this using the profile preferences.  It returns the current values as a list, such as ('en-US', 'en').

## loaded

returns true if `document.readyState === "complete"`

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    $firefox->find_id('metacpan_search-input')->type('Type::More');
    $firefox->await(sub { $firefox->find_class('autocomplete-suggestion'); })->click();
    while(!$firefox->loaded()) {
        # redirecting to Test::More page
    }

## logins

returns a list of all [Firefox::Marionette::Login](https://metacpan.org/pod/Firefox::Marionette::Login) objects available.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $login ($firefox->logins()) {
       say "Found login for " . $login->host() . " and user " . $login->user();
    }

## logins\_from\_csv

accepts a filehandle as a parameter and then reads the filehandle for exported logins as CSV.  This is known to work with the following formats;

- [Bitwarden CSV](https://bitwarden.com/help/article/condition-bitwarden-import/)
- [LastPass CSV](https://support.logmeininc.com/lastpass/help/how-do-i-nbsp-export-stored-data-from-lastpass-using-a-generic-csv-file)
- [KeePass CSV](https://keepass.info/help/base/importexport.html#csv)

returns a list of [Firefox::Marionette::Login](https://metacpan.org/pod/Firefox::Marionette::Login) objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/last_pass.csv');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
        $firefox->add_login($login);
    }

## logins\_from\_xml

accepts a filehandle as a parameter and then reads the filehandle for exported logins as XML.  This is known to work with the following formats;

- [KeePass 1.x XML](https://keepass.info/help/base/importexport.html#xml)

returns a list of [Firefox::Marionette::Login](https://metacpan.org/pod/Firefox::Marionette::Login) objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/keepass1.xml');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_csv($handle)) {
        $firefox->add_login($login);
    }

## logins\_from\_zip

accepts a filehandle as a parameter and then reads the filehandle for exported logins as a zip file.  This is known to work with the following formats;

- [1Password Unencrypted Export format](https://support.1password.com/1pux-format/)

returns a list of [Firefox::Marionette::Login](https://metacpan.org/pod/Firefox::Marionette::Login) objects.

    use Firefox::Marionette();
    use FileHandle();

    my $handle = FileHandle->new('/path/to/1Passwordv8.1pux');
    my $firefox = Firefox::Marionette->new();
    foreach my $login (Firefox::Marionette->logins_from_zip($handle)) {
        $firefox->add_login($login);
    }

## links

returns a list of all of the following elements;

- [anchor](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a)
- [area](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/area)
- [frame](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/frame)
- [iframe](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/iframe)
- [meta](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/meta)

as [Firefox::Marionette::Link](https://metacpan.org/pod/Firefox::Marionette::Link) objects.

This method is subject to the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeouts#implicit) timeout, which, by default is 0 seconds.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    if (my $link = $firefox->links()) {
        if ($link->tag() eq 'a') {
            warn "Found a hyperlink to " . $link->URL();
        }
    }

If no elements are found, this method will return undef.

## macos\_binary\_paths

returns a list of filesystem paths that this module will check for binaries that it can automate when running on [MacOS](https://en.wikipedia.org/wiki/MacOS).  Only of interest when sub-classing.

## marionette\_protocol

returns the version for the Marionette protocol.  Current most recent version is '3'.

## maximise

maximises the firefox window. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## mime\_types

returns a list of MIME types that will be downloaded by firefox and made available from the [downloads](#downloads) method

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new(mime_types => [ 'application/pkcs10' ])

    foreach my $mime_type ($firefox->mime_types()) {
        say $mime_type;
    }

## minimise

minimises the firefox window. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## mouse\_down

accepts a parameter describing which mouse button the method should apply to ([left](https://metacpan.org/pod/Firefox::Marionette::Buttons#LEFT), [middle](https://metacpan.org/pod/Firefox::Marionette::Buttons#MIDDLE) or [right](https://metacpan.org/pod/Firefox::Marionette::Buttons#RIGHT)) and returns an action for use in the [perform](#perform) method that corresponding with a mouse button being depressed.

## mouse\_move

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter, or a `( x => 0, y => 0 )` type hash manually describing exactly where to move the mouse to and returns an action for use in the [perform](#perform) method that corresponding with such a mouse movement, either to the specified co-ordinates or to the middle of the supplied [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter.  Other parameters that may be passed are listed below;

- origin - the origin of the C(&lt;x => 0, y => 0)> co-ordinates.  Should be either `viewport`, `pointer` or an [element](https://metacpan.org/pod/Firefox::Marionette::Element).
- duration - Number of milliseconds over which to distribute the move. If not defined, the duration defaults to 0.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## mouse\_up

accepts a parameter describing which mouse button the method should apply to ([left](https://metacpan.org/pod/Firefox::Marionette::Buttons#LEFT), [middle](https://metacpan.org/pod/Firefox::Marionette::Buttons#MIDDLE) or [right](https://metacpan.org/pod/Firefox::Marionette::Buttons#RIGHT)) and returns an action for use in the [perform](#perform) method that corresponding with a mouse button being released.

## new

accepts an optional hash as a parameter.  Allowed keys are below;

- addons - should any firefox extensions and themes be available in this session.  This defaults to "0".
- binary - use the specified path to the [Firefox](https://firefox.org/) binary, rather than the default path.
- capabilities - use the supplied [capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities) object, for example to set whether the browser should [accept insecure certs](https://metacpan.org/pod/Firefox::Marionette::Capabilities#accept_insecure_certs) or whether the browser should use a [proxy](https://metacpan.org/pod/Firefox::Marionette::Proxy).
- chatty - Firefox is extremely chatty on the network, including checking for the latest malware/phishing sites, updates to firefox/etc.  This option is therefore off ("0") by default, however, it can be switched on ("1") if required.  Even with chatty switched off, [connections to firefox.settings.services.mozilla.com will still be made](https://bugzilla.mozilla.org/show_bug.cgi?id=1598562#c13).  The only way to prevent this seems to be to set firefox.settings.services.mozilla.com to 127.0.0.1 via [/etc/hosts](https://en.wikipedia.org/wiki//etc/hosts).  NOTE: that this option only works when profile\_name/profile is not specified.
- console - show the [browser console](https://developer.mozilla.org/en-US/docs/Tools/Browser_Console/) when the browser is launched.  This defaults to "0" (off).  See [CONSOLE LOGGING](#console-logging) for a discussion of how to send log messages to the console.
- debug - should firefox's debug to be available via STDERR. This defaults to "0". Any ssh connections will also be printed to STDERR.  This defaults to "0" (off).  This setting may be updated by the [debug](#debug) method.  If this option is not a boolean (0|1), the value will be passed to the [MOZ\_LOG](https://firefox-source-docs.mozilla.org/networking/http/logging.html) option on the command line of the firefox binary to allow extra levels of debug.
- developer - only allow a [developer edition](https://www.mozilla.org/en-US/firefox/developer/) to be launched. This defaults to "0" (off).
- devtools - begin the session with the [devtools](https://developer.mozilla.org/en-US/docs/Tools) window opened in a separate window.
- geo - setup the browser [preferences](http://kb.mozillazine.org/About:config) to allow the [Geolocation API](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API) to work.  If the value for this key is a [URI](https://metacpan.org/pod/URI) object or a string beginning with '^(?:data|http)', this object will be retrieved using the [json](#json) method and the response will used to build a [GeoLocation](https://metacpan.org/pod/Firefox::Mozilla::GeoLocation) object, which will be sent to the [geo](#geo) method.  If the value for this key is a hash, the hash will be used to build a [GeoLocation](https://metacpan.org/pod/Firefox::Mozilla::GeoLocation) object, which will be sent to the [geo](#geo) method.
- height - set the [height](http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29) of the initial firefox window
- har - begin the session with the [devtools](https://developer.mozilla.org/en-US/docs/Tools) window opened in a separate window.  The [HAR Export Trigger](https://addons.mozilla.org/en-US/firefox/addon/har-export-trigger/) addon will be loaded into the new session automatically, which means that [-safe-mode](http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29) will not be activated for this session AND this functionality will only be available for Firefox 61+.
- host - use [ssh](https://man.openbsd.org/ssh.1) to create and automate firefox on the specified host.  See [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh) and [NETWORK ARCHITECTURE](#network-architecture).  The user will default to the current user name (see the user parameter to change this).  Authentication should be via public keys loaded into the local [ssh-agent](https://man.openbsd.org/ssh-agent).
- implicit - a shortcut to allow directly providing the [implicit](https://metacpan.org/pod/Firefox::Marionette::Timeout#implicit) timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.
- index - a parameter to allow the user to specify a specific firefox instance to survive and reconnect to.  It does not do anything else at the moment.  See the survive parameter.
- kiosk - start the browser in [kiosk](https://support.mozilla.org/en-US/kb/firefox-enterprise-kiosk-mode) mode.
- mime\_types - any MIME types that Firefox will encounter during this session.  MIME types that are not specified will result in a hung browser (the File Download popup will appear).
- nightly - only allow a [nightly release](https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly) to be launched.  This defaults to "0" (off).
- port - if the "host" parameter is also set, use [ssh](https://man.openbsd.org/ssh.1) to create and automate firefox via the specified port.  See [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh) and [NETWORK ARCHITECTURE](#network-architecture).
- page\_load - a shortcut to allow directly providing the [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.
- profile - create a new profile based on the supplied [profile](https://metacpan.org/pod/Firefox::Marionette::Profile).  NOTE: firefox ignores any changes made to the profile on the disk while it is running, instead, use the [set\_pref](#set_pref) and [clear\_pref](#clear_pref) methods to make changes while firefox is running.
- profile\_name - pick a specific existing profile to automate, rather than creating a new profile.  [Firefox](https://firefox.com) refuses to allow more than one instance of a profile to run at the same time.  Profile names can be obtained by using the [Firefox::Marionette::Profile::names()](https://metacpan.org/pod/Firefox::Marionette::Profile#names) method. The following conditions are required to use existing profiles;

    - the preference `security.webauth.webauthn_enable_softtoken` must be set to `true` in the profile OR
    - the `webauth` parameter to this method must be set to `0`

    NOTE: firefox ignores any changes made to the profile on the disk while it is running, instead, use the [set\_pref](#set_pref) and [clear\_pref](#clear_pref) methods to make changes while firefox is running.

- proxy - this is a shortcut method for setting a [proxy](https://metacpan.org/pod/Firefox::Marionette::Proxy) using the [capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities) parameter above.  It accepts a proxy URL, with the following allowable schemes, 'http' and 'https'.  It also allows a reference to a list of proxy URLs which will function as list of proxies that Firefox will try in [left to right order](https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling/Proxy_Auto-Configuration_PAC_file#description) until a working proxy is found.  See [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh), [NETWORK ARCHITECTURE](#network-architecture) and [SETTING UP SOCKS SERVERS USING SSH](https://metacpan.org/pod/Firefox::Marionette::Proxy#SETTING-UP-SOCKS-SERVERS-USING-SSH).
- reconnect - an experimental parameter to allow a reconnection to firefox that a connection has been discontinued.  See the survive parameter.
- scp - force the scp protocol when transferring files to remote hosts via ssh. See [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh) and the --scp-only option in the [ssh-auth-cmd-marionette](https://metacpan.org/pod/ssh-auth-cmd-marionette) script in this distribution.
- script - a shortcut to allow directly providing the [script](https://metacpan.org/pod/Firefox::Marionette::Timeout#script) timeout, instead of needing to use timeouts from the capabilities parameter.  Overrides all longer ways.
- seer - this option is switched off "0" by default.  When it is switched on "1", it will activate the various speculative and pre-fetch options for firefox.  NOTE: that this option only works when profile\_name/profile is not specified.
- sleep\_time\_in\_ms - the amount of time (in milliseconds) that this module should sleep when unsuccessfully calling the subroutine provided to the [await](#await) or [bye](#bye) methods.  This defaults to "1" millisecond.
- stealth - stops [navigator.webdriver](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/webdriver) from being accessible by the current web page.  This is achieved by loading an [extension](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions), which will automatically switch on the `addons` parameter for the [new](#new) method.  This is extremely experimental.  See [IMITATING OTHER BROWSERS](#imitating-other-browsers) for a discussion.
- survive - if this is set to a true value, firefox will not automatically exit when the object goes out of scope.  See the reconnect parameter for an experimental technique for reconnecting.
- system\_access - firefox [after version 138](https://bugzilla.mozilla.org/show_bug.cgi?id=1944565) allows disabling system access for javascript.  By default, this module will turn on system access.
- trust - give a path to a [root certificate](https://en.wikipedia.org/wiki/Root_certificate) encoded as a [PEM encoded X.509 certificate](https://datatracker.ietf.org/doc/html/rfc7468#section-5) that will be trusted for this session.
- timeouts - a shortcut to allow directly providing a [timeout](https://metacpan.org/pod/Firefox::Marionette::Timeout) object, instead of needing to use timeouts from the capabilities parameter.  Overrides the timeouts provided (if any) in the capabilities parameter.
- trackable - if this is set, profile preferences will be [set](#set_pref) to make it harder to be tracked by the [browsers fingerprint](https://en.wikipedia.org/wiki/Device_fingerprint#Browser_fingerprint) across browser restarts.  This is on by default, but may be switched off by setting it to 0;
- user - if the "host" parameter is also set, use [ssh](https://man.openbsd.org/ssh.1) to create and automate firefox with the specified user.  See [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh) and [NETWORK ARCHITECTURE](#network-architecture).  The user will default to the current user name.  Authentication should be via public keys loaded into the local [ssh-agent](https://man.openbsd.org/ssh-agent).
- via - specifies a [proxy jump box](https://man.openbsd.org/ssh_config#ProxyJump) to be used to connect to a remote host.  See the host parameter.
- visible - should firefox be visible on the desktop.  This defaults to "0".  When moving from a X11 platform to another X11 platform, you can set visible to 'local' to enable [X11 forwarding](https://man.openbsd.org/ssh#X).  See [X11 FORWARDING WITH FIREFOX](#x11-forwarding-with-firefox).
- waterfox - only allow a binary that looks like a [waterfox version](https://www.waterfox.net/) to be launched.
- webauthn - a boolean parameter to determine whether or not to [add a webauthn authenticator](#add_webauthn_authenticator) after the connection is established.  The default is to add a webauthn authenticator for Firefox after version 118.
- width - set the [width](http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29) of the initial firefox window

This method returns a new `Firefox::Marionette` object, connected to an instance of [firefox](https://firefox.com).  In a non MacOS/Win32/Cygwin environment, if necessary (no DISPLAY variable can be found and the visible parameter to the new method has been set to true) and possible (Xvfb can be executed successfully), this method will also automatically start an [Xvfb](https://en.wikipedia.org/wiki/Xvfb) instance.

    use Firefox::Marionette();

    my $remote_darwin_firefox = Firefox::Marionette->new(
                     debug => 'timestamp,nsHttp:1',
                     host => '10.1.2.3',
                     trust => '/path/to/root_ca.pem',
                     binary => '/Applications/Firefox.app/Contents/MacOS/firefox'
                                                        ); # start a temporary profile for a remote firefox and load a new CA into the temp profile
    ...

    foreach my $profile_name (Firefox::Marionette::Profile->names()) {
        my $firefox_with_existing_profile = Firefox::Marionette->new( profile_name => $profile_name, visible => 1 );
        ...
    }

## new\_window

accepts an optional hash as the parameter.  Allowed keys are below;

- focus - a boolean field representing if the new window be opened in the foreground (focused) or background (not focused). Defaults to false.
- private - a boolean field representing if the new window should be a private window. Defaults to false.
- type - the type of the new window. Can be one of 'tab' or 'window'. Defaults to 'tab'.

Returns the [window handle](https://metacpan.org/pod/Firefox::Marionette::WebWindow) for the new window.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $window_handle = $firefox->new_window(type => 'tab');

    $firefox->switch_to_window($window_handle);

## new\_session

creates a new WebDriver session.  It is expected that the caller performs the necessary checks on the requested capabilities to be WebDriver conforming.  The WebDriver service offered by Marionette does not match or negotiate capabilities beyond type and bounds checks.

## nightly

returns true if the [current version](#browser_version) of firefox is a [nightly release](https://www.mozilla.org/en-US/firefox/channel/desktop/#nightly) (does the minor version number end with an 'a1'?)

## paper\_sizes 

returns a list of all the recognised names for paper sizes, such as A4 or LEGAL.

## pause

accepts a parameter in milliseconds and returns a corresponding action for the [perform](#perform) method that will cause a pause in the chain of actions given to the [perform](#perform) method.

## pdf

accepts a optional hash as the first parameter with the following allowed keys;

- landscape - Paper orientation.  Boolean value.  Defaults to false
- margin - A hash describing the margins.  The hash may have the following optional keys, 'top', 'left', 'right' and 'bottom'.  All these keys are in cm and default to 1 (~0.4 inches)
- page - A hash describing the page.  The hash may have the following keys; 'height' and 'width'.  Both keys are in cm and default to US letter size.  See the 'size' key.
- page\_ranges - A list of the pages to print. Available for [Firefox 96](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/96#webdriver_conformance_marionette) and after.
- print\_background - Print background graphics.  Boolean value.  Defaults to false. 
- raw - rather than a file handle containing the PDF, the binary PDF will be returned.
- scale - Scale of the webpage rendering.  Defaults to 1.  `shrink_to_fit` should be disabled to make `scale` work.
- size - The desired size (width and height) of the pdf, specified by name.  See the page key for an alternative and the [paper\_sizes](#paper_sizes) method for a list of accepted page size names. 
- shrink\_to\_fit - Whether or not to override page size as defined by CSS.  Boolean value.  Defaults to true. 

returns a [File::Temp](https://metacpan.org/pod/File::Temp) object containing a PDF encoded version of the current page for printing.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $handle = $firefox->pdf();
    foreach my $paper_size ($firefox->paper_sizes()) {
            $handle = $firefox->pdf(size => $paper_size, landscape => 1, margin => { top => 0.5, left => 1.5 });
            ...
            print $firefox->pdf(page => { width => 21, height => 27 }, raw => 1);
            ...
    }

## percentage\_visible

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and returns the percentage of that [element](https://metacpan.org/pod/Firefox::Marionette::Element) that is currently visible in the [viewport](https://developer.mozilla.org/en-US/docs/Glossary/Viewport).  It achieves this by determining the co-ordinates of the [DOMRect](https://developer.mozilla.org/en-US/docs/Web/API/DOMRect) with a [getBoundingClientRect](https://developer.mozilla.org/en-US/docs/Web/API/Element/getBoundingClientRect) call and then using [elementsFromPoint](https://developer.mozilla.org/en-US/docs/Web/API/Document/elementsFromPoint) and [getComputedStyle](https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle) calls to determine how the percentage of the [DOMRect](https://developer.mozilla.org/en-US/docs/Web/API/DOMRect) that is visible to the user.  The [getComputedStyle](https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle) call is used to determine the state of the [visibility](https://developer.mozilla.org/en-US/docs/Web/CSS/visibility) and [display](https://developer.mozilla.org/en-US/docs/Web/CSS/display) attributes.

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    my $element = $firefox->find_id('metacpan_search-input');
    my $totally_viewable_percentage = $firefox->percentage_visible($element); # search box is slightly hidden by different effects
    foreach my $display ($firefox->displays()) {
        if ($firefox->resize($display->width(), $display->height())) {
            if ($firefox->percentage_visible($element) < $totally_viewable_percentage) {
               say 'Search box stops being fully viewable with ' . Encode::encode('UTF-8', $display->usage());
               last;
            }
        }
    }

## perform

accepts a list of actions (see [mouse\_up](#mouse_up), [mouse\_down](#mouse_down), [mouse\_move](#mouse_move), [pause](#pause), [key\_down](#key_down) and [key\_up](#key_up)) and performs these actions in sequence.  This allows fine control over interactions, including sending right clicks to the browser and sending Control, Alt and other special keys.  The [release](#release) method will complete outstanding actions (such as [mouse\_up](#mouse_up) or [key\_up](#key_up) actions).

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);
    use Firefox::Marionette::Buttons qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                                 $firefox->key_up('l'),
                                 $firefox->key_up(CONTROL())
                               )->content();

    $firefox->go('https://metacpan.org');
    my $help_button = $firefox->find_class('btn search-btn help-btn');
    $firefox->perform(
                                  $firefox->mouse_move($help_button),
                                  $firefox->mouse_down(RIGHT_BUTTON()),
                                  $firefox->pause(4),
                                  $firefox->mouse_up(RIGHT_BUTTON()),
                );

See the [release](#release) method for an alternative for manually specifying all the [mouse\_up](#mouse_up) and [key\_up](#key_up) methods

## profile\_directory

returns the profile directory used by the current instance of firefox.  This is mainly intended for debugging firefox.  Firefox is not designed to cope with these files being altered while firefox is running.

## property

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and a scalar attribute name as the second parameter.  It returns the current value of the property with the supplied name.  This method will return the current content, the [attribute](#attribute) method will return the initial content from the HTML source code.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');
    my $element = $firefox->find_id('metacpan_search-input');
    $element->property('value') eq '' or die "Initial property should be the empty string";
    $element->type('Test::More');
    $element->property('value') eq 'Test::More' or die "This property should have changed!";

    # OR getting the innerHTML property

    my $title = $firefox->find_tag('title')->property('innerHTML'); # same as $firefox->title();

## pwd\_mgr\_lock

Accepts a new [primary password](https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins) and locks the [Password Manager](https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins) with it.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new();
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_lock($password);
    $firefox->pwd_mgr_logout();
    # now no-one can access the Password Manager Database without the value in $password

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## pwd\_mgr\_login

Accepts the [primary password](https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins) and allows the user to access the [Password Manager](https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins).

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_login($password);
    ...
    # access the Password Database.
    ...
    $firefox->pwd_mgr_logout();
    ...
    # no longer able to access the Password Database.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## pwd\_mgr\_logout

Logs the user out of being able to access the [Password Manager](https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins).

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
    $firefox->pwd_mgr_login($password);
    ...
    # access the Password Database.
    ...
    $firefox->pwd_mgr_logout();
    ...
    # no longer able to access the Password Database.

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## pwd\_mgr\_needs\_login

returns true or false if the [Password Manager](https://support.mozilla.org/en-US/kb/password-manager-remember-delete-edit-logins) has been locked and needs a [primary password](https://support.mozilla.org/en-US/kb/use-primary-password-protect-stored-logins) to access it.

    use Firefox::Marionette();
    use IO::Prompt();

    my $firefox = Firefox::Marionette->new( profile_name => 'default' );
    if ($firefox->pwd_mgr_needs_login()) {
      my $password = IO::Prompt::prompt(-echo => q[*], "Please enter the password for the Firefox Password Manager:");
      $firefox->pwd_mgr_login($password);
    }

## quit

Marionette will stop accepting new connections before ending the current session, and finally attempting to quit the application.  This method returns the $? (CHILD\_ERROR) value for the Firefox process

## rect

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and returns the current [position and size](https://metacpan.org/pod/Firefox::Marionette::Element::Rect) of the [element](https://metacpan.org/pod/Firefox::Marionette::Element)

## refresh

refreshes the current page.  The browser will wait for the page to completely refresh or the session's [page\_load](https://metacpan.org/pod/Firefox::Marionette::Timeouts#page_load) duration to elapse before returning, which, by default is 5 minutes.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## release

completes any outstanding actions issued by the [perform](#perform) method.

    use Firefox::Marionette();
    use Firefox::Marionette::Keys qw(:all);
    use Firefox::Marionette::Buttons qw(:all);

    my $firefox = Firefox::Marionette->new();

    $firefox->chrome()->perform(
                                 $firefox->key_down(CONTROL()),
                                 $firefox->key_down('l'),
                               )->release()->content();

    $firefox->go('https://metacpan.org');
    my $help_button = $firefox->find_class('btn search-btn help-btn');
    $firefox->perform(
                                  $firefox->mouse_move($help_button),
                                  $firefox->mouse_down(RIGHT_BUTTON()),
                                  $firefox->pause(4),
                )->release();

## resize

accepts width and height parameters in a list and then attempts to resize the entire browser to match those parameters.  Due to the oddities of various window managers, this function needs to manually calculate what the maximum and minimum sizes of the display is.  It does this by;

- 1 performing a [maximise](https://metacpan.org/pod/Firefox::Marionette::maximise), then
- 2 caching the browser's current width and height as the maximum width and height. It
- 3 then calls [resizeTo](https://developer.mozilla.org/en-US/docs/Web/API/Window/resizeTo) to resize the window to 0,0
- 4 wait for the browser to send a [resize](https://developer.mozilla.org/en-US/docs/Web/API/Window/resize_event) event.
- 5 cache the browser's current width and height as the minimum width and height
- 6 if the requested width and height are outside of the maximum and minimum widths and heights return false
- 7 if the requested width and height matches the current width and height return [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods. Otherwise,
- 8 call [resizeTo](https://developer.mozilla.org/en-US/docs/Web/API/Window/resizeTo) for the requested width and height
- 9 wait for the [resize](https://developer.mozilla.org/en-US/docs/Web/API/Window/resize_event) event

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods if the method succeeds, otherwise it returns false.

    use Firefox::Marionette();
    use Encode();
    use v5.10;

    my $firefox = Firefox::Marionette->new( visible => 1, kiosk => 1 )->go('http://metacpan.org');;
    if ($firefox->resize(1024, 768)) {
        say 'We are showing an XGA display';
    } else {
       say 'Resize failed to work';
    }

## resolve

accepts a hostname as an argument and resolves it to a list of matching IP addresses.  It can also accept an optional hash containing additional keys, described in [Firefox::Marionette::DNS](https://metacpan.org/pod/Firefox::Marionette::DNS).

    use Firefox::Marionette();
    use v5.10;

    my $ssh_server = 'remote.example.org';
    my $firefox = Firefox::Marionette->new( host => $ssh_server );
    my $hostname = 'metacpan.org';
    foreach my $ip_address ($firefox->resolve($hostname)) {
       say "$hostname resolves to $ip_address at $ssh_server";
    }
    $firefox = Firefox::Marionette->new();
    foreach my $ip_address ($firefox->resolve($hostname, flags => Firefox::Marionette::DNS::RESOLVE_REFRESH_CACHE() | Firefox::Marionette::DNS::RESOLVE_BYPASS_CACHE(), type => Firefox::Marionette::DNS::RESOLVE_TYPE_DEFAULT())) {
       say "$hostname resolves to $ip_address;
    }

## resolve\_override

accepts a hostname and an IP address as parameters.  This method then forces the browser to override any future DNS requests for the supplied hostname.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    my $hostname = 'metacpan.org';
    my $ip_address = '127.0.0.1';
    foreach my $result ($firefox->resolve_override($hostname, $ip_address)->resolve($hostname)) {
       if ($result eq $ip_address) {
         warn "local metacpan time?";
       } else {
         die "This should not happen";
       }
    }
    $firefox->go('https://metacpan.org'); # this tries to contact a webserver on 127.0.0.1

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## restart

restarts the browser.  After the restart, [capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities) should be restored.  The same profile settings should be applied, but the current state of the browser (such as the [uri](#uri) will be reset (like after a normal browser restart).  This method is primarily intended for use by the [update](#update) method.  Not sure if this is useful by itself.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    $firefox->restart(); # but why?

This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## root\_directory

this is the root directory for the current instance of firefox.  The directory may exist on a remote server.  For debugging purposes only.

## screen\_orientation

returns the current browser orientation.  This will be one of the valid primary orientation values 'portrait-primary', 'landscape-primary', 'portrait-secondary', or 'landscape-secondary'.  This method is only currently available on Android (Fennec).

## script 

accepts a scalar containing a javascript function body that is executed in the browser, and an optional hash as a second parameter.  Allowed keys are below;

- args - The reference to a list is the arguments passed to the function body.
- filename - Filename of the client's program where this script is evaluated.
- line - Line in the client's program where this script is evaluated.
- new - Forces the script to be evaluated in a fresh sandbox.  Note that if it is undefined, the script will normally be evaluated in a fresh sandbox.
- sandbox - Name of the sandbox to evaluate the script in.  The sandbox is cached for later re-use on the same [window](https://developer.mozilla.org/en-US/docs/Web/API/Window) object if `new` is false.  If he parameter is undefined, the script is evaluated in a mutable sandbox.  If the parameter is "system", it will be evaluated in a sandbox with elevated system privileges, equivalent to chrome space.
- timeout - A timeout to override the default [script](https://metacpan.org/pod/Firefox::Marionette::Timeouts#script) timeout, which, by default is 30 seconds.

Returns the result of the javascript function.  When a parameter is an [element](https://metacpan.org/pod/Firefox::Marionette::Element) (such as being returned from a [find](#find) type operation), the [script](#script) method will automatically translate that into a javascript object.  Likewise, when the result being returned in a [script](#script) method is an [element](https://dom.spec.whatwg.org/#concept-element) it will be automatically translated into a [perl object](https://metacpan.org/pod/Firefox::Marionette::Element).

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new()->go('https://metacpan.org/');

    if (my $element = $firefox->script('return document.getElementsByName("metacpan_search-input")[0];')) {
        say "Lucky find is a " . $element->tag_name() . " element";
    }

    my $search_input = $firefox->find_id('metacpan_search-input');

    $firefox->script('arguments[0].style.backgroundColor = "red"', args => [ $search_input ]); # turn the search input box red

The executing javascript is subject to the [script](https://metacpan.org/pod/Firefox::Marionette::Timeouts#script) timeout, which, by default is 30 seconds.

## selfie

returns a [File::Temp](https://metacpan.org/pod/File::Temp) object containing a lossless PNG image screenshot.  If an [element](https://metacpan.org/pod/Firefox::Marionette::Element) is passed as a parameter, the screenshot will be restricted to the element.  

If an [element](https://metacpan.org/pod/Firefox::Marionette::Element) is not passed as a parameter and the current [context](#context) is 'chrome', a screenshot of the current viewport will be returned.

If an [element](https://metacpan.org/pod/Firefox::Marionette::Element) is not passed as a parameter and the current [context](#context) is 'content', a screenshot of the current frame will be returned.

The parameters after the [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter are taken to be a optional hash with the following allowed keys;

- hash - return a SHA256 hex encoded digest of the PNG image rather than the image itself
- full - take a screenshot of the whole document unless the first [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter has been supplied.
- raw - rather than a file handle containing the screenshot, the binary PNG image will be returned.
- scroll - scroll to the [element](https://metacpan.org/pod/Firefox::Marionette::Element) supplied
- highlights - a reference to a list containing [elements](https://metacpan.org/pod/Firefox::Marionette::Element) to draw a highlight around.  Not available in [Firefox 70](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases/70#WebDriver_conformance_Marionette) onwards.

## scroll

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and [scrolls](https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView) to it.  The optional second parameter is the same as for the [scrollInfoView](https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView) method.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(visible => 1)->go('https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView');
    my $link = $firefox->find_id('content')->find_link('Examples');
    $firefox->scroll($link);
    $firefox->scroll($link, 1);
    $firefox->scroll($link, { behavior => 'smooth', block => 'center' });
    $firefox->scroll($link, { block => 'end', inline => 'nearest' });

## send\_alert\_text

sends keys to the input field of a currently displayed modal message box

## set\_javascript

accepts a parameter for the the profile preference value of [javascript.enabled](https://support.mozilla.org/en-US/kb/javascript-settings-for-interactive-web-pages#w_for-advanced-users).  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## set\_pref

accepts a [preference](http://kb.mozillazine.org/About:config) name and the new value to set it to.  See the [get\_pref](#get_pref) and [clear\_pref](#clear_pref) methods to get a preference value and to restore it to it's original value.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();
    my $firefox = Firefox::Marionette->new();
    ...
    $firefox->set_pref('browser.search.defaultenginename', 'DuckDuckGo');

## shadow\_root

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as a parameter and returns it's [ShadowRoot](https://developer.mozilla.org/en-US/docs/Web/API/ShadowRoot) as a [shadow root](https://metacpan.org/pod/Firefox::Marionette::ShadowRoot) object or throws an exception.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new()->go('file://' . Cwd::cwd() . '/t/data/elements.html');

    $firefox->find_class('add')->click();
    my $custom_square = $firefox->find_tag('custom-square');
    my $shadow_root = $firefox->shadow_root($custom_square);

    foreach my $element (@{$firefox->script('return arguments[0].children', args => [ $shadow_root ])}) {
        warn $element->tag_name();
    }

See the [FINDING ELEMENTS IN A SHADOW DOM](#finding-elements-in-a-shadow-dom) section for how to delve into a [shadow DOM](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM).

## shadowy

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as a parameter and returns true if the element has a [ShadowRoot](https://developer.mozilla.org/en-US/docs/Web/API/ShadowRoot) or false otherwise.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new()->go('file://' . Cwd::cwd() . '/t/data/elements.html');
    $firefox->find_class('add')->click();
    my $custom_square = $firefox->find_tag('custom-square');
    if ($firefox->shadowy($custom_square)) {
        my $shadow_root = $firefox->find_tag('custom-square')->shadow_root();
        warn $firefox->script('return arguments[0].innerHTML', args => [ $shadow_root ]);
        ...
    }

This function will probably be used to see if the [shadow\_root](https://metacpan.org/pod/Firefox::Marionette::Element#shadow_root) method can be called on this element without raising an exception.

## sleep\_time\_in\_ms

accepts a new time to sleep in [await](#await) or [bye](#bye) methods and returns the previous time.  The default time is "1" millisecond.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(sleep_time_in_ms => 5); # setting default time to 5 milliseconds

    my $old_time_in_ms = $firefox->sleep_time_in_ms(8); # setting default time to 8 milliseconds, returning 5 (milliseconds)

## ssh\_local\_directory

returns the path to the local directory for the ssh connection (if any). For debugging purposes only.

## strip

returns the page source of the content document after an attempt has been made to remove typical firefox html wrappers of non html content types such as text/plain and application/json.  See the [json](#json) method for an alternative when dealing with response content types such as application/json and [html](#html) for an alternative when dealing with html content types.  This is a convenience method that wraps the [html](#html) method.

    use Firefox::Marionette();
    use JSON();
    use v5.10;

    say JSON::decode_json(Firefox::Marionette->new()->go("https://fastapi.metacpan.org/v1/download_url/Firefox::Marionette")->strip())->{version};

Note that this method will assume the bytes it receives from the [html](#html) method are UTF-8 encoded and will translate accordingly, throwing an exception in the process if the bytes are not UTF-8 encoded.

## switch\_to\_frame

accepts a [frame](https://metacpan.org/pod/Firefox::Marionette::Element) as a parameter and switches to it within the current window.

## switch\_to\_parent\_frame

set the current browsing context for future commands to the parent of the current browsing context

## switch\_to\_window

accepts a [window handle](https://metacpan.org/pod/Firefox::Marionette::WebWindow) (either the result of [window\_handles](#window_handles) or a window name as a parameter and switches focus to this window.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->version
    my $original_window = $firefox->window_handle();
    $firefox->new_window( type => 'tab' );
    $firefox->new_window( type => 'window' );
    $firefox->switch_to_window($original_window);
    $firefox->go('https://metacpan.org');

## tag\_name

accepts a [Firefox::Marionette::Element](https://metacpan.org/pod/Firefox::Marionette::Element) object as the first parameter and returns the relevant tag name.  For example '[a](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a)' or '[input](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input)'.

## text

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and returns the text that is contained by that element (if any)

## timeouts

returns the current [timeouts](https://metacpan.org/pod/Firefox::Marionette::Timeouts) for page loading, searching, and scripts.

## tz

accepts a [Olson TZ identifier](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) as the first parameter. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## title

returns the current [title](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/title) of the window.

## type

accepts an [element](https://metacpan.org/pod/Firefox::Marionette::Element) as the first parameter and a string as the second parameter.  It sends the string to the specified [element](https://metacpan.org/pod/Firefox::Marionette::Element) in the current page, such as filling out a text box. This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

## uname

returns the $^O ($OSNAME) compatible string to describe the platform where firefox is running.

## update

queries the Update Services and applies any available updates.  [Restarts](#restart) the browser if necessary to complete the update.  This function is experimental and currently has not been successfully tested on Win32 or MacOS.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();

    my $update = $firefox->update();

    while($update->successful()) {
        $update = $firefox->update();
    }

    say "Updated to " . $update->display_version() . " - Build ID " . $update->build_id();

    $firefox->quit();

returns a [status](https://metacpan.org/pod/Firefox::Marionette::UpdateStatus) object that contains useful information about any updates that occurred.

## uninstall

accepts the GUID for the addon to uninstall.  The GUID is returned when from the [install](#install) method.  This method returns [itself](https://metacpan.org/pod/Firefox::Marionette) to aid in chaining methods.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();

    my $extension_id = $firefox->install('/full/path/to/gnu_terry_pratchett-0.4-an+fx.xpi');

    # do something

    $firefox->uninstall($extension_id); # not recommended to uninstall this extension IRL.

## uri

returns the current [URI](https://metacpan.org/pod/URI) of current top level browsing context for Desktop.  It is equivalent to the javascript `document.location.href`

## webauthn\_authenticator

returns the default [WebAuthn authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator) created when the [new](#new) method was called.

## webauthn\_credentials

This method accepts an optional [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator), in which case it will return all the [credentials](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential) attached to this authenticator.  If no parameter is supplied, [credentials](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Credential) from the default authenticator will be returned.

    use Firefox::Marionette();
    use v5.10;

    my $firefox = Firefox::Marionette->new();
    foreach my $credential ($firefox->webauthn_credentials()) {
       say "Credential host is " . $credential->host();
    }

    # OR

    my $authenticator = $firefox->add_webauthn_authenticator( transport => Firefox::Marionette::WebAuthn::Authenticator::INTERNAL(), protocol => Firefox::Marionette::WebAuthn::Authenticator::CTAP2() );
    foreach my $credential ($firefox->webauthn_credentials($authenticator)) {
       say "Credential host is " . $credential->host();
    }

## webauthn\_set\_user\_verified

This method accepts a boolean for the [is\_user\_verified](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#is_user_verified) field and an optional [authenticator](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator) (the default authenticator will be used otherwise).  It sets the [is\_user\_verified](https://metacpan.org/pod/Firefox::Marionette::WebAuthn::Authenticator#is_user_verified) field to the supplied boolean value.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    $firefox->webauthn_set_user_verified(1);

## wheel

accepts a [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter, or a `( x => 0, y => 0 )` type hash manually describing exactly where to move the mouse from and returns an action for use in the [perform](#perform) method that corresponding with such a wheel action, either to the specified co-ordinates or to the middle of the supplied [element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter.  Other parameters that may be passed are listed below;

- origin - the origin of the C(&lt;x => 0, y => 0)> co-ordinates.  Should be either `viewport`, `pointer` or an [element](https://metacpan.org/pod/Firefox::Marionette::Element).
- duration - Number of milliseconds over which to distribute the move. If not defined, the duration defaults to 0.
- deltaX - the change in X co-ordinates during the wheel.  If not defined, deltaX defaults to 0.
- deltaY - the change in Y co-ordinates during the wheel.  If not defined, deltaY defaults to 0.

## win32\_organisation

accepts a parameter of a Win32 product name and returns the matching organisation.  Only of interest when sub-classing.

## win32\_product\_names

returns a hash of known Windows product names (such as 'Mozilla Firefox') with priority orders.  The lower the priority will determine the order that this module will check for the existence of this product.  Only of interest when sub-classing.

## window\_handle

returns the [current window's handle](https://metacpan.org/pod/Firefox::Marionette::WebWindow). On desktop this typically corresponds to the currently selected tab.  returns an opaque server-assigned identifier to this window that uniquely identifies it within this Marionette instance.  This can be used to switch to this window at a later point.  This is the same as the [window](https://developer.mozilla.org/en-US/docs/Web/API/Window) object in Javascript.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new();
    my $original_window = $firefox->window_handle();
    my $javascript_window = $firefox->script('return window'); # only works for Firefox 121 and later
    if ($javascript_window ne $original_window) {
        die "That was unexpected!!! What happened?";
    }

## window\_handles

returns a list of top-level [browsing contexts](https://metacpan.org/pod/Firefox::Marionette::WebWindow). On desktop this typically corresponds to the set of open tabs for browser windows, or the window itself for non-browser chrome windows.  Each window handle is assigned by the server and is guaranteed unique, however the return array does not have a specified ordering.

    use Firefox::Marionette();
    use 5.010;

    my $firefox = Firefox::Marionette->new();
    my $original_window = $firefox->window_handle();
    $firefox->new_window( type => 'tab' );
    $firefox->new_window( type => 'window' );
    say "There are " . $firefox->window_handles() . " tabs open in total";
    say "Across " . $firefox->chrome()->window_handles()->content() . " chrome windows";

## window\_rect

accepts an optional [position and size](https://metacpan.org/pod/Firefox::Marionette::Window::Rect) as a parameter, sets the current browser window to that position and size and returns the previous [position, size and state](https://metacpan.org/pod/Firefox::Marionette::Window::Rect) of the browser window.  If no parameter is supplied, it returns the current  [position, size and state](https://metacpan.org/pod/Firefox::Marionette::Window::Rect) of the browser window.

## window\_type

returns the current window's type.  This should be 'navigator:browser'.

## xvfb\_pid

returns the pid of the xvfb process if it exists.

## xvfb\_display

returns the value for the DISPLAY environment variable if one has been generated for the xvfb environment.

## xvfb\_xauthority

returns the value for the XAUTHORITY environment variable if one has been generated for the xvfb environment

# NETWORK ARCHITECTURE

This module allows for a complicated network architecture, including SSH and HTTP proxies.

    my $firefox = Firefox::Marionette->new(
                    host  => 'Firefox.runs.here'
                    via   => 'SSH.Jump.Box',
                    trust => '/path/to/ca-for-squid-proxy-server.crt',
                    proxy => 'https://Squid.Proxy.Server:3128'
                       )->go('https://Target.Web.Site');

produces the following effect, with an ascii box representing a separate network node.

     ---------          ----------         -----------
     | Perl  |  SSH     | SSH    |  SSH    | Firefox |
     | runs  |--------->| Jump   |-------->| runs    |
     | here  |          | Box    |         | here    |
     ---------          ----------         -----------
                                                |
     ----------          ----------             |
     | Target |  HTTPS   | Squid  |    TLS      |
     | Web    |<---------| Proxy  |<-------------
     | Site   |          | Server |
     ----------          ----------

In addition, the proxy parameter can be used to specify multiple proxies using a reference
to a list.

    my $firefox = Firefox::Marionette->new(
                    host  => 'Firefox.runs.here'
                    trust => '/path/to/ca-for-squid-proxy-server.crt',
                    proxy => [ 'https://Squid1.Proxy.Server:3128', 'https://Squid2.Proxy.Server:3128' ]
                       )->go('https://Target.Web.Site');

When firefox gets a list of proxies, it will use the first one that works.  In addition, it will perform a basic form of proxy failover, which may involve a failed network request before it fails over to the next proxy.  In the diagram below, Squid1.Proxy.Server is the first proxy in the list and will be used exclusively, unless it is unavailable, in which case Squid2.Proxy.Server will be used.

                                          ----------
                                     TLS  | Squid1 |
                                   ------>| Proxy  |-----
                                   |      | Server |    |
     ---------      -----------    |      ----------    |       -----------
     | Perl  | SSH  | Firefox |    |                    | HTTPS | Target  |
     | runs  |----->| runs    |----|                    ------->| Web     |
     | here  |      | here    |    |                    |       | Site    |
     ---------      -----------    |      ----------    |       -----------
                                   | TLS  | Squid2 |    |
                                   ------>| Proxy  |-----
                                          | Server |
                                          ----------

See the [REMOTE AUTOMATION OF FIREFOX VIA SSH](#remote-automation-of-firefox-via-ssh) section for more options.

See [SETTING UP SOCKS SERVERS USING SSH](https://metacpan.org/pod/Firefox::Marionette::Proxy#SETTING-UP-SOCKS-SERVERS-USING-SSH) for easy proxying via [ssh](https://man.openbsd.org/ssh)

See [GEO LOCATION](#geo-location) section for how to combine this with providing appropriate browser settings for the end point.

# AUTOMATING THE FIREFOX PASSWORD MANAGER

This module allows you to login to a website without ever directly handling usernames and password details.  The Password Manager may be preloaded with appropriate passwords and locked, like so;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( profile_name => 'locked' ); # using a pre-built profile called 'locked'
    if ($firefox->pwd_mgr_needs_login()) {
        my $new_password = IO::Prompt::prompt(-echo => q[*], 'Enter the password for the locked profile:');
        $firefox->pwd_mgr_login($password);
    } else {
        my $new_password = IO::Prompt::prompt(-echo => q[*], 'Enter the new password for the locked profile:');
        $firefox->pwd_mgr_lock($password);
    }
    ...
    $firefox->pwd_mgr_logout();

Usernames and passwords (for both HTTP Authentication popups and HTML Form based logins) may be added, viewed and deleted.

    use WebService::HIBP();

    my $hibp = WebService::HIBP->new();

    $firefox->add_login(host => 'https://github.com', user => 'me@example.org', password => 'qwerty', user_field => 'login', password_field => 'password');
    $firefox->add_login(host => 'https://pause.perl.org', user => 'AUSER', password => 'qwerty', realm => 'PAUSE');
    ...
    foreach my $login ($firefox->logins()) {
        if ($hibp->password($login->password())) { # does NOT send the password to the HIBP webservice
            warn "HIBP reports that your password for the " . $login->user() " account at " . $login->host() . " has been found in a data breach";
            $firefox->delete_login($login); # how could this possibly help?
        }
    }

And used to fill in login prompts without explicitly knowing the account details.

    $firefox->go('https://pause.perl.org/pause/authenquery')->accept_alert(); # this goes to the page and submits the http auth popup

    $firefox->go('https://github.com/login')->fill_login(); # fill the login and password fields without needing to see them

# GEO LOCATION

The firefox [Geolocation API](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API) can be used by supplying the `geo` parameter to the [new](#new) method and then calling the [geo](#geo) method (from a [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)).

The [geo](#geo) method can accept various specific latitude and longitude parameters as a list, such as;

    $firefox->geo(latitude => -37.82896, longitude => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, long => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, lng => 144.9811);

    OR

    $firefox->geo(lat => -37.82896, lon => 144.9811);

or it can be passed in as a reference, such as;

    $firefox->geo({ latitude => -37.82896, longitude => 144.9811 });

the combination of a variety of parameter names and the ability to pass parameters in as a reference means it can be deal with various geo location websites, such as;

    $firefox->geo($firefox->json('https://freeipapi.com/api/json/')); # get geo location from current IP address

    $firefox->geo($firefox->json('https://geocode.maps.co/search?street=101+Collins+St&city=Melbourne&state=VIC&postalcode=3000&country=AU&format=json')->[0]); # get geo location of street address

    $firefox->geo($firefox->json('http://api.positionstack.com/v1/forward?access_key=' . $access_key . '&query=101+Collins+St,Melbourne,VIC+3000')->{data}->[0]); # get geo location of street address using api key

    $firefox->geo($firefox->json('https://api.ipgeolocation.io/ipgeo?apiKey=' . $api_key)); # get geo location from current IP address

    $firefox->geo($firefox->json('http://api.ipstack.com/142.250.70.206?access_key=' . $api_key)); # get geo location from specific IP address (http access only for free)

These sites were active at the time this documentation was written, but mainly function as an illustration of the flexibility of [geo](#geo) and [json](#json) methods in providing the desired location to the [Geolocation API](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API).

As mentioned in the [geo](#geo) method documentation, the [ipgeolocation API](https://ipgeolocation.io/documentation/ip-geolocation-api.html) is the only API that currently providing geolocation data and matching timezone data in one API call.  If this url is used, the [tz](#tz) method will be automatically called to set the timezone to the matching timezone for the geographic location.

# CONSOLE LOGGING

Sending debug to the console can be quite confusing in firefox, as some techniques won't work in [chrome](#chrome) context.  The following example can be quite useful.

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( visible => 1, devtools => 1, console => 1, devtools => 1 );

    $firefox->script( q[console.log("This goes to devtools b/c it's being generated in content mode")]);

    $firefox->chrome()->script( q[console.log("Sent out on standard error for Firefox 136 and later")]);

# REMOTE AUTOMATION OF FIREFOX VIA SSH

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', debug => 1 );
    $firefox->go('https://metacpan.org/');

    # OR specify a different user to login as ...
    
    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', user => 'R2D2', debug => 1 );
    $firefox->go('https://metacpan.org/');

    # OR specify a different port to connect to
    
    my $firefox = Firefox::Marionette->new( host => 'remote.example.org', port => 2222, debug => 1 );
    $firefox->go('https://metacpan.org/');

    # OR use a proxy host to jump via to the final host

    my $firefox = Firefox::Marionette->new(
                                             host  => 'remote.example.org',
                                             port  => 2222,
                                             via   => 'user@secure-jump-box.example.org:42222',
                                             debug => 1,
                                          );
    $firefox->go('https://metacpan.org/');

This module has support for creating and automating an instance of Firefox on a remote node.  It has been tested against a number of operating systems, including recent version of [Windows 10 or Windows Server 2019](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse), OS X, and Linux and BSD distributions.  It expects to be able to login to the remote node via public key authentication.  It can be further secured via the [command](https://man.openbsd.org/sshd#command=_command_) option in the [OpenSSH](https://www.openssh.com/) [authorized\_keys](https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT) file such as;

    no-agent-forwarding,no-pty,no-X11-forwarding,permitopen="127.0.0.1:*",command="/usr/local/bin/ssh-auth-cmd-marionette" ssh-rsa AAAA ... == user@server

As an example, the [ssh-auth-cmd-marionette](https://metacpan.org/pod/ssh-auth-cmd-marionette) command is provided as part of this distribution.

The module will expect to access private keys via the local [ssh-agent](https://man.openbsd.org/ssh-agent) when authenticating.

When using ssh, Firefox::Marionette will attempt to pass the [TMPDIR](https://en.wikipedia.org/wiki/TMPDIR) environment variable across the ssh connection to make cleanups easier.  In order to allow this, the [AcceptEnv](https://man.openbsd.org/sshd_config#AcceptEnv) setting in the remote [sshd configuration](https://man.openbsd.org/sshd_config) should be set to allow TMPDIR, which will look like;

    AcceptEnv TMPDIR

This module uses [ControlMaster](https://man.openbsd.org/ssh_config#ControlMaster) functionality when using [ssh](https://man.openbsd.org/ssh), for a useful speedup of executing remote commands.  Unfortunately, when using ssh to move from a [cygwin](https://gcc.gnu.org/wiki/SSH_connection_caching), [Windows 10 or Windows Server 2019](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse) node to a remote environment, we cannot use [ControlMaster](https://man.openbsd.org/ssh_config#ControlMaster), because at this time, Windows [does not support ControlMaster](https://github.com/Microsoft/vscode-remote-release/issues/96) and therefore this type of automation is still possible, but slower than other client platforms.

The [NETWORK ARCHITECTURE](#network-architecture) section has an example of a more complicated network design.

# WEBGL

There are a number of steps to getting [WebGL](https://en.wikipedia.org/wiki/WebGL) to work correctly;

- 1. The `addons` parameter to the [new](#new) method must be set.  This will disable [-safe-mode](http://kb.mozillazine.org/Command_line_arguments#List_of_command_line_arguments_.28incomplete.29)
- 2. The visible parameter to the [new](#new) method must be set.  This is due to [an existing bug in Firefox](https://bugzilla.mozilla.org/show_bug.cgi?id=1375585).
- 3. It can be tricky getting [WebGL](https://en.wikipedia.org/wiki/WebGL) to work with a [Xvfb](https://en.wikipedia.org/wiki/Xvfb) instance.  [glxinfo](https://dri.freedesktop.org/wiki/glxinfo/) can be useful to help debug issues in this case.  The mesa-dri-drivers rpm is also required for Redhat systems.

With all those conditions being met, [WebGL](https://en.wikipedia.org/wiki/WebGL) can be enabled like so;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( addons => 1, visible => 1 );
    if ($firefox->script(q[let c = document.createElement('canvas'); return c.getContext('webgl2') ? true : c.getContext('experimental-webgl') ? true : false;])) {
        $firefox->go("https://get.webgl.org/");
    } else {
        die "WebGL is not supported";
    }

# FILE UPLOADS

Uploading files in forms is accomplished by using the [type](https://metacpan.org/pod/Firefox::Marionette::Element#type) command to enter the full path of the file you want to upload.  An example is shown below;

    use Firefox::Marionette();
    use File::Spec();
    use Cwd();

    my $firefox = Firefox::Marionette->new();
    my $firefox_marionette_directory = Cwd::cwd();
    $firefox->go("https://practice.expandtesting.com/upload");
    while($firefox->percentage_visible($firefox->find_id("fileSubmit")) < 90) {
        sleep 1;
    }
    $firefox->find_id("fileInput")->type(File::Spec->catfile($firefox_marionette_directory, qw(t 04-uploads.t)));
    $firefox->find_id("fileSubmit")->click();

# FINDING ELEMENTS IN A SHADOW DOM

One aspect of [Web Components](https://developer.mozilla.org/en-US/docs/Web/API/Web_components) is the [shadow DOM](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM).  When you need to explore the structure of a [custom element](https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements), you need to access it via the shadow DOM.  The following is an example of navigating the shadow DOM via a html file included in the test suite of this package.

    use Firefox::Marionette();
    use Cwd();

    my $firefox = Firefox::Marionette->new();
    my $firefox_marionette_directory = Cwd::cwd();
    $firefox->go("file://$firefox_marionette_directory/t/data/elements.html");

    my $shadow_root = $firefox->find_tag('custom-square')->shadow_root();

    my $outer_div = $firefox->find_id('outer-div', $shadow_root);

So, this module is designed to allow you to navigate the shadow DOM using normal find methods, but you must get the shadow element's shadow root and use that as the root for the search into the shadow DOM.  An important caveat is that [xpath](https://bugzilla.mozilla.org/show_bug.cgi?id=1822311) and [tag name](https://bugzilla.mozilla.org/show_bug.cgi?id=1822321) strategies do not officially work yet (and also the class name and name strategies).  This module works around the tag name, class name and name deficiencies by using the matching [css selector](#find_selector) search if the original search throws a recognisable exception.  Therefore these cases may be considered to be extremely experimental and subject to change when Firefox gets the "correct" functionality.

# IMITATING OTHER BROWSERS

There are a collection of methods and techniques that may be useful if you would like to change your geographic location or how the browser appears to your web site.

- the `stealth` parameter of the [new](#new) method.  This method will stop the browser reporting itself as a robot and will also (when combined with the [agent](#agent) method, change other javascript characteristics to match the [User Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent) string.
- the [agent](#agent) method, which if supplied a recognisable [User Agent](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent), will attempt to change other attributes to match the desired browser.  This is extremely experimental and feedback is welcome.
- the [geo](#geo) method, which allows the modification of the [Geolocation](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation) reported by the browser, but not the location produced by mapping the external IP address used by the browser (see the [NETWORK ARCHITECTURE](#network-architecture) section for a discussion of different types of proxies that can be used to change your external IP address).
- the [languages](#languages) method, which can change the [requested languages](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language) for your browser session.
- the [tz](#tz) method, which can change the [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) for your browser session.

This list of methods may grow.

# WEBSITES THAT BLOCK AUTOMATION

Marionette [by design](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/webdriver) allows web sites to detect that the browser is being automated.  Firefox [no longer (since version 88)](https://bugzilla.mozilla.org/show_bug.cgi?id=1632821) allows you to disable this functionality while you are automating the browser, but this can be overridden with the `stealth` parameter for the [new](#new) method.  This is extremely experimental and feedback is welcome.

If the web site you are trying to automate mysteriously fails when you are automating a workflow, but it works when you perform the workflow manually, you may be dealing with a web site that is hostile to automation.  I would be very interested if you can supply a test case.

At the very least, under these circumstances, it would be a good idea to be aware that there's an [ongoing arms race](https://en.wikipedia.org/wiki/Web_scraping#Methods_to_prevent_web_scraping), and potential [legal issues](https://en.wikipedia.org/wiki/Web_scraping#Legal_issues) in this area.

# X11 FORWARDING WITH FIREFOX

[X11 Forwarding](https://man.openbsd.org/ssh#X) allows you to launch a [remote firefox via ssh](#remote-automation-of-firefox-via-ssh) and have it visually appear in your local X11 desktop.  This can be accomplished with the following code;

    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new(
                                             host    => 'remote-x11.example.org',
                                             visible => 'local',
                                             debug   => 1,
                                          );
    $firefox->go('https://metacpan.org');

Feedback is welcome on any odd X11 workarounds that might be required for different platforms.

# UBUNTU AND FIREFOX DELIVERED VIA SNAP

[Ubuntu 22.04 LTS](https://ubuntu.com/blog/ubuntu-22-04-lts-whats-new-linux-desktop) is packaging firefox as a [snap](https://ubuntu.com/blog/whats-in-a-snap).  This breaks the way that this module expects to be able to run, specifically, being able to setup a firefox profile in a systems temporary directory (/tmp or $TMPDIR in most Unix based systems) and allow the operating system to cleanup old directories caused by exceptions / network failures / etc.

Because of this design decision, attempting to run a snap version of firefox will simply result in firefox hanging, unable to read it's custom profile directory and hence unable to read the marionette port configuration entry.

Which would be workable except that; there does not appear to be \_any\_ way to detect that a snap firefox will run (/usr/bin/firefox is a bash shell which eventually runs the snap firefox), so there is no way to know (heuristics aside) if a normal firefox or a snap firefox will be launched by execing 'firefox'.

It seems the only way to fix this issue (as documented in more than a few websites) is;

- 1. sudo snap remove firefox
- 2. sudo add-apt-repository -y ppa:mozillateam/ppa
- 3. sudo apt update
- 4. sudo apt install -t 'o=LP-PPA-mozillateam' firefox
- 5. echo -e "Package: firefox\*\\nPin: release o=LP-PPA-mozillateam\\nPin-Priority: 501" >/tmp/mozillateamppa
- 6. sudo mv /tmp/mozillateamppa /etc/apt/preferences.d/mozillateamppa

If anyone is aware of a reliable method to detect if a snap firefox is going to launch vs a normal firefox, I would love to know about it.

This technique is used in the [setup-for-firefox-marionette-build.sh](https://metacpan.org/pod/setup-for-firefox-marionette-build.sh) script in this distribution.

# DIAGNOSTICS

- `Failed to correctly setup the Firefox process`

    The module was unable to retrieve a session id and capabilities from Firefox when it requests a [new\_session](#new_session) as part of the initial setup of the connection to Firefox.

- `Failed to correctly determined the Firefox process id through the initial connection capabilities`

    The module was found that firefox is reporting through it's [Capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities#moz_process_id) object a different process id than this module was using.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.

- `'%s --version' did not produce output that could be parsed.  Assuming modern Marionette is available:%s`

    The Firefox binary did not produce a version number that could be recognised as a Firefox version number.

- `Failed to create process from '%s':%s`

    The module was to start Firefox process in a Win32 environment.  Something is seriously wrong with your environment.

- `Failed to redirect %s to %s:%s`

    The module was unable to redirect a file handle's output.  Something is seriously wrong with your environment.

- `Failed to exec %s:%s`

    The module was unable to run the Firefox binary.  Check the path is correct and the current user has execute permissions.

- `Failed to fork:%s`

    The module was unable to fork itself, prior to executing a command.  Check the current `ulimit` for max number of user processes.

- `Failed to open directory '%s':%s`

    The module was unable to open a directory.  Something is seriously wrong with your environment.

- `Failed to close directory '%s':%s`

    The module was unable to close a directory.  Something is seriously wrong with your environment.

- `Failed to open '%s' for writing:%s`

    The module was unable to create a file in your temporary directory.  Maybe your disk is full?

- `Failed to open temporary file for writing:%s`

    The module was unable to create a file in your temporary directory.  Maybe your disk is full?

- `Failed to close '%s':%s`

    The module was unable to close a file in your temporary directory.  Maybe your disk is full?

- `Failed to close temporary file:%s`

    The module was unable to close a file in your temporary directory.  Maybe your disk is full?

- `Failed to create temporary directory:%s`

    The module was unable to create a directory in your temporary directory.  Maybe your disk is full?

- `Failed to clear the close-on-exec flag on a temporary file:%s`

    The module was unable to call fcntl using F\_SETFD for a file in your temporary directory.  Something is seriously wrong with your environment.

- `Failed to seek to start of temporary file:%s`

    The module was unable to seek to the start of a file in your temporary directory.  Something is seriously wrong with your environment.

- `Failed to create a socket:%s`

    The module was unable to even create a socket.  Something is seriously wrong with your environment.

- `Failed to connect to %s on port %d:%s`

    The module was unable to connect to the Marionette port.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.

- `Firefox killed by a %s signal (%d)`

    Firefox crashed after being hit with a signal.  

- `Firefox exited with a %d`

    Firefox has exited with an error code

- `Failed to bind socket:%s`

    The module was unable to bind a socket to any port.  Something is seriously wrong with your environment.

- `Failed to close random socket:%s`

    The module was unable to close a socket without any reads or writes being performed on it.  Something is seriously wrong with your environment.

- `moz:headless has not been determined correctly`

    The module was unable to correctly determine whether Firefox is running in "headless" or not.  This is probably a bug in this module's logic.  Please report as described in the BUGS AND LIMITATIONS section below.

- `%s method requires a Firefox::Marionette::Element parameter`

    This function was called incorrectly by your code.  Please supply a [Firefox::Marionette::Element](https://metacpan.org/pod/Firefox::Marionette::Element) parameter when calling this function.

- `Failed to write to temporary file:%s`

    The module was unable to write to a file in your temporary directory.  Maybe your disk is full?

- `Failed to close socket to firefox:%s`

    The module was unable to even close a socket.  Something is seriously wrong with your environment.

- `Failed to send request to firefox:%s`

    The module was unable to perform a syswrite on the socket connected to firefox.  Maybe firefox crashed?

- `Failed to read size of response from socket to firefox:%s`

    The module was unable to read from the socket connected to firefox.  Maybe firefox crashed?

- `Failed to read response from socket to firefox:%s`

    The module was unable to read from the socket connected to firefox.  Maybe firefox crashed?

# CONFIGURATION AND ENVIRONMENT

Firefox::Marionette requires no configuration files or environment variables.  It will however use the DISPLAY and XAUTHORITY environment variables to try to connect to an X Server.
It will also use the HTTP\_PROXY, HTTPS\_PROXY, FTP\_PROXY and ALL\_PROXY environment variables as defaults if the session [capabilities](https://metacpan.org/pod/Firefox::Marionette::Capabilities) do not specify proxy information.

# DEPENDENCIES

Firefox::Marionette requires the following non-core Perl modules

- [JSON](https://metacpan.org/pod/JSON)
- [URI](https://metacpan.org/pod/URI)
- [XML::Parser](https://metacpan.org/pod/XML::Parser)
- [Time::Local](https://metacpan.org/pod/Time::Local)

# INCOMPATIBILITIES

None reported.  Always interested in any products with marionette support that this module could be patched to work with.

# BUGS AND LIMITATIONS

## DOWNLOADING USING GO METHOD

When using the [go](#go) method to go directly to a URL containing a downloadable file, Firefox can hang.  You can work around this by setting the [page\_load\_strategy](https://metacpan.org/pod/Firefox::Marionette::Capabilities#page_load_strategy) to `none` like below;

    #! /usr/bin/perl

    use strict;
    use warnings;
    use Firefox::Marionette();

    my $firefox = Firefox::Marionette->new( capabilities => Firefox::Marionette::Capabilities->new( page_load_strategy => 'none' ) );
    $firefox->go("https://github.com/david-dick/firefox-marionette/archive/refs/heads/master.zip");
    while(!$firefox->downloads()) { sleep 1 }
    while($firefox->downloading()) { sleep 1 }
    foreach my $path ($firefox->downloads()) {
        warn "$path has been downloaded";
    }
    $firefox->quit();

Also, check out the [download](#download) method for an alternative.

## MISSING METHODS

Currently the following Marionette methods have not been implemented;

- WebDriver:SetScreenOrientation

To report a bug, or view the current list of bugs, please visit [https://github.com/david-dick/firefox-marionette/issues](https://github.com/david-dick/firefox-marionette/issues)

# SEE ALSO

- [MozRepl](https://metacpan.org/pod/MozRepl)
- [Selenium::Firefox](https://metacpan.org/pod/Selenium::Firefox)
- [Firefox::Application](https://metacpan.org/pod/Firefox::Application)
- [Mozilla::Mechanize](https://metacpan.org/pod/Mozilla::Mechanize)
- [Gtk2::MozEmbed](https://metacpan.org/pod/Gtk2::MozEmbed)

# AUTHOR

David Dick  `<ddick@cpan.org>`

# ACKNOWLEDGEMENTS

Thanks to the entire Mozilla organisation for a great browser and to the team behind Marionette for providing an interface for automation.

Thanks to [Jan Odvarko](http://www.softwareishard.com/blog/about/) for creating the [HAR Export Trigger](https://github.com/firefox-devtools/har-export-trigger) extension for Firefox.

Thanks to [Mike Kaply](https://mike.kaply.com/about/) for his [post](https://mike.kaply.com/2015/02/10/installing-certificates-into-firefox/) describing importing certificates into Firefox.

Thanks also to the authors of the documentation in the following sources;

- [Marionette Protocol](https://firefox-source-docs.mozilla.org/testing/marionette/marionette/index.html)
- [Marionette driver.js](https://hg.mozilla.org/mozilla-central/file/tip/remote/marionette/driver.sys.mjs)
- [about:config](http://kb.mozillazine.org/About:config_entries)
- [nsIPrefService interface](https://developer.mozilla.org/en-US/docs/Mozilla/Tech/XPCOM/Reference/Interface/nsIPrefService)

# LICENSE AND COPYRIGHT

Copyright (c) 2024, David Dick `<ddick@cpan.org>`. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See ["perlartistic" in perlartistic](https://metacpan.org/pod/perlartistic#perlartistic).

The [Firefox::Marionette::Extension::HarExportTrigger](https://metacpan.org/pod/Firefox::Marionette::Extension::HarExportTrigger) module includes the [HAR Export Trigger](https://github.com/firefox-devtools/har-export-trigger)
extension which is licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/).

# DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
