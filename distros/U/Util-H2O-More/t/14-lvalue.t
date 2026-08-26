use strict;
use warnings;

use Test::More q//;
use attributes ();
use File::Temp qw/tempfile/;

use Util::H2O::More qw/
  baptise
  d2o
  Getopt2h2o
  h2o
  ini2h2o
  ini2o
  o2h2o
  opt2h2o
  HTTPTiny2h2o
  yaml2h2o
  yaml2o
  /;

sub _dies_like {
    my ( $code, $regex, $name ) = @_;
    local $@;
    my $ok = eval {
        $code->();
        1;
    };
    ok !$ok, $name;
    like $@, $regex, qq{$name - exception};
    return;
}

sub _consume {
    return $_[0];
}

# -------------------------------------------------------------------------
# Default behavior remains non-lvalue.
# -------------------------------------------------------------------------

my $plain = h2o { foo => 1 };
is $plain->foo(2), 2, q{normal setter syntax still works without -lvalue};
ok !grep { $_ eq q{lvalue} } attributes::get( $plain->can(q{foo}) ),
  q{default accessor does not have the lvalue attribute};
_dies_like(
    sub { $plain->foo = 3 },
    qr/non-lvalue subroutine call/,
    q{assignment syntax remains invalid without -lvalue},
);

my $readonly = h2o -ro, { foo => 1 };
is $readonly->foo, 1, q{normal upstream -ro object still reads normally};
_dies_like(
    sub { $readonly->foo(2) },
    qr/read-only/,
    q{normal upstream -ro setter still dies},
);

# -------------------------------------------------------------------------
# Basic lvalue behavior and preservation of setter syntax.
# -------------------------------------------------------------------------

my $o = h2o -lvalue, {
    foo    => 1,
    text   => q{a},
    undefv => undef,
  },
  qw/missing/;

ok grep { $_ eq q{lvalue} } attributes::get( $o->can(q{foo}) ),
  q{generated accessor has lvalue attribute};

$o->foo = 42;
is $o->foo, 42, q{direct assignment works};

$o->foo++;
is $o->foo, 43, q{post-increment works};

++$o->foo;
is $o->foo, 44, q{pre-increment works};

$o->text .= q{bc};
is $o->text, q{abc}, q{concatenation assignment works};

is $o->foo(100),        100, q{normal setter syntax remains supported};
is $o->foo( 101, 999 ), 101, q{setter continues to use the first supplied value};

is $o->undefv(undef), undef, q{normal setter can still store undef};
$o->undefv = 9;
is $o->undefv, 9, q{an existing undef-valued slot is assignable as an lvalue};
$o->undefv = undef;
is $o->undefv, undef, q{lvalue syntax can assign undef};

my $copy = $o->foo;
$copy = 500;
is $o->foo, 101, q{ordinary scalar assignment receives a copy, not a persistent alias};

my $alias = \$o->foo;
$$alias = 102;
is $o->foo, 102, q{taking a scalar reference retains a real alias to the hash slot};

# -------------------------------------------------------------------------
# Missing additional keys and Perl alias materialization.
# -------------------------------------------------------------------------

ok !exists $o->{missing}, q{declared additional key initially remains absent};
my $missing_value = $o->missing;
is $missing_value, undef, q{missing additional accessor reads undef};
ok !exists $o->{missing}, q{plain scalar read does not create the missing key};

$o->missing = q{created};
is $o->{missing}, q{created}, q{lvalue assignment creates an allowed missing key};

my $by_ref = h2o -lvalue, {}, qw/future/;
ok !exists $by_ref->{future}, q{future key starts absent before reference is taken};
my $future_ref = \$by_ref->future;
ok exists $by_ref->{future}, q{taking a reference to a missing lvalue materializes its hash slot};
$$future_ref = 7;
is $by_ref->future, 7, q{materialized lvalue reference remains writable};

my $by_arg = h2o -lvalue, {}, qw/future/;
ok !exists $by_arg->{future}, q{future key starts absent before direct argument passing};
is _consume( $by_arg->future ), undef, q{missing lvalue may be passed directly as an argument};
ok exists $by_arg->{future}, q{direct argument passing may materialize the lvalue slot};

# -------------------------------------------------------------------------
# Upstream h2o options and recursion.
# -------------------------------------------------------------------------

