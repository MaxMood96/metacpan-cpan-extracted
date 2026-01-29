#!/usr/bin/perl

use strict;
use feature qw( say );
use IO::All;
use File::Basename;
use FindBin;
use JSON;
use Term::ReadLine;
use Data::Dumper;

use lib "$FindBin::Bin/../lib";
use FSM::Basic;

my ($srcip, $srcport, $dstip, $dstport) = (split(/\s+/, $ENV{SSH_CONNECTION}));
my %to_subst = (
    __ENPROMPT__ => 'Admin# ',
    __PROMPT__   => $srcip . '=>' . $dstip . '> '
);

my $basename = basename $0 , '.pl';
my $file_def;
if (-f "$FindBin::Bin/$dstip.json") {
    $file_def = "$FindBin::Bin/$dstip.json";
} else {
    $to_subst{__PROMPT__} = $srcip . '=>' . $dstip . " you're not using the correct IP > ";
    $file_def = "$FindBin::Bin/$basename.json";
}
my $json = io($file_def)->slurp;
foreach my $subst (keys %to_subst) {
    $json =~ s/$subst/$to_subst{$subst}/g;
}

my $states       = from_json($json);
say Dumper($states);
my $history_file = glob('~/.bash.history');
my $prompt       = $to_subst{__PROMPT__};
my $line;
my $term    = new Term::ReadLine 'bash';
my $attribs = $term->Attribs->ornaments(0);
$term->using_history();
$term->read_history($history_file);
$term->clear_signals();
my $fsm = FSM::Basic->new($states, 'prompt');
my $final = 0;
my $extra;
my $out   = $prompt;
#say " $fsm->{state} => ".Dumper($fsm->{states_list}{ $fsm->{state} });
my $timer = $fsm->{states_list}{ $fsm->{state} }{timer};
my $start = time;

while (defined($line = $term->readline($out))) {
    my $now = time;

    if ($timer && $now - $start > $timer) {
        if (exists $fsm->{states_list}{ $fsm->{state} }{timeout}) {
            say "$timer $now $start $fsm->{state}".Dumper($fsm->{states_list}{ $fsm->{state} }{timeout});
            $fsm->set($fsm->{states_list}{ $fsm->{state} }{timeout});
        }
    }
    say "*******line=<$line>";
    ($final, $out, $extra) = $fsm->run($line);
    say "** out=<$out> line=<$line>";
    if (exists $extra->{readmode} && $extra->{readmode} == 2) {
        system("stty", "-echo");
    } else {
        system("stty", "sane");
    }
    $term->write_history($history_file);
    $start = $now;
    last if $final;
}
