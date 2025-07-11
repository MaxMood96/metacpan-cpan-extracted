package Type::Tiny::Union;

use 5.006001;
use strict;
use warnings;

BEGIN {
	$Type::Tiny::Union::AUTHORITY = 'cpan:TOBYINK';
	$Type::Tiny::Union::VERSION   = '1.000000';
}

use Scalar::Util qw< blessed >;
use Types::TypeTiny ();

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

use overload q[@{}] => sub { $_[0]{type_constraints} ||= [] };

use Type::Tiny ();
our @ISA = 'Type::Tiny';

sub new {
	my $proto = shift;
	
	my %opts = (@_==1) ? %{$_[0]} : @_;
	_croak "Union type constraints cannot have a parent constraint passed to the constructor" if exists $opts{parent};
	_croak "Union type constraints cannot have a constraint coderef passed to the constructor" if exists $opts{constraint};
	_croak "Union type constraints cannot have a inlining coderef passed to the constructor" if exists $opts{inlined};
	_croak "Need to supply list of type constraints" unless exists $opts{type_constraints};
	
	$opts{type_constraints} = [
		map { $_->isa(__PACKAGE__) ? @$_ : $_ }
		map Types::TypeTiny::to_TypeTiny($_),
		@{ ref $opts{type_constraints} eq "ARRAY" ? $opts{type_constraints} : [$opts{type_constraints}] }
	];
	
	if (Type::Tiny::_USE_XS)
	{
		my @constraints = @{$opts{type_constraints}};
		my @known = map {
			my $known = Type::Tiny::XS::is_known($_->compiled_check);
			defined($known) ? $known : ();
		} @constraints;
		
		if (@known == @constraints)
		{
			my $xsub = Type::Tiny::XS::get_coderef_for(
				sprintf "AnyOf[%s]", join(',', @known)
			);
			$opts{compiled_type_constraint} = $xsub if $xsub;
		}
	}

	my $self = $proto->SUPER::new(%opts);
	$self->coercion if grep $_->has_coercion, @$self;
	return $self;
}

sub type_constraints { $_[0]{type_constraints} }
sub constraint       { $_[0]{constraint} ||= $_[0]->_build_constraint }

sub _build_display_name
{
	my $self = shift;
	join q[|], @$self;
}

sub _build_coercion
{
	require Type::Coercion::Union;
	my $self = shift;
	return "Type::Coercion::Union"->new(type_constraint => $self);
}

sub _build_constraint
{
	my @checks = map $_->compiled_check, @{+shift};
	return sub
	{
		my $val = $_;
		$_->($val) && return !!1 for @checks;
		return;
	}
}

sub can_be_inlined
{
	my $self = shift;
	not grep !$_->can_be_inlined, @$self;
}

sub inline_check
{
	my $self = shift;
	
	if (Type::Tiny::_USE_XS and !exists $self->{xs_sub})
	{
		$self->{xs_sub} = undef;
		
		my @constraints = @{$self->type_constraints};
		my @known = map {
			my $known = Type::Tiny::XS::is_known($_->compiled_check);
			defined($known) ? $known : ();
		} @constraints;
		
		if (@known == @constraints)
		{
			$self->{xs_sub} = Type::Tiny::XS::get_subname_for(
				sprintf "AnyOf[%s]", join(',', @known)
			);
		}
	}
	
	if (Type::Tiny::_USE_XS and $self->{xs_sub}) {
		return "$self->{xs_sub}\($_[0]\)";
	}
	
	sprintf '(%s)', join " or ", map $_->inline_check($_[0]), @$self;
}

sub _instantiate_moose_type
{
	my $self = shift;
	my %opts = @_;
	delete $opts{parent};
	delete $opts{constraint};
	delete $opts{inlined};
	
	my @tc = map $_->moose_type, @{$self->type_constraints};
	
	require Moose::Meta::TypeConstraint::Union;
	return "Moose::Meta::TypeConstraint::Union"->new(%opts, type_constraints => \@tc);
}

sub has_parent
{
	defined(shift->parent);
}

sub parent
{
	$_[0]{parent} ||= $_[0]->_build_parent;
}

sub _build_parent
{
	my $self = shift;
	my ($first, @rest) = @$self;
	
	for my $parent ($first, $first->parents)
	{
		return $parent unless grep !$_->is_a_type_of($parent), @rest;
	}
	
	return;
}

sub find_type_for
{
	my @types = @{+shift};
	for my $type (@types)
	{
		return $type if $type->check(@_);
	}
	return;
}

sub validate_explain
{
	my $self = shift;
	my ($value, $varname) = @_;
	$varname = '$_' unless defined $varname;
	
	return undef if $self->check($value);
	
	require Type::Utils;
	return [
		sprintf(
			'"%s" requires that the value pass %s',
			$self,
			Type::Utils::english_list(\"or", map qq["$_"], @$self),
		),
		map {
			$_->get_message($value),
			map("    $_", @{ $_->validate_explain($value) || []}),
		} @$self
	];
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Tiny::Union - union type constraints

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

Union type constraints.

This package inherits from L<Type::Tiny>; see that for most documentation.
Major differences are listed below:

=head2 Attributes

=over

=item C<type_constraints>

Arrayref of type constraints.

When passed to the constructor, if any of the type constraints in the union
is itself a union type constraint, this is "exploded" into the new union.

=item C<constraint>

Unlike Type::Tiny, you I<cannot> pass a constraint coderef to the constructor.
Instead rely on the default.

=item C<inlined>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
Instead rely on the default.

=item C<parent>

Unlike Type::Tiny, you I<cannot> pass an inlining coderef to the constructor.
A parent will instead be automatically calculated.

=item C<coercion>

You probably do not pass this to the constructor. (It's not currently
disallowed, as there may be a use for it that I haven't thought of.)

The auto-generated default will be a L<Type::Coercion::Union> object.

=back

=head2 Methods

=over

=item C<< find_type_for($value) >>

Returns the first individual type constraint in the union which
C<< $value >> passes.

=back

=head2 Overloading

=over

=item *

Arrayrefification calls C<type_constraints>.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Tiny>.

=head1 SEE ALSO

L<Type::Tiny::Manual>.

L<Type::Tiny>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013-2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

