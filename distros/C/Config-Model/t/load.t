# -*- cperl -*-

use ExtUtils::testlib;
use Test::More;
use Test::Exception;
use Test::Differences;
use Test::Memory::Cycle;
use Test::Synopsis::Expectation;
use Config::Model;
use Config::Model::Tester::Setup qw/init_test/;
use Test::Log::Log4perl;

use strict;
use warnings;
use lib "t/lib";
use utf8;


Test::Log::Log4perl->ignore_priority("info");

synopsis_ok('lib/Config/Model/Loader.pm');

my ($model, $trace) = init_test();

# See caveats in Test::More doc
my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(UTF-8)";
binmode $builder->failure_output, ":encoding(UTF-8)";
binmode $builder->todo_output,    ":encoding(UTF-8)";
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

ok( 1, "compiled" );

subtest "split command" => sub {
    my @tests = (
        [ qq!#"root comment " std_id:ab X=Bv -\na_string="titi and\nfoo"!, '#"root comment "', 'std_id:ab', 'X=Bv', '-', qq!a_string="titi and\nfoo"!],
        [ q!std_id:~"/a\".*/"!, ],
        [ q!std_id:~"a\".*"!, ],
        [ q!a:~/b.*/.="\"a"! ],
        [ q!a:~"b.*".="\"a"! ],
        [ q!m:=a,"a b "! ],
        [ q!a:=~"s/.*\".*/c/g"! ],
        [ qq!#'root comment ' std_id:ab X=Bv -\na_string='titi and\nfoo'!, q!#'root comment '!, 'std_id:ab', 'X=Bv', '-', qq!a_string='titi and\nfoo'!],
        [ q!std_id:~'/a\'.*/'!, ],
        [ q!std_id:~'a\'.*'!, ],
        [ q!a:~/b.*/.='\'a'! ],
        [ q!a:~'b.*'.='\'a'! ],
        [ q!m:=a,'a b '! ],
        [ q!a:=~'s/.*\'.*/c/g'! ],
    );

    foreach my $subtest (@tests) {
        my ( $str, @command ) = @$subtest;
        push @command, $str unless @command;
        my @res = Config::Model::Loader::_split_string($str);
        my $label = length $str > 20 ? substr($str,0,20).'...' : $str;

        eq_or_diff( \@res, \@command, "test _split_string with '$label'" );
    }

};

subtest "mega regexp" => sub {

    my $big_list = '"dh-autoreconf","pkg-config","debhelper-compat (= 12)","dh-autotools (> 3)"';

    # test mega regexp, 'x' means undef
    my @regexp_test = (

        #                              id_operation                        leaf_operation
        # string                 elt   op   (param)          id             op    (param)    val        note
        [ 'a',                 [ 'a',  'x',  'x',           'x',            'x',  'x',      'x',        'x' ] ],
        [ '#C',                [ 'x',  'x',  'x',           'x',            'x',  'x',      'x',        'C' ] ],
        [ '#"m C"',            [ 'x',  'x',  'x',           'x',            'x',  'x',      'x',        '"m C"' ] ],
        [ q!#'m C'!,           [ 'x',  'x',  'x',           'x',            'x',  'x',      'x',        "'m C'" ] ],
        [ 'a=b',               [ 'a',  'x',  'x',           'x',            '=',  'x',      'b',        'x' ] ],
        [ 'a=a~',              [ 'a',  'x',  'x',           'x',            '=',  'x',      'a~',       'x' ] ],
        [ 'a="~"',             [ 'a',  'x',  'x',           'x',            '=',  'x',      '"~"',      'x' ] ],
        [ "a='~'",             [ 'a',  'x',  'x',           'x',            '=',  'x',      "'~'",      'x' ] ],
        [ 'a=.foo(bar)',       [ 'a',  'x',  'x',           'x',          '=.foo','bar',   'x',        'x' ] ],
        [ 'a=.foo("b r")',     [ 'a',  'x',  'x',           'x',          '=.foo','"b r"', 'x',        'x' ] ],
        [ "a=.foo('b r')",     [ 'a',  'x',  'x',           'x',          '=.foo',"'b r'", 'x',        'x' ] ],
        [ 'a=.json(dir/foo.json/b/a)',
          [ 'a',  'x',  'x',           'x',          '=.json','dir/foo.json/b/a', 'x',        'x' ] ], # path + vector
        [ 'a-z=b',             [ 'a-z','x',  'x',           'x',            '=',  'x',      'b',        'x' ] ],
        [ "a=\x{263A}",        [ 'a',  'x',  'x',           'x',            '=',  'x',      "\x{263A}", 'x' ] ], # utf8 smiley
        [ 'a.=b',              [ 'a',  'x',  'x',           'x',            '.=', 'x',      'b',        'x' ] ],
        [ "a.=\x{263A}",       [ 'a',  'x',  'x',           'x',            '.=', 'x',      "\x{263A}", 'x' ] ], # utf8 smiley
        [ 'a="b=c"',           [ 'a',  'x',  'x',           'x',            '=',  'x',      '"b=c"',    'x' ] ],
        [ "a='b=c'",           [ 'a',  'x',  'x',           'x',            '=',  'x',      "'b=c'",    'x' ] ],
        [ 'a="b=\"c\""',       [ 'a',  'x',  'x',           'x',            '=',  'x',      '"b=\"c\""','x' ] ],
        [ 'a=~s/a/A/',         [ 'a',  'x',  'x',           'x',            '=~', 'x',      's/a/A/',   'x' ] ], # subst on value
        [ 'a=b#B',             [ 'a',  'x',  'x',           'x',            '=',  'x',      'b',        'B' ] ],
        [ 'a#B',               [ 'a',  'x',  'x',           'x',            'x',  'x',      'x',        'B' ] ],
        [ 'a#"b=c"',           [ 'a',  'x',  'x',           'x',            'x',  'x',      'x',        '"b=c"' ] ],
        [ q!c=~'s/\s*".*//'!,  [ 'c',  'x',  'x',           'x',            '=~', 'x',      q!'s/\s*".*//'!, 'x' ]],
        #                              id_operation                        leaf_operation
        # string                 elt   op   (param)          id             op    (param)      val        note
        [ 'a:b=c',             [ 'a',  ':',  'x',           'b',            '=',  'x',      'c',        'x' ] ], # fetch and assign elt
        [ 'a:"b\""="\"c"',     [ 'a',  ':',  'x',           '"b\""',        '=',  'x',      '"\"c"',    'x' ] ],
        [ q!a:'b\''='\'c'!,    [ 'a',  ':',  'x',           q!'b\''!,        '=',  'x',      q!'\'c'!,   'x' ] ],
        # fetch and assign elt with quotes
        [ 'a:~',               [ 'a',  ':~', 'x',           'x',            'x',  'x',      'x',        'x' ] ], # loop on matched value
        [ 'a:~.=b',            [ 'a',  ':~', 'x',           'x',            '.=', 'x',      'b',        'x' ] ], # loop on matched value
        [ 'a:~/b.*/',          [ 'a',  ':~', 'x',           '/b.*/',        'x',  'x',      'x',        'x' ] ], # loop on matched value
        [ 'a:~"b.*"',          [ 'a',  ':~', 'x',           '"b.*"',        'x',  'x',      'x',        'x' ] ], # loop on matched value
        [ 'a:~/b.*/.="\"a"',   [ 'a',  ':~', 'x',           '/b.*/',        '.=', 'x',      '"\"a"',    'x' ] ], # loop on matched value and append
        [ 'a:~"b.*".="\"a"',   [ 'a',  ':~', 'x',           '"b.*"',        '.=', 'x',      '"\"a"',    'x' ] ], # loop on matched value and append
        [ q!a:~'b.*'!,         [ 'a',  ':~', 'x',           "'b.*'",        'x',  'x',      'x',        'x' ] ], # loop on matched value
        [ q!a:~/b.*/.='\'a'!,  [ 'a',  ':~', 'x',           '/b.*/',        '.=', 'x',      q!'\'a'!,   'x' ] ], # loop on matched value and append
        [ q!a:~'b.*'.='\'a'!,  [ 'a',  ':~', 'x',           "'b.*'",        '.=', 'x',      q!'\'a'!,   'x' ] ], # loop on matched value and append
        [ 'a:~/^\w+$/',        [ 'a',  ':~', 'x',           '/^\w+$/',      'x',  'x',      'x',        'x' ] ], # loop on matched value
        [ 'a:="dod@foo.com"',  [ 'a',  ':=', 'x',           '"dod@foo.com"','x',  'x',      'x',        'x' ] ], # set list
        [ 'a:=b,c,d',          [ 'a',  ':=', 'x',           'b,c,d',        'x',  'x',      'x',        'x' ] ], # set list
        [ 'a=b,c,d',           [ 'a',  'x',  'x',           'x',            '=',  'x',      'b,c,d',    'x' ] ], # set list old style
        [ 'm:=a,"a b "',       [ 'm',  ':=', 'x',           'a,"a b "',     'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ 'm:="a b ",c',       [ 'm',  ':=', 'x',           '"a b ",c',     'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ 'm:="a b","c d"',    [ 'm',  ':=', 'x',           '"a b","c d"',  'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ q!m:=a,'a b '!,      [ 'm',  ':=', 'x',           "a,'a b '",     'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ q!m:='a b ',c!,      [ 'm',  ':=', 'x',           "'a b ',c",     'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ q!m:='a b','c d'!,   [ 'm',  ':=', 'x',           q!'a b','c d'!, 'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ "m:=$big_list",      [ 'm',  ':=', 'x',           $big_list,      'x',  'x',      'x',        'x' ] ], # set list with quotes
        [ 'm=a,"a b "',        [ 'm',  'x',  'x',           'x',            '=',  'x',      'a,"a b "', 'x' ] ],

        # set list with quotes,old style
        #                              id_operation                        leaf_operation
        # string                 elt   op   (param)          id             op    (param)      val        note
        [ 'a:b#C',             [ 'a',  ':',  'x',           'b',            'x',  'x',      'x',        'C' ] ], # fetch elt and add comment
        [ 'a:"b\""#"\"c"',     [ 'a',  ':',  'x',           '"b\""',        'x',  'x',      'x',        '"\"c"' ] ] ,
        # fetch elt and add comment with quotes
        [ 'a:b=c#C',           [ 'a',  ':',  'x',           'b',            '=',  'x',      'c',        'C' ] ], # fetch and assign elt and add comment
        [ 'a:-',               [ 'a',  ':-', 'x',           'x',            'x',  'x',      'x',        'x' ] ], # empty list
        [ 'a:-b',              [ 'a',  ':-', 'x',           'b',            'x',  'x',      'x',        'x' ] ], # remove id b
        [ 'a:-=b',             [ 'a',  ':-=','x',           'b',            'x',  'x',      'x',        'x' ] ], # remove value b from list or hash
        [ 'a:-~/b/',           [ 'a',  ':-~','x',           '/b/',          'x',  'x',      'x',        'x' ] ], # remove value matching stuff
        [ 'a:=~s/b/c/g',       [ 'a',  ':=~','x',           's/b/c/g',      'x',  'x',      'x',        'x' ] ] ,

        # subsitute value value matching stuff
        #                              id_operation                        leaf_operation
        # string                 elt   op   (param)          id             op    (param)      val        note
        [ 'a:@',               [ 'a',  ':@', 'x',           'x',            'x',  'x',      'x',        'x' ] ], # sort list
        [ 'a:.b',              [ 'a',  ':.b','x',           'x',            'x',  'x',      'x',        'x' ] ], # function called on elt
        [ 'a:.b(foo)',         [ 'a',  ':.b','foo',         'x',            'x',  'x',      'x',        'x' ] ], # idem with param
        [ 'a:<c',              [ 'a',  ':<', 'x',           'c',            'x',  'x',      'x',        'x' ] ], # push value
        [ 'a:>c',              [ 'a',  ':>', 'x',           'c',            'x',  'x',      'x',        'x' ] ], # unshift value
        [ 'a:b<c',             [ 'a',  ':',  'x',           'b',            '<',  'x',      'c',        'x' ] ], # insert at index
        [ 'a:=b<c',            [ 'a',  ':=', 'x',           'b',            '<',  'x',      'c',        'x' ] ], # insert at value
        [ 'a:~/b/<c',          [ 'a',  ':~', 'x',           '/b/',          '<',  'x',      'c',        'x' ] ], # insert at matching value

        # function call
        [ 'a:.b("foo(a > b)")', [ 'a',  ':.b','"foo(a > b)"','x',            'x',  'x',      'x',        'x' ] ], # tricky value with ()
        [ q!a:.b('foo(a > b)')!,[ 'a',  ':.b',"'foo(a > b)'",'x',            'x',  'x',      'x',        'x' ] ], # tricky value with ()
    );

    foreach my $subtest (@regexp_test) {
        my ( $cmd, $ref ) = @$subtest;
        my @res = Config::Model::Loader::_split_cmd($cmd);

        #print Dumper $res,"\n";
        foreach (@res) {
            $_ = 'x' unless defined $_;
        }
        eq_or_diff( \@res, $ref, "test _split_cmd with '$cmd'" );
    }
};

$model->load('Master' => 'dump_load_model.pl',);

$model->augment_config_class(
    name => 'Master',
    element => [
        # uses to test .set_to_std_value
        two => {
            type => 'leaf',
            value_type => 'uniline',
            compute => {
                allow_override => 1,
                use_eval => 1,
                formula => '1+1;'
            }
        },
    ]
);

my $inst = $model->instance(
    root_class_name => 'Master',
    instance_name   => 'test1'
);
ok( $inst, "created dummy instance" );

my $root;

subtest "check with embedded \n" => sub {
    #  also check that instance can load before config_root is called
    my $step = qq!#"root cooment " std_id:ab X=Bv -\na_string="titi and\nfoo" !;
    ok( $inst->load( step => $step ), "load steps with embedded \\n" );
    $root = $inst->config_root;
    is( $root->fetch_element('a_string')->fetch, "titi and\nfoo", "check a_string" );
};


subtest "check with embedded \n and \\n" => sub {
    my $step = q!a_string="titi and\nfoo and \\\\n literal" !;
    ok( $root->load( step => $step ), 'load steps with embedded \n and \\n' );
    is( $root->fetch_element('a_string')->fetch, "titi and\nfoo and \\n literal", "check a_string" );
};

subtest "check search up for element" => sub {
    my $step = qq!std_id:ab X=Bv /a_string="titi and\ntoto" !;
    ok( $root->load( step => $step ), "load steps with /a_string" );
    is( $root->fetch_element('a_string')->fetch, "titi and\ntoto", "check a_string found with search" );
};

subtest "check that : action fails on a leaf" => sub {
    my $step = qq!a_string:toto!; # should blow up
    throws_ok { $root->load( step => $step ) ; }
        qr/f/, "use ':' on a leaf";
};

subtest "test apply regexp" => sub {
    my $step = qq!a_string=~s/TOTO/tata/i!;
    ok( $root->load( step => $step ), "load steps with apply regexp" );
    is( $root->fetch_element('a_string')->fetch, qq!titi and\ntata!, "check a_string after regexp" );
};

subtest "test apply regexp with embedded spaces" => sub {
    my $step = qq!a_string=~"s/titi and\n//""!;
    ok(
        $root->load( step => $step ),
        "load steps with apply regexp with embedded spaces"
    );
    is( $root->fetch_element('a_string')->fetch,
        qq!tata!, "check a_string after regexp with embedded spaces" );
};

subtest "check with embedded quotes" => sub {
    my $step = qq!std_id:ab X=Bv -\na_string="\"titi\" and \"toto\"" std_id:bc X=Av!;
    ok( $root->load( step => $step ), "load steps with embedded quotes" );
    is(
        $root->fetch_element('a_string')->fetch,
        qq!"titi" and "toto"!,
        "check a_string with embedded quotes"
    );
};

subtest "check with embedded utf8" => sub {
    my $step =
        qq!#"root cooment \x{263A} " std_id:\x{263A} X=Bv -\na_string="titi and\ntoto and \x{263A}" !;
    ok( $root->load( step => $step ), "load steps with embedded \x{263A}" );
    is( $root->fetch_element('a_string')->fetch, "titi and\ntoto and \x{263A}", "check a_string" );
    is( $root->fetch_element('std_id')->fetch_with_id("\x{263A}")->fetch_element_value('X'),
        'Bv', "check hash with utf8 index" );
};

subtest "check with embedded literal \n that are switched with real \n" => sub {
    # note: using q and not qq
    my $step = q!std_id:"long\nkey" X=Bv - a_string="titi and\ntoto" !;
    ok( $root->load( step => $step ), 'load steps with embedded \n' );

    # now double quote for real \n
    is( $root->fetch_element('a_string')->fetch, "titi and\ntoto", 'check a_string with embedded \n' );
    is( $root->fetch_element('std_id')->fetch_with_id("long\nkey")->fetch_element_value('X'),
    'Bv', 'check hash with index with embedded \n' );
};

subtest "check with embedded comma and quotes" => sub {
    my $step = 'std_id:ab X=Bv - std_id:bc X=Av - a_string="titi , toto" ';
    ok( $root->load( step => $step ), "load '$step'" );
    is( $root->fetch_element('a_string')->fetch, 'titi , toto', "check a_string" );
};

subtest "check that we can go to root node starting from below" => sub {
    my $stdab = $root->grab("std_id:ab");
    $stdab->load("! a_string=titi");
    ok( 1, "go to root node starting from below" );

    # check that we can put an pseudo root
    $stdab->load(steps => "! X=Bv", caller_is_root => 1);
    ok( 1, "go to pseudo root node" );

    throws_ok {
        $stdab->load(steps => "- std_id:fg X=Bv", caller_is_root => 1);
    }
        qr/too many '-'/, "cannot exit pseudo root with '-'";
};


subtest "test load with warped_node below root (used to fail)" => sub {
    ok( $root->load( step => 'tree_macro=XZ' ), "Set tree_macro to XZ" );
    my $step = 'slave_y warp2 aa2="foo bar baz"';
    ok( $root->load( step => $step ), "load '$step'" );

    # this will warp out slave_y warp2
    ok( $root->load( step => 'tree_macro=XY' ), "Set tree_macro to XY" );
};

subtest "use indexes with white spaces" => sub {
    my $step = 'std_id:"a b" X=Bv - std_id:" b  c " X=Av " ';
    ok( $root->load( step => $step ), "load '$step'" );

    is_deeply(
        [ $root->fetch_element('std_id')->fetch_all_indexes ],
        [ ' b  c ', 'a b', 'ab', 'bc', "long\nkey", "\x{263A}" ],
        "check indexes"
    );
};

subtest "check for load errors" => sub {
    my $step = 'std_id:ab ZZX=Bv - std_id:bc X=Bv';
    throws_ok { $root->load( step => $step ); }
        "Config::Model::Exception::UnknownElement", "load wrong '$step'";

    $step = 'listb:=b,c,d,,f,"",h,0';
    throws_ok { $root->load( step => $step ); } qr/comma/,
        "load wrong '$step'";
};


subtest "check complex load string on many lists" => sub {
    my $step = 'lista:=a,b,c,d lista:4=e olist:0 X=Av - olist:1 X=Bv - listb:=b,c,d,f,"",h,0 listc:="dod@foo.com"';
    ok( $root->load( step => $step ), "load '$step'" );

    # perform some checks
    my $olist = $root->fetch_element('olist');
    is( $olist->fetch_with_id(0)->element_name, 'olist', 'check list element_name' );

    foreach ( 0, 1 ) {
        is( $olist->fetch_with_id($_)->config_class_name, 'SlaveZ', "check list element $_ class" );
    }

    my $lista = $root->fetch_element('lista');
    isa_ok( $lista, 'Config::Model::ListId', 'check lista class' );
    foreach ( 0, 1 ) { isa_ok( $lista->fetch_with_id($_), 'Config::Model::Value', "check lista element $_ class" ); }

    is( $olist->fetch_with_id(0)->fetch_element('X')->fetch, 'Av', "check list element 0 content" );
    is( $olist->fetch_with_id(1)->fetch_element('X')->fetch, 'Bv', "check list element 1 content" );

    my @expect = qw/a b c d e/;
    foreach ( 0 .. $#expect ) {
        is( $lista->fetch_with_id($_)->fetch, $expect[$_], "check lista element $_ content" );
    }

    my $listb = $root->fetch_element('listb');
    @expect = ( qw/b c d/, 'f', '', 'h', '0' );
    foreach ( 0 .. $#expect ) {
        is( $listb->fetch_with_id($_)->fetch, $expect[$_], "check listb element $_ content" );
    }
};

subtest "check quoted string and list assignment" => sub {
    my $step = 'a_string="foo bar"';
    ok( $root->load( step => $step, ), "load quoted string: '$step'" );
    is( $root->fetch_element('a_string')->fetch, "foo bar", 'check result' );

    $step = 'a_string="foo bar baz" lista:=a,b,c,d,e';
    ok( $root->load( step => $step, ), "load : '$step'" );
    is( $root->fetch_element('a_string')->fetch, "foo bar baz", 'check result' );

    my @expect = qw/a b c d e/;
    my $lista = $root->fetch_element('lista');
    foreach ( 0 .. 4 ) {
        is( $lista->fetch_with_id($_)->fetch, $expect[$_], "check lista element $_ content" );
    }
};

subtest "check complex hash index" => sub {
    my $step = 'std_id:"f/o/o:b.ar" X=Bv';
    ok( $root->load( step => $step, ), "load : '$step'" );
    eq_or_diff(
        [ sort $root->fetch_element('std_id')->fetch_all_indexes ],
        [ ' b  c ', 'a b', qw!ab bc f/o/o:b.ar!, "long\nkey", "\x{263A}" ],
        "check result after load '$step'"
    );

    $step = 'hash_a:a=z hash_a:b=z2 hash_a:"a b "="z 1" hash_a:empty';
    ok( $root->load( step => $step, ), "load : '$step'" );
    is_deeply(
        [ sort $root->fetch_element('hash_a')->fetch_all_indexes ],
        [ 'a', 'a b ', 'b', 'empty' ],
        "check result after load '$step'"
    );
    is( $root->fetch_element('hash_a')->fetch_with_id('a')->fetch, 'z', 'check result' );

    my $elt = $root->fetch_element('hash_a')->fetch_with_id('a b ');
    is( $elt->fetch, 'z 1', 'check result with white spaces' );

    is( $elt->location, 'hash_a:"a b "', 'check location' );
};

subtest "check quoted values" => sub {
    my $step = 'my_check_list=a,"a b "';
    ok( $root->load( step => $step, ), "load : '$step'" );

    $step = 'a_string="a \"b\" "';
    ok( $root->load( step => $step, ), "load : '$step'" );
    is( $root->fetch_element('a_string')->fetch, 'a "b" ', "test value loaded by '$step'" );

    $step = 'lista:=a,"a \"b\" "';
    ok( $root->load( step => $step, ), "load : '$step'" );
    my $lista = $root->fetch_element('lista');
    is( $lista->fetch_with_id(1)->fetch, 'a "b" ', "test value loaded by '$step'" );
};

subtest "test that lista~a complains about non numeric index" => sub {
    my $step = 'lista~a';
    throws_ok { $root->load( step => $step ); } "Config::Model::Exception::User", "load wrong '$step'";
};

subtest "use new and old notation to delete elements" => sub {
    my $step = 'lista:-1 hash_a~"a b "';
    ok( $root->load( step => $step, ), "load : '$step'" );
    my $lista = $root->fetch_element('lista');
    is( $lista->fetch_with_id(1)->fetch, undef, "test list value loaded by '$step'" );
    my $elt = $root->fetch_element('hash_a')->fetch_with_id('a b ');
    is( $elt->fetch, undef, "test hash value loaded by '$step'" );
};

subtest "test append mode" => sub {
    $root->load('a_string.=c');
    is( $root->fetch_element_value('a_string'), 'a "b" c', "test append on list" );

    # test append mode with utf8
    $root->load("a_string.=\x{263A}");
    is(
        $root->fetch_element_value('a_string'),
        'a "b" c' . "\x{263A}",
        "test append on list with utf8"
    );

    $root->load('lista:0.=" b c"');
    my $lista = $root->fetch_element('lista');
    is( $lista->fetch_with_id(0)->fetch,, 'a b c', "test append on leaf" );

    $root->load('hash_a:b.=" z3"');
    is( $root->fetch_element('hash_a')->fetch_with_id('b')->fetch,, 'z2 z3', "test append on hash" );
};

subtest "test loop mode" => sub {
    $root->load('std_id:~ DX=Av - int_v=9');
    is( $root->grab_value('std_id:ab DX'), 'Av', "check looped assign 1" );
    is( $root->grab_value('std_id:bc DX'), 'Av', "check looped assign 2" );
    is( $root->grab_value('std_id:"a b" DX'), 'Av', "check looped assign 3" );

    #$root->load('std_id:.foreach_match("/^\w+$/") DX=Bv - int_v=9');
    $root->load('std_id:~/^\w+$/ DX=Bv - int_v=9');
    is( $root->grab_value('std_id:ab DX'), 'Bv', "check looped assign 1" );
    is( $root->grab_value('std_id:bc DX'), 'Bv', "check looped assign 2" );
    is( $root->grab_value('std_id:"a b" DX'), 'Av', "check out of loop left alone" );
};

subtest "test annotation setting" => sub {
    my @anno_test = ( 'std_id', 'std_id:ab', 'lista', 'lista:0', );
    foreach my $path (@anno_test) {
        $root->load(qq!$path#"$path annotation"!);
        is( $root->grab($path)->annotation, "$path annotation", "fetch $path annotation" );
    }
};

subtest "test remove by value and remove by matched value" => sub {
    $root->load('lista:=a,b,c,d,foo lista:-=b lista:-~/oo/');
    my $lista = $root->fetch_element('lista');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/a c d/], "removed value from list" );
};

subtest "test substitution" => sub {
    $root->load('lista:=Foo1,foo2,bar lista:=~s/foo/doh/i');
    my $lista = $root->fetch_element('lista');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/doh1 doh2 bar/], "test :=~ on list" );

    $root->load('hash_a:a=Foo3 hash_a:b=foo4 hash_a:c=bar hash_a:=~s/foo/doh/i');
    eq_or_diff( [ sort $root->fetch_element('hash_a')->fetch_all_values ],
                [qw/bar doh3 doh4/], "test :=~ on hash" );
};

subtest "test function call in load string" => sub {
    my $lista = $root->fetch_element('lista');
    $root->load('lista:=j,h,g,f lista:@');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/f g h j/], "test :@ on list" );

    $root->load('lista:=j,h,g,f lista:.sort');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/f g h j/], "test :.sort on list" );

    $root->load('lista:=a,b lista:.push(c) lista:<d');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/a b c d/], "test push on list" );

    $root->load('lista:=a,b lista:.unshift(1) lista:>2');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/2 1 a b/], "test unshift on list" );
};

