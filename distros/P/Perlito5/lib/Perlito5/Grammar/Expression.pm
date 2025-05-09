# Do not edit this file - Generated by Perlito5 9.027

{
    package main;
    package Perlito5::Grammar::Expression;
    use Perlito5::Grammar::Precedence ;
    use Perlito5::Grammar::Bareword ;
    use Perlito5::Grammar::Attribute ;
    use Perlito5::Grammar::Statement ;
    sub Perlito5::Grammar::Expression::expand_list_fat_arrow {
        my $param_list = shift;
        if (ref($param_list) eq "Perlito5::AST::Apply" && $param_list->{"code"} eq "infix:<=>>") {;
            return (Perlito5::AST::Lookup::->autoquote($param_list->{"arguments"}->[0]), Perlito5::Grammar::Expression::expand_list_fat_arrow($param_list->{"arguments"}->[1]))
        }
        return $param_list
    }
    sub Perlito5::Grammar::Expression::expand_list {
        my $param_list = shift;
        if (ref($param_list) eq "Perlito5::AST::Apply" && $param_list->{"code"} eq "list:<,>") {;
            return [map {;
                Perlito5::Grammar::Expression::expand_list_fat_arrow($_)
            } grep {;
                defined($_)
            } @{$param_list->arguments()}]
        }
        if (ref($param_list) eq "Perlito5::AST::Apply" && $param_list->{"code"} eq "infix:<=>>") {;
            return [Perlito5::Grammar::Expression::expand_list_fat_arrow($param_list)]
        }
        elsif ($param_list eq "*undef*") {;
            return []
        }
        else {;
            return [$param_list]
        }
    }
    sub Perlito5::Grammar::Expression::block_or_hash {
        my $o = shift;
        if (defined($o->sig())) {;
            return $o
        }
        my $stmts = $o->stmts();
        if (!defined($stmts) || scalar(@{$stmts}) == 0) {;
            return Perlito5::AST::Apply::->new("code", "circumfix:<{ }>", "namespace", '', "arguments", [])
        }
        if (scalar(@{$stmts}) != 1) {;
            return $o
        }
        my $stmt = $stmts->[0];
        if (ref($stmt) eq "Perlito5::AST::Var") {;
            return Perlito5::AST::Apply::->new("code", "circumfix:<{ }>", "namespace", '', "arguments", [$stmt])
        }
        if (ref($stmt) ne "Perlito5::AST::Apply") {;
            return $o
        }
        if ($stmt->{"code"} eq "infix:<=>>" || $stmt->{"code"} eq "prefix:<%>" || $stmt->{"code"} eq "prefix:<\@>" || $stmt->{"code"} eq "list:<,>") {
            if (@{$stmt->{"arguments"}}) {
                my $arg = $stmt->{"arguments"}->[0];
                if (ref($arg) eq "Perlito5::AST::Apply" && $arg->{"code"} eq "prefix:<&>") {;
                    return $o
                }
            }
            return Perlito5::AST::Apply::->new("code", "circumfix:<{ }>", "namespace", '', "arguments", [$stmt])
        }
        return Perlito5::AST::Apply::->new("code", "circumfix:<{ }>", "namespace", '', "arguments", Perlito5::Grammar::Expression::expand_list($stmt))
    }
    sub Perlito5::Grammar::Expression::pop_term {
        my $num_stack = shift;
        my $v = pop(@{$num_stack});
        if (ref($v) eq "ARRAY") {
            ref($v->[1]) && return $v->[1];
            if ($v->[1] eq "methcall_no_params") {
                $v = Perlito5::AST::Call::->new("invocant", undef, "method", $v->[2], "arguments", []);
                return $v
            }
            if ($v->[1] eq "funcall_no_params") {
                $v = $v->[2];
                return $v
            }
            if ($v->[1] eq "methcall") {
                my $param_list = Perlito5::Grammar::Expression::expand_list(($v->[3]));
                $v = Perlito5::AST::Call::->new("invocant", undef, "method", $v->[2], "arguments", $param_list);
                return $v
            }
            if ($v->[1] eq "funcall") {
                $v = Perlito5::AST::Apply::->new("code", $v->[3], "arguments", $v->[4], "namespace", $v->[2]);
                return $v
            }
            if ($v->[1] eq "( )") {
                my $param_list = Perlito5::Grammar::Expression::expand_list($v->[2]);
                $v = Perlito5::AST::Apply::->new("code", "circumfix:<( )>", "arguments", $param_list, "namespace", '');
                return $v
            }
            if ($v->[1] eq "[ ]") {
                my $param_list = Perlito5::Grammar::Expression::expand_list($v->[2]);
                $v = Perlito5::AST::Apply::->new("code", "circumfix:<[ ]>", "arguments", $param_list, "namespace", '');
                return $v
            }
            if ($v->[1] eq "block") {
                $v = Perlito5::AST::Block::->new("stmts", $v->[2], "sig", $v->[3]);
                $v = Perlito5::Grammar::Expression::block_or_hash($v);
                return $v
            }
            if ($v->[1] eq ".( )") {
                $v = Perlito5::AST::Call::->new("invocant", undef, "method", "postcircumfix:<( )>", "arguments", $v->[2]);
                return $v
            }
            if ($v->[1] eq ".[ ]") {
                $v = Perlito5::AST::Index::->new("obj", undef, "index_exp", $v->[2]);
                return $v
            }
            if ($v->[1] eq ".{ }") {
                $v = Perlito5::AST::Lookup::->new("obj", undef, "index_exp", $v->[2]);
                return $v
            }
            return $v->[1]
        }
        return $v
    }
    sub Perlito5::Grammar::Expression::reduce_postfix {
        my $op = shift;
        my $value = shift;
        my $v = $op;
        if ($v->[1] eq ".{ }") {
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", "postcircumfix:<{ }>", "arguments", $v->[2]);
            return $v
        }
        if ($v->[1] eq ".[ ]") {
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", "postcircumfix:<[ ]>", "arguments", $v->[2]);
            return $v
        }
        if ($v->[1] eq "methcall_no_params") {
            if ($v->[2] eq "\@*") {;
                return Perlito5::AST::Apply::->new("code", "prefix:<\@>", "arguments", [$value])
            }
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", $v->[2], "arguments", [], (ref($v->[2]) ? () : ("_no_params", 1)));
            return $v
        }
        if ($v->[1] eq "funcall_no_params") {;
            Perlito5::Compiler::error("Bareword found where operator expected")
        }
        if ($v->[1] eq "methcall") {
            my $param_list = Perlito5::Grammar::Expression::expand_list($v->[3]);
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", $v->[2], "arguments", $param_list);
            return $v
        }
        if ($v->[1] eq "funcall") {;
            Perlito5::Compiler::error("unexpected function call")
        }
        if ($v->[1] eq "( )") {
            my $param_list = Perlito5::Grammar::Expression::expand_list($v->[2]);
            if (ref($value) eq "Perlito5::AST::Apply" && !defined($value->arguments())) {
                $value->{"arguments"} = $param_list;
                return $value
            }
            if (ref($value) eq "Perlito5::AST::Call" && !defined($value->arguments())) {
                $value->{"arguments"} = $param_list;
                return $value
            }
            if (ref($value) eq "Perlito5::AST::Var" && $value->{"sigil"} eq "&") {
                $v = Perlito5::AST::Apply::->new("ignore_proto", 1, "code", $value->{"name"}, "namespace", $value->{"namespace"}, "arguments", $param_list, "proto", undef);
                return $v
            }
            if (ref($value) eq "Perlito5::AST::Apply" && $value->{"code"} eq "prefix:<&>") {
                $v = Perlito5::AST::Apply::->new("ignore_proto", 1, "code", $value, "namespace", '', "arguments", $param_list, "proto", undef);
                return $v
            }
            if (ref($value) eq "Perlito5::AST::Var") {;
                Perlito5::Compiler::error("syntax error")
            }
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", "postcircumfix:<( )>", "arguments", $param_list);
            return $v
        }
        if ($v->[1] eq "[ ]") {
            if (ref($value) eq "Perlito5::AST::Var") {;
                $value->{"_real_sigil"} = "\@"
            }
            $v = Perlito5::AST::Index::->new("obj", $value, "index_exp", $v->[2]);
            return $v
        }
        if ($v->[1] eq "block") {
            if (ref($value) eq "Perlito5::AST::Var") {
                $value->{"_real_sigil"} = "%";
                $value->{"sigil"} eq "*" && ($value->{"_real_sigil"} = "*")
            }
            $v = Perlito5::AST::Lookup::->new("obj", $value, "index_exp", $v->[2]->[0]);
            return $v
        }
        if ($v->[1] eq ".( )") {
            my $param_list = Perlito5::Grammar::Expression::expand_list($v->[2]);
            $v = Perlito5::AST::Call::->new("invocant", $value, "method", "postcircumfix:<( )>", "arguments", $param_list);
            return $v
        }
        push(@{$op}, $value);
        return $op
    }
    sub Perlito5::Grammar::Expression::reduce_to_ast {
        my $op_stack = shift;
        my $num_stack = shift;
        my $last_op = shift(@{$op_stack});
        if ($last_op->[0] eq "prefix") {
            my $v = Perlito5::Grammar::Expression::pop_term($num_stack);
            if (ref($v) eq "Perlito5::AST::Apply" && $v->{"code"} eq "circumfix:<( )>" && @{$v->{"arguments"}} == 1) {;
                $v = $v->{"arguments"}
            }
            else {;
                $v = [$v]
            }
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "prefix:<" . ($last_op->[1]) . ">", "arguments", $v))
        }
        elsif ($last_op->[0] eq "postfix") {;
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "postfix:<" . ($last_op->[1]) . ">", "arguments", [Perlito5::Grammar::Expression::pop_term($num_stack)]))
        }
        elsif ($last_op->[0] eq "postfix_or_term") {;
            push(@{$num_stack}, Perlito5::Grammar::Expression::reduce_postfix($last_op, Perlito5::Grammar::Expression::pop_term($num_stack)))
        }
        elsif (Perlito5::Grammar::Precedence::is_assoc_type("list", $last_op->[1])) {
            my $arg;
            if (scalar(@{$num_stack}) < 2) {
                my $v2 = Perlito5::Grammar::Expression::pop_term($num_stack);
                if (ref($v2) eq "Perlito5::AST::Apply" && $v2->{"code"} eq ("list:<" . ($last_op->[1]) . ">")) {;
                    push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", $v2->namespace(), "code", $v2->{"code"}, "arguments", [@{$v2->arguments()}]))
                }
                else {;
                    push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "list:<" . ($last_op->[1]) . ">", "arguments", [$v2]))
                }
                return
            }
            else {
                my $v2 = Perlito5::Grammar::Expression::pop_term($num_stack);
                $arg = [Perlito5::Grammar::Expression::pop_term($num_stack), $v2]
            }
            if (ref($arg->[0]) eq "Perlito5::AST::Apply" && $last_op->[0] eq "infix" && ($arg->[0]->{"code"} eq "list:<" . ($last_op->[1]) . ">")) {
                push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", ($arg->[0])->{"code"}, "arguments", [@{($arg->[0])->arguments()}, $arg->[1]]));
                return
            }
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "list:<" . ($last_op->[1]) . ">", "arguments", $arg))
        }
        elsif (Perlito5::Grammar::Precedence::is_assoc_type("chain", $last_op->[1])) {
            if (scalar(@{$num_stack}) < 2) {;
                Perlito5::Compiler::error("Missing value after operator " . ($last_op->[1]))
            }
            my $v2 = Perlito5::Grammar::Expression::pop_term($num_stack);
            my $arg = [Perlito5::Grammar::Expression::pop_term($num_stack), $v2];
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "infix:<" . ($last_op->[1]) . ">", "arguments", $arg))
        }
        elsif ($last_op->[0] eq "ternary") {
            if (scalar(@{$num_stack}) < 2) {;
                Perlito5::Compiler::error("Missing value after ternary operator")
            }
            my $v2 = Perlito5::Grammar::Expression::pop_term($num_stack);
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "ternary:<" . ($last_op->[1]) . ">", "arguments", [Perlito5::Grammar::Expression::pop_term($num_stack), $last_op->[2], $v2]))
        }
        else {
            if (scalar(@{$num_stack}) < 2) {;
                Perlito5::Compiler::error("missing value after operator '" . ($last_op->[1]) . "'")
            }
            my $v2 = Perlito5::Grammar::Expression::pop_term($num_stack);
            my $op = $last_op->[1];
            push(@{$num_stack}, Perlito5::AST::Apply::->new("namespace", '', "code", "infix:<" . $op . ">", "arguments", [Perlito5::Grammar::Expression::pop_term($num_stack), $v2], Perlito5::integer_flag($op), Perlito5::overloading_flag()))
        }
    }
    sub Perlito5::Grammar::Expression::term_arrow {
        my $str = $_[0];
        my $pos = $_[1];
        my $MATCH = {"str" => $str, "from" => $pos, "to" => $pos, };
        my $tmp = (((("-" eq $str->[($MATCH->{"to"}) + 0]) && (">" eq $str->[($MATCH->{"to"}) + 1]) && ($MATCH->{"to"} += 2)) && (do {
            my $m2 = Perlito5::Grammar::Space::opt_ws($str, $MATCH->{"to"});
            if ($m2) {
                $MATCH->{"to"} = $m2->{"to"};
                1
            }
            else {;
                0
            }
        }) && (do {
            my $tmp129 = $MATCH->{"to"};
            (((("(" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                my $m2 = Perlito5::Grammar::Expression::paren_parse($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"paren_parse"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && ((")" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                $MATCH->{"capture"} = ["postfix_or_term", ".( )", Perlito5::Match::flat($MATCH->{"paren_parse"})];
                1
            }))) || ($MATCH->{"to"} = $tmp129, ((("[" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                my $m2 = Perlito5::Grammar::Expression::square_parse($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"square_parse"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && (("]" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                $MATCH->{"capture"} = ["postfix_or_term", ".[ ]", Perlito5::Match::flat($MATCH->{"square_parse"})];
                1
            }))) || ($MATCH->{"to"} = $tmp129, ((("{" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                my $tmp130 = $MATCH->{"to"};
                (((do {
                    my $m2 = Perlito5::Grammar::Space::opt_ws($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        1
                    }
                    else {;
                        0
                    }
                }) && (do {
                    my $m2 = Perlito5::Grammar::ident($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        $MATCH->{"Perlito5::Grammar::ident"} = $m2;
                        1
                    }
                    else {;
                        0
                    }
                }) && (do {
                    my $m2 = Perlito5::Grammar::Space::opt_ws($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        1
                    }
                    else {;
                        0
                    }
                }) && (("}" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                    $MATCH->{"capture"} = ["postfix_or_term", ".{ }", Perlito5::AST::Buf::->new("buf", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::ident"}))];
                    1
                }))) || ($MATCH->{"to"} = $tmp130, ((do {
                    my $m2 = Perlito5::Grammar::Expression::curly_parse($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        $MATCH->{"curly_parse"} = $m2;
                        1
                    }
                    else {;
                        0
                    }
                }) && (do {
                    my $tmp131 = $MATCH->{"to"};
                    ((("}" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1))) || ($MATCH->{"to"} = $tmp131, (do {
                        Perlito5::Compiler::error("Missing right curly or square bracket");
                        1
                    }))
                }) && (do {
                    $MATCH->{"capture"} = ["postfix_or_term", ".{ }", Perlito5::Match::flat($MATCH->{"curly_parse"})];
                    1
                })))
            }))) || ($MATCH->{"to"} = $tmp129, ((do {
                my $m2 = Perlito5::Grammar::full_ident($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"Perlito5::Grammar::full_ident"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && (do {
                my $m2 = Perlito5::Grammar::Space::opt_ws($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    1
                }
                else {;
                    0
                }
            }) && (do {
                my $tmp132 = $MATCH->{"to"};
                (((("(" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                    my $m2 = Perlito5::Grammar::Expression::paren_parse($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        $MATCH->{"paren_parse"} = $m2;
                        1
                    }
                    else {;
                        0
                    }
                }) && ((")" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                    $MATCH->{"capture"} = ["postfix_or_term", "methcall", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::full_ident"}), Perlito5::Match::flat($MATCH->{"paren_parse"})];
                    1
                }))) || ($MATCH->{"to"} = $tmp132, (do {
                    $MATCH->{"capture"} = ["postfix_or_term", "methcall_no_params", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::full_ident"})];
                    1
                }))
            }))) || ($MATCH->{"to"} = $tmp129, ((do {
                my $tmp = $MATCH;
                $MATCH = {"from" => $tmp->{"to"}, "to" => $tmp->{"to"}, };
                my $res = (("\$" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1));
                $MATCH = $tmp;
                $res ? 1 : 0
            }) && (do {
                my $m2 = Perlito5::Grammar::Sigil::term_sigil($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"Perlito5::Grammar::Sigil::term_sigil"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && (do {
                my $m2 = Perlito5::Grammar::Space::opt_ws($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    1
                }
                else {;
                    0
                }
            }) && (do {
                my $tmp133 = $MATCH->{"to"};
                (((("(" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                    my $m2 = Perlito5::Grammar::Expression::paren_parse($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        $MATCH->{"paren_parse"} = $m2;
                        1
                    }
                    else {;
                        0
                    }
                }) && ((")" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                    $MATCH->{"capture"} = ["postfix_or_term", "methcall", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::Sigil::term_sigil"})->[1], Perlito5::Match::flat($MATCH->{"paren_parse"})];
                    1
                }))) || ($MATCH->{"to"} = $tmp133, (do {
                    $MATCH->{"capture"} = ["postfix_or_term", "methcall_no_params", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::Sigil::term_sigil"})->[1]];
                    1
                }))
            }))) || ($MATCH->{"to"} = $tmp129, ((("\@" eq $str->[($MATCH->{"to"}) + 0]) && ("*" eq $str->[($MATCH->{"to"}) + 1]) && ($MATCH->{"to"} += 2)) && (do {
                $MATCH->{"capture"} = ["postfix_or_term", "methcall_no_params", "\@*"];
                1
            })))
        })));
        $tmp ? $MATCH : undef
    }
    sub Perlito5::Grammar::Expression::term_ternary {
        my $str = $_[0];
        my $pos = $_[1];
        my $MATCH = {"str" => $str, "from" => $pos, "to" => $pos, };
        my $tmp = (((("?" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            my $m2 = Perlito5::Grammar::Expression::ternary5_parse($str, $MATCH->{"to"});
            if ($m2) {
                $MATCH->{"to"} = $m2->{"to"};
                $MATCH->{"ternary5_parse"} = $m2;
                1
            }
            else {;
                0
            }
        }) && ((":" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            $MATCH->{"capture"} = ["op", "? :", Perlito5::Match::flat($MATCH->{"ternary5_parse"})];
            1
        })));
        $tmp ? $MATCH : undef
    }
    sub Perlito5::Grammar::Expression::term_paren {
        my $str = $_[0];
        my $pos = $_[1];
        my $MATCH = {"str" => $str, "from" => $pos, "to" => $pos, };
        my $tmp = (((("(" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            my $m2 = Perlito5::Grammar::Expression::paren_parse($str, $MATCH->{"to"});
            if ($m2) {
                $MATCH->{"to"} = $m2->{"to"};
                $MATCH->{"paren_parse"} = $m2;
                1
            }
            else {;
                0
            }
        }) && ((")" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            $MATCH->{"capture"} = ["postfix_or_term", "( )", Perlito5::Match::flat($MATCH->{"paren_parse"})];
            1
        })));
        $tmp ? $MATCH : undef
    }
    sub Perlito5::Grammar::Expression::term_square {
        my $str = $_[0];
        my $pos = $_[1];
        my $MATCH = {"str" => $str, "from" => $pos, "to" => $pos, };
        my $tmp = (((("[" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            my $m2 = Perlito5::Grammar::Expression::square_parse($str, $MATCH->{"to"});
            if ($m2) {
                $MATCH->{"to"} = $m2->{"to"};
                $MATCH->{"square_parse"} = $m2;
                1
            }
            else {;
                0
            }
        }) && (("]" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            $MATCH->{"capture"} = ["postfix_or_term", "[ ]", Perlito5::Match::flat($MATCH->{"square_parse"})];
            1
        })));
        $tmp ? $MATCH : undef
    }
    sub Perlito5::Grammar::Expression::term_curly {
        my $str = $_[0];
        my $pos = $_[1];
        my $MATCH = {"str" => $str, "from" => $pos, "to" => $pos, };
        my $tmp = (((("{" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
            my $m = $MATCH;
            if (!(do {
                my $m2 = Perlito5::Grammar::Space::ws($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    1
                }
                else {;
                    0
                }
            })) {;
                $MATCH = $m
            }
            1
        }) && (do {
            my $tmp173 = $MATCH->{"to"};
            (((do {
                my $m2 = Perlito5::Grammar::ident($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"Perlito5::Grammar::ident"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && (do {
                my $m = $MATCH;
                if (!(do {
                    my $m2 = Perlito5::Grammar::Space::ws($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        1
                    }
                    else {;
                        0
                    }
                })) {;
                    $MATCH = $m
                }
                1
            }) && (("}" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1)) && (do {
                $MATCH->{"capture"} = ["postfix_or_term", "block", [Perlito5::AST::Apply::->new("arguments", [], "bareword", 1, "code", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::ident"}), "namespace", '')]];
                1
            }))) || ($MATCH->{"to"} = $tmp173, ((do {
                $MATCH->{"_save_scope"} = [@Perlito5::SCOPE_STMT];
                @Perlito5::SCOPE_STMT = ();
                1
            }) && (do {
                my $m2 = Perlito5::Grammar::exp_stmts($str, $MATCH->{"to"});
                if ($m2) {
                    $MATCH->{"to"} = $m2->{"to"};
                    $MATCH->{"Perlito5::Grammar::exp_stmts"} = $m2;
                    1
                }
                else {;
                    0
                }
            }) && (do {
                @Perlito5::SCOPE_STMT = @{$MATCH->{"_save_scope"}};
                1
            }) && (do {
                my $m = $MATCH;
                if (!(do {
                    my $m2 = Perlito5::Grammar::Space::ws($str, $MATCH->{"to"});
                    if ($m2) {
                        $MATCH->{"to"} = $m2->{"to"};
                        1
                    }
                    else {;
                        0
                    }
                })) {;
                    $MATCH = $m
                }
                1
            }) && (do {
                my $tmp174 = $MATCH->{"to"};
                ((("}" eq $str->[($MATCH->{"to"}) + 0]) && ($MATCH->{"to"} += 1))) || ($MATCH->{"to"} = $tmp174, (do {
                    Perlito5::Compiler::error("Missing right curly or square bracket");
                    1
                }))
            }) && (do {
                $MATCH->{"capture"} = ["postfix_or_term", "block", Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::exp_stmts"})];
                1
            })))
        })));
        $tmp ? $MATCH : undef
    }
    my $Expr_end_token_chars = [7, 6, 5, 4, 3, 2, 1];
    my $Expr_end_token = {"]" => 1, ")" => 1, "}" => 1, ";" => 1, "if" => 1, "for" => 1, "else" => 1, "when" => 1, "while" => 1, "until" => 1, "elsif" => 1, "unless" => 1, "foreach" => 1, };
    my $List_end_token = {":" => 1, "or" => 1, "and" => 1, "xor" => 1, %{$Expr_end_token}, };
    my $Next_Last_Redo_end_token = {"," => 1, "=>" => 1, %{$List_end_token}, };
    my $Argument_end_token = {"," => 1, "<" => 1, ">" => 1, "=" => 1, "|" => 1, "^" => 1, "?" => 1, "=>" => 1, "lt" => 1, "le" => 1, "gt" => 1, "=>" => 1, "lt" => 1, "le" => 1, "gt" => 1, "ge" => 1, "<=" => 1, ">=" => 1, "==" => 1, "!=" => 1, "ne" => 1, "eq" => 1, ".." => 1, "~~" => 1, "&&" => 1, "||" => 1, "+=" => 1, "-=" => 1, "*=" => 1, "/=" => 1, "x=" => 1, "|=" => 1, "&=" => 1, ".=" => 1, "^=" => 1, "%=" => 1, "//" => 1, "|." => 1, "&." => 1, "^." => 1, "..." => 1, "<=>" => 1, "cmp" => 1, "<<=" => 1, ">>=" => 1, "||=" => 1, "&&=" => 1, "//=" => 1, "**=" => 1, "|.=" => 1, "&.=" => 1, "^.=" => 1, "last" => 1, "next" => 1, "redo" => 1, %{$List_end_token}, };
    sub Perlito5::Grammar::Expression::list_parser {
        (my $str, my $pos, my $end_token) = @_;
        my $last_pos = $pos;
        my $is_first_token = 1;
        my $get_token = sub {
            my $last_is_term = $_[0];
            my $v;
            my $m = Perlito5::Grammar::Precedence::op_parse($str, $last_pos, $last_is_term);
            if (!$m) {;
                return ["end", "*end*"]
            }
            my $spc = Perlito5::Grammar::Space::ws($str, $m->{"to"});
            if ($spc) {;
                $m->{"to"} = $spc->{"to"}
            }
            $v = $m->{"capture"};
            if ($is_first_token && ($v->[0] eq "op") && !Perlito5::Grammar::Precedence::is_fixity_type("prefix", $v->[1])) {;
                $v->[0] = "end"
            }
            if ($v->[0] ne "end") {;
                $last_pos = $m->{"to"}
            }
            $is_first_token = 0;
            return $v
        };
        my $res = Perlito5::Grammar::Precedence::precedence_parse($get_token, $end_token, $Expr_end_token_chars);
        if (scalar(@{$res}) == 0) {;
            return {"str" => $str, "from" => $pos, "to" => $last_pos, "capture" => "*undef*", }
        }
        my $result = Perlito5::Grammar::Expression::pop_term($res);
        return {"str" => $str, "from" => $pos, "to" => $last_pos, "capture" => $result, }
    }
    sub Perlito5::Grammar::Expression::next_last_redo_parse {
        (my $str, my $pos) = @_;
        return Perlito5::Grammar::Expression::list_parser($str, $pos, $Next_Last_Redo_end_token)
    }
    sub Perlito5::Grammar::Expression::argument_parse {
        (my $str, my $pos) = @_;
        my $m = Perlito5::Grammar::Expression::list_parser($str, $pos, $Argument_end_token);
        if ($m->{"capture"} eq "*undef*") {
            my $term = Perlito5::Grammar::String::term_glob($str, $pos);
            if ($term) {
                $m->{"capture"} = $term->{"capture"}->[1];
                $m->{"to"} = $term->{"to"}
            }
        }
        return $m
    }
    sub Perlito5::Grammar::Expression::list_parse {
        (my $str, my $pos) = @_;
        return Perlito5::Grammar::Expression::list_parser($str, $pos, $List_end_token)
    }
    sub Perlito5::Grammar::Expression::circumfix_parse {
        (my $str, my $pos, my $delimiter) = @_;
        my $last_pos = $pos;
        my $get_token = sub {
            my $last_is_term = $_[0];
            my $m = Perlito5::Grammar::Precedence::op_parse($str, $last_pos, $last_is_term);
            if (!$m) {
                my $msg = "Expected closing delimiter: " . $delimiter;
                ($delimiter eq "}" || $delimiter eq "]") && ($msg = "Missing right curly or square bracket");
                Perlito5::Compiler::error($msg . " near ", $last_pos)
            }
            my $spc = Perlito5::Grammar::Space::ws($str, $m->{"to"});
            if ($spc) {;
                $m->{"to"} = $spc->{"to"}
            }
            my $v = $m->{"capture"};
            if ($v->[0] ne "end") {;
                $last_pos = $m->{"to"}
            }
            return $v
        };
        my %delim_token;
        $delim_token{$delimiter} = 1;
        my $res = Perlito5::Grammar::Precedence::precedence_parse($get_token, \%delim_token, [length($delimiter)]);
        $res = Perlito5::Grammar::Expression::pop_term($res);
        if (!defined($res)) {;
            $res = "*undef*"
        }
        return {"str" => $str, "from" => $pos, "to" => $last_pos, "capture" => $res, }
    }
    sub Perlito5::Grammar::Expression::ternary5_parse {;
        return Perlito5::Grammar::Expression::circumfix_parse(@_, ":")
    }
    sub Perlito5::Grammar::Expression::curly_parse {;
        return Perlito5::Grammar::Expression::circumfix_parse(@_, "}")
    }
    sub Perlito5::Grammar::Expression::square_parse {;
        return Perlito5::Grammar::Expression::circumfix_parse(@_, "]")
    }
    sub Perlito5::Grammar::Expression::paren_parse {;
        return Perlito5::Grammar::Expression::circumfix_parse(@_, ")")
    }
    sub Perlito5::Grammar::Expression::exp_parse {
        (my $str, my $pos) = @_;
        my $last_pos = $pos;
        my $get_token = sub {
            my $last_is_term = $_[0];
            my $v;
            my $m = Perlito5::Grammar::Precedence::op_parse($str, $last_pos, $last_is_term);
            if (!$m) {;
                return ["end", "*end*"]
            }
            my $spc = Perlito5::Grammar::Space::ws($str, $m->{"to"});
            if ($spc) {;
                $m->{"to"} = $spc->{"to"}
            }
            $v = $m->{"capture"};
            if ($v->[0] ne "end") {;
                $last_pos = $m->{"to"}
            }
            return $v
        };
        my $res = Perlito5::Grammar::Precedence::precedence_parse($get_token, $Expr_end_token, $Expr_end_token_chars);
        if (scalar(@{$res}) == 0) {;
            return 0
        }
        my $result = Perlito5::Grammar::Expression::pop_term($res);
        return {"str" => $str, "from" => $pos, "to" => $last_pos, "capture" => $result, }
    }
    1
}
;1
