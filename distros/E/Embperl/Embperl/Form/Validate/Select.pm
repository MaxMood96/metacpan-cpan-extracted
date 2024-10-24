
###################################################################################
#
#   Embperl - Copyright (c) 1997-2008 Gerald Richter / ecos gmbh  www.ecos.de
#   Embperl - Copyright (c) 2008-2015 Gerald Richter
#   Embperl - Copyright (c) 2015-2023 actevy.io
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.
#
#   THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
#   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
#   WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
###################################################################################


package Embperl::Form::Validate::Select ;

use base qw(Embperl::Form::Validate::Default);
use utf8 ;


# --------------------------------------------------------------

sub getscript_required
    {
    my ($self, $arg, $pref) = @_ ;
    
    return ('obj.selectedIndex != 0', ['validate_required']) ;
    }


1;