my $nested = h2o -lvalue, -recurse, {
    child => { n => 1 },
    array => [ { n => 2 } ],
};
$nested->child->n += 4;
is $nested->child->n, 5, q{-recurse gives nested HASH accessors lvalue behavior};
_dies_like(
    sub { $nested->array->[0]->n = 9 },
    qr/(?:unblessed reference|non-lvalue|method .* HASH)/i,
    q{-recurse still does not objectify HASH refs inside ARRAY refs},
);

my $array_recurse = h2o -lvalue, -arrays, {
    rows => [ { n => 2 } ],
};
$array_recurse->rows->[0]->n = 9;
is $array_recurse->rows->[0]->n, 9, q{-arrays propagates lvalue accessors through nested arrays};

my $array_root = h2o -lvalue, -arrays, [ { n => 1 }, [ { n => 2 } ] ];
$array_root->[0]->n++;
$array_root->[1]->[0]->n++;
is $array_root->[0]->n,      2, q{-arrays works when the top-level argument itself is an ARRAY ref};
is $array_root->[1]->[0]->n, 3, q{-arrays handles nested ARRAY refs from an ARRAY root};

my $nolock = h2o -lvalue, -nolock, {}, qw/future/;
$nolock->future = q{ok};
is $nolock->future, q{ok}, q{-nolock remains compatible with -lvalue};

my $lock0 = h2o -lvalue, -lock => 0, { foo => 1 };
$lock0->foo++;
is $lock0->foo, 2, q{-lock => 0 remains compatible with -lvalue};

my $classed = h2o -lvalue, -class => q{LvaluePlainClass}, -clean => 0, { foo => 1 };
$classed->foo++;
is $classed->foo, 2, q{-class and -clean remain compatible with -lvalue};

{

    package LvalueIsaParent;
    sub inherited { return q{yes}; }
}
my $isa = h2o -lvalue, -isa => q{LvalueIsaParent}, { foo => 1 };
$isa->foo++;
is $isa->foo,       2,      q{-isa object accessor remains lvalue};
is $isa->inherited, q{yes}, q{-isa inheritance remains intact};

my $destroyed = 0;
{
    my $destroy = h2o -lvalue, -destroy => sub { ++$destroyed }, { foo => 1 };
    $destroy->foo++;
    is $destroy->foo, 2, q{-destroy object accessor remains lvalue};
}
is $destroyed, 1, q{-destroy callback still runs};

my $new_proto = h2o -lvalue, -new, -class => q{LvalueNewClass}, -clean => 0,
  { foo => 1 }, qw/bar/;
my $new_obj = LvalueNewClass->new( foo => 5, bar => 6 );
$new_obj->foo++;
$new_obj->bar .= q{x};
is $new_obj->foo, 6,     q{-new constructor object receives lvalue accessor methods};
is $new_obj->bar, q{6x}, q{-new additional accessor remains lvalue};

my $pass_undef = h2o -lvalue, -pass => q{undef}, undef;
is $pass_undef, undef, q{-pass => undef remains a pass-through under -lvalue};

my $pass_ref = h2o -lvalue, -pass => q{ref}, [];
is ref $pass_ref, q{ARRAY}, q{-pass => ref still passes an unrelated reference through};

_dies_like(
    sub { h2o -lvalue, -ro, { foo => 1 } },
    qr/-lvalue cannot be combined with -ro/,
    q{-ro and -lvalue are rejected explicitly},
);

_dies_like(
    sub { h2o -recurse, -lvalue, { foo => 1 } },
    qr/unknown option to h2o: '-lvalue'/,
    q{-lvalue must precede upstream h2o options},
);

_dies_like(
    sub { h2o -lvalue, '-does-not-exist', { foo => 1 } },
    qr/unknown option to h2o: '-does-not-exist'/,
    q{unknown upstream option is still rejected by Util::H2O},
);

# Exercise parsing of the HASH shorthand for -classify without creating a
# class in Util::H2O::More's own namespace.  The named-class behavior is tested
# below through the public h2o interface.
my ( $parsed_hash, undef, undef, $parsed_meth ) =
  Util::H2O::More::_h2o_lvalue_info( -classify => { foo => 1 } );
is ref $parsed_hash, q{HASH}, q{lvalue option parser recognizes HASH-form -classify target};
ok $parsed_meth, q{HASH-form -classify is recognized as -meth semantics};

SKIP: {
    skip q{Util::H2O -parent was added after 0.24}, 2
      if $Util::H2O::VERSION < 0.26;

    {

        package LvalueNamedParent;
        sub inherited_parent { return q{yes}; }
    }

    my $parented = h2o -lvalue, -parent, -class => q{LvalueNamedParent}, { foo => 1 };
    $parented->foo++;
    is $parented->foo,              2,      q{-parent object accessor is lvalue when upstream supports -parent};
    is $parented->inherited_parent, q{yes}, q{-parent inheritance remains intact};
}

