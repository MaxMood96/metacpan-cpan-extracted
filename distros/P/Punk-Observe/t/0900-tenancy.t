#!perl
# The tenant seam, kept honest with no site in existence.
#
# THE POINT OF TESTING THIS NOW is that these properties decide whether the
# hosted deployment is configuration or a rewrite. They are all testable with
# a constant resolver, and if they hold here they hold there.
#
# The strongest assertion in this file is a NEGATIVE one: there is no code
# path that takes a tenant from a request. That is asserted against the
# source, because the absence of a function is not something a unit test can
# call.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use Punk::Observe;

my $T = 'Punk::Observe::Tenant';
sub chk     { $T->can('check')->($_[0]) }
sub resolve { $T->can('resolve')->(@_) }

# --- the boundary -----------------------------------------------------------

{
    for my $ok (qw(default acme acme-1 acme_1 A 0 a-b_c), 'x' x 64) {
        my $r = chk($ok);
        ok($r->{ok}, "'" . (length($ok) > 10 ? length($ok) . " chars" : $ok)
                     . "' is a valid tenant id") or diag $r->{reason};
    }
}

# A resolver returning any of these must not be able to construct a path.
{
    my @bad = (
        [ ''            => 'empty'     ],
        [ '.'           => 'traversal' ],
        [ '..'          => 'traversal' ],
        [ '../other'    => 'char'      ],
        [ 'a/b'         => 'char'      ],
        [ "a\\b"        => 'char'      ],
        [ 'a b'         => 'char'      ],
        [ 'a.b'         => 'char'      ],
        [ "a\0b"        => 'char'      ],
        [ "a\nb"        => 'char'      ],
        [ "caf\xc3\xa9" => 'char'      ],
        [ '%2e%2e'      => 'char'      ],
        [ 'x' x 65      => 'long'      ],
    );
    for my $c (@bad) {
        my $label = $c->[0] =~ /[^ -~]/ ? '(non-printable)'
                  : length($c->[0]) > 20 ? length($c->[0]) . ' chars'
                  : "'$c->[0]'";
        my $r = chk($c->[0]);
        ok(!$r->{ok}, "$label is refused");
    }
}

# The reason is specific, because the person debugging a resolver wrote the
# resolver and "invalid tenant" is not a bug report.
{
    like(chk('')->{reason},        qr/empty/,   'an empty id says so');
    like(chk('..')->{reason},      qr/\.\./,    '  and a traversal names itself');
    like(chk('a/b')->{reason},     qr/A-Za-z/,  '  and a bad character names the class');
    like(chk('x' x 65)->{reason},  qr/64/,      '  and an over-long one names the limit');
}

# --- the resolver, with the CONSTANT default -------------------------------

{
    my $r = resolve('acme', undef);
    ok($r->{ok}, 'the constant resolver resolves');
    is($r->{tenant}, 'acme', '  to the configured id');
}

{
    my $r = resolve('', undef);
    ok($r->{ok}, 'no configured id falls back to the default');
    is($r->{tenant}, 'default', '  which is the documented constant');
}

# A typo in a config file is a BOOT failure, not a runtime one.
{
    my $r = resolve('../etc', undef);
    ok(!$r->{ok}, 'a bad configured id is refused at configuration time');
    is($r->{at}, 'configuration', '  and says where it was refused');
}

# --- HOST CODE IS NOT TRUSTED ----------------------------------------------
#
# A resolver is a callback the host supplies. One that returns `../other` is a
# bug this seam must CATCH, not a value to pass through.

{
    my $r = resolve('acme', sub { 'other' });
    ok($r->{ok}, 'a callback resolver is used when supplied');
    is($r->{tenant}, 'other', '  and its answer wins over the constant');
}

