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
use Test::More;
use WWW::Suffit::API;

my $api = WWW::Suffit::API->new;

note $api->hint('E0000');

subtest 'Get hints by errcode' => sub {
    is $api->hint, 'Ok', 'Default';
    is $api->hint('E0000'), 'Ok', 'E0000';
    is $api->hint('Etest', 'bar'), 'foo with bar', "Etest";
};

done_testing;

1;

__END__

prove -lv t/02-hints.t
