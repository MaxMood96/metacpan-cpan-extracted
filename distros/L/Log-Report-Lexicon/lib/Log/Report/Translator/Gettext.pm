# This code is part of Perl distribution Log-Report-Lexicon version 1.14.
# The POD got stripped from this file by OODoc version 3.04.
# For contributors see file ChangeLog.

# This software is copyright (c) 2007-2025 by Mark Overmeer.

# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later

#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Translator::Gettext;{
our $VERSION = '1.14';
}

use base 'Log::Report::Translator';

use warnings;
use strict;

use Log::Report 'log-report-lexicon';

use Locale::gettext;

#--------------------

sub translate($;$$)
{	my ($msg, $lang, $ctxt) = @_;

#XXX MO: how to use $lang when specified?
	my $domain = $msg->{_textdomain};
	load_domain $domain;

	my $count  = $msg->{_count};

	defined $count
	  ?	( defined $msg->{_category}
		? dcngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count, $msg->{_category})
		: dngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count)
		)
	  :	( defined $msg->{_category}
		? dcgettext($domain, $msg->{_msgid}, $msg->{_category})
		: dgettext($domain, $msg->{_msgid})
		);
}

1;
