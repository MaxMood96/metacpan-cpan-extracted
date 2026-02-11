#!/usr/bin/env bats

# Load the helper (which loads bats-support and bats-assert)
load test_helper.bash
# Source getoptlong.sh to make its functions available for testing
. ../script/getoptlong.sh

# Test: permute - options after non-option argument
@test "getoptlong: permute - option after non-option arg" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([verbose|v]= [file|f:]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse --verbose arg1 --file data.txt
        eval "$(getoptlong set)"
        echo "verbose:$verbose"
        echo "file:$file"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "verbose:1"
    assert_line --index 1 "file:data.txt"
    assert_line --index 2 "argv:arg1"
}

# Test: permute - single option with arg after non-option
@test "getoptlong: permute - single -f val after non-option" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([file|f:]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 -f data.txt
        eval "$(getoptlong set)"
        echo "file:$file"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "file:data.txt"
    assert_line --index 1 "argv:arg1"
}

# Test: permute - two options with args after non-option
@test "getoptlong: permute - two -f val after non-option" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([item|i@]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 -i val1 -i val2
        eval "$(getoptlong set)"
        echo "items:${item[*]}"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "items:val1 val2"
    assert_line --index 1 "argv:arg1"
}

# Test: permute - three options with args after non-option
@test "getoptlong: permute - three -i val after non-option" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([item|i@]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 -i val1 -i val2 -i val3
        eval "$(getoptlong set)"
        echo "items:${item[*]}"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "items:val1 val2 val3"
    assert_line --index 1 "argv:arg1"
}

# Test: permute - --no-item then options before and after non-option
# Triggers OPTIND out-of-bounds in ${!OPTIND} at gol_parse_ line 304
@test "getoptlong: permute - --no-item -i val1 arg -i val2 -i val3" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([debug|d]= [item|i@]=default)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse -d --no-item -i val1 arg1 -i val2 -i val3
        eval "$(getoptlong set)"
        echo "debug:$debug"
        echo "items:${item[*]}"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "debug:1"
    assert_line --index 1 "items:val1 val2 val3"
    assert_line --index 2 "argv:arg1"
}

# Test: permute - multiple non-options interspersed with options
@test "getoptlong: permute - interspersed args and options" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([verbose|v]= [file|f:]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 --verbose arg2 --file data.txt arg3
        eval "$(getoptlong set)"
        echo "verbose:$verbose"
        echo "file:$file"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "verbose:1"
    assert_line --index 1 "file:data.txt"
    assert_line --index 2 "argv:arg1 arg2 arg3"
}

# Test: permute - options with args at end of argument list
@test "getoptlong: permute - options at end of args" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([debug|d]= [file|f:]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 arg2 -d --file last.txt
        eval "$(getoptlong set)"
        echo "debug:$debug"
        echo "file:$file"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "debug:1"
    assert_line --index 1 "file:last.txt"
    assert_line --index 2 "argv:arg1 arg2"
}

# Test: permute - flag options followed by option-with-arg at end
@test "getoptlong: permute - flag then option-with-arg at end" {
    run $BASH -c '
        . ../script/getoptlong.sh
        declare -A OPTS=([verbose|v]= [debug|d]= [file|f:]=)
        declare -a ARGV=()
        getoptlong init OPTS PERMUTE=ARGV
        getoptlong parse arg1 -v -d -f data.txt
        eval "$(getoptlong set)"
        echo "verbose:$verbose"
        echo "debug:$debug"
        echo "file:$file"
        echo "argv:${ARGV[*]}"
    '
    assert_success
    assert_line --index 0 "verbose:1"
    assert_line --index 1 "debug:1"
    assert_line --index 2 "file:data.txt"
    assert_line --index 3 "argv:arg1"
}
