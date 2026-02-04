package Ancient;
use strict;
use warnings;
our $VERSION = '0.18';

1;

__END__

=head1 NAME

Ancient - Post-Apocalyptic Perl

=head1 DESCRIPTION

And I saw another angel coming down from heaven, wrapped in a cloud, with a rainbow over his head; his face was like the sun, and his legs like pillars of fire.

This distribution provides ten independent modules:

=over 4

=item * L<slot> - Global reactive state slots with optional watchers

=item * L<util> - Functional programming utilities with XS acceleration

=item * L<noop> - No-operation functions for benchmarking and testing

=item * L<const> - Fast read-only constants with compile-time optimization

=item * L<doubly> - Doubly linked list implementation

=item * L<lru> - LRU cache with O(1) operations

=item * L<object> - Objects with prototype chains

=item * L<heap> - Binary heap (priority queue)

=item * L<file> - Fast file operations with custom ops

=item * L<nvec> - Numeric vectors with SIMD acceleration

=back

=head1 MODULES

=head2 slot

    use slot qw(app_name debug);
    
    app_name("MyApp");
    print app_name();

Global reactive state slots shared across packages with optional
watchers for reactive programming. All slot:: functions are optimized
to custom ops when called with constant names.

See L<slot> for full documentation.

=head2 util

    use util qw(is_array is_hash memo pipeline trim ...);

Fast functional programming utilities including type predicates,
memoization, pipelines, lazy evaluation, and more. Many functions
use custom ops for compile-time optimization.

See L<util> for full documentation.

=head2 noop

    use noop;

    noop::pp();   # Pure Perl no-op
    noop::xs();   # XS no-op

Minimal no-operation functions for benchmarking overhead and
baseline performance testing.

See L<noop> for full documentation.

=head2 const

    use const;

    my $pi = const::c(3.14159);
    my $name = const::c("immutable");
    const::const(my @list => qw/a b c/);

Fast read-only constants with compile-time optimization. When called
with literal values, C<const::c()> is optimized away at compile time
for zero runtime overhead.

See L<const> for full documentation.

=head2 doubly

    use doubly;

    my $list = doubly->new(1);
    $list->add(2)->add(3);
    $list = $list->start;
    $list = $list->next;

Fast doubly linked list implementation with full navigation, insertion,
and removal operations. Approximately 3x faster than pure Perl implementations.

See L<doubly> for full documentation.

=head2 lru

    use lru;

    my $cache = lru::new(1000);
    $cache->set('key', $value);
    my $val = $cache->get('key');

LRU (Least Recently Used) cache with O(1) operations for get, set,
exists, peek, and delete. Automatic eviction when capacity is reached.

See L<lru> for full documentation.

=head2 object

    use object;

    object::define('Cat', qw(name age));
    my $cat = new Cat 'Whiskers', 3;
    print $cat->name;

Objects with prototype chains stored as arrays for speed. Property
accessors are compiled to custom ops. Getters are 2.4x faster and
setters 2x faster than traditional blessed hash references.

See L<object> for full documentation.

=head2 heap

    use heap;

    my $pq = heap::new('min');
    $pq->push(5)->push(1)->push(3);
    print $pq->pop;  # 1

Binary heap (priority queue) with configurable min/max behavior.
Supports custom comparison callbacks for complex objects.
O(log n) push and pop, O(1) peek.

See L<heap> for full documentation.

=head2 file

    use file;

    my $content = file::slurp('data.txt');
    file::spew('out.txt', $content);
    my @lines = file::lines('log.txt');

Fast file operations with custom ops for slurp, spew, exists, size,
and more. Supports atomic writes and memory-mapped reading.

See L<file> for full documentation.

=head2 nvec

    use nvec;

    my $v = nvec::new([1, 2, 3, 4]);
    my $sum = $v->sum;
    my $scaled = $v->scale(2.0);

Numeric vectors with SIMD acceleration for mathematical operations.
Provides fast arithmetic, reductions, linear algebra, and element-wise
math functions.

See L<nvec> for full documentation.

=head1 CUSTOM OP OPTIMIZATION

Many functions in Ancient modules are compiled to custom ops at compile time
for performance. This optimization is transparent - the functions
work identically whether optimized or not.

=head2 Full Context Support

Custom ops work correctly in all Perl contexts including C<map>, C<grep>,
C<for>/C<foreach> loops, and C<while> loops - both with the implicit C<$_>
variable and with explicit lexical loop variables:

    # All of these use optimized custom ops:
    my @clamped = map { util::clamp($_, 0, 100) } @values;
    my @existing = grep { file::exists($_) } @paths;
    my @evens = grep { util::is_even($_) } @numbers;
    
    for (@keys) {
        my $val = $cache->get($_);
    }
    
    for my $i (@nums) {
        push @results, util::clamp($i, 0, 100);
    }

The custom ops properly handle both C<$_> (implemented as OP_RV2SV->OP_GV)
and lexical loop variables (PADSV) in all contexts.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
