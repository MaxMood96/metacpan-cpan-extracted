package Stefo;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Stefo', $VERSION);

1;

__END__

=head1 NAME

Stefo - Compile Perl subs to optimized bytecode via optree walking

=head1 SYNOPSIS

    use Stefo;
    
    # Compile a simple predicate - returns optimized checker
    my $check = Stefo::compile(sub { $_ > 0 });
    
    # Execute in C (~5 cycles instead of ~100)
    my $ok = Stefo::check($check, 42);     # true
    my $ok = Stefo::check($check, -1);     # false
    
    # Check if a sub was successfully optimized
    if (Stefo::is_optimized($check)) {
        print "Running at C speed!\n";
    }

=head1 DESCRIPTION

C<Stefo> walks Perl optrees at compile-time and extracts simple
patterns that can be executed in pure C without Perl callback overhead.

When you pass a sub to C<compile()>, it:

=over 4

=item 1. Gets the CV's optree via CvROOT

=item 2. Walks the ops looking for recognizable patterns

=item 3. Compiles matching patterns to a simple bytecode IR

=item 4. Executes that bytecode in C (~5 cycles vs ~100 for call_sv)

=back

Subs that can't be optimized fall back to normal Perl execution.

=head2 SUPPORTED PATTERNS

=head3 Numeric Comparisons

    $_ > N       $_ >= N      $_ < N       $_ <= N
    $_ == N      $_ != N

=head3 String Comparisons

    $_ eq 'str'              $_ ne 'str'

=head3 Arithmetic Operations

    $_ + N       $_ - N       $_ * N       $_ / N
    $_ % N       abs($_)      int($_)

=head3 Definedness and Boolean

    defined $_               !defined $_
    $_                       !$_
    !!$_                     (double negation for bool coercion)

=head3 Length Checks

    length($_)               length($_) > N
    length($_) == N          length($_) < N

=head3 Reference Type Checks

    ref($_)                  ref($_) eq 'ARRAY'
    ref($_) eq 'HASH'        ref($_) eq 'CODE'
    ref($_) eq 'SCALAR'      ref($_) eq 'Regexp'
    ref($_) eq 'GLOB'        ref($_) ne 'TYPE'

=head3 Regex Matching

    $_ =~ /pattern/          $_ !~ /pattern/

=head3 Boolean Logic

    EXPR && EXPR             short-circuit AND
    EXPR || EXPR             short-circuit OR
    EXPR // EXPR             defined-or
    !EXPR                    logical NOT

=head3 Complex Expressions

    $_ > 0 && $_ < 100       range check
    ($_ > 0 && $_ < 10) || $_ == 100
    $_ % 2 == 0              even check
    int($_) == $_            integer check
    abs($_) > 5              absolute value comparison

=head3 Performance Estimates

    Pattern                    Cycles (approx)
    ----------------------------------------------------------------
    Simple comparison          ~5-10
    defined/ref check          ~3-5
    String comparison          ~10-15
    Regex match                ~20-100 (varies by pattern)
    Boolean logic              +1-2 per operator
    call_sv (fallback)         ~100

Unsupported patterns (method calls, external functions, complex logic)
fall back to Perl C<call_sv>.

=head1 FUNCTIONS

=head2 compile($sub)

Compile a sub to an optimized checker. Returns an opaque blessed reference.

    my $checker = Stefo::compile(sub { $_ > 0 && $_ < 100 });

The returned object can be passed to C<check()>.

=head2 check($checker, $value)

Execute a compiled checker against a value. Returns true/false.

    my $ok = Stefo::check($checker, 42);

If the sub wasn't optimizable, this falls back to calling the original sub.

=head2 is_optimized($checker)

Returns true if the sub was successfully compiled to bytecode.

    if (Stefo::is_optimized($checker)) {
        # Running at C speed
    }

=head2 instruction_count($checker)

Returns the number of bytecode instructions (for debugging/profiling).

=head1 DIRECT HELPER FUNCTIONS

