package Test::Class::Moose::Role::HasTimeReport;

# ABSTRACT: Report timing role

use strict;
use warnings;
use namespace::autoclean;

use 5.010000;

our $VERSION = '1.00';

use Moose::Role;
use Benchmark qw(timediff timestr :hireswallclock);
use Test::Class::Moose::Report::Time;

has '_start_benchmark' => (
    is        => 'ro',
    isa       => 'Benchmark',
    lazy      => 1,
    default   => sub { Benchmark->new },
    predicate => '_has_start_benchmark',
);

has '_end_benchmark' => (
    is        => 'ro',
    isa       => 'Benchmark',
    lazy      => 1,
    default   => sub { Benchmark->new },
    predicate => '_has_end_benchmark',
);

has 'time' => (
    is      => 'ro',
    isa     => 'Test::Class::Moose::Report::Time',
    lazy    => 1,
    builder => '_build_time',
);

# If Time::HiRes is available these will be non-integers
has 'start_time' => (
    is      => 'ro',
    isa     => 'Num',
    lazy    => 1,
    default => sub { $_[0]->_start_benchmark->[0] },
);

has 'end_time' => (
    is      => 'ro',
    isa     => 'Num',
    lazy    => 1,
    default => sub { $_[0]->_end_benchmark->[0] },
);

sub _build_time {
    my $self = shift;

    # If we don't have start & end marked we'll return a report with zero time
    # elapsed.
    unless ( $self->_has_start_benchmark && $self->_has_end_benchmark ) {
        my $benchmark = Benchmark->new;
        return Test::Class::Moose::Report::Time->new(
            timediff => timediff( $benchmark, $benchmark ) );
    }

    return Test::Class::Moose::Report::Time->new( timediff =>
          timediff( $self->_end_benchmark, $self->_start_benchmark ) );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Class::Moose::Role::HasTimeReport - Report timing role

=head1 VERSION

version 1.00

=head1 DESCRIPTION

Note that everything in here is experimental and subject to change.

=head1 REQUIRES

None.

=head1 PROVIDED

=head1 ATTRIBUTES

=head2 C<time>

Returns a L<Test::Class::Moose::Report::Time> object. This object represents
the duration of this class or method. The duration may be "0" if it's an
abstract class with no tests run.

=head2 C<start_time>

Returns the start time for the report as an epoch value.

=head2 C<end_time>

Returns the end time for the report as an epoch value.

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