subtest "load with check set to no" => sub {
    my $list = $root->fetch_element('int_list_with_max');
    throws_ok {
        $root->load(steps => 'int_list_with_max:=1,5,12');
    } qr!max limit!, "cannot load value > max with default check value";

    $root->load(steps => 'int_list_with_max:=1,5,12', check => 'no');
    eq_or_diff( [ $list->fetch_all_values(check => 'no') ],
                [qw/1 5 12/], "load without check" );

    $root->load(steps => 'int_list_with_max:.clear');

    {
        my $xp = Test::Log::Log4perl->expect(
            ignore_priority => "info",
            ['User', warn =>  qr/value 12 > max limit/]
        );
        $root->load(steps => 'int_list_with_max:=1,5,12', check => 'skip');
    }
    eq_or_diff( [ $list->fetch_all_values ], [qw/1 5/], "load with check skip" );
};

subtest "test insert_before" => sub {
    my $lista = $root->fetch_element('lista');
    $root->load('lista=foo,baz lista:.insert_before(baz,bar1,bar2)');
    eq_or_diff( [ $lista->fetch_all_values ], [qw/foo bar1 bar2 baz/], "check insert_before result" );

    $root->load('lista:.insert_before(/z/,bar3,bar4)');
    eq_or_diff(
        [ $lista->fetch_all_values ],
        [qw/foo bar1 bar2 bar3 bar4 baz/],
        "check insert_before with regexp /z/"
    );

    $root->load('lista:.insert_before(/1/,"bar0a bar0b, bar0c")');
    eq_or_diff(
        [ $lista->fetch_all_values ],
        [ foo => "bar0a bar0b, bar0c", qw/bar1 bar2 bar3 bar4 baz/ ],
        "check insert_before with regexp /1/"
    );
};

