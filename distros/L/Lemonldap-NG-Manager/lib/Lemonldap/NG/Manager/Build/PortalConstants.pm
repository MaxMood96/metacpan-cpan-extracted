# This file contains the list of portal statuses, used in portal and portal
# plugins, and displayed in the Handler Status page

# DON'T FORGET TO RUN "make json" AFTER EACH CHANGE

package Lemonldap::NG::Manager::Build::PortalConstants;

our $VERSION = '2.19.0';

sub portalConstants {
    return {

        # Portal errors
        # Developers warning, do not use PE_INFO, it's reserved to autoRedirect.
        PE_2FWAIT                            => -6,
        PE_IDPCHOICE                         => -5,
        PE_SENDRESPONSE                      => -4,
        PE_INFO                              => -3,
        PE_REDIRECT                          => -2,
        PE_DONE                              => -1,
        PE_OK                                => 0,
        PE_SESSIONEXPIRED                    => 1,
        PE_FORMEMPTY                         => 2,
        PE_WRONGMANAGERACCOUNT               => 3,
        PE_USERNOTFOUND                      => 4,
        PE_BADCREDENTIALS                    => 5,
        PE_LDAPCONNECTFAILED                 => 6,
        PE_LDAPERROR                         => 7,
        PE_APACHESESSIONERROR                => 8,
        PE_FIRSTACCESS                       => 9,
        PE_BADCERTIFICATE                    => 10,
        PE_NO_PASSWORD_BE                    => 20,
        PE_PP_ACCOUNT_LOCKED                 => 21,
        PE_PP_PASSWORD_EXPIRED               => 22,
        PE_CERTIFICATEREQUIRED               => 23,
        PE_ERROR                             => 24,
        PE_PP_CHANGE_AFTER_RESET             => 25,
        PE_PP_PASSWORD_MOD_NOT_ALLOWED       => 26,
        PE_PP_MUST_SUPPLY_OLD_PASSWORD       => 27,
        PE_PP_INSUFFICIENT_PASSWORD_QUALITY  => 28,
        PE_PP_PASSWORD_TOO_SHORT             => 29,
        PE_PP_PASSWORD_TOO_YOUNG             => 30,
        PE_PP_PASSWORD_IN_HISTORY            => 31,
        PE_PP_GRACE                          => 32,
        PE_PP_EXP_WARNING                    => 33,
        PE_PASSWORD_MISMATCH                 => 34,
        PE_PASSWORD_OK                       => 35,
        PE_NOTIFICATION                      => 36,
        PE_BADURL                            => 37,
        PE_NOSCHEME                          => 38,
        PE_BADOLDPASSWORD                    => 39,
        PE_MALFORMEDUSER                     => 40,
        PE_SESSIONNOTGRANTED                 => 41,
        PE_CONFIRM                           => 42,
        PE_MAILFORMEMPTY                     => 43,
        PE_BADMAILTOKEN                      => 44,
        PE_MAILERROR                         => 45,
        PE_MAILOK                            => 46,
        PE_LOGOUT_OK                         => 47,
        PE_SAML_ERROR                        => 48,
        PE_SAML_LOAD_SERVICE_ERROR           => 49,
        PE_SAML_LOAD_IDP_ERROR               => 50,
        PE_SAML_SSO_ERROR                    => 51,
        PE_SAML_UNKNOWN_ENTITY               => 52,
        PE_SAML_DESTINATION_ERROR            => 53,
        PE_SAML_CONDITIONS_ERROR             => 54,
        PE_SAML_IDPSSOINITIATED_NOTALLOWED   => 55,
        PE_SLO_ERROR                         => 56,
        PE_SAML_SIGNATURE_ERROR              => 57,
        PE_SAML_ART_ERROR                    => 58,
        PE_SAML_SESSION_ERROR                => 59,
        PE_SAML_LOAD_SP_ERROR                => 60,
        PE_SAML_ATTR_ERROR                   => 61,
        PE_OPENID_EMPTY                      => 62,
        PE_OPENID_BADID                      => 63,
        PE_MISSINGREQATTR                    => 64,
        PE_BADPARTNER                        => 65,
        PE_MAILCONFIRMATION_ALREADY_SENT     => 66,
        PE_PASSWORDFORMEMPTY                 => 67,
        PE_CAS_SERVICE_NOT_ALLOWED           => 68,
        PE_MAILFIRSTACCESS                   => 69,
        PE_MAILNOTFOUND                      => 70,
        PE_PASSWORDFIRSTACCESS               => 71,
        PE_MAILCONFIRMOK                     => 72,
        PE_RADIUSCONNECTFAILED               => 73,
        PE_MUST_SUPPLY_OLD_PASSWORD          => 74,
        PE_FORBIDDENIP                       => 75,
        PE_CAPTCHAERROR                      => 76,
        PE_CAPTCHAEMPTY                      => 77,
        PE_REGISTERFIRSTACCESS               => 78,
        PE_REGISTERFORMEMPTY                 => 79,
        PE_REGISTERALREADYEXISTS             => 80,
        PE_NOTOKEN                           => 81,
        PE_TOKENEXPIRED                      => 82,
        PE_WEBAUTHNFAILED                    => 83,
        PE_UNAUTHORIZEDPARTNER               => 84,
        PE_RENEWSESSION                      => 85,
        PE_WAIT                              => 86,
        PE_MUSTAUTHN                         => 87,
        PE_MUSTHAVEMAIL                      => 88,
        PE_SAML_SERVICE_NOT_ALLOWED          => 89,
        PE_OIDC_SERVICE_NOT_ALLOWED          => 90,
        PE_OID_SERVICE_NOT_ALLOWED           => 91,
        PE_GET_SERVICE_NOT_ALLOWED           => 92,
        PE_IMPERSONATION_SERVICE_NOT_ALLOWED => 93,
        PE_ISSUERMISSINGREQATTR              => 94,
        PE_DECRYPTVALUE_SERVICE_NOT_ALLOWED  => 95,
        PE_BADOTP                            => 96,
        PE_RESETCERTIFICATE_INVALID          => 97,
        PE_RESETCERTIFICATE_FORMEMPTY        => 98,
        PE_RESETCERTIFICATE_FIRSTACCESS      => 99,
        PE_PP_NOT_ALLOWED_CHARACTER          => 100,
        PE_PP_NOT_ALLOWED_CHARACTERS         => 101,
        PE_UPGRADESESSION                    => 102,
        PE_NO_SECOND_FACTORS                 => 103,
        PE_BAD_DEVOPS_FILE                   => 104,
        PE_FILENOTFOUND                      => 105,
        PE_OIDC_AUTH_ERROR                   => 106,
        PE_UNKNOWNPARTNER                    => 107,
        PE_UNAUTHORIZEDURL                   => 108,
        PE_UNPROTECTEDURL                    => 109,
        PE_RETRY_2FA                         => 110,
        PE_PP_PASSWORD_TOO_LONG              => 111,
    };
}

1;
