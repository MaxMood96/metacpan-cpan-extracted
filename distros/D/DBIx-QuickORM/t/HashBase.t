use strict;
use warnings;

use Test::More;

sub warnings(&) {
    my $code = shift;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    $code->();
    return \@warnings;
}

sub exception(&) {
    my $code = shift;
    local ($@, $!, $SIG{__DIE__});
    my $ok = eval { $code->(); 1 };
    my $error = $@ || 'SQUASHED ERROR';
    return $ok ? undef : $error;
}

BEGIN {
    $INC{'Object/HashBase/Test/HBase.pm'} = __FILE__;

    package
        main::HBase;
    use DBIx::QuickORM::Util::HashBase qw/foo bar baz/;

    main::is(FOO, 'foo', "FOO CONSTANT");
    main::is(BAR, 'bar', "BAR CONSTANT");
    main::is(BAZ, 'baz', "BAZ CONSTANT");
}

{
    BEGIN {
        $INC{'Object/HashBase/Test/HBaseINIT.pm'} = __FILE__;
        $INC{'Object/HashBase/Test/HBaseINIT2.pm'} = __FILE__;
        $INC{'main/HBaseINIT.pm'} = __FILE__;
    }

    package
        main::HBaseINIT;
    use DBIx::QuickORM::Util::HashBase qw/foo bar baz/;

    $main::counter = 0;
    add_pre_init { shift->{pre_init_1} = $main::counter++ };
    add_pre_init { shift->{pre_init_2} = $main::counter++ };
    sub init { shift->{init} = $main::counter++ };
    add_post_init { shift->{post_init_1} = $main::counter++ };
    add_post_init { shift->{post_init_2} = $main::counter++ };

    package
        main::HBaseINIT2;
    use parent 'main::HBaseINIT';
    use DBIx::QuickORM::Util::HashBase qw/boop/;

    add_pre_init { shift->{pre_init_3} = $main::counter++ };
    sub init { $_[0]->SUPER::init(); $_[0]->{init2} = $main::counter++ };
    add_post_init { shift->{post_init_3} = $main::counter++ };
}

BEGIN {
    package
        main::HBaseSub;
    use base 'main::HBase';
    use DBIx::QuickORM::Util::HashBase qw/apple pear/;

    main::is(FOO,   'foo',   "FOO CONSTANT");
    main::is(BAR,   'bar',   "BAR CONSTANT");
    main::is(BAZ,   'baz',   "BAZ CONSTANT");
    main::is(APPLE, 'apple', "APPLE CONSTANT");
    main::is(PEAR,  'pear',  "PEAR CONSTANT");
}

my $one = main::HBase->new(foo => 'a', bar => 'b', baz => 'c');
is($one->foo, 'a', "Accessor");
is($one->bar, 'b', "Accessor");
is($one->baz, 'c', "Accessor");
$one->set_foo('x');
is($one->foo, 'x', "Accessor set");
$one->set_foo(undef);

is_deeply(
    $one,
    {
        foo => undef,
        bar => 'b',
        baz => 'c',
    },
    'hash'
);

{
    my @warns;
    local $SIG{__WARN__} = sub { push @warns => @_ };
    main::HBaseINIT->add_post_init(sub { shift->{late_post} = 'yes' });
    ok(!@warns, "No Warnings adding a post-init") or diag(@_);
}

$main::counter = 0;
my $two = main::HBaseINIT->new();
is_deeply(
    $two,
    {
        pre_init_1  => 0,
        pre_init_2  => 1,
        init        => 2,
        post_init_2 => 3,
        post_init_1 => 4,
        late_post   => 'yes',
    },
    "inits ran in the correct order"
);

$main::counter = 0;
my $three = main::HBaseINIT2->new();
is_deeply(
    $three,
    {
        pre_init_1  => 0,
        pre_init_2  => 1,
        pre_init_3  => 2,
        init        => 3,
        init2       => 4,
        post_init_3 => 5,
        post_init_2 => 6,
        post_init_1 => 7,
        late_post   => 'yes',
    },
    "inits ran in the correct order"
);


BEGIN {
    package
        main::Const::Test;
    use DBIx::QuickORM::Util::HashBase qw/foo/;

    sub do_it {
        if (FOO()) {
            return 'const';
        }
        return 'not const'
    }
}

my $pkg = 'main::Const::Test';
is($pkg->do_it, 'const', "worked as expected");
{
    local $SIG{__WARN__} = sub { };
    *main::Const::Test::FOO = sub { 0 };
}
ok(!$pkg->FOO, "overrode const sub");
{
local $TODO = "known to fail on $]" if $] le "5.006002";
is($pkg->do_it, 'const', "worked as expected, const was constant");
}

BEGIN {
    $INC{'Object/HashBase/Test/HBase/Wrapped.pm'} = __FILE__;

    package
        main::HBase::Wrapped;
    use DBIx::QuickORM::Util::HashBase qw/foo bar dup/;

    my $foo = __PACKAGE__->can('foo');
    no warnings 'redefine';
    *foo = sub {
        my $self = shift;
        $self->set_bar(1);
        $self->$foo(@_);
    };
}