subtest "test sort and insort" => sub {
    my @set1 = qw/c1 e i1 j1 p1/;
    my @set2 = qw/a2 z2 d2 e b2 k2/;
    my $lista = $root->fetch_element('lista');
    $root->load(
        'lista=' . join( ',', @set1 ) . ' lista:.sort lista:.insort(' . join( ',', @set2 ) . ')' );
    eq_or_diff( [ $lista->fetch_all_values ], [ sort( @set1, @set2 ) ], "check insort result" );

    # test insort with a tricky value
    my $tricky = q!libmodule-build-perl (>= 0.421100-2)!;
    $root->load( qq!lista:.insort("$tricky")! );
    eq_or_diff( [ $lista->fetch_all_values ], [ sort( @set1, @set2, $tricky ) ], "check insort result" );

    # test sort on ordered hash
    my $oh = $root->fetch_element('ordered_hash');
    $root->load('ordered_hash:b=bv ordered_hash:a=av');
    eq_or_diff( [$oh->fetch_all_indexes()],[qw/b a/], "check unsorted keys") ;
    $root->load('ordered_hash:.sort') ;
    eq_or_diff( [$oh->fetch_all_indexes()],[qw/a b/], "check sorted keys") ;

    # test insort on ordered hash
    $root->load('ordered_hash:.insort(d,"dv")') ;
    eq_or_diff( [$oh->fetch_all_indexes()],[qw/a b d/], "check sorted keys after insort") ;

    # test insort on ordered hash of node
    my $ohon = $root->fetch_element('ordered_hash_of_node');
    $root->load('ordered_hash_of_node:g aa2="g aa2 val" - ordered_hash_of_node:.insort(d) aa2="d aa2 val"');
    eq_or_diff( [$ohon->fetch_all_indexes()],[qw/d g/], "check sorted keys") ;
};