# -------------------------------------------------------------------------
# -meth, AUTOLOAD, and -classify.
# -------------------------------------------------------------------------

my $meth = h2o -lvalue, -meth, {
    foo    => 2,
    double => sub { return $_[0]->foo * 2 },
};
$meth->foo = 4;
is $meth->double, 8, q{custom -meth method remains callable};
ok !grep { $_ eq q{lvalue} } attributes::get( $meth->can(q{double}) ),
  q{custom -meth method is not decorated as lvalue};
_dies_like(
    sub { $meth->double = 9 },
    qr/non-lvalue subroutine call/,
    q{custom -meth method cannot be assigned through lvalue syntax},
);

my $meth_additional = h2o -lvalue, -meth,
  { foo => sub { return q{method}; } }, qw/foo bar/;
is $meth_additional->foo, q{method}, q{CODE method wins over same-named additional key as upstream};
_dies_like(
    sub { $meth_additional->foo = q{data} },
    qr/non-lvalue subroutine call/,
    q{same-named additional key does not overwrite a custom method with an lvalue accessor},
);
$meth_additional->bar = q{data};
is $meth_additional->bar, q{data}, q{ordinary additional key remains lvalue under -meth};

my $autoload = h2o -lvalue, {
    AUTOLOAD => q{fallback},
    foo      => 1,
};
is $autoload->whatever, q{fallback}, q{ordinary H2O AUTOLOAD catch-all behavior is preserved};
ok !grep { $_ eq q{lvalue} } attributes::get( $autoload->can(q{AUTOLOAD}) ),
  q{AUTOLOAD itself is deliberately not converted to lvalue};
_dies_like(
    sub { $autoload->whatever = q{x} },
    qr/non-lvalue subroutine call/,
    q{AUTOLOAD catch-all remains non-lvalue},
);

my $classified = h2o -lvalue, -classify => q{LvalueClassified}, {
    foo   => 1,
    twice => sub { return $_[0]->foo * 2 },
  },
  qw/bar/;
$classified->foo = 3;
is $classified->twice, 6, q{classified prototype keeps its custom method};
my $classified_new = LvalueClassified->new( foo => 5, bar => 6 );
$classified_new->foo++;
$classified_new->bar .= q{x};
is $classified_new->foo, 6,     q{classified constructor object uses lvalue generated accessor};
is $classified_new->bar, q{6x}, q{classified additional key is lvalue};
_dies_like(
    sub { $classified_new->twice = 3 },
    qr/non-lvalue subroutine call/,
    q{classified custom method remains non-lvalue},
);

# -------------------------------------------------------------------------
# baptise and inheritance.
# -------------------------------------------------------------------------

{

    package LvalueBaptiseParent;
    sub inherited { return q{parent}; }
}

my $baptised = baptise -lvalue, -recurse,
  { foo => 1, child => { n => 2 } },
  q{LvalueBaptiseParent}, qw/extra/;
$baptised->foo++;
$baptised->child->n = 8;
$baptised->extra = q{ok};
is $baptised->foo,       2,         q{baptised top-level accessor is lvalue};
is $baptised->child->n,  8,         q{baptise -recurse propagates lvalue to nested HASH accessors};
is $baptised->extra,     q{ok},     q{baptise default accessor is lvalue};
is $baptised->inherited, q{parent}, q{baptise inheritance remains intact};

my $baptised_reverse = baptise -recurse, -lvalue,
  { foo => 1 }, q{LvalueBaptiseParent};
$baptised_reverse->foo++;
is $baptised_reverse->foo, 2, q{baptise accepts its More-specific flags in either leading order};

# -------------------------------------------------------------------------
# d2o, -autoundef, and ARRAY virtual methods.
# -------------------------------------------------------------------------

my $deep = {
    rows  => [ { n => 1 }, { n => 2 } ],
    child => { text => q{x} },
};
d2o -lvalue, $deep;

$deep->rows->i(0)->n++;
is $deep->rows->get(0)->n, 2, q{d2o HASH accessor inside ARRAY is lvalue};
$deep->child->text .= q{y};
is $deep->child->text, q{xy}, q{d2o nested HASH accessor is lvalue};

