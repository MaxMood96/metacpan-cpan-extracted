use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Data::HashMap::Shared::SS;

# Regression (0.18): the list-returning keywords (keys/values/items/each/
# cursor_next) built their entersub with OPf_STACKED | OPf_WANT_LIST.
# Perl_scalar() returns early on an op whose OPf_WANT bits are already set, so
# the call ran in list context even in scalar context and its surplus return
# values spilled into the enclosing expression -- silently adding arguments to
# whatever call contained it.  A keyword must behave exactly like the method it
# wraps; the reference in every case below is the method form.

my $dir = tempdir(CLEANUP => 1);
my $m = Data::HashMap::Shared::SS->new("$dir/ctx.hm", 1024);
$m->put("b", "1");
$m->put("c", "2");

sub take { return scalar @_ }
sub lst  { return join '|', @_ }

is( take("x", (shm_ss_keys $m) ? "T" : "F"),
    take("x", ($m->keys)       ? "T" : "F"),
    'keyword in a boolean sub-expression passes no extra arguments' );

is( lst("x", (shm_ss_keys $m) ? "T" : "F"),
    lst("x", ($m->keys)       ? "T" : "F"),
    '  ...and the argument values match the method form' );

is( lst("pre" . (shm_ss_keys $m)),
    lst("pre" . ($m->keys)),
    'keyword in a concatenation yields one value' );

{
    my $kw = shm_ss_keys $m;
    my $mm = $m->keys;
    is( $kw, $mm, 'keyword in scalar assignment matches the method' );
}

# List contexts must be untouched by the fix.
{
    my @kw = sort(shm_ss_keys $m);
    my @mm = sort($m->keys);
    is_deeply( \@kw, \@mm, 'list context still yields every key' );
    my $n = () = shm_ss_keys $m;
    is( $n, 2, 'count idiom still sees both keys' );
}

# The pair-returning keywords keep working in their idiomatic loop form.
{
    my %seen;
    while (my ($k, $v) = shm_ss_each $m) { $seen{$k} = $v }
    is_deeply( \%seen, { b => "1", c => "2" }, 'each keyword loop yields all pairs' );

    my $cur = shm_ss_cursor $m;
    my %cseen;
    while (my ($k, $v) = shm_ss_cursor_next $cur) { $cseen{$k} = $v }
    is_deeply( \%cseen, { b => "1", c => "2" }, 'cursor_next keyword loop yields all pairs' );
}

done_testing;
