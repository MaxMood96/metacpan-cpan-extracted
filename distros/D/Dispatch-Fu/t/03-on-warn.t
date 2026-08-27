use strict;
use warnings;
use Dispatch::Fu;
use Test::More tests => 4;

my $error = q{};
{
    local $@;
    eval { dispatch { return q{foo} } 1 };
    $error = $@;
}
like $error, qr/no cases defined/i,
  q{croaks with the expected diagnostic if no cases are defined};

$error = q{};
{
    local $@;
    eval { dispatch { return q{foo} } 1, on bar => sub { 1 } };
    $error = $@;
}
like $error, qr/Computed static bucket "foo" not found/i,
  q{croaks if dispatch returns an unregistered case};

my $warning = q{};
{
    local $SIG{__WARN__} = sub { $warning .= shift };
    on foo => sub { 1 };
}
like $warning, qr/follows a comma/i,
  q{'on' warns when used in void context};

$warning = q{};
{
    local $SIG{__WARN__} = sub { $warning .= shift };
    my $ignored = on foo => sub { 1 };
}
like $warning, qr/follows a comma/i,
  q{'on' warns when used in scalar context};

