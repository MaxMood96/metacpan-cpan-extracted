#!/usr/bin/env -S perl -wT --
use strict;
use warnings 'FATAL' => 'all';
no warnings qw(experimental::signatures);
use feature qw(signatures);
use version;
use boolean qw(:all);
use lib qw(../lib);

use Data::Dumper;
use DeyeCloud::Client;
use POSIX;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

use constant {
	#{{{
	DEVICE_SERIAL => '2407240613',
	STATION_ID    => '61849454',
	ACCESS_TOKEN  => 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsib2F1dGgyLXJlc291cmNlIl0sInVzZXJfbmFtZSI6IjBfdnBvZGdvcm55QGdtYWlsLmNvbV8yIiwic2NvcGUiOlsiYWxsIl0sImRldGFpbCI6eyJvcmdhbml6YXRpb25JZCI6MCwidG9wR3JvdXBJZCI6bnVsbCwiZ3JvdXBJZCI6bnVsbCwicm9sZUlkIjotMSwidXNlcklkIjoxMzU2MDI1MSwidmVyc2lvbiI6MTAwMCwiaWRlbnRpZmllciI6InZwb2Rnb3JueUBnbWFpbC5jb20iLCJpZGVudGl0eVR5cGUiOjIsIm1kYyI6InVjIiwiYXBwSWQiOiIyMDI2MDIwMjEyMjIwMDYiLCJtZmFTdGF0dXMiOm51bGwsInRlbmFudCI6IkRleWUifSwiZXhwIjoxNzc1ODIzMzI3LCJtZGMiOiJ1YyIsImF1dGhvcml0aWVzIjpbImFsbCJdLCJqdGkiOiI5ZWE1ZWFkYy1mMDAxLTQxNDctYjJhNi01Y2FlMWM1ZDYwODYiLCJjbGllbnRfaWQiOiJ0ZXN0In0.G6q9HZIOemyZaG-gN8OoyQsxy4peOL0QU405iVWajVUQGVpVBH5tMuyMBghioJyGRNG2uH73vZASJIS9i46oFfODWlGzED8Ld2qQF1wceqTaxwrac9LHMxA_mo5vwHBo9xi_P84yy_N4m2lr8lS8MfsbgINy4emldyiPzQmhlBjHJFw4W7bIPsIHQWFutsQ-fB62bR8JuY4C0QZKXAxiSmDOAUgTtaZ8Vh5MpU6FAdBh5515wV3PjbojvZdtT8-aMR6BfsGDKZ5BqIHrqGbyFuAcIMrTxsEVRONIPLrZUKG1dq7hrU-hTsd7Lfv65PPWRIucJmeznLvZLtekFMhtHQ',
}; #}}}

my $data = undef;

my $deye = DeyeCloud::Client->new('token' => ACCESS_TOKEN);

# $data = $deye->__call('station/listWithDevice', 'page' => 1, 'size' => 10, 'deviceType' => 'INVERTER');
# $data = $deye->__call('station/list', 'page' => 1, 'size' => 10);
# $data = $deye->call('station/device', 'page' => 1, 'size' => 10, 'stationIds' => [ 61802673 ]);
# $data = $deye->__call('station/alertList',
# 	'stationId' => 61802673,
# 	'startTimestamp' => 1767438387,
# 	'endTimestamp' => 1770116787
#);
#$data = $deye->__call('station/history/power',
#  	'stationId' => 61802673,
#  	'startTimestamp' => 1767438387,
#  	'endTimestamp' => 1770116787
#);
#$data = $deye->call('station/history', {
#	'granularity' => 2,
#	'stationId' => 61802673,
#	'startAt' => '2026-02-01',
#	'endAt' => '2026-02-03',
#});
# $data = $deye->devices('stationIds' => [ 61802673 ]);
# $data = $deye->__call('device/latest', 'deviceList' => [ 8205375 ]);
# $data = $deye->__call('device/measurePoints', deviceSn => 2407240613, deviceType => 'INVERTER');

#$data = $deye->token(
#	'appid' => '202602021222006',
#	'appsecret' => 'd232b624fe6666b9faf4e3c4196a3937',
#	'email' => 'vpodgorny@gmail.com',
#	'password' => 'P5iUoBC4S_GV1pB'
#);

# $data = $deye->call('station/latest', 'stationId' => 61849454);
# $data = $deye->call('device/detail', 'deviceId' => '8205375', 'language' => 'en');
# $data = $deye->call('device/originalData', 'deviceId' => '8205375');

$data = $deye->status('stationId' => 61849454);
# map { printf "  %s => %s\n", $_, $data->{$_}; } sort keys %{$data};
#printf "%s\n", Dumper $data;
#printf "  batterySOC => %s\n", $data->batterySOC;
#printf "  generationPower => %s\n", $data->generationPower;
#printf "  chargePower => %s\n", $data->chargePower;
#printf "  dischargePower => %s\n", $data->dischargePower;
$data = $deye->status('deviceId' => 8205375);
# map { printf "  %s => %s\n", $_, $data->$_; } sort keys %{$data};
# print Dumper $data->grid_voltage->[0];
printf "%s\n", $data->updateTime;

# printf "error: %s\n", $deye->error;
# printf "errno: %s\n", $deye->errno;
# printf "errmsg: %s\n", $deye->errmsg;
