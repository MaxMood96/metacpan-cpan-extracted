#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use Cwd ();
use File::Temp ();

# The `punk doctor` row this distribution registers.
#
# In a child, and the child loads Punk::Command and NOTHING of this
# distribution: Punk 0.32 loads every Punk::Command::* on @INC before it
# prints, which is what makes the row appear for an operator who has not run
# `punk apikey`. That is the whole reason the floor is 0.32 rather than 0.31,
# so it is asserted rather than described.
#
# From a directory with no application in it, because the row must not need
# one: it reports where the Sqitch plan is, which is a fact about the
# installation and not about anybody's app.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
    plan skip_all => 'Punk::Command required'
        unless eval { require Punk::Command; 1 };
}

my @INC_ABS = map { Cwd::abs_path($_) || $_ } grep { !ref } @INC;

my $tmp = File::Temp::tempdir(CLEANUP => 1);
my $cwd = Cwd::getcwd();
END { chdir $cwd if $cwd }

sub _q { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'" }

my ($code, $out) = do {
    my $child = <<'CHILD';
use Punk::Command ();
my $out = '';
open my $o, '>', \$out or die $!;
my $rc = do { local $Punk::Command::OUT = $o; Punk::Command->main('doctor') };
close $o;
print "\0CODE\0$rc\0OUT\0$out";
CHILD
    chdir $tmp or die $!;
    my $cmd = join ' ', _q($^X), (map { '-I' . _q($_) } @INC_ABS),
                        '-e', _q($child);
    my $raw = qx{$cmd 2>/dev/null};
    chdir $cwd or die $!;
    my ($rc, $o) = $raw =~ /\0CODE\0(.*?)\0OUT\0(.*)\z/s;
    (defined $rc ? $rc : 255, $o // '');
};

is($code, 0, 'punk doctor runs with no application in the directory')
    or diag $out;

like($out, qr/^\s*Punk::APIKey\s+\S+/m,
    'and prints this distribution\'s row without the command being named - '
  . 'the Punk 0.32 behaviour the floor is set for');

like($out, qr/^\s*Punk::APIKey\s+\S*\s*\(punk_apikey\)/m,
    'naming the Sqitch project it found a plan for');

unlike($out, qr/^\s*Punk::APIKey\s+.*no plan for/m,
    'and not reporting a missing plan, which is what a half-installed '
  . 'distribution looks like');

done_testing();
