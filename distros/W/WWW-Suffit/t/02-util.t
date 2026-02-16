#!/usr/bin/perl -w
#########################################################################
#
# Serż Minus (Sergey Lepenkov), <abalama@cpan.org>
#
# Copyright (C) 1998-2026 D&D Corporation
#
# This program is distributed under the terms of the Artistic License 2.0
#
#########################################################################
use Test::More tests => 1;
use WWW::Suffit::Util qw/md5sum/;

is(md5sum('LICENSE'), '2babd339892857699767bda29d606988', 'LICENSE md5sum check');

1;

__END__

prove -lv t/02-util.t
