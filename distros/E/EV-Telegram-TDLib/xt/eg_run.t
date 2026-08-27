use strict;
use warnings;
use Test::More;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};
plan tests => 5;

# eg/06 needs no credentials and no network: execute() is local and the
# async getOption is answered by TDLib itself, so it can run for real.
# Compiling alone did not catch a wrong reply deref; running does.
my ($out, $rc);
eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 30;
    $out = `"$^X" -Mblib eg/06-raw-method.pl 2>&1`;
    $rc = $?;
    alarm 0;
};
alarm 0;

is($rc, 0, 'eg/06-raw-method.pl exits cleanly');
like($out, qr/^TDLib version: \S/m,             'prints TDLib version');
like($out, qr/^entities: \d+$/m,                'prints entity count');
like($out, qr/assigned \@extra \d+/,            'prints assigned @extra');
like($out, qr/^async getOption reply: \S+/m,    'prints async reply');
diag($out) if $rc;