{
    for my $bad ('../other', 'a/b', '', '..', "a\0b", 'x' x 100) {
        my $r = resolve('acme', sub { $bad });
        ok(!$r->{ok}, "a resolver returning '"
                    . ($bad =~ /[^ -~]/ ? '(non-printable)' : $bad)
                    . "' is refused");
        isnt($r->{tenant}, $bad, '  and its value never becomes the tenant');
    }
}

{
    my $r = resolve('acme', sub { undef });
    ok(!$r->{ok}, 'a resolver returning undef is refused');
    ok(!exists $r->{tenant}, '  and yields no tenant at all');
}

# --- a path for A never resolves inside B ----------------------------------

{
    my $S = 'Punk::Observe::Segment';
    my $store = $S->can('store_path');
    SKIP: {
        skip 'no store_path in this build', 4 unless $store;
        my $dir = tempdir(CLEANUP => 1);
        my $a = $store->("$dir/acme", 'seg/1.po');
        my $b = $store->("$dir/rival", 'seg/1.po');
        isnt($a, $b, 'two tenants build different paths');
        unlike($a, qr{/rival/}, "tenant A's path never mentions tenant B");
        unlike($b, qr{/acme/},  '  and the reverse');
        like($a, qr{\Q$dir/acme\E}, '  each rooted at its own directory');
    }
}

# --- the segment header check ----------------------------------------------
#
# Checked when the file is OPENED. A mis-filed segment found at open is an
# error; one found after it has been read is a disclosure that already
# happened.

{
    my $h_acme  = $T->can('hash')->('acme');
    my $h_rival = $T->can('hash')->('rival');
    isnt($h_acme, $h_rival, 'two tenants hash differently');

    ok($T->can('owns')->($h_acme, 'acme'),
       'a segment whose header names this tenant is accepted');
    ok(!$T->can('owns')->($h_acme, 'rival'),
       'a segment whose header names ANOTHER tenant is refused');
    ok(!$T->can('owns')->($h_rival, 'acme'), '  in both directions');
}

# --- THE NEGATIVE ASSERTION -------------------------------------------------
#
# A code path that reads a tenant from a request cannot be added later by
# accident if it was never written. This is asserted against the source,
# because the absence of a function is not something a unit test can call.

{
    my @src = glob('include/punk_observe/*.h');
    push @src, glob('xs/*.xs'), 'Observe.xs';
    my $bad = 0;
    my @where;
    for my $f (@src) {
        open my $fh, '<', $f or next;
        my $s = do { local $/; <$fh> };
        close $fh;
        # Prose discusses this at length; only CODE is searched. (The lesson
        # phase 10 paid for by failing on its own documentation.)
        $s =~ s{/\*.*?\*/}{}gs;
        $s =~ s{^\s*#.*$}{}gm;
        # A tenant taken from a header, a query parameter or a path segment.
        for my $pat (qr/X-(?:Scope-)?Org ?Id/i,
                     qr/tenant[^;\n]*(?:HTTP_|PATH_INFO|QUERY_STRING|
                                        req(?:uest)?_head|psgi)/xi,
                     qr/(?:HTTP_|PATH_INFO|QUERY_STRING)[^;\n]*tenant/i) {
            if ($s =~ $pat) { $bad++; push @where, "$f: $&" }
        }
    }
    is($bad, 0, 'NO code path derives a tenant from anything a client sends')
        or diag join "\n", @where;
}

# And the resolver signature takes no request, which is what makes the above
# structural rather than a convention.
{
    open my $fh, '<', 'include/punk_observe/po_tenant.h' or die $!;
    my $s = do { local $/; <$fh> };
    close $fh;
    like($s, qr/typedef int \(\*po_tenant_fn\)\(void \*ud,/,
         'the resolver callback takes an opaque userdata and no request');
    # Code only: the prose above it discusses requests at length, which is
    # the point of the prose.
    (my $code = $s) =~ s{/\*.*?\*/}{}gs;
    unlike($code, qr/\brequest\b|\bHTTP_|\bPATH_INFO\b/i,
           '  and the code names no request, header or path at all');
}

done_testing();
