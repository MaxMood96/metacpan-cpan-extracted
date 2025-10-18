## @file
# Display functions for LemonLDAP::NG Portal
package Lemonldap::NG::Portal::Main::Display;

our $VERSION = '2.22.0';

package Lemonldap::NG::Portal::Main;
use strict;
use Mouse;
use JSON;
use URI;

has speChars                 => ( is => 'rw' );
has skinRules                => ( is => 'rw' );
has stayConnected            => ( is => 'rw', default => sub { 0 } );
has requireOldPwd            => ( is => 'rw', default => sub { 1 } );
has rememberAuthChoice       => ( is => 'rw', default => sub { 0 } );
has passwordPolicyActivation => ( is => 'rw', default => sub { 0 } );
has passwordResetUrl => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        $_[0]->conf->{mailUrl} || $_[0]->buildUrl("resetpwd");
    }
);
has certificateResetUrl => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        $_[0]->conf->{certificateResetByMailURL}
          || $_[0]->buildUrl("certificateReset");
    }
);
has registerUrl => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        $_[0]->conf->{registerUrl} || $_[0]->buildUrl("register");
    }
);
has ott => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $ott = $_[0]->loadModule('::Lib::OneTimeToken');
        $ott->timeout( $_[0]->conf->{formTimeout} );
        return $ott;
    }
);

sub displayInit {
    my ($self) = @_;
    $self->skinRules( [] );
    if ( $self->conf->{portalSkinRules} ) {
        foreach my $skinRule ( sort keys %{ $self->conf->{portalSkinRules} } ) {
            my $sub = HANDLER->buildSub( HANDLER->substitute($skinRule) );
            if ($sub) {
                push @{ $self->skinRules },
                  [ $self->conf->{portalSkinRules}->{$skinRule}, $sub ];
            }
            else {
                $self->logger->error(
                    qq(Skin rule "$skinRule" returns an error: )
                      . HANDLER->tsv->{jail}->error
                      || 'Unable to compile rule' );
            }
        }
    }

    my $rule = HANDLER->buildSub(
        HANDLER->substitute( $self->conf->{portalRequireOldPassword} ) );
    unless ($rule) {
        my $error = HANDLER->tsv->{jail}->error || 'Unable to compile rule';
        $self->logger->error("Bad requireOldPwd rule: $error");
    }
    $self->requireOldPwd($rule);

    $rule =
      HANDLER->buildSub( HANDLER->substitute( $self->conf->{stayConnected} ) );
    unless ($rule) {
        my $error = HANDLER->tsv->{jail}->error || 'Unable to compile rule';
        $self->logger->error("Bad stayConnected rule: $error");
    }
    $self->stayConnected($rule);

    $rule =
      HANDLER->buildSub(
        HANDLER->substitute( $self->conf->{passwordPolicyActivation} ) );
    unless ($rule) {
        my $error = HANDLER->tsv->{jail}->error || 'Unable to compile rule';
        $self->logger->error("Bad passwordPolicyActivation rule: $error");
    }
    $self->passwordPolicyActivation($rule);

    $rule =
      HANDLER->buildSub(
        HANDLER->substitute( $self->conf->{rememberAuthChoiceRule} ) );
    unless ($rule) {
        my $error = HANDLER->tsv->{jail}->error || 'Unable to compile rule';
        $self->logger->error("Bad rememberAuthChoiceRule rule: $error");
    }
    $self->rememberAuthChoice($rule);

    my %speChars = $self->conf->{passwordPolicySpecialChar} eq '__ALL__'
      ? ()    # Dedup
      : map { ( s/\s+/<space>/r => 1 ) } split '',
      $self->conf->{passwordPolicySpecialChar};
    $self->speChars( join q{ }, sort keys %speChars );
}

sub isPP {
    my $self    = shift;
    my $ppRules = $self->getPpolicyRules();
    foreach (@$ppRules) {
        return 1 if $_->{'condition'};
    }
    return 0;
}