subtest "test list.ensure" => sub {
    my $lista = $root->fetch_element('lista');
    $root->load('lista=a,b,c,d');
    my @expect = $lista->fetch_all_values;

    $root->load( qq!lista:.ensure(b)! );
    eq_or_diff( [ $lista->fetch_all_values ], \@expect, "ensure(b) -> no change" );

    $root->load( qq!lista:.ensure(b2)! );
    eq_or_diff( [ $lista->fetch_all_values ], [qw/a b b2 c d/], "ensure(b2) -> inserted and sorted");

    $root->load( qq!lista:.ensure(c2,f4,b2,c2,"z z")! );
    eq_or_diff( [ $lista->fetch_all_values ], [qw/a b b2 c c2 d f4/, "z z"], "ensure several values");
};

subtest "test combination of annotation plus load and some utf8" => sub {
    my $step = 'std_id#std_id_note ! std_id:ab#std_id_ab_note X=Bv X#X_note 
      - std_id:bc X=Av X#X2_note '
          . '- a_string="toto \"titi\" tata" a_string#string_note '
          . 'lista:=a,b,c,d olist:0 - olist:0#olist0_note X=Av - olist:1 X=Bv - listb:=b,"c c2",d '
          . '! hash_a:X2=x#x_note hash_a:Y2=xy  hash_b:X3=xy my_check_list=X2,X3 '
          . 'plain_object#"plain comment" aa2="aa2_value '
          . "\x{263A}\"";

    my $inst2 = $model->instance(
        root_class_name => 'Master',
        instance_name   => 'test2'
    );

    my $root2 = $inst2->config_root;

    ok(
        $root2->load( step => $step ),
        "set up data in tree with combination of load and annotations"
    );

    my @to_check = (
        [ 'std_id',       'std_id_note' ],
        [ 'std_id:ab',    'std_id_ab_note' ],
        [ 'std_id:ab X',  'X_note' ],
        [ 'std_id:bc X',  'X2_note' ],
        [ 'a_string',     'string_note' ],
        [ 'olist:0',      'olist0_note' ],
        [ 'hash_a:X2',    'x_note' ],
        [ 'plain_object', 'plain comment' ],
    );
    foreach (@to_check) {
        is( $root2->grab( $_->[0] )->annotation, $_->[1], "Check annotation for '$_->[0]'" );
    }

    # check utf8 value
    is( $root2->grab_value('plain_object aa2'), "aa2_value \x{263A}", "utf8 value" );

    # test deletion of leaf items
    $step = 'a_string=foobar a_string~';
    ok( $root2->load( step => $step ), "set up data then delete it" );

    is( $root2->grab_value('a_string'), undef, "check that another_string was undef'ed" );

    $root2->load("lista:0.=\x{263A}");
    is( $root2->grab_value('lista:0'), "a\x{263A}", "check that list append work" );
};