Stefo also provides direct XS helper functions that don't require
compilation. These are fast C implementations for common type checks.

=head2 Type Checks

    Stefo::is_array($val)       # true if ARRAY ref
    Stefo::is_hash($val)        # true if HASH ref
    Stefo::is_code($val)        # true if CODE ref
    Stefo::is_ref($val)         # true if any reference
    Stefo::is_scalar($val)      # true if SCALAR ref
    Stefo::is_regexp($val)      # true if Regexp ref
    Stefo::is_glob($val)        # true if GLOB ref
    Stefo::is_blessed($val)     # true if blessed object

=head2 Value Checks

    Stefo::is_defined($val)     # true if defined
    Stefo::is_undef($val)       # true if undef
    Stefo::is_true($val)        # true if Perl-true
    Stefo::is_false($val)       # true if Perl-false
    Stefo::looks_like_number($val)  # true if numeric

=head2 Numeric Checks

    Stefo::is_integer($val)     # true if integer value
    Stefo::is_positive($val)    # true if > 0
    Stefo::is_negative($val)    # true if < 0
    Stefo::is_zero($val)        # true if == 0
    Stefo::is_even($val)        # true if even integer
    Stefo::is_odd($val)         # true if odd integer

=head2 String Checks

    Stefo::is_empty_string($val)     # true if ""
    Stefo::is_nonempty_string($val)  # true if length > 0
    Stefo::is_alpha($val)            # all alphabetic
    Stefo::is_alnum($val)            # all alphanumeric
    Stefo::is_digit($val)            # all digits
    Stefo::is_space($val)            # all whitespace
    Stefo::is_word_char($val)        # all word characters (\w)
    Stefo::is_upper($val)            # all uppercase
    Stefo::is_lower($val)            # all lowercase
    Stefo::is_ascii($val)            # all ASCII (0-127)
    Stefo::is_printable($val)        # all printable

=head2 String Operations

    Stefo::string_contains($str, $needle)    # substring search
    Stefo::string_starts_with($str, $prefix) # prefix check
    Stefo::string_ends_with($str, $suffix)   # suffix check

=head2 Collection Checks

    Stefo::array_length($val)   # number of elements (-1 if not array)
    Stefo::hash_size($val)      # number of keys (-1 if not hash)
    Stefo::is_array_empty($val) # true if empty array
    Stefo::is_hash_empty($val)  # true if empty hash

=head2 Type Inspection

    Stefo::typeof($val)     # returns: UNDEF, INTEGER, NUMBER, STRING,
                            #          ARRAY, HASH, CODE, REGEXP, GLOB,
                            #          SCALAR, OBJECT, UNKNOWN
    Stefo::reftype($val)    # returns ref type or undef

=head1 USE CASES

=head2 Type Constraints

    # Before: ~100 cycles per check
    object::register_type('PositiveInt', sub { $_ > 0 });
    
    # After: ~5 cycles per check
    my $check = Stefo::compile(sub { $_ > 0 });
    object::register_type_compiled('PositiveInt', $check);

=head2 Hot Loop Predicates

    # Before: call_sv overhead per element
    my @valid = grep { $_ > 0 && $_ < 100 } @huge_list;
    
    # After: bytecode execution
    my $pred = Stefo::compile(sub { $_ > 0 && $_ < 100 });
    my @valid = grep { Stefo::check($pred, $_) } @huge_list;

=head1 HOW IT WORKS

The module walks Perl's internal optree representation. For example:

    sub { $_ > 0 }

Produces this optree:

    leavesub
      nextstate
      gt
        gvsv[*_]
        const[IV 0]

Which gets compiled to bytecode:

    PUSH_VAL      ; push $_
    PUSH_IV 0     ; push 0
    GT            ; compare, push result
    RETURN        ; return top of stack

The bytecode is executed by a simple stack-based VM written in C.

=head1 REQUIREMENTS

Perl 5.10.0 or later. Works with threaded and non-threaded Perl.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE

Same as Perl itself.

=cut