my $before_count = $deep->rows->count;
is $deep->rows->get(99), undef,         q{ARRAY get still returns undef out of range};
is $deep->rows->count,   $before_count, q{out-of-range get still does not grow ARRAY};

_dies_like(
    sub { $deep->rows->i(0) = { n => 7 } },
    qr/non-lvalue subroutine call/,
    q{ARRAY i/get virtual method is not made lvalue},
);

_dies_like(
    sub { $deep->rows->count = 7 },
    qr/non-lvalue subroutine call/,
    q{ARRAY count/scalar virtual method is not made lvalue},
);

$deep->rows->push( { n => 8 } );
$deep->rows->get(2)->n = 9;
is $deep->rows->get(2)->n, 9, q{push retains lvalue mode for newly objectified HASH items};

$deep->rows->unshift( { n => 3 } );
$deep->rows->get(0)->n++;
is $deep->rows->get(0)->n, 4, q{unshift retains lvalue mode for newly objectified HASH items};

my $popped = $deep->rows->pop;
$popped->n++;
is $popped->n, 10, q{popped object keeps its lvalue accessor methods};

my $shifted = $deep->rows->shift;
$shifted->n++;
is $shifted->n, 5, q{shifted object keeps its lvalue accessor methods};

my $plain_array = [ { n => 1 } ];
d2o $plain_array;
$plain_array->push( { n => 2 } );
_dies_like(
    sub { $plain_array->get(1)->n = 3 },
    qr/non-lvalue subroutine call/,
    q{ordinary d2o push remains non-lvalue without -lvalue},
);

my $auto = {
    present => 1,
    child   => { present => 2 },
};
d2o -autoundef, -lvalue, $auto;
$auto->present++;
$auto->child->present = 7;
is $auto->present,        2,     q{existing -autoundef top-level key is lvalue};
is $auto->child->present, 7,     q{existing -autoundef nested key is lvalue};
is $auto->missing,        undef, q{-autoundef unknown getter still returns undef};
ok !exists $auto->{missing}, q{-autoundef unknown getter does not create a key};
_dies_like(
    sub { $auto->missing(q{value}) },
    qr/Won't set value for non-existing key/,
    q{-autoundef unknown setter call still dies},
);
_dies_like(
    sub { $auto->other = q{value} },
    qr/non-lvalue subroutine call/,
    q{-autoundef unknown assignment fails because AUTOLOAD is non-lvalue},
);
ok !exists $auto->{other}, q{failed unknown lvalue assignment does not create a key};

my $auto_rows = [ { present => 1 } ];
d2o -autoundef, -lvalue, $auto_rows;
$auto_rows->push( { present => 2 } );
$auto_rows->get(1)->present++;
is $auto_rows->get(1)->present, 3, q{push preserves new lvalue mode under d2o -autoundef -lvalue};
_dies_like(
    sub { $auto_rows->get(1)->missing },
    qr/Can't locate object method/,
    q{push does not change historical -autoundef propagation behavior},
);

# A later reference assignment is intentionally not automatically objectified.
my $replacement = h2o -lvalue, { child => { n => 1 } };
$replacement->child = { n => 2 };
is ref $replacement->child, q{HASH}, q{lvalue assignment of a new HASH ref stores the plain reference as-is};
_dies_like(
    sub { $replacement->child->n },
    qr/Can't call method .* unblessed reference/i,
    q{newly assigned HASH ref is not implicitly objectified},
);

# -------------------------------------------------------------------------
# opt2h2o / Getopt2h2o.
# -------------------------------------------------------------------------

my @spec       = qw/name=s count=i/;
my $opt_manual = h2o -lvalue, {}, opt2h2o(@spec);
$opt_manual->name  = q{Perl};
$opt_manual->count = 3;
is $opt_manual->name,  q{Perl}, q{opt2h2o composes with h2o -lvalue};
is $opt_manual->count, 3,       q{all opt2h2o-generated additional accessors may be lvalues};

my @argv   = qw/--name Alice --count 3/;
my $getopt = Getopt2h2o -lvalue, \@argv, {}, qw/name=s count=i optional=s/;
is $getopt->name,  q{Alice}, q{Getopt2h2o still parses string option under -lvalue};
is $getopt->count, 3,        q{Getopt2h2o still parses integer option under -lvalue};
$getopt->count++;
$getopt->optional = q{later};
is $getopt->count,    4,        q{parsed Getopt option accessor is lvalue};
is $getopt->optional, q{later}, q{declared but absent Getopt option accessor is lvalue};

