#===============================================================================
#         FILE: 006_export.t
#  DESCRIPTION: test exported osrelease() function
#       AUTHOR: Ian Kluft (IKLUFT)
#      CREATED: 04/30/2022 06:17:49 PM
#===============================================================================

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use Sys::OsRelease;  # default instantiation occurs here
use Test::More;

my @std_attrs = Sys::OsRelease::std_attrs();
plan tests => (3 + 2 * scalar @std_attrs);

# verify function import
ok( Sys::OsRelease->can("osrelease"), "Sys::OsRelease can osrelease()");
ok( main->can("osrelease"), "main can osrelease()");

# osrelease returns correct type
isa_ok( osrelease(), "Sys::OsRelease", "osrelease return value" );

# check each attribute accessor method exists and is the same value as the class method
foreach my $attr (map {lc $_} @std_attrs) {
    ok((osrelease()->can($attr)), "osrelease() can $attr()");
    is((osrelease()->can($attr)), Sys::OsRelease->can($attr), "osrelease->$attr() matches class method");
}

1;

