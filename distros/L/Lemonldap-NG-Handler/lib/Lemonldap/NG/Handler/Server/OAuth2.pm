# LLNG wrapper class to enable OAuth2 handler with FastCGI handler
#
# See https://lemonldap-ng.org/documentation/latest/handlerarch
package Lemonldap::NG::Handler::Server::OAuth2;

use strict;

use base 'Lemonldap::NG::Handler::Lib::OAuth2',
  'Lemonldap::NG::Handler::Server::Main';

our $VERSION = '2.0.4';

1;