@argv = ();
my $getopt_auto = Getopt2h2o -lvalue, -autoundef, \@argv, {}, qw/name=s/;
is $getopt_auto->unknown, undef, q{Getopt2h2o -autoundef unknown getter remains undef};
_dies_like(
    sub { $getopt_auto->unknown(q{x}) },
    qr/Won't set value for non-existing key/,
    q{Getopt2h2o -autoundef unknown setter call still dies},
);
$getopt_auto->name = q{Bob};
is $getopt_auto->name, q{Bob}, q{declared Getopt option remains lvalue with -autoundef};

# -------------------------------------------------------------------------
# o2h2o / INI / YAML / HTTP convenience helpers.
# -------------------------------------------------------------------------

my $config_like = bless { section => { x => 1 } }, q{LvalueConfigLike};
my $objectified = o2h2o -lvalue, $config_like;
$objectified->section->x++;
is $objectified->section->x, 2, q{o2h2o -lvalue propagates to recursive HASH accessors};

my $config_like_plain = bless { section => { x => 1 } }, q{LvalueConfigLikePlain};
my $objectified_plain = o2h2o $config_like_plain;
_dies_like(
    sub { $objectified_plain->section->x = 2 },
    qr/non-lvalue subroutine call/,
    q{o2h2o default remains non-lvalue},
);

_dies_like(
    sub { &Util::H2O::More::o2h2o( q{-lvalue}, $config_like, q{extra} ) },
    qr/o2h2o: expected one argument/,
    q{o2h2o still enforces one data argument when called without prototype checking},
);

my ( $ini_fh, $ini_file ) = tempfile();
print {$ini_fh} <<'INI';
[database]
host=localhost
port=123
INI
close $ini_fh;

my $ini = ini2h2o -lvalue, $ini_file;
$ini->database->port++;
is $ini->database->port, 124, q{ini2h2o -lvalue makes nested configuration accessor lvalue};

my $ini_alias = ini2o -lvalue, $ini_file;
$ini_alias->database->host .= q{.local};
is $ini_alias->database->host, q{localhost.local}, q{ini2o backward-compatible alias supports -lvalue};

my $yaml = <<'YAML';
---
foo: 1
nested:
  bar: 2
YAML

my ($yaml_object) = yaml2h2o -lvalue, $yaml;
$yaml_object->foo++;
$yaml_object->nested->bar++;
is $yaml_object->foo,         2, q{yaml2h2o -lvalue top-level accessor is lvalue};
is $yaml_object->nested->bar, 3, q{yaml2h2o -lvalue nested accessor is lvalue};

my ($yaml_alias) = yaml2o -lvalue, $yaml;
$yaml_alias->foo = 9;
is $yaml_alias->foo, 9, q{yaml2o backward-compatible alias supports -lvalue};

my $response = HTTPTiny2h2o -lvalue, {
    success => 1,
    content => q{{"foo":1,"nested":{"bar":2}}},
};
$response->success = 0;
$response->content->foo++;
$response->content->nested->bar = 5;
is $response->success,              0,     q{HTTPTiny2h2o response accessor is lvalue};
is $response->content->foo,         2,     q{decoded HTTP JSON top-level accessor is lvalue};
is $response->content->nested->bar, 5,     q{decoded HTTP JSON nested accessor is lvalue};
is $response->content->unknown,     undef, q{decoded HTTP JSON retains -autoundef behavior};

my $bad_response = HTTPTiny2h2o -lvalue, { content => q{{not-json} } };
$bad_response->content .= q{!};
is $bad_response->content, q{{not-json} !}, q{suppressed JSON failure leaves original content as an lvalue scalar};

_dies_like(
    sub { HTTPTiny2h2o -lvalue, -autothrow, { content => q{{not-json} } } },
    qr/./,
    q{HTTPTiny2h2o -autothrow still propagates decode errors with -lvalue},
);

my $empty_response = HTTPTiny2h2o -lvalue, { content => q{} };
is $empty_response->content->missing, undef,
  q{empty HTTP content still becomes an -autoundef object under -lvalue};

# -------------------------------------------------------------------------
# The new feature remains opt-in all the way through the test.
# -------------------------------------------------------------------------

my $final_plain = h2o { value => 1 };
is $final_plain->value(2), 2, q{ordinary setter still works after lvalue objects have been created};
_dies_like(
    sub { $final_plain->value = 3 },
    qr/non-lvalue subroutine call/,
    q{lvalue decoration does not leak into unrelated H2O packages},
);

done_testing;

