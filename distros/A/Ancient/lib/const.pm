package
    const;
use strict;
use warnings;
our $VERSION = '0.18';
require XSLoader;
XSLoader::load('const', $VERSION);
1;

__END__

=head1 NAME

const - fast read-only constants with compile-time optimization

=head1 SYNOPSIS

    use const;
    
    # Create a constant inline (compile-time optimized!)
    my $pi = const::c(3.14159);
    my $name = const::c("immutable");
    my $data = const::c({ key => "value", nested => [1, 2, 3] });
    
    # Traditional Const::XS style
    const::const(my $greeting => "Hello World");
    const::const(my @list => qw/a b c/);
    const::const(my %config => (debug => 1, verbose => 0));
    
    # Make existing variable readonly
    my $x = 42;
    const::make_readonly(\$x);
    
    # Check readonly status
    if (const::is_readonly(\$x)) {
        print "x is constant\n";
    }
    
    # Undo if needed
    const::unmake_readonly(\$x);

=head1 DESCRIPTION

C<const> provides high-performance read-only constants for Perl. It's designed
for Perl programmers who prefer declaring constants the way Perl programmers
actually like to: inline, with minimal ceremony.

Unlike C<use constant> which creates subroutines, C<const::c()> creates actual
readonly scalars that behave like normal variables.

=head1 COMPILE-TIME OPTIMIZATION

The killer feature of this module is compile-time constant folding:

    my $val = const::c(42);           # Constant-folded at compile time!
    my $str = const::c("hello");      # No function call at runtime

When C<const::c()> is called with a B<literal constant value>, the entire
function call is eliminated and replaced with the readonly value directly.
This means B<zero runtime overhead> for constant literals.

=head2 What Gets Optimized

    # OPTIMIZED - literal values
    const::c(42)                      # Integer literal
    const::c(3.14)                    # Float literal
    const::c("string")                # String literal
    const::c('also string')           # Single-quoted string

    # NOT OPTIMIZED - runtime values (XS fallback, still fast)
    my $v = get_value();
    const::c($v)                      # Variable - needs runtime evaluation
    const::c($a + $b)                 # Expression - needs runtime evaluation

=head1 FUNCTIONS

=head2 c

    my $const = const::c($value);

Create a readonly copy of C<$value>. If C<$value> is a reference, it will be
deeply frozen (the entire structure becomes readonly).

When called with a literal constant, this is optimized away at compile time.

    my $answer = const::c(42);        # Just becomes: my $answer = 42;
                                      # (but readonly)

=head2 const

    const::const(my $scalar => $value);
    const::const(my @array => @values);
    const::const(my %hash => %values);

Set a variable to a value and make it deeply readonly. Compatible with
L<Const::XS> syntax.

    const::const(my $pi => 3.14159);
    const::const(my @primes => (2, 3, 5, 7, 11));
    const::const(my %defaults => (timeout => 30, retries => 3));

=head2 make_readonly

    const::make_readonly(\$var);
    const::make_readonly(\@arr);
    const::make_readonly(\%hash);

Deeply make an existing variable readonly.

=head2 make_readonly_ref

    my $const_ref = const::make_readonly_ref($ref);

Make a reference deeply readonly. Unlike C<make_readonly>, the variable
holding the reference can be reassigned:

    my $ref = const::make_readonly_ref({ a => 1 });
    $ref->{b} = 2;          # Dies - hash is readonly
    $ref = { b => 2 };      # OK - $ref itself is writable

=head2 unmake_readonly

    const::unmake_readonly(\$var);

Deeply undo readonly status on a variable. Use with caution.

=head2 is_readonly

    my $bool = const::is_readonly(\$var);

Returns true if the variable is readonly, false otherwise.

=head1 PERFORMANCE

=head2 vs use constant

C<use constant> creates a subroutine, which has call overhead and can't be
interpolated in strings without ceremony:

    use constant PI => 3.14159;
    print "Pi is @{[PI]}\n";          # Awkward

    use const;
    my $PI = const::c(3.14159);
    print "Pi is $PI\n";              # Natural

=head1 SEE ALSO

L<Const::XS> - the original, full-featured readonly module

L<Const::Fast> - another popular readonly module

L<Readonly> - the classic (but slower due to tie)

=head1 AUTHOR

LNATION C<< <email@lnation.org> >>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