subtest "test element with embedded dash" => sub {
    $root->load("std_id:ab X-Y-Z=Av");
    is( $root->grab_value('std_id:ab X-Y-Z'), "Av", "check load grab of X-Y-Z" );
};

subtest "test deep copy and rename" => sub {
    $root->load("std_id:.copy(ab,copy)");
    is( $root->grab_value('std_id:copy X-Y-Z'), "Av", "check hash copy" );

    $root->load("std_id:.rename(copy,copy2)");
    ok( ! $root->grab('std_id')->exists('copy'), "check hash rename: old key is gone" );
    is( $root->grab_value('std_id:copy2 X-Y-Z'), "Av", "check hash rename: new key is found" );

    $root->load('lista=a,b,c,d,e,f');
    is( $root->grab_value('lista:5'), 'f' , "list copy" );
    $root->load("lista:.copy(1,5)");
    is( $root->grab_value('lista:5'), 'b' , "list copy" );
};

subtest "test clear instruction" => sub {
    $root->load("hash_a:.clear");
    is( $root->grab('hash_a')->has_data, 0 , "cleared hash" );

    $root->load("lista:.clear");
    is( $root->grab('lista')->has_data, 0 , "cleared list" );
};

subtest "test load data from file" => sub {
    $root->load("a_string=.file(README.md)");
    like( $root->grab_value('a_string'), qr/# What is Config-Model project/,
          "slurp README.md file");
};