# Call portal process and set template parameters
# @return template name and template parameters
sub display {
    my ( $self, $req ) = @_;

    my $skin_dir = $self->conf->{templateDir};
    my ( $skinfile, %templateParams );

    # 1. Authentication not complete

    # 1.1 A notification has to be done (session is created but hidden and
    #     unusable until the user has accept the message)
    if ( my $notif = $req->data->{notification} ) {
        $self->logger->debug('Display: notification detected');
        $skinfile       = 'notification';
        %templateParams = (
            $self->getErrorTplParams($req),
            FORM_ACTION   => $self->relativeUrl( $req, 'notifback' ),
            NOTIFICATION  => $notif,
            HIDDEN_INPUTS => $self->buildHiddenForm($req),
            AUTH_URL      => $req->{data}->{_url},
            CHOICE_PARAM  => $self->conf->{authChoiceParam},
            CHOICE_VALUE  => $req->data->{_authChoice},
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 1.2a An authentication (or userDB) module needs to ask a question
    #     before processing to the request
    elsif ( $req->{error} == PE_CONFIRM ) {
        $self->logger->debug('Display: confirm detected');
        $skinfile       = 'confirm';
        %templateParams = (
            $self->getErrorTplParams($req),
            AUTH_URL      => $req->{data}->{_url},
            MSG           => $req->info,
            HIDDEN_INPUTS => $self->buildHiddenForm($req),
            ACTIVE_TIMER  => $req->data->{activeTimer},
            FORM_ACTION   => $req->data->{confirmFormAction}
              || "#",
            FORM_METHOD  => $self->conf->{confirmFormMethod},
            CHOICE_PARAM => $self->conf->{authChoiceParam},
            CHOICE_VALUE => $req->data->{_authChoice},
            CHECK_LOGINS => $self->conf->{portalCheckLogins}
              && $req->data->{login},
            ASK_LOGINS => $req->param('checkLogins')
              || 0,
            ASK_STAYCONNECTED => $req->param('stayconnected')
              || 0,
            CONFIRMKEY => $self->stamp(),
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),

        );
    }

    # 1.2b An authentication (or userDB) module needs to ask a question
    #     before processing to the request
    elsif ( $req->{error} == PE_IDPCHOICE ) {
        $self->logger->debug('Display: IDP choice detected');
        $skinfile       = 'idpchoice';
        %templateParams = (
            $self->getErrorTplParams($req),
            AUTH_URL      => $req->{data}->{_url},
            HIDDEN_INPUTS => $self->buildHiddenForm($req),
            ACTIVE_TIMER  => $req->data->{activeTimer},
            FORM_METHOD   => $self->conf->{confirmFormMethod},
            CHOICE_PARAM  => $self->conf->{authChoiceParam},
            CHOICE_VALUE  => $req->data->{_authChoice},
            CHECK_LOGINS  => $self->conf->{portalCheckLogins}
              && $req->data->{login},
            ASK_LOGINS        => $req->param('checkLogins')   || 0,
            ASK_STAYCONNECTED => $req->param('stayconnected') || 0,
            CONFIRMKEY        => $self->stamp(),
            LIST              => $req->data->{list} || [],
            LOGIN_HINT        => $req->data->{suggestedLogin},
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 1.3 There is a message to display
    elsif ( my $info = $req->info ) {
        my $method =
          $req->data->{infoFormMethod} || $self->conf->{infoFormMethod};
        $self->logger->debug('Display: info detected');
        $self->logger->debug('Hidden values :');
        $self->logger->debug( " $_: " . $req->{portalHiddenFormValues}->{$_} )
          for keys %{ $req->{portalHiddenFormValues} // {} };
        $skinfile = 'info';

        if ( !$req->urldc and $req->error == PE_LOGOUT_OK ) {
            $req->urldc( $self->buildUrl( $req->portal, { logout => 1 } ) );
        }

        %templateParams = (
            $self->getErrorTplParams($req),
            MSG           => $info,
            URL           => $req->urldc || $req->portal,
            HIDDEN_INPUTS => $self->buildOutgoingHiddenForm( $req, $method ),
            ACTIVE_TIMER  => $req->data->{activeTimer},
            CHOICE_PARAM  => $self->conf->{authChoiceParam},
            CHOICE_VALUE  => $req->data->{_authChoice},
            FORM_METHOD   => $method,
            (
                  ( not $req->{urldc} ) ? ( SEND_PARAMS => 1 )
                : ()
            ),
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 1.4 OpenID menu page
    elsif ($req->{error} == PE_OPENID_EMPTY
        or $req->{error} == PE_OPENID_BADID )
    {
        $skinfile = 'openid';

        my $openid_path =
          $self->conf->{issuerDBOpenIDPath} =~ s/^.*?(\w+).*?$/$1/r;
        my $id = $req->{sessionInfo}
          ->{ $self->conf->{openIdAttr} || $self->conf->{whatToTrace} };
        %templateParams = (
            $self->getErrorTplParams($req),
            PROVIDERURI => $self->buildUrl( $req->portal, $openid_path, "" ),
            MSG         => $req->info(),
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
        $templateParams{ID} = $req->data->{_openidPortal} . $id if ($id);
    }

    # 2. Good authentication

    # 2.1 Redirection
    elsif ( $req->{error} == PE_REDIRECT ) {
        my $method = $req->data->{redirectFormMethod} || 'get';
        $skinfile       = "redirect";
        %templateParams = (
            URL           => $req->{urldc},
            HIDDEN_INPUTS => $self->buildOutgoingHiddenForm( $req, $method ),
            FORM_METHOD   => $method,
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 2.1 Wait for 2FA
    elsif ( $req->{error} == PE_2FWAIT ) {
        my $method = $req->data->{redirectFormMethod} || 'get';
        $skinfile       = "2fwait";
        %templateParams = (
            URL           => $req->{urldc},
            HIDDEN_INPUTS => $self->buildOutgoingHiddenForm( $req, $method ),
            FORM_METHOD   => $method,
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 2.2 Case : display menu (with error or not)
    elsif ( $req->error == PE_OK ) {
        $skinfile = 'menu';

        #utf8::decode($auth_user);
        %templateParams = (
            AUTH_USER => $req->{sessionInfo}->{ $self->conf->{portalUserAttr} },
            NEWWINDOW => $self->conf->{portalOpenLinkInNewWindow},
            LOGOUT_URL     => $self->buildUrl( $req->portal, { logout => 1 } ),
            APPSLIST_ORDER => $req->{sessionInfo}->{'_appsListOrder'},
            PING           => $self->conf->{portalPingInterval},
            DONT_STORE_PASSWORD => $self->conf->{browsersDontStorePassword},
            HIDE_OLDPASSWORD    => 0,
            ENABLE_PASSWORD_DISPLAY =>
              $self->conf->{portalEnablePasswordDisplay},
            %{ $self->getPasswordPolicyTemplateVars },
            (
                $self->requireOldPwd->( $req, $req->userData )
                ? ( REQUIRE_OLDPASSWORD => 1 )
                : ()
            ),
            $self->menu->params($req),
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # when upgrading session, the administrator can configure LLNG
    # to ask only for 2FA
    elsif ( $req->error == PE_UPGRADESESSION ) {
        $skinfile       = 'upgradesession';
        %templateParams = (
            FORMACTION   => '/upgradesession',
            MSG          => 'askToUpgrade',
            PORTALBUTTON => 1,
            BUTTON       => 'upgradeSession',
            CONFIRMKEY   => $self->stamp,
            PORTAL       => $req->portal,
            URL          => $req->data->{_url},
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # renew uses the same plugin as upgrade, but first factor is mandatory
    elsif ( $req->error == PE_RENEWSESSION ) {
        $skinfile       = 'upgradesession';
        %templateParams = (
            FORMACTION   => '/renewsession',
            MSG          => 'askToRenew',
            CONFIRMKEY   => $self->stamp,
            PORTAL       => $req->portal,
            PORTALBUTTON => 1,
            BUTTON       => 'renewSession',
            URL          => $req->data->{_url},
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # Looks a lot like upgradesession, but no portal logo
    elsif ( $req->error == PE_MUSTAUTHN ) {
        $skinfile       = 'upgradesession';
        %templateParams = (
            FORMACTION => '/renewsession',
            MSG        => 'PE87',
            CONFIRMKEY => $self->stamp,
            BUTTON     => 'renewSession',
            PORTAL     => $req->portal,
            URL        => $req->data->{_url},
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 2.3 Case : user authenticated but an error was returned (bad url,...)
    elsif (
        $req->noLoginDisplay
        or (    not $req->data->{noerror}
            and $req->userData
            and %{ $req->userData } )

        # Avoid issue 1867
        or (    $self->conf->{authentication} eq 'Combination'
            and $req->{error} > PE_OK
            and $req->{error} != PE_FIRSTACCESS
            and $req->{error} != PE_BADCREDENTIALS
            and $req->{error} != PE_PP_CHANGE_AFTER_RESET
            and $req->{error} != PE_PP_PASSWORD_EXPIRED
            and $req->{error} != PE_BADOLDPASSWORD
            and $req->{error} != PE_PP_PASSWORD_EXPIRES_SOON )
      )
    {
        $skinfile       = 'error';
        %templateParams = (
            $self->getErrorTplParams($req),
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );
    }

    # 3 Authentication has been refused OR first access
    else {
        $skinfile = 'login';
        my $login = $req->user || $req->data->{suggestedLogin};
        %templateParams = (
            $self->getErrorTplParams($req),
            AUTH_URL              => $req->{data}->{_url},
            LOGIN                 => $login,
            ACTIVE_FORM           => 1,
            DONT_STORE_PASSWORD   => $self->conf->{browsersDontStorePassword},
            CHECK_LOGINS          => $self->conf->{portalCheckLogins},
            ASK_LOGINS            => $req->param('checkLogins') || 0,
            ASK_STAYCONNECTED     => $req->param('stayconnected') || 0,
            DISPLAY_RESETPASSWORD => $self->conf->{portalDisplayResetPassword},
            DISPLAY_REGISTER      => $self->conf->{portalDisplayRegister},
            DISPLAY_UPDATECERTIF =>
              $self->conf->{portalDisplayCertificateResetByMail},
            MAILCERTIF_URL => $self->certificateResetUrl,
            MAIL_URL       => $self->passwordResetUrl,
            REGISTER_URL   => $self->registerUrl,
            HIDDEN_INPUTS  => $self->buildHiddenForm($req),
            IMPERSONATION  => $self->conf->{impersonationRule}
              || $self->conf->{proxyAuthServiceImpersonation},
            ENABLE_PASSWORD_DISPLAY =>
              $self->conf->{portalEnablePasswordDisplay},
            %{ $self->getPasswordPolicyTemplateVars },
            ( (
                         $self->conf->{trustedBrowserRule}
                      or $self->stayConnected->( $req, $req->sessionInfo )
                ) ? ( STAYCONNECTED => 1 )
                : ()
            ),
            BROWSER_ALREADY_TRUSTED => $req->{data}->{browserAlreadyTrusted},
            (
                $self->rememberAuthChoice->( $req, $req->sessionInfo )
                ? ( REMEMBERAUTHCHOICE => 1 )
                : ()
            ),
            REMEMBERAUTHCHOICEDEFAULTCHECKED =>
              $self->conf->{rememberDefaultChecked} // 0,
            REMEMBERAUTHCHOICECOOKIENAME => $self->conf->{rememberCookieName}
              // 'llngrememberauthchoice',
            REMEMBERAUTHCHOICETIMER => $self->conf->{rememberTimer} // 5,
            (
                $req->data->{customScript}
                ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                : ()
            ),
        );

        # External links
        if ( $self->conf->{portalDisplayResetPassword} ) {
            $templateParams{"MAIL_URL_EXTERNAL"} =
              $self->_isExternalUrl( $req, $self->passwordResetUrl );
        }
        if ( $self->conf->{portalDisplayRegister} ) {
            $templateParams{"REGISTER_URL_EXTERNAL"} =
              $self->_isExternalUrl( $req, $self->registerUrl );
        }
        if ( $self->conf->{portalDisplayCertificateResetByMail} ) {
            $templateParams{MAILCERTIF_URL_EXTERNAL} =
              $self->_isExternalUrl( $req, $self->certificateResetUrl );
        }

        # Display captcha if it's enabled
        if ( $req->captchaHtml ) {
            %templateParams =
              ( %templateParams, CAPTCHA_HTML => $req->captchaHtml, );
        }
        if ( $req->token ) {
            %templateParams = ( %templateParams, TOKEN => $req->token, );
        }

       # DEPRECATED: This is only used for compatibility with existing templates
        if ( $req->captcha ) {
            %templateParams = (
                %templateParams,
                CAPTCHA_SRC  => $req->captcha,
                CAPTCHA_SIZE => $self->{conf}->{captcha_size} || 6
            );
        }

        # Show password form if password policy error
        if (

               $req->{error} == PE_PP_CHANGE_AFTER_RESET
            or $req->{error} == PE_PP_MUST_SUPPLY_OLD_PASSWORD
            or $req->{error} == PE_PP_INSUFFICIENT_PASSWORD_QUALITY
            or $req->{error} == PE_PP_PASSWORD_TOO_SHORT
            or $req->{error} == PE_PP_PASSWORD_TOO_YOUNG
            or $req->{error} == PE_PP_PASSWORD_IN_HISTORY
            or $req->{error} == PE_PASSWORD_MISMATCH
            or $req->{error} == PE_BADOLDPASSWORD
            or $req->{error} == PE_PASSWORDFORMEMPTY
            or $req->{error} == PE_PP_PASSWORD_EXPIRES_SOON
            or (    $req->{error} == PE_PP_PASSWORD_EXPIRED
                and $self->conf->{ldapAllowResetExpiredPassword} )
          )
        {
            %templateParams = (
                %templateParams,
                REQUIRE_OLDPASSWORD =>
                  1,    # Old password is required to check user credentials
                DISPLAY_FORM          => 0,
                DISPLAY_OPENID_FORM   => 0,
                DISPLAY_YUBIKEY_FORM  => 0,
                DISPLAY_PASSWORD      => 1,
                DISPLAY_RESETPASSWORD => 0,
                AUTH_LOOP             => [],
                CHOICE_PARAM          => $self->conf->{authChoiceParam},
                CHOICE_VALUE          => $req->data->{_authChoice},
                OLDPASSWORD           => $self->conf->{hideOldPassword}
                ? $self->ott->createToken( {
                        oldpassword => $self->conf->{cipher}
                          ->encrypt( $req->data->{oldpassword}, 1 )
                    }
                  )
                : $self->checkXSSAttack( 'oldpassword',
                    $req->data->{oldpassword} ) ? ''
                : $req->data->{oldpassword},
                HIDE_OLDPASSWORD    => $self->conf->{hideOldPassword},
                DONT_STORE_PASSWORD => $self->conf->{browsersDontStorePassword},
                ENABLE_PASSWORD_DISPLAY =>
                  $self->conf->{portalEnablePasswordDisplay},
                %{ $self->getPasswordPolicyTemplateVars },
            );
        }

        # Disable all forms on:
        # * Logout message
        # * Account lock
        # * Bad URL error
        elsif ($req->{error} == PE_LOGOUT_OK
            or $req->{error} == PE_WAIT
            or $req->{error} == PE_BADURL )
        {
            %templateParams = (
                %templateParams,
                DISPLAY_RESETPASSWORD => 0,
                DISPLAY_FORM          => 0,
                DISPLAY_OPENID_FORM   => 0,
                DISPLAY_YUBIKEY_FORM  => 0,
                AUTH_LOOP             => [],
                MSG                   => $req->info(),
                LOCKTIME              => $req->lockTime(),
            );
        }

        # Display authentication form
        else {
            my $plugin =
              $self->loadedModules->{
                "Lemonldap::NG::Portal::Plugins::FindUser"};
            my ( $fields, $slogin, $mandatory ) = ( [], '', 0 );

            if (   $plugin
                && $self->conf->{findUser}
                && $self->conf->{impersonationRule}
                && $self->conf->{findUserSearchingAttributes} )
            {
                $slogin = $req->data->{findUser};
                ( $fields, $mandatory ) = $plugin->buildForm();
            }

            # Authentication loop
            if ( $self->conf->{authentication} eq 'Choice'
                and my $authLoop = $self->_buildAuthLoop($req) )
            {
                %templateParams = (
                    %templateParams,
                    AUTH_LOOP            => $authLoop,
                    CHOICE_PARAM         => $self->conf->{authChoiceParam},
                    CHOICE_VALUE         => $req->data->{_authChoice},
                    DISPLAY_FORM         => 0,
                    DISPLAY_OPENID_FORM  => 0,
                    DISPLAY_YUBIKEY_FORM => 0,
                    DISPLAY_FINDUSER     => scalar @$fields,
                    MANDATORY            => $mandatory,
                    FIELDS               => $fields,
                    SPOOFID              => $slogin,

                    # Hidden inputs and custom scripts may have been modified
                    # by _buildAuthLoop so we need to update them
                    HIDDEN_INPUTS => $self->buildHiddenForm($req),
                    (
                        $req->data->{customScript}
                        ? ( CUSTOM_SCRIPT => $req->data->{customScript} )
                        : ()
                    ),
                );
            }

            # Choose which form to display if not in a loop
            else {
                my $displayType =
                  eval { $self->_authentication->getDisplayType($req) }
                  || 'logo';

                $self->logger->debug("Display type $displayType");

                %templateParams = (
                    %templateParams,
                    DISPLAY_FORM => $displayType =~ /\bstandardform\b/ ? 1
                    : 0,
                    DISPLAY_OPENID_FORM => $displayType =~ /\bopenidform\b/ ? 1
                    : 0,
                    DISPLAY_YUBIKEY_FORM => $displayType =~ /\byubikeyform\b/
                    ? 1
                    : 0,
                    DISPLAY_SSL_FORM      => $displayType =~ /sslform/ ? 1 : 0,
                    DISPLAY_WEBAUTHN_FORM => $displayType =~ /webauthnform/ ? 1
                    : 0,
                    DISPLAY_GPG_FORM  => $displayType =~ /gpgform/ ? 1 : 0,
                    DISPLAY_LOGO_FORM => $displayType eq "logo"    ? 1 : 0,
                    DISPLAY_FINDUSER  => scalar @$fields,
                    module            => $displayType eq "logo"
                    ? $self->getModule( $req, 'auth' )
                    : "",
                    AUTH_LOOP  => [],
                    PORTAL_URL => ( $displayType eq "logo" ? $req->portal : 0 ),
                    MSG        => $req->info(),
                    MANDATORY  => $mandatory,
                    FIELDS     => $fields,
                    SPOOFID    => $slogin
                );
            }
        }
    }

    if ( $req->data->{waitingMessage} ) {
        $templateParams{WAITING_MESSAGE} = 1;
    }

    $self->logger->debug("Skin returned: $skinfile");
    return ( $skinfile, \%templateParams );
}

##@method public void printImage(string file, string type)
# Print image to STDOUT
# @param $file The path to the file to print
# @param $type The content-type to use (ie: image/png)
# @return void
sub staticFile {
    my ( $self, $req, $file, $type ) = @_;
    require Plack::Util;
    require Cwd;
    require HTTP::Date;
    open my $fh, '<:raw', $self->conf->{templateDir} . "/$file"
      or return $self->sendError( $req,
        $self->conf->{templateDir} . "/$file: $!", 403 );
    my @stat = stat $file;
    Plack::Util::set_io_path( $fh, Cwd::realpath($file) );
    return [
        200,
        [
            'Content-Type'   => $type,
            'Content-Length' => $stat[7],
            'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
        ],
        $fh,
    ];
}

sub buildOutgoingHiddenForm {
    my ( $self, $req, $method ) = @_;
    my @extra_keys;

    if ( lc $method eq 'get' ) {
        my $uri = URI->new( $req->{urldc} );
        @extra_keys = $uri->query_form;
    }

    return $self->buildHiddenForm( $req, @extra_keys );
}

sub buildHiddenForm {
    my ( $self, $req, @extra_keys ) = @_;
    my @keys = keys %{ $req->{portalHiddenFormValues} };
    my $val  = '';

    foreach (@keys) {

        # Check XSS attacks
        next
          if (!$req->data->{safeHiddenFormValues}->{$_}
            && $self->checkXSSAttack( $_, $req->{portalHiddenFormValues}->{$_} )
          );

        $val .= qq{<input type="hidden" name="$_" value="}
          . $req->{portalHiddenFormValues}->{$_} . '" />';
    }

    while ( my ( $key, $value ) = splice( @extra_keys, 0, 2 ) ) {

        # Check XSS attacks
        next
          if (!$req->data->{safeHiddenFormValues}->{$key}
            && $self->checkXSSAttack( $key, $value ) );

        $val .= qq{<input type="hidden" name="$key" value="$value" />};
    }

    return $val;
}

# Return skin name
# @return skin name
sub getSkin {
    my ( $self, $req ) = @_;
    my $skin = $self->conf->{portalSkin};

    # Fill sessionInfo to eval rule if empty (unauthenticated user)
    $req->{sessionInfo}->{_url}   ||= $req->{urldc};
    $req->{sessionInfo}->{ipAddr} ||= $req->address;

    # Load specific skin from skinRules
    foreach my $rule ( @{ $self->skinRules } ) {
        if ( $rule->[1]->( $req, $req->sessionInfo ) ) {
            my $directory = $self->conf->{templateDir} . '/' . $rule->[0];
            if ( -d $directory ) {
                $skin = $rule->[0];
                $self->logger->debug("Skin $skin selected from skin rule");
                last;
            }
            else {
                $self->logger->warn( "Skin $rule->[0] was not selected "
                      . "because $directory does not exist" );
            }
        }
    }

    # Check skin GET/POST parameter
    my $skinParam = $req->param('skin');
    if ( defined $skinParam ) {
        if ( $skinParam =~ /^[\w\-]+$/ ) {
            if ( -d $self->getSkinTplDir($skinParam) ) {
                $skin = $skinParam;
                $self->logger->debug(
                    "Skin $skin selected from GET/POST parameter");
            }
            else {
                $self->logger->warn(
                    "User tries to access to nonexistent skin dir $skinParam");
            }
        }
        else {
            $self->logger->warn("Invalid skin name $skinParam");
        }
    }

    return $skin;
}

# Build an HTML array to display sessions
# @param $sessions Array ref of hash ref containing sessions data
# @param $title Title of the array
# @param $displayUser To display "User" column
# @param $displaError To display "Error" column
# @return HTML string
sub mkSessionArray {
    my ( $self, $req, $sessions, $title, $displayUser, $displayError ) = @_;

    return "" unless ( ref $sessions eq "ARRAY" and @$sessions );

    # Merge user configuration with plugin self-configuration
    my %rememberedData = %{ $self->pluginSessionDataToRemember };
    @rememberedData{ keys %{ $self->conf->{sessionDataToRemember} } } =
      values %{ $self->conf->{sessionDataToRemember} };

    # Delete fields with an empty/undef/__hidden__ column name
    delete @rememberedData{
        grep {
                 ( not $rememberedData{$_} )
              or ( $rememberedData{$_} eq "__hidden__" )
        } keys %rememberedData
    };

    my @fields = sort( keys %rememberedData );

    return $self->loadTemplate(
        $req,
        'sessionArray',
        params => {
            title        => $title,
            displayUser  => $displayUser,
            displayError => $displayError,
            fields       => [ map { { name => $rememberedData{$_} } } @fields ],
            sessions     => [
                map {
                    my $session = $_;
                    {
                        user   => $session->{user},
                        utime  => $session->{_utime},
                        ip     => $session->{ipAddr},
                        values => [
                            map {
                                # Modifying key to remove ordering prefix
                                my $modifiedKey = $_;
                                $modifiedKey =~ s/(\d+_)?//;
                                {
                                    v => $session->{$modifiedKey},
                                    k => $modifiedKey,
                                    "k_$modifiedKey" => 1
                                }
                            } @fields
                        ],
                        error        => $session->{error},
                        displayUser  => $displayUser,
                        displayError => $displayError,
                    }
                } @$sessions
            ],
        }
    );
}

sub mkOidcConsent {
    my ( $self, $req, $session ) = @_;

    if ( defined( $self->conf->{oidcRPMetaDataOptions} )
        and ref( $self->conf->{oidcRPMetaDataOptions} ) )
    {

        # Set default RP displayname
        foreach my $oidc ( keys %{ $self->conf->{oidcRPMetaDataOptions} } ) {
            $self->conf->{oidcRPMetaDataOptions}->{$oidc}
              ->{oidcRPMetaDataOptionsDisplayName} ||= $oidc;
        }
    }

    # Loading existing oidcConsents
    $self->logger->debug("Searching OIDC Consents...");
    my $_oidcConsents;
    if ( exists $session->{_oidcConsents} ) {
        $_oidcConsents = eval {
            from_json( $session->{_oidcConsents}, { allow_nonref => 1 } );
        };
        if ($@) {
            $self->logger->error("Corrupted session (_oidcConsents): $@");
            return PE_ERROR;
        }
    }
    else {
        $self->logger->debug("No OIDC Consent found");
    }
    my $consents = {};
    foreach (@$_oidcConsents) {
        if ( defined $_->{rp} ) {
            my $rp = $_->{rp};
            $self->logger->debug("RP { $rp } Consent found");
            $consents->{$rp}->{epoch} = $_->{epoch};
            $consents->{$rp}->{scope} = $_->{scope};
            $consents->{$rp}->{displayName} =
              $self->conf->{oidcRPMetaDataOptions}->{$rp}
              ->{oidcRPMetaDataOptionsDisplayName};
        }
    }

    # Display existing oidcConsents
    return $self->loadTemplate(
        $req,
        'oidcConsents',
        params => {
            partners => [
                map { {
                        name        => $_,
                        epoch       => $consents->{$_}->{epoch},
                        scope       => $consents->{$_}->{scope},
                        displayName => $consents->{$_}->{displayName}
                    }
                } ( sort keys %$consents )
            ],
            consents => join( ",", keys %$consents ),
        }
    );
}

sub _isExternalUrl {
    my ( $self, $req, $url ) = @_;
    return ( index( $url, $req->portal ) < 0 );
}

sub getPasswordPolicyTemplateVars {
    my ( $self, $req ) = @_;
    return {
        PPOLICY_RULES    => $self->getPpolicyRules,
        PPOLICY_NOPOLICY => !$self->isPP(),
        ENABLE_CHECKHIBP => $self->conf->{checkHIBP},
        DISPLAY_PPOLICY  => $self->conf->{portalDisplayPasswordPolicy},
        PPOLICY_MINSIZE  => $self->conf->{passwordPolicyMinSize},
        PPOLICY_MAXSIZE  => $self->conf->{passwordPolicyMaxSize},
        PPOLICY_MINLOWER => $self->conf->{passwordPolicyMinLower},
        PPOLICY_MINUPPER => $self->conf->{passwordPolicyMinUpper},
        PPOLICY_MINDIGIT => $self->conf->{passwordPolicyMinDigit},
        (
            $self->conf->{passwordPolicyMinSpeChar}
            ? ( PPOLICY_MINSPECHAR => $self->conf->{passwordPolicyMinSpeChar} )
            : ()
        ),
        (
            $self->conf->{passwordPolicyMinSpeChar} && $self->speChars()
            ? (
                PPOLICY_ALLOWEDSPECHAR => $self->speChars(),
                PPOLICY_ALLOWEDSPECHAR_JSON =>
                  to_json( $self->speChars(), { allow_nonref => 1 } ),
              )
            : ()
        ),
    };
}

sub getPpolicyRules {
    my ($self) = @_;
    my $result = [];

    # Avoid useless computation if ppolicy is not displayed
    return $result if !$self->conf->{portalDisplayPasswordPolicy};

    while ( my ( $id, $policy ) = each %{ $self->_ppRules } ) {
        push @$result, { %$policy, id => $id };
    }

    # Sort ppolicy items by "order" numerically and then by "id" lexically
    $result = [ sort { $a->{order} <=> $b->{order} || $a->{id} cmp $b->{id} }
          @$result ];

    # Format data attributes for HTML::Template loop
    # data => { foo => "bar" } becomes
    # data => [ { key => "foo", value => "bar" } ]
    for my $result (@$result) {
        if ( ref( $result->{data} ) eq "HASH" ) {
            $result->{data} = [
                map { { key => $_, value => $result->{data}->{$_} } }
                  keys %{ $result->{data} }
            ];
        }
    }
    return $result;
}

1;
