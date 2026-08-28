use strict;
use warnings;
use Test::More;
use File::Temp ();

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

my $PM   = 'lib/EV/Telegram/TDLib.pm';
my $BOOK = 'lib/EV/Telegram/TDLib/Cookbook.pod';

sub slurp { open my $h, '<', $_[0] or die "$_[0]: $!"; local $/; <$h> }

# --- the SYNOPSIS is the most copied code in the dist, so it must compile
my ($syn) = slurp($PM) =~ /^=head1 SYNOPSIS\n\n(.*?)^=head1 /ms;
ok $syn, 'found the SYNOPSIS';
$syn =~ s/^    //gm;
my $tmp = File::Temp->new(SUFFIX => '.pl');
print {$tmp} "use strict;\nuse warnings;\n", $syn;
close $tmp;
my $out = `$^X -Iblib/lib -Iblib/arch -c "$tmp" 2>&1`;
like $out, qr/syntax OK/, 'the SYNOPSIS compiles as written'
    or diag $out;

# --- every method the docs demonstrate must actually exist, so a rewritten
# API cannot leave the prose describing something that is gone
my %have;
for my $f ($PM, glob 'lib/EV/Telegram/TDLib/*.pm') {
    # bind the text first: calling slurp() in the condition would reread the
    # file every iteration, resetting pos() and looping forever
    my $src = slurp($f);
    $have{$1} = 1 while $src =~ /^sub ([a-z_]\w*)/mg;
    # Bots.pm defines three getters through the symbol table, so a ^sub scan
    # cannot see them and documenting a call to one would look like a typo
    $have{$1} = 1 while $src =~ /\[\s*(\w+)\s*=>\s*'get\w+'\s*\]/g;
}
my %called;
for my $f ($PM, $BOOK) {
    my $s = slurp($f);
    $called{$1}{$f} = 1 while $s =~ /\$(?:td|bot|user|self)\s*->\s*([a-z_]\w*)\s*\(/g;
}
ok scalar keys %called, 'found documented method calls to check';
my @missing = grep { !$have{$_} } sort keys %called;
# the assertion must not hang off a statement-modifier for: with nothing
# missing the loop body never runs and the test silently never executes
is "@missing", '', 'every documented method call exists';
diag "missing: $_ (in " . join(', ', sort keys %{ $called{$_} }) . ")"
    for @missing;

done_testing;