subtest "test load data from JSON file" => sub {
    $inst->clear_changes;
    $root->load('a_string=.json("t/lib/load-data.json/foo/bar")');
    is( $root->grab_value('a_string'), "bar json value", "extract data from json file");

    $root->load('listc:.json("t/lib/load-data.json/foo_array")');
    is( $root->grab_value('listc:0'), "bar", "extract array data from json file 1/2");
    is( $root->grab_value('listc:1'), "baz", "extract array data from json file 2/2");

    is( $inst->needs_save, 3,     "verify instance needs_save after storing 3 values" );

    throws_ok {
        $root->load('a_string=.json(t/lib/dummy.json/foo/bar)');
    }
        qr!Cannot find file in t/lib/dummy.json/foo/bar!,
        "throws error on dummy json file: check error message";

    throws_ok {
        $root->load('a_string=.json(t/lib/dummy.json/foo/bar)');
    }
        qr!a_string=\.json\(t/lib/dummy\.json/foo/bar\)!,
        "throws error on dummy json file: check reported command";
};

subtest "test load data from JSON utf8 file" => sub {
    $inst->clear_changes;

    $root->load('a_string=.json("t/lib/load-data.json/utf8-value")');
    is( $root->grab_value('a_string'), "30€ de thé", "extract utf-8 data from json file");
};

