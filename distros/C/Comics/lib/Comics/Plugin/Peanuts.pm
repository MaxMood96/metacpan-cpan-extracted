#! perl

use strict;
use warnings;

package Comics::Plugin::Peanuts;

use parent qw(Comics::Fetcher::GoComics);

our $VERSION = "0.02";

sub register {
    shift->SUPER::register
      ( { name    => "Peanuts",
	  url     => "https://www.gocomics.com/peanuts",
	} );
}

# Important: Return the package name!
__PACKAGE__;
