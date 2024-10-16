package Devel::Events::Filter;
# vim: set ts=2 sw=2 noet nolist :
# ABSTRACT: A handler role that filters events and delegates to another
our $VERSION = '0.10';
use Moose::Role;

with qw/Devel::Events::Handler/;

requires 'filter_event';

has handler => (
	# does => "Devel::Events::Handler", # we like duck typing
	isa => "Object",
	is  => "rw",
	required => 1,
);

sub new_event {
	my ( $self, @event ) = @_;

	if ( my @filtered = $self->filter_event( @event ) ) {
		$self->send_filtered_event(@filtered);
	}
}

sub send_filtered_event {
	my ( $self, @filtered ) = @_;
	$self->handler->new_event( @filtered );
}

__PACKAGE__;

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::Events::Filter - A handler role that filters events and delegates to another

=head1 VERSION

version 0.10

=head1 SYNOPSIS

	package MyFilter;
	use Moose;

	with qw/Devel::Events::Filter/;

	sub filter_event {
		my ( $self, @event ) = @_;

		return (map { ... } @event);
	}

=head1 DESCRIPTION

This role allows you to build event filters easily:

=head1 USAGE

To use this role you must provide the C<filter_event> method.

This role provides an optional C<handler> attribute and a C<new_event> method,
and does the L<Devel::Events::Handler> role implicitly.

If a sub handler was provided then the filtered event will be delegated to it,
but due to the usefulness of filters as debugging aids this is currently
optional.

In the future this design choice might change.

=head1 ATTRIBUTES

=over 4

=item handler

A L<Devel::Events::Handler> to delegate to.

=back

=head1 METHODS

=over 4

=item new_event @event

Filters the event through C<filter_event>.

If C<handler> is set, delegates the filtered event to the handler. If not
C<no_handler_error> is called instead.

=item no_handler_error @filtered_event

This method is called if no handler is present. It is a stub, but in the future
it may raise an error.

=back

=head1 SEE ALSO

L<Devel::Events>, L<Devel::Events::Handler>, L<Devel::Events::Filter::Stamp>,
L<Devel::Events::Filter::Warn>

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Devel-Events>
(or L<bug-Devel-Events@rt.cpan.org|mailto:bug-Devel-Events@rt.cpan.org>).

=head1 AUTHOR

יובל קוג'מן (Yuval Kogman) <nothingmuch@woobling.org>

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2007 by יובל קוג'מן (Yuval Kogman).

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
