use strict;
use warnings;
use Test::More;
use File::Temp ();

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

my $pm  = 'lib/EV/Telegram/TDLib.pm';
my $out = File::Temp->new;
close $out;

# README is generated, but tracked: nothing regenerates it on commit, so it
# drifts silently whenever the POD changes
my $rc = system(qq{pod2text $pm > "$out" 2>/dev/null});
plan skip_all => 'pod2text is unavailable' if $rc != 0;

open my $a, '<', 'README' or plan skip_all => "README: $!";
open my $b, '<', "$out"   or plan skip_all => "generated: $!";
local $/;
my ($have, $want) = (<$a>, <$b>);
close $a; close $b;

is $have, $want, 'README is current with the POD (run: make README)';

done_testing;