subtest "test load data from YAML file" => sub {
    $root->load('a_string=.yaml("t/lib/load-data.yaml/0/foo/bar")');
    is( $root->grab_value('a_string'), "bar yaml value", "extract data from yaml file");
};

subtest "load data from environment" => sub {
    my $expect = $ENV{TEST_CONFIG_MODEL_LOADER} = 'plop';
    $root->load("a_string=.env(TEST_CONFIG_MODEL_LOADER)");
    is( $root->grab_value('a_string'), 'plop', "set value from environment");
};

subtest "test some errors cases" => sub {
    my %errors = (
        'std_id'                  => qr/Missing key/,
        'olist'                   => qr/Wrong assignment/,
        'std_id:Apache-2.0 X=Av'  => qr/spurious char/,
        'std_id:-Apache-2.0 X=Av' => qr/spurious char/,
    );

    foreach my $bad ( sort keys %errors ) {
        throws_ok { $root->load($bad) } $errors{$bad}, "Check error for load('$bad')";
    }
};

subtest "test .set_to_std_value" => sub {
    $root->load('two=3');
    is($root->grab_value("two"), 3, "check two value (wrong)");
    $root->load('two=.set_to_std_value()');
    is($root->grab_value("two"), 2, "check two value (correct)");
};

memory_cycle_ok( $model, "check memory cycles" );

done_testing;
