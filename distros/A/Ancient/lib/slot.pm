package
    slot;
use strict;
use warnings;
our $VERSION = '0.18';
require XSLoader;
XSLoader::load('slot', $VERSION);
1;

__END__

=head1 NAME

slot - global reactive state slots with optional watchers

=head1 SYNOPSIS

    # Define and use slots
    package Config;
    use slot qw(app_name debug);
    
    app_name("MyApp");
    debug(1);
    
    # Access from another package (same underlying storage)
    package Service;
    use slot qw(app_name);
    
    print app_name();  # "MyApp"
    app_name("Changed");

    # Watchers (reactive)
    slot::watch('app_name', sub {
        my ($name, $value) = @_;
        print "app_name changed to: $value\n";
    });
    
    slot::unwatch('app_name');  # Remove all watchers

=head1 DESCRIPTION

C<slot> provides fast, globally shared named storage slots.
Slots are shared across all packages - importing the same slot name in different
packages gives access to the same underlying value.

Key features:

=over 4

=item * B<Fast> - Custom ops with compile-time optimization

=item * B<Global> - Slots are shared across packages by name

=item * B<Reactive> - Optional watchers fire on value changes

=item * B<Lazy watchers> - No overhead unless you use C<watch()>

=back

=head1 COMPILE-TIME OPTIMIZATION

When you call any C<slot::*> function with a B<constant string> name for a
slot that B<exists at compile time> (created via C<use slot qw(...)>), the
call is optimized at compile time to a custom op or constant.

    use slot qw(counter);           # Creates slot at compile time
    
    slot::get('counter');           # Optimized to custom op (185% faster)
    slot::set('counter', 42);       # Optimized to custom op (283% faster)
    my $idx = slot::index('counter'); # Constant-folded (no runtime code!)
    slot::watch('counter', \&cb);   # Optimized to custom op
    slot::unwatch('counter');       # Optimized to custom op
    slot::clear('counter');         # Optimized to custom op

Variable names are NOT optimized and use the XS fallback:

    my $name = 'counter';
    slot::get($name);               # XS function call (slower)

=head2 Optimization Requirements

=over 4

=item 1. The slot name must be a B<literal string constant>

=item 2. The slot must B<exist at compile time> (use C<use slot qw(...)>)

=item 3. Slots created at runtime with C<slot::add()> cannot be optimized

=back

=head1 FUNCTIONS

=head2 import

    use slot qw(foo bar baz);

Imports slot accessors into the calling package. Each accessor is both a
getter and setter:

    foo();       # get
    foo(42);     # set and returns value

=head2 slot::add

    slot::add('name');
    slot::add('name1', 'name2', 'name3');

Create slots without importing accessors into the current package.
93% faster than C<use slot qw(...)> when you only need get/set access.
Idempotent - adding an existing slot is a no-op.

=head2 slot::index

    my $idx = slot::index('name');

Get the numeric index of a slot. Use with C<get_by_idx>/C<set_by_idx>
for maximum performance when you need repeated access.

B<Compile-time optimization:> When called with a constant string,
the index is computed at compile time and the call is replaced with
a constant - no runtime code at all (228% faster).

=head2 slot::get

    my $val = slot::get('name');

Get a slot value by name (without importing an accessor).

B<Compile-time optimization:> When called with a constant string for a
slot that exists at compile time, this is optimized to a custom op and
runs as fast as an accessor (210% faster than variable name lookups).

=head2 slot::set

    slot::set('name', $value);

Set a slot value by name.

B<Compile-time optimization:> Like C<slot::get>, when called with a
constant string, this is optimized at compile time to run as fast as
an accessor.

=head2 slot::get_by_idx

    my $idx = slot::index('name');
    my $val = slot::get_by_idx($idx);

Get a slot value by numeric index. 45% faster than variable name lookup,
but slower than C<slot::get('constant')> with compile-time optimization.

B<Best use case:> When the slot name is a runtime variable and you need
repeated access, cache the index once and use C<get_by_idx>.

=head2 slot::set_by_idx

    slot::set_by_idx($idx, $value);

Set a slot value by numeric index. Faster than variable name lookup.
Watchers are still triggered.

=head2 slot::watch

    slot::watch('name', sub { my ($name, $val) = @_; ... });

Register a callback that fires whenever the slot value changes.

B<Compile-time optimization:> When called with a constant string,
optimized to a custom op.

=head2 slot::unwatch

    slot::unwatch('name');            # Remove all watchers
    slot::unwatch('name', $coderef);  # Remove specific watcher

B<Compile-time optimization:> When called with a constant string,
optimized to a custom op.

=head2 slot::clear

    slot::clear('name');
    slot::clear('name1', 'name2');

Reset slot value(s) to undef and remove all associated watchers.
The slot still exists (can be set again), but its value is cleared.

B<Compile-time optimization:> When called with a single constant string,
optimized to a custom op.

=head2 slot::clear_by_idx

    slot::clear_by_idx($idx);
    slot::clear_by_idx($idx1, $idx2);

Reset slot value(s) to undef and remove watchers by numeric index.

=head2 slot::slots

    my @names = slot::slots();

Returns a list of all defined slot names.

=head2 slot::exists

    if (slot::exists('config')) {
        # slot is defined
    }

Check if a slot with the given name has been defined. Returns true if
the slot exists, false otherwise.

=head1 THREAD SAFETY

For thread-safe data sharing, store C<threads::shared> variables in slots:

    use threads;
    use threads::shared;
    use slot qw(config);

    # Create shared data and store in slot
    my %shared :shared;
    $shared{counter} = 0;
    config(\%shared);

    # Threads can now safely share data via the slot
    my @threads = map {
        threads->create(sub {
            my $cfg = config();
            lock(%$cfg);
            $cfg->{counter}++;
        });
    } 1..10;

    $_->join for @threads;
    print config()->{counter};  # 10

The slot provides the global accessor; C<threads::shared> provides the
thread-safe storage.

=head1 FORK BEHAVIOR

After C<fork()>, child processes get a copy of slot values (copy-on-write).
Changes in child processes do not affect the parent, and vice versa.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
