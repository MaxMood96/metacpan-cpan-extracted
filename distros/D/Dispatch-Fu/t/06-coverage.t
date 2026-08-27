use strict;
use warnings;
use Dispatch::Fu;
use Test::More;

# Exercise the SCALAR branch of xshift_and_deref.
my $scalar = q{scalar value};
is xshift_and_deref(\$scalar), $scalar,
  q{xshift_and_deref dereferences a SCALAR reference};

# Exercise the final fall-through branch for unsupported/non-reference input.
is xshift_and_deref(q{not a reference}), undef,
  q{xshift_and_deref returns undef for a non-reference};

# A false-but-defined key is a valid static dispatch key.
my $zero;
my $zero_result = dispatch { return q{0} } \$zero,
  on 0 => sub { return q{zero} };
is $zero_result, q{zero},
  q{false-but-defined dispatch key is supported};

# Exercise the non-CODE handler validation path.
my $error = q{};
my $bad_input;
{
    local $@;
    eval {
        dispatch { return q{bad} } \$bad_input,
          on bad => q{not a code reference};
    };
    $error = $@;
}
like $error, qr/Computed static bucket "bad" not found/i,
  q{non-CODE handlers are rejected};

# A failed dispatch must not leak registered handlers into the next call.
my $stale_input;
{
    local $@;
    eval {
        dispatch { return q{missing} } \$stale_input,
          on stale => sub { return q{stale} };
    };
}

$error = q{};
my $fresh_input;
{
    local $@;
    eval {
        dispatch { return q{stale} } \$fresh_input,
          on fresh => sub { return q{fresh} };
    };
    $error = $@;
}
like $error, qr/Computed static bucket "stale" not found/i,
  q{failed dispatch does not leak handlers into the next dispatch};

# Exercise the built-in default handler.  A real case is supplied so this is
# distinct from the no-cases diagnostic.
my ($warning, $stdout) = (q{}, q{});
{
    local $SIG{__WARN__} = sub { $warning .= shift };
    open my $capture, '>', \$stdout or die qq{Unable to capture STDOUT: $!};
    local *STDOUT = $capture;

    my $default_input;
    dispatch { return q{default} } \$default_input,
      on supported => sub { return q{unused} };
}
like $warning, qr/Supported cases are:/i,
  q{built-in default handler warns with supported-cases heading};
like $stdout, qr/^\s+default\s*$/m,
  q{built-in default handler lists the active default case};

# Verify the dispatch table is reset following a successful dispatch.
is_deeply [cases], [q{default}],
  q{dispatch table resets to its default state after dispatch};

done_testing;

