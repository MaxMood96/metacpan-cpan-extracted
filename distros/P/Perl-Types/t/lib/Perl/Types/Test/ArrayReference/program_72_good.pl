#!/usr/bin/env perl

# [[[ PREPROCESSOR ]]]
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_compact($array_1D) = ['hi','hello','howdy','how do you do','hey']" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string($array_1D)         = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_pretty($array_1D)  = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_expand($array_1D)  =" >>>
# <<< EXECUTE_SUCCESS: "[" >>>
# <<< EXECUTE_SUCCESS: "    'hi'," >>>
# <<< EXECUTE_SUCCESS: "    'hello'," >>>
# <<< EXECUTE_SUCCESS: "    'howdy'," >>>
# <<< EXECUTE_SUCCESS: "    'how do you do'," >>>
# <<< EXECUTE_SUCCESS: "    'hey'" >>>
# <<< EXECUTE_SUCCESS: "]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D, -2, 0) = ['hi','hello','howdy','how do you do','hey']" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D, -1, 0) = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D,  0, 0) = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D,  1, 0) =" >>>
# <<< EXECUTE_SUCCESS: "[" >>>
# <<< EXECUTE_SUCCESS: "    'hi'," >>>
# <<< EXECUTE_SUCCESS: "    'hello'," >>>
# <<< EXECUTE_SUCCESS: "    'howdy'," >>>
# <<< EXECUTE_SUCCESS: "    'how do you do'," >>>
# <<< EXECUTE_SUCCESS: "    'hey'" >>>
# <<< EXECUTE_SUCCESS: "]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D, -2, 1) = ['hi','hello','howdy','how do you do','hey']" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D, -1, 1) = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D,  0, 1) = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ]" >>>
# <<< EXECUTE_SUCCESS: "have arrayref_string_to_string_format($array_1D,  1, 1) =" >>>
# <<< EXECUTE_SUCCESS: "    [" >>>
# <<< EXECUTE_SUCCESS: "        'hi'," >>>
# <<< EXECUTE_SUCCESS: "        'hello'," >>>
# <<< EXECUTE_SUCCESS: "        'howdy'," >>>
# <<< EXECUTE_SUCCESS: "        'how do you do'," >>>
# <<< EXECUTE_SUCCESS: "        'hey'" >>>
# <<< EXECUTE_SUCCESS: "    ]" >>>

# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

# [[[ OPERATIONS ]]]

my arrayref::string $array_1D = [ 'hi', 'hello', 'howdy', 'how do you do', 'hey' ];

print 'have arrayref_string_to_string_compact($array_1D) = ', arrayref_string_to_string_compact($array_1D), "\n";
print 'have arrayref_string_to_string($array_1D)         = ', arrayref_string_to_string($array_1D), "\n";
print 'have arrayref_string_to_string_pretty($array_1D)  = ', arrayref_string_to_string_pretty($array_1D), "\n";
print 'have arrayref_string_to_string_expand($array_1D)  = ', "\n", arrayref_string_to_string_expand($array_1D), "\n";

print 'have arrayref_string_to_string_format($array_1D, -2, 0) = ', arrayref_string_to_string_format($array_1D, -2, 0), "\n";
print 'have arrayref_string_to_string_format($array_1D, -1, 0) = ', arrayref_string_to_string_format($array_1D, -1, 0), "\n";
print 'have arrayref_string_to_string_format($array_1D,  0, 0) = ', arrayref_string_to_string_format($array_1D, 0, 0), "\n";
print 'have arrayref_string_to_string_format($array_1D,  1, 0) = ', "\n", arrayref_string_to_string_format($array_1D, 1, 0), "\n";

print 'have arrayref_string_to_string_format($array_1D, -2, 1) = ', arrayref_string_to_string_format($array_1D, -2, 1), "\n";
print 'have arrayref_string_to_string_format($array_1D, -1, 1) = ', arrayref_string_to_string_format($array_1D, -1, 1), "\n";
print 'have arrayref_string_to_string_format($array_1D,  0, 1) = ', arrayref_string_to_string_format($array_1D, 0, 1), "\n";
print 'have arrayref_string_to_string_format($array_1D,  1, 1) = ', "\n", arrayref_string_to_string_format($array_1D, 1, 1), "\n";
