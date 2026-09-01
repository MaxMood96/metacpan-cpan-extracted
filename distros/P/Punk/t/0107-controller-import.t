#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use Punk::Controller;

# `use Punk::Controller` is the one-line controller preamble: base class plus
# strict and warnings, the way `use Punk::Model` works for a model. The older
# `use parent 'Punk::Controller'` must keep behaving exactly as it did.

# ---- the one-line form ---------------------------------------------------
{
    package T::Ctl::New;
    use Punk::Controller;
    sub trigger { my $u; my $x = $u + 1; return $x }   # warns if warnings on
    our $STRICT = eval q{ $never_declared = 1; 1 } ? 0 : 1;
}
ok(T::Ctl::New->isa('Punk::Controller'), 'use Punk::Controller sets the base class');
is($T::Ctl::New::STRICT, 1, 'and turns on strict in the caller');
{
    my @w;
    local $SIG{__WARN__} = sub { push @w, shift };
    T::Ctl::New::trigger();
    ok(scalar @w, 'and turns on warnings in the caller');
}

# ---- the older form is untouched -----------------------------------------
{
    package T::Ctl::Parent;
    use parent -norequire, 'Punk::Controller';
    sub list { 'ok' }
}
ok(T::Ctl::Parent->isa('Punk::Controller'), 'use parent still sets the base class');
is(T::Ctl::Parent::list(), 'ok', 'and the controller still works');

# ---- idempotent, and main is left alone ----------------------------------
{
    package T::Ctl::Twice;
    use Punk::Controller;
    use Punk::Controller;
}
is(scalar(grep { $_ eq 'Punk::Controller' } @T::Ctl::Twice::ISA), 1,
   'a second use does not push the base class twice');
{
    package T::Ctl::Already;
    use parent -norequire, 'Punk::Controller';
    use Punk::Controller;
}
is(scalar(grep { $_ eq 'Punk::Controller' } @T::Ctl::Already::ISA), 1,
   'nor does it duplicate one use parent already set');
ok(!main->isa('Punk::Controller'), 'main is never made a controller');

done_testing;
