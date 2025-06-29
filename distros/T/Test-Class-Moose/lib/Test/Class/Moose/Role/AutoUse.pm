package Test::Class::Moose::Role::AutoUse;

# ABSTRACT: Automatically load the classes you're testing

use strict;
use warnings;
use namespace::autoclean;

use 5.010000;

our $VERSION = '1.00';

use Moose::Role;
use Carp 'confess';

has 'class_name' => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    builder => '_build_class_name',
);

sub _build_class_name {
    my $test = shift;

    my $name = $test->get_class_name_to_use or return;

    ## no critic (BuiltinFunctions::ProhibitStringyEval, ErrorHandling::RequireCheckingReturnValueOfEval)
    eval "use $name";
    if ( my $error = $@ ) {
        confess("Could not use $name: $error");
    }
    return $name;
}

sub get_class_name_to_use {
    my $test = shift;
    my $name = ref $test;
    $name =~ s/^[^:]+:://;
    return $name;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Test::Class::Moose::Role::AutoUse - Automatically load the classes you're testing

=head1 VERSION

version 1.00

=head1 SYNOPSIS

 package TestsFor::Some::Class;
 use Test::Class::Moose;
 with 'Test::Class::Moose::Role::AutoUse';

 sub test_constructor {
     my $test  = shift;

     my $class = $test->class_name;             # Some::Class
     can_ok $class, 'new';                      # Some::Class is already loaded
     isa_ok my $object = $class->new, $class;   # and can be used as normal
 }

=head1 DESCRIPTION

This role allows you to automatically C<use> the classes your test class is
testing, providing the name of the class via the C<class_name> attribute. Thus,
you don't need to hardcode your class names.

=head1 PROVIDES

=head2 C<class_name>

Returns the name of the class you're testing. As a side-effect, the first time
it's called it will attempt to C<use> the class being tested.

=head2 C<get_class_name_to_use>

This method strips the leading section of the package name, up to and including
the first C<::>, and returns the rest of the name as the name of the class
being tested. For example, if your test class is named C<Tests::Some::Person>,
the name C<Some::Person> is returned as the name of the class to use and test.
If your test class is named C<IHateTestingThis::Person>, then C<Person> is the
name of the class to be used and tested.

If you don't like how the name is calculated, you can override this method in
your code.

Warning: Don't use L<Test::> as a prefix. There are already plenty of modules
in that namespace and you could accidentally cause a collision.

=head1 RATIONALE

The example from our synopsis looks like this:

 package TestsFor::Some::Class;
 use Test::Class::Moose;
 with 'Test::Class::Moose::Role::AutoUse';

 sub test_constructor {
     my $test  = shift;

     my $class = $test->class_name;             # Some::Class
     can_ok $class, 'new';                      # Some::Class is already loaded
     isa_ok my $object = $class->new, $class;   # and can be used as normal
 }

Without this role, it would often look like this:

 package TestsFor::Some::Class;
 use Test::Class::Moose;
 use Some::Class;

 sub test_constructor {
     my $test  = shift;

     can_ok 'Some::Class', 'new';
     isa_ok my $object = 'Some::Class'->new, 'Some::Class';
 }

That's OK, but there are a couple of issues here.

First, if you need to rename your class, you must change this name repeatedly.
With L<Test::Class::Moose::Role::AutoUse>, you only rename the test class name
to correspond to the new class name and you're done.

The first problem is not very serious, but the second problem is. Let's say you
have a C<Person> class and then you create a C<Person::Employee> subclass. Your
test subclass might look like this:

 package TestsFor::Person::Employee;

 use Test::Class::Moose extends => "TestsFor::Person";

 # insert tests here

Object-oriented tests I<inherit> their parent class tests. Thus,
C<TestsFor::Person::Employee> will inherit the C<<
TestsFor::Person->test_constructor() >> method. Except as you can see in our
example above, we've B<hardcoded> the class name, meaning that we won't be
testing our code appropriately. The code using the
L<Test::Class::Moose::Role::AutoUse> role doesn't hardcode the class name (at
least, it shouldn't), so when we call the inherited C<<
TestsFor::Person::Employee->test_constructor() >> method, it constructs a
C<TestsFor::Person::Employee> object, not a C<TestsFor::Person> object.

Some might argue that this is a strawman and we should have done this:

 package TestsFor::Some::Class;
 use Test::Class::Moose;
 use Some::Class;

 sub class_name { 'Some::Class' }

 sub test_constructor {
     my $test  = shift;

     my $class = $test->class_name;             # Some::Class
     can_ok $class, 'new';                      # Some::Class is already loaded
     isa_ok my $object = $class->new, $class;   # and can be used as normal
 }

Yes, that's correct. We should have done this, except that now it's almost
identical to the AutoUse code, except that the first time you forget to C<use>
the class in question, you'll be unhappy. Why not automate this?

=head1 SUPPORT

Bugs may be submitted at L<https://github.com/Test-More/test-class-moose/issues>.

=head1 SOURCE

The source code repository for Test-Class-Moose can be found at L<https://github.com/Test-More/test-class-moose>.

=head1 AUTHORS

=over 4

=item *

Curtis "Ovid" Poe <ovid@cpan.org>

=item *

Dave Rolsky <autarch@urth.org>

=item *

Chad Granum <exodist@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 - 2025 by Curtis "Ovid" Poe.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

The full text of the license can be found in the
F<LICENSE> file included with this distribution.

=cut

__END__


1;
