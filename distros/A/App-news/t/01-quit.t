# Copyright (C) 2021–2023  Alex Schroeder <alex@gnu.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;
use Test::More;
use Net::NNTP;

our $port;

require './t/test.pl';
diag "Starting NNTP on $port";
$ENV{NNTPSERVER} = "localhost:$port";
my $nntp = Net::NNTP->new();
ok($nntp->quit, "QUIT");

done_testing;
