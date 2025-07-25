#!./perl -w

# Verify that all files generated by perl scripts are up to date.

BEGIN {
    if (-f "./TestInit.pm") {
        push @INC, ".";
    } elsif (-f '../TestInit.pm') {
        push @INC, "..";
    }
}
use TestInit qw(T A); # T is chdir to the top level, A makes paths absolute
use strict;

# this tests the functions in HeaderParser.pm which we use for make regen.

require './t/test.pl';
require './regen/HeaderParser.pm';

skip_all_if_miniperl("needs Data::Dumper");

# It could fairly easily be ported, but no need to do so, so far
our $IS_EBCDIC;
skip_all("HeaderParser hasn't been ported to EBCDIC") if $::IS_EBCDIC;

require Data::Dumper;

my $update_key= "PERL_DEV_UPDATE_TESTFILE";
my $is_term = -t;

sub show_text {
    my ($as_text, $can_update)= @_;
    print STDERR "\n# Full text is as follows:\n\n" if $is_term;
    print STDERR $as_text=~s/^/" " x 8/mger;
    print STDERR <<EOF_BLURB if $is_term and $can_update

# You can set the env var $update_key to true and rerun
# this test script ($0) to automatically fix this test.
# Eg:
#
#   $update_key=1 ./perl -Ilib $0

EOF_BLURB
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(indent_defines=>1);
    $hp->parse_text(<<~'EOF');
        #ifdef A
        #ifdef B
        #define AB
        content 1
        #endif
        content 2
        #define A
        #endif
        /*comment
          line */
        #define C /* this is
                     a hidden line continuation */ D
        #de\
        fine E\
        F 42 /\
        * a different kind of
        hidden line continuation *\
        /
        #\
        if defined E\
        F
        #endif
        # /* null directive */
        #error #undef
        #error #pragma
        #error #include
        #error #define
        #if 1
        #if CH == 'x' || CH == '\\' || CH == '\n' || CH == 'AB'
        #define CH_IS_IT
        #endif
        #endif
        #if defined          (foo)
        foo
        #endif
        #if (CH == '\a' ||          /* Bell (alert) */           \
             CH == '\b'   || /* Backspace */ \
                CH == '\f'   ||       /* Form feed */ \
             CH == '\n'   || /* Newline */ \
             CH == '\r'   || /* Carriage return */ \
                    CH == '\t'   || /* Horizontal tab */ \
             CH == '\v'   || /* Vertical tab */ \
             CH == '\''         || /* Single quote */ \
              CH == '\"'   || /* Double quote (rare in single quotes) */ \
             CH == '\?'   || /* Question mark (avoids trigraphs) */ \
                CH == '\\'   || /* Backslash */ \
             CH == '\102' || /* Octal escape for 'B' (ASCII 66) */ \
             CH == '\x43')   /* Hexadecimal escape for 'C' (ASCII 67) */
                    #define MATCH 1
        #else
            #define MATCH 0
        #endif
        EOF

    my $normal= $hp->lines_as_str();
    my $lines= $hp->lines();
    my $lines_dump= Data::Dumper->new([$lines])->Sortkeys(1)->Useqq(1)->Indent(1)->Dump();


    if ($ENV{$update_key}) {
        open my $ifh, "<", $0 or die "Failed to read '$0': $!";
        open my $ofh, ">", "$0.tmp" or die "Failed to open for write: '$0.tmp': $!";
        my %content = (
            'EOF_DUMP'   => $lines_dump,
            'EOF_NORMAL' => $normal
        );
        while (<$ifh>) {
            if (/^\s*is\b.*<<~'(EOF_\w+)'/) {
                my $here_doc_name = $1;
                print $ofh $_;
                my $indent= " " x 8;
                print $ofh $content{$here_doc_name} =~ s/^/$indent/mgr;
                while (<$ifh>) {
                    next unless /^\s+$here_doc_name\s*$/;
                    print $ofh $_;
                    last;
                }
            } else {
                print $ofh $_;
            }
        }
        close $ofh;
        close $ifh;
        rename "$0.tmp", "$0" or die "Failed to rename '$0.tmp' to '$0': $!";
    }

    is($lines_dump,<<~'EOF_DUMP', "Simple data structure as expected") or show_text($lines_dump,1);
        $VAR1 = [
          bless( {
            "cond" => [
              [
                "defined(A)"
              ]
            ],
            "flat" => "#if defined(A)",
            "level" => 0,
            "line" => "#if defined(A)\n",
            "n_lines" => 1,
            "raw" => "#ifdef A\n",
            "source" => "(buffer)",
            "start_line_num" => 1,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ],
              [
                "defined(B)"
              ]
            ],
            "flat" => "#if defined(B)",
            "level" => 1,
            "line" => "# if defined(B)\n",
            "n_lines" => 1,
            "raw" => "#ifdef B\n",
            "source" => "(buffer)",
            "start_line_num" => 2,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ],
              [
                "defined(B)"
              ]
            ],
            "flat" => "#define AB",
            "level" => 2,
            "line" => "#   define AB\n",
            "n_lines" => 1,
            "raw" => "#define AB\n",
            "source" => "(buffer)",
            "start_line_num" => 3,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ],
              [
                "defined(B)"
              ]
            ],
            "flat" => "content 1",
            "level" => 2,
            "line" => "content 1\n",
            "n_lines" => 1,
            "raw" => "content 1\n",
            "source" => "(buffer)",
            "start_line_num" => 4,
            "sub_type" => "text",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ],
              [
                "defined(B)"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 3,
            "level" => 1,
            "line" => "# endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 5,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ]
            ],
            "flat" => "content 2",
            "level" => 1,
            "line" => "content 2\n",
            "n_lines" => 1,
            "raw" => "content 2\n",
            "source" => "(buffer)",
            "start_line_num" => 6,
            "sub_type" => "text",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ]
            ],
            "flat" => "#define A",
            "level" => 1,
            "line" => "# define A\n",
            "n_lines" => 1,
            "raw" => "#define A\n",
            "source" => "(buffer)",
            "start_line_num" => 7,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(A)"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 7,
            "level" => 0,
            "line" => "#endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 8,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "",
            "level" => 0,
            "line" => "/*comment\n  line */\n",
            "n_lines" => 2,
            "raw" => "/*comment\n  line */\n",
            "source" => "(buffer)",
            "start_line_num" => 9,
            "sub_type" => "text",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#define C D",
            "level" => 0,
            "line" => "#define C /* this is\n             a hidden line continuation */ D\n",
            "n_lines" => 2,
            "raw" => "#define C /* this is\n             a hidden line continuation */ D\n",
            "source" => "(buffer)",
            "start_line_num" => 11,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#define EF 42",
            "level" => 0,
            "line" => "#de\\\nfine E\\\nF 42 /\\\n* a different kind of\nhidden line continuation *\\\n/\n",
            "n_lines" => 6,
            "raw" => "#de\\\nfine E\\\nF 42 /\\\n* a different kind of\nhidden line continuation *\\\n/\n",
            "source" => "(buffer)",
            "start_line_num" => 13,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(EF)"
              ]
            ],
            "flat" => "#if defined(EF)",
            "level" => 0,
            "line" => "#if defined(EF)\n",
            "n_lines" => 3,
            "raw" => "#\\\nif defined E\\\nF\n",
            "source" => "(buffer)",
            "start_line_num" => 19,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(EF)"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 3,
            "level" => 0,
            "line" => "#endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 22,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#",
            "level" => 0,
            "line" => "# /* null directive */\n",
            "n_lines" => 1,
            "raw" => "# /* null directive */\n",
            "source" => "(buffer)",
            "start_line_num" => 23,
            "sub_type" => "text",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#error #undef",
            "level" => 0,
            "line" => "#error #undef\n",
            "n_lines" => 1,
            "raw" => "#error #undef\n",
            "source" => "(buffer)",
            "start_line_num" => 24,
            "sub_type" => "#error",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#error #pragma",
            "level" => 0,
            "line" => "#error #pragma\n",
            "n_lines" => 1,
            "raw" => "#error #pragma\n",
            "source" => "(buffer)",
            "start_line_num" => 25,
            "sub_type" => "#error",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#error #include",
            "level" => 0,
            "line" => "#error #include\n",
            "n_lines" => 1,
            "raw" => "#error #include\n",
            "source" => "(buffer)",
            "start_line_num" => 26,
            "sub_type" => "#error",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [],
            "flat" => "#error #define",
            "level" => 0,
            "line" => "#error #define\n",
            "n_lines" => 1,
            "raw" => "#error #define\n",
            "source" => "(buffer)",
            "start_line_num" => 27,
            "sub_type" => "#error",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                1
              ]
            ],
            "flat" => "#if 1",
            "level" => 0,
            "line" => "#if 1\n",
            "n_lines" => 1,
            "raw" => "#if 1\n",
            "source" => "(buffer)",
            "start_line_num" => 28,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                1
              ],
              [
                "CH == '\\\\' || CH == 'AB' || CH == '\\n' || CH == 'x'"
              ]
            ],
            "flat" => "#if CH == '\\\\' || CH == 'AB' || CH == '\\n' || CH == 'x'",
            "level" => 1,
            "line" => "# if CH == '\\\\' || CH == 'AB' || CH == '\\n' || CH == 'x'\n",
            "n_lines" => 1,
            "raw" => "#if CH == 'x' || CH == '\\\\' || CH == '\\n' || CH == 'AB'\n",
            "source" => "(buffer)",
            "start_line_num" => 29,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                1
              ],
              [
                "CH == '\\\\' || CH == 'AB' || CH == '\\n' || CH == 'x'"
              ]
            ],
            "flat" => "#define CH_IS_IT",
            "level" => 2,
            "line" => "#   define CH_IS_IT\n",
            "n_lines" => 1,
            "raw" => "#define CH_IS_IT\n",
            "source" => "(buffer)",
            "start_line_num" => 30,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                1
              ],
              [
                "CH == '\\\\' || CH == 'AB' || CH == '\\n' || CH == 'x'"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 2,
            "level" => 1,
            "line" => "# endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 31,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                1
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 4,
            "level" => 0,
            "line" => "#endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 32,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(foo)"
              ]
            ],
            "flat" => "#if defined(foo)",
            "level" => 0,
            "line" => "#if defined(foo)\n",
            "n_lines" => 1,
            "raw" => "#if defined          (foo)\n",
            "source" => "(buffer)",
            "start_line_num" => 33,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(foo)"
              ]
            ],
            "flat" => "foo",
            "level" => 1,
            "line" => "foo\n",
            "n_lines" => 1,
            "raw" => "foo\n",
            "source" => "(buffer)",
            "start_line_num" => 34,
            "sub_type" => "text",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "defined(foo)"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 2,
            "level" => 0,
            "line" => "#endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 35,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?'"
              ]
            ],
            "flat" => "#if CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?'",
            "level" => 0,
            "line" => "#if CH == '\\\"' || CH == '\\''   || CH == '\\\\' || CH == '\\102' || CH == '\\a' || \\\n    CH == '\\b' || CH == '\\f'   || CH == '\\n' || CH == '\\r'   || CH == '\\t' || \\\n    CH == '\\v' || CH == '\\x43' || CH == '\\?'\n",
            "n_lines" => 13,
            "raw" => "#if (CH == '\\a' ||          /* Bell (alert) */           \\\n     CH == '\\b'   || /* Backspace */ \\\n        CH == '\\f'   ||       /* Form feed */ \\\n     CH == '\\n'   || /* Newline */ \\\n     CH == '\\r'   || /* Carriage return */ \\\n            CH == '\\t'   || /* Horizontal tab */ \\\n     CH == '\\v'   || /* Vertical tab */ \\\n     CH == '\\''         || /* Single quote */ \\\n      CH == '\\\"'   || /* Double quote (rare in single quotes) */ \\\n     CH == '\\?'   || /* Question mark (avoids trigraphs) */ \\\n        CH == '\\\\'   || /* Backslash */ \\\n     CH == '\\102' || /* Octal escape for 'B' (ASCII 66) */ \\\n     CH == '\\x43')   /* Hexadecimal escape for 'C' (ASCII 67) */\n",
            "source" => "(buffer)",
            "start_line_num" => 36,
            "sub_type" => "#if",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?'"
              ]
            ],
            "flat" => "#define MATCH 1",
            "level" => 1,
            "line" => "# define MATCH 1\n",
            "n_lines" => 1,
            "raw" => "            #define MATCH 1\n",
            "source" => "(buffer)",
            "start_line_num" => 49,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "!( CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?' )"
              ]
            ],
            "flat" => "#else",
            "level" => 0,
            "line" => "#else\n",
            "n_lines" => 1,
            "raw" => "#else\n",
            "source" => "(buffer)",
            "start_line_num" => 50,
            "sub_type" => "#else",
            "type" => "cond"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "!( CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?' )"
              ]
            ],
            "flat" => "#define MATCH 0",
            "level" => 1,
            "line" => "# define MATCH 0\n",
            "n_lines" => 1,
            "raw" => "    #define MATCH 0\n",
            "source" => "(buffer)",
            "start_line_num" => 51,
            "sub_type" => "#define",
            "type" => "content"
          }, 'HeaderLine' ),
          bless( {
            "cond" => [
              [
                "!( CH == '\\\"' || CH == '\\'' || CH == '\\\\' || CH == '\\102' || CH == '\\a' || CH == '\\b' || CH == '\\f' || CH == '\\n' || CH == '\\r' || CH == '\\t' || CH == '\\v' || CH == '\\x43' || CH == '\\?' )"
              ]
            ],
            "flat" => "#endif",
            "inner_lines" => 2,
            "level" => 0,
            "line" => "#endif\n",
            "n_lines" => 1,
            "raw" => "#endif\n",
            "source" => "(buffer)",
            "start_line_num" => 52,
            "sub_type" => "#endif",
            "type" => "cond"
          }, 'HeaderLine' )
        ];
        EOF_DUMP

    is($normal,<<~'EOF_NORMAL',"Normalized text as expected") || show_text($normal,1);
        #if defined(A)
        # if defined(B)
        #   define AB
        content 1
        # endif
        content 2
        # define A
        #endif
        /*comment
          line */
        #define C /* this is
                     a hidden line continuation */ D
        #de\
        fine E\
        F 42 /\
        * a different kind of
        hidden line continuation *\
        /
        #if defined(EF)
        #endif
        # /* null directive */
        #error #undef
        #error #pragma
        #error #include
        #error #define
        #if 1
        # if CH == '\\' || CH == 'AB' || CH == '\n' || CH == 'x'
        #   define CH_IS_IT
        # endif
        #endif
        #if defined(foo)
        foo
        #endif
        #if CH == '\"' || CH == '\''   || CH == '\\' || CH == '\102' || CH == '\a' || \
            CH == '\b' || CH == '\f'   || CH == '\n' || CH == '\r'   || CH == '\t' || \
            CH == '\v' || CH == '\x43' || CH == '\?'
        # define MATCH 1
        #else
        # define MATCH 0
        #endif
        EOF_NORMAL
    {
        local $::TODO = "We currently don't handle comments in expressions properly";
        ok($normal=~/Vertical tab/ ? 1 : 0,"comments in logical expressions");
    }
    is(join("\n",@warn),"", "No warnings generated from main parse");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $ok= eval {
        HeaderParser->new(add_commented_expr_after=>0)->parse_text(<<~'EOF'); 1
        #ifdef A
        #ifdef B
        #endif
        EOF
    };
    my $err= !$ok ? $@ : "";
    ok(!$ok, my $tname= "Should throw an error, missing #endif");
    like($err,qr/Unterminated conditional block starting line 1 with last conditional operation at line 3/,
         "Got expected error message");
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $ok= eval {
        HeaderParser->new(add_commented_expr_after=>0)->parse_text(<<~'EOF'); 1
        #ifdef A
        #ifdef B
        #elif C
        EOF
    };
    my $err= !$ok ? $@ : "";
    ok(!$ok, my $tname= "Should throw an error, unterminated #if");
    like($err,qr/Unterminated conditional block starting line 3/,
         "Unterminated block detected");
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $ok= eval {
        HeaderParser->new(add_commented_expr_after=>0)->parse_text(<<~'EOF'); 1
        #if 1 * * 10 > 5
        #elifdef C
        EOF
    };
    my $err= !$ok ? $@ : "";
    ok(!$ok, my $tname= "Should throw an error, bad directive");
    is($err,
       "Error at line 1\n" .
       "Line 1: #if 1 * * 10 > 5\n" .
       "Error in multiplication expression: " .
       "Unexpected token '*', expecting literal, unary, or expression.\n",
         "Expected token error") or warn $err;
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);

    $hp->parse_text(<<~'EOF');
        #ifdef A
        # ifdef B
        #   define P
        # else
        #   define Q
        # endif
        # if !defined B
        #   define R
        # else
        #   define S
        # endif
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF',my $tname= "inverted simple clauses get merged properly") or show_text($as_text);
        #if defined(A)
        # if defined(B)
        #   define P
        #   define S
        # else /* if !defined(B) */
        #   define Q
        #   define R
        # endif /* !defined(B) */
        #endif /* defined(A) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A) && defined(B)
        # if (defined(C) && defined(D))
        #   define P
        # else
        #   define Q
        # endif
        # if !(defined C && defined D)
        #   define R
        # else
        #   define S
        # endif
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "inverted complex clauses get merged properly") or show_text($as_text);
        #if defined(A) && defined(B)
        # if defined(C) && defined(D)
        #   define P
        #   define S
        # else /* if !( defined(C) && defined(D) ) */
        #   define Q
        #   define R
        # endif /* !( defined(C) && defined(D) ) */
        #endif /* defined(A) && defined(B) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A)
        #define HAS_A
        #elif defined(B)
        #define HAS_B
        #elif defined(C)
        #define HAS_C
        #else
        #define HAS_D
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "nested elif round trip") or show_text($as_text);
        #if defined(A)
        # define HAS_A
        #elif defined(B) /* && !defined(A) */
        # define HAS_B
        #elif defined(C) /* && !defined(A) && !defined(B) */
        # define HAS_C
        #else /* if !defined(A) && !defined(B) && !defined(C) */
        # define HAS_D
        #endif /* !defined(A) && !defined(B) && !defined(C) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A)
        #define HAS_A
        #endif
        #if !defined(A) && defined(B)
        #define HAS_B
        #endif
        #if defined(C)
        #if !defined(A)
        #if !defined(B)
        #define HAS_C
        #endif
        #endif
        #endif
        #if !defined(B) && !defined(A) && !defined(C)
        #define HAS_D
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF',my $tname= "test elif composition from disparate statements") or show_text($as_text);
        #if defined(A)
        # define HAS_A
        #elif defined(B) /* && !defined(A) */
        # define HAS_B
        #elif defined(C) /* && !defined(A) && !defined(B) */
        # define HAS_C
        #else /* if !defined(A) && !defined(B) && !defined(C) */
        # define HAS_D
        #endif /* !defined(A) && !defined(B) && !defined(C) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A)
        #define HAS_A
        #endif
        #if !defined(A)
        #define HAS_NOT_A
        #if !defined(C)
        #define HAS_A_NOT_C
        #endif
        #endif
        #if defined(C)
        #define HAS_C
        #if defined(A)
        #define HAS_A_C
        #endif
        #else
        #if defined(A)
        #define HAS_NOT_C_A
        #endif
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "test else composition") or show_text($as_text);
        #if defined(A)
        # define HAS_A
        # if defined(C)
        #   define HAS_A_C
        # else /* if !defined(C) */
        #   define HAS_NOT_C_A
        # endif /* !defined(C) */
        #else /* if !defined(A) */
        # define HAS_NOT_A
        # if !defined(C)
        #   define HAS_A_NOT_C
        # endif /* !defined(C) */
        #endif /* !defined(A) */
        #if defined(C)
        # define HAS_C
        #endif /* defined(C) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if !defined(A)
        #define NOT_A1
        #else
        #define A1
        #endif
        #if !!!!defined(A)
        #define A2
        #else
        #define NOT_A2
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "normalization into if/else") or show_text($as_text);
        #if defined(A)
        # define A1
        # define A2
        #else /* if !defined(A) */
        # define NOT_A1
        # define NOT_A2
        #endif /* !defined(A) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if !!!(defined(A) && defined(B))
        #define NOT_A_AND_B
        #endif
        #if defined(A)
        #if defined(B)
        #define A_AND_B
        #endif
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF',my $tname = "normalization with complex else") or show_text($as_text);
        #if defined(A) && defined(B)
        # define A_AND_B
        #else /* if !( defined(A) && defined(B) ) */
        # define NOT_A_AND_B
        #endif /* !( defined(A) && defined(B) ) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A) && !!defined(A) && !!!!defined(A)
        #define HAS_A
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname = "simplification") or show_text($as_text);
        #if defined(A)
        # define HAS_A
        #endif /* defined(A) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $tname = "simplification by absorbtion";
    {
        local $::TODO = "Absorbtion not implemented yet";
        # currently we don't handle absorbtion: (A && (A || B || C ...)) == A
        my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
        $hp->parse_text(<<~'EOF');
            #if defined(X) && (defined(X) || defined(Y))
            #define HAS_X
            #endif
            EOF
        my $grouped= $hp->group_content();
        my $as_text= $hp->lines_as_str($grouped);
        is($as_text,<<~'EOF', $tname); # or show_text($as_text);
            #if defined(X)
            # define HAS_X
            #endif /* defined(X) */
            EOF
    }
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if defined(A) && (defined(B) && defined(C))
        #define HAS_A
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "expression flattening") or show_text($as_text);
        #if defined(A) && defined(B) && defined(C)
        # define HAS_A
        #endif /* defined(A) && defined(B) && defined(C) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>3);
    $hp->parse_text(<<~'EOF');
        #if defined(A)
        #define HAS_A1
        #define HAS_A2
        #define HAS_A3
        #endif
        #if defined(B)
        #define HAS_B1
        #else
        #define HAS_B1e
        #define HAS_B2e
        #define HAS_B3e
        #endif
        #if defined(C)
        #if defined(D)
        #define HAS_D1
        #endif
        #elif defined(CC)
        #define HAS_CC1
        #define HAS_CC2
        #define HAS_CC3
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "auto-comments") or show_text($as_text);
        #if defined(A)
        # define HAS_A1
        # define HAS_A2
        # define HAS_A3
        #endif /* defined(A) */
        #if defined(B)
        # define HAS_B1
        #else
        # define HAS_B1e
        # define HAS_B2e
        # define HAS_B3e
        #endif /* !defined(B) */
        #if defined(C)
        # if defined(D)
        #   define HAS_D1
        # endif
        #elif defined(CC) /* && !defined(C) */
        # define HAS_CC1
        # define HAS_CC2
        # define HAS_CC3
        #endif /* !defined(C) && defined(CC) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}
{
    my @warn;
    local $SIG{__WARN__}= sub { push @warn, $_[0]; warn $_[0] };
    my $hp= HeaderParser->new(debug=>0,add_commented_expr_after=>0);
    $hp->parse_text(<<~'EOF');
        #if  defined(DEBUGGING)                                                    \
             || (defined(USE_LOCALE) && (    defined(USE_THREADS)                  \
                                        ||   defined(HAS_IGNORED_LOCALE_CATEGORIES)\
                                        ||   defined(USE_POSIX_2008_LOCALE)        \
                                        || ! defined(LC_ALL)))
        # define X
        #endif
        EOF
    my $grouped= $hp->group_content();
    my $as_text= $hp->lines_as_str($grouped);
    is($as_text,<<~'EOF', my $tname= "Karls example") or show_text($as_text);
        #if   defined(DEBUGGING) ||                                         \
            ( defined(USE_LOCALE) &&                                        \
            ( defined(HAS_IGNORED_LOCALE_CATEGORIES) || !defined(LC_ALL) || \
              defined(USE_POSIX_2008_LOCALE) || defined(USE_THREADS) ) )
        # define X
        #endif /*   defined(DEBUGGING) ||
                  ( defined(USE_LOCALE) &&
                  ( defined(HAS_IGNORED_LOCALE_CATEGORIES) || !defined(LC_ALL) ||
                    defined(USE_POSIX_2008_LOCALE) || defined(USE_THREADS) ) ) */
        EOF
    is(join("\n",@warn),"", "No warnings generated from $tname");
}

done_testing();