BEGIN {
    $INC{'Object/HashBase/Test/HBase/Wrapped/Inherit.pm'} = __FILE__;

    package
        main::HBase::Wrapped::Inherit;
    use base 'main::HBase::Wrapped';
    use DBIx::QuickORM::Util::HashBase qw/baz dup/;
}

my $o = main::HBase::Wrapped::Inherit->new(foo => 1);
my $foo = $o->foo;
is($o->bar, 1, 'parent attribute sub not overridden');

{
    package
        Foo;

    sub new;

    use DBIx::QuickORM::Util::HashBase qw/foo bar baz/;

    sub new { 'foo' };
}

is(Foo->new, 'foo', "Did not override existing 'new' method");

BEGIN {
    $INC{'Object/HashBase/Test/HBase2.pm'} = __FILE__;

    package
        main::HBase2;
    use DBIx::QuickORM::Util::HashBase qw/foo -bar ^baz <bat >ban +boo/;

    main::is(FOO, 'foo', "FOO CONSTANT");
    main::is(BAR, 'bar', "BAR CONSTANT");
    main::is(BAZ, 'baz', "BAZ CONSTANT");
    main::is(BAT, 'bat', "BAT CONSTANT");
    main::is(BAN, 'ban', "BAN CONSTANT");
    main::is(BOO, 'boo', "BOO CONSTANT");
}

my $ro = main::HBase2->new(foo => 'foo', bar => 'bar', baz => 'baz', bat => 'bat', ban => 'ban');
is($ro->foo, 'foo', "got foo");
is($ro->bar, 'bar', "got bar");
is($ro->baz, 'baz', "got baz");
is($ro->bat, 'bat', "got bat");
ok(!$ro->can('set_bat'), "No setter for bat");
ok(!$ro->can('ban'), "No reader for ban");
ok(!$ro->can('boo'), "No reader for boo");
ok(!$ro->can('set_boo'), "No setter for boo");
is($ro->{ban}, 'ban', "ban attribute is set");
$ro->set_ban('xxx');
is($ro->{ban}, 'xxx', "ban attribute can be set");

is($ro->set_foo('xxx'), 'xxx', "Can set foo");
is($ro->foo, 'xxx', "got foo");

like(exception { $ro->set_bar('xxx') }, qr/'bar' is read-only/, "Cannot set bar");

my $warnings = warnings { is($ro->set_baz('xxx'), 'xxx', 'set baz') };
like($warnings->[0], qr/set_baz\(\) is deprecated/, "Deprecation warning");



is_deeply(
    [DBIx::QuickORM::Util::HashBase::attr_list('main::HBase::Wrapped::Inherit')],
    [qw/foo bar dup baz/],
    "Got a list of attributes in order starting from base class, duplicates removed",
);

my $x = main::HBase::Wrapped::Inherit->new(foo => 1, baz => 2);
is($x->foo, 1, "set foo via pairs");
is($x->baz, 2, "set baz via pairs");

# Now with hashref
my $y = main::HBase::Wrapped::Inherit->new({foo => 1, baz => 2});
is($y->foo, 1, "set foo via hashref");
is($y->baz, 2, "set baz via hashref");

# Now with hashref
my $z = main::HBase::Wrapped::Inherit->new([
    1, # foo
    2, # bar
    3, # dup
    4, # baz
]);
is($z->foo, 1, "set foo via arrayref");
is($z->baz, 4, "set baz via arrayref");

like(
    exception { main::HBase::Wrapped::Inherit->new([1 .. 10]) },
    qr/Too many arguments for main::HBase::Wrapped::Inherit constructor/,
    "Too many args in array form"
);


my $CAN_COUNT = 0;
my $CAN_COUNT2 = 0;
my $INIT_COUNT = 0;
BEGIN {
    $INC{'Object/HashBase/Test/HBase3.pm'} = __FILE__;
    package
        main::HBase3;
    use DBIx::QuickORM::Util::HashBase qw/foo/;

    sub can {
        my $self = shift;
        $CAN_COUNT++;
        $self->SUPER::can(@_);
    }

    $INC{'Object/HashBase/Test/HBase4.pm'} = __FILE__;
    package
        main::HBase4;
    use DBIx::QuickORM::Util::HashBase qw/foo/;

    sub can {
        my $self = shift;
        $CAN_COUNT2++;
        $self->SUPER::can(@_);
    }

    sub init { $INIT_COUNT++ }
}

is($CAN_COUNT, 0, "->can has not been called yet");
my $it = main::HBase3->new;
is($CAN_COUNT, 1, "->can has been called once to check for init");
$it = main::HBase3->new;
is($CAN_COUNT, 1, "->can was not called again, we cached it");

is($CAN_COUNT2, 0, "->can has not been called yet");
is($INIT_COUNT, 0, "->init has not been called yet");
$it = main::HBase4->new;
is($CAN_COUNT2, 1, "->can has been called once to check for init");
is($INIT_COUNT, 1, "->init has been called once");
$it = main::HBase4->new;
is($CAN_COUNT2, 1, "->can was not called again, we cached it");
is($INIT_COUNT, 2, "->init has been called again");

done_testing;

1;
