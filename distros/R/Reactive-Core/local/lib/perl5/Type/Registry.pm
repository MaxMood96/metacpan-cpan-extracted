package Type::Registry;

use 5.006001;
use strict;
use warnings;

BEGIN {
	$Type::Registry::AUTHORITY = 'cpan:TOBYINK';
	$Type::Registry::VERSION   = '1.000000';
}

use Exporter::Tiny qw( mkopt );
use Scalar::Util qw( refaddr );
use Type::Parser qw( eval_type );
use Types::TypeTiny qw( CodeLike ArrayLike to_TypeTiny );

our @ISA = 'Exporter::Tiny';
our @EXPORT_OK = qw(t);

sub _croak ($;@) { require Error::TypeTiny; goto \&Error::TypeTiny::croak }

sub _exporter_expand_sub
{
	my $class = shift;
	my ($name, $value, $globals, $permitted) = @_;
	
	if ($name eq "t")
	{
		my $caller = $globals->{into};
		my $reg = $class->for_class(
			ref($caller) ? sprintf('HASH(0x%08X)', refaddr($caller)) : $caller
		);
		return t => sub (;$) { @_ ? $reg->lookup(@_) : $reg };
	}
	
	return $class->SUPER::_exporter_expand_sub(@_);
}

sub new
{
	my $class = shift;
	ref($class) and _croak("Not an object method");
	bless {}, $class;
}

{
	my %registries;
	
	sub for_class
	{
		my $class = shift;
		my ($for) = @_;
		$registries{$for} ||= $class->new;
	}
	
	sub for_me
	{
		my $class = shift;
		my $for   = caller;
		$registries{$for} ||= $class->new;
	}
}

sub add_types
{
	my $self = shift;
	my $opts = mkopt(\@_);
	for my $opt (@$opts)
	{
		my ($lib, $types) = @_;
		
		$lib =~ s/^-/Types::/;
		eval "require $lib";
		
		my %hash;
		
		if ($lib->isa("Type::Library") or $lib eq 'Types::TypeTiny')
		{
			$types ||= [qw/-types/];
			ArrayLike->check($types)
				or _croak("Expected arrayref following '%s'; got %s", $lib, $types);
			
			$lib->import({into => \%hash}, @$types);
			$hash{$_} = &{$hash{$_}}() for keys %hash;
		}
		elsif ($lib->isa("MooseX::Types::Base"))
		{
			$types ||= [];
			ArrayLike->check($types) && (@$types == 0)
				or _croak("Library '%s' is a MooseX::Types type constraint library. No import options currently supported", $lib);
			
			require Moose::Util::TypeConstraints;
			my $moosextypes = $lib->type_storage;
			for my $name (sort keys %$moosextypes)
			{
				my $tt = to_TypeTiny(
					Moose::Util::TypeConstraints::find_type_constraint($moosextypes->{$name})
				);
				$hash{$name} = $tt;
			}
		}
		elsif ($lib->isa("MouseX::Types::Base"))
		{
			$types ||= [];
			ArrayLike->check($types) && (@$types == 0)
				or _croak("Library '%s' is a MouseX::Types type constraint library. No import options currently supported", $lib);
			
			require Mouse::Util::TypeConstraints;
			my $moosextypes = $lib->type_storage;
			for my $name (sort keys %$moosextypes)
			{
				my $tt = to_TypeTiny(
					Mouse::Util::TypeConstraints::find_type_constraint($moosextypes->{$name})
				);
				$hash{$name} = $tt;
			}
		}
		else
		{
			_croak("%s is not a type library", $lib);
		}
		
		for my $key (sort keys %hash)
		{
			exists($self->{$key})
				and $self->{$key}{uniq} != $hash{$key}{uniq}
				and _croak("Duplicate type name: %s", $key);
			$self->{$key} = $hash{$key};
		}
	}
	$self;
}

sub add_type
{
	my $self = shift;
	my ($type, $name) = @_;
	$type = to_TypeTiny($type);
	$name ||= do {
		$type->is_anon
			and _croak("Expected named type constraint; got anonymous type constraint");
		$type->name;
	};
	
	exists($self->{$name})
		and $self->{$name}{uniq} != $type->{uniq}
		and _croak("Duplicate type name: %s", $name);
	
	$self->{$name} = $type;
	$self;
}

sub alias_type
{
	my $self = shift;
	my ($old, @new) = @_;
	my $lookup = eval { $self->lookup($old) }
		or _croak("Expected existing type constraint name; got '$old'");
	$self->{$_} = $lookup for @new;
	$self;
}

sub simple_lookup
{
	my $self = shift;
	
	my ($tc) = @_;
	$tc =~ s/(^\s+|\s+$)//g;
	
	if (exists $self->{$tc})
	{
		return $self->{$tc};
	}
	
	return;
}

sub foreign_lookup
{
	my $self = shift;
	
	return $self->simple_lookup($_[0], 1)
		unless $_[0] =~ /^(.+)::(\w+)$/;
	
	my $library  = $1;
	my $typename = $2;
	
	eval "require $library;";
	
	if ( $library->isa('MooseX::Types::Base') )
	{
		require Moose::Util::TypeConstraints;
		my $type = Moose::Util::TypeConstraints::find_type_constraint(
			$library->get_type($typename)
		) or return;
		return to_TypeTiny($type);
	}
	
	if ( $library->isa('MouseX::Types::Base') )
	{
		require Mouse::Util::TypeConstraints;
		my $sub  = $library->can($typename) or return;
		my $type = Mouse::Util::TypeConstraints::find_type_constraint($sub->()) or return;
		return to_TypeTiny($type);
	}
	
	if ( $library->can("get_type") )
	{
		my $type = $library->get_type($typename);
		return to_TypeTiny($type);
	}
	
	return;
}

sub lookup
{
	my $self = shift;
	
	$self->simple_lookup(@_) or eval_type($_[0], $self);
}

sub make_union
{
	my $self = shift;
	my (@types) = @_;
	
	require Type::Tiny::Union;
	return "Type::Tiny::Union"->new(type_constraints => \@types);
}

sub make_intersection
{
	my $self = shift;
	my (@types) = @_;
	
	require Type::Tiny::Intersection;
	return "Type::Tiny::Intersection"->new(type_constraints => \@types);
}

sub make_class_type
{
	my $self = shift;
	my ($class) = @_;
	
	require Type::Tiny::Class;
	return "Type::Tiny::Class"->new(class => $class);
}

sub make_role_type
{
	my $self = shift;
	my ($role) = @_;
	
	require Type::Tiny::Role;
	return "Type::Tiny::Role"->new(role => $role);
}

sub AUTOLOAD
{
	my $self = shift;
	my ($method) = (our $AUTOLOAD =~ /(\w+)$/);
	my $type = $self->simple_lookup($method);
	return $type if $type;
	_croak(q[Can't locate object method "%s" via package "%s"], $method, ref($self));
}

# Prevent AUTOLOAD being called for DESTROY!
sub DESTROY
{
	return;
}

DELAYED: {
	our %DELAYED;
	for my $package (sort keys %DELAYED)
	{
		my $reg   = __PACKAGE__->for_class($package);
		my $types = $DELAYED{$package};
		
		for my $name (sort keys %$types)
		{
			$reg->add_type($types->{$name}, $name);
		}
	}
}

1;

__END__

=pod

=encoding utf-8

=for stopwords optlist

=head1 NAME

Type::Registry - a glorified hashref for looking up type constraints

=head1 SYNOPSIS

=for test_synopsis no warnings qw(misc);

   package Foo::Bar;
   
   use Type::Registry;
   
   my $reg = "Type::Registry"->for_me;  # a registry for Foo::Bar
   
   # Register all types from Types::Standard
   $reg->add_types(-Standard);
   
   # Register just one type from Types::XSD
   $reg->add_types(-XSD => ["NonNegativeInteger"]);
   
   # Register all types from MyApp::Types
   $reg->add_types("MyApp::Types");
   
   # Create a type alias
   $reg->alias_type("NonNegativeInteger" => "Count");
   
   # Look up a type constraint
   my $type = $reg->lookup("ArrayRef[Count]");
   
   $type->check([1, 2, 3.14159]);  # croaks

Alternatively:

   package Foo::Bar;
   
   use Type::Registry qw( t );
   
   # Register all types from Types::Standard
   t->add_types(-Standard);
   
   # Register just one type from Types::XSD
   t->add_types(-XSD => ["NonNegativeInteger"]);
   
   # Register all types from MyApp::Types
   t->add_types("MyApp::Types");
   
   # Create a type alias
   t->alias_type("NonNegativeInteger" => "Count");
   
   # Look up a type constraint
   my $type = t("ArrayRef[Count]");
   
   $type->check([1, 2, 3.14159]);  # croaks

=head1 STATUS

This module is covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

A type registry is basically just a hashref mapping type names to type
constraint objects.

=head2 Constructors

=over

=item C<< new >>

Create a new glorified hashref.

=item C<< for_class($class) >>

Create or return the existing glorified hashref associated with the given
class.

Note that any type constraint you have imported from Type::Library-based
type libraries will be automatically available in your class' registry.

=item C<< for_me >>

Create or return the existing glorified hashref associated with the caller.

=back

=head2 Methods

=over

=item C<< add_types(@libraries) >>

The libraries list is treated as an "optlist" (a la L<Data::OptList>).

Strings are the names of type libraries; if the first character is a
hyphen, it is expanded to the "Types::" prefix. If followed by an
arrayref, this is the list of types to import from that library.
Otherwise, imports all types from the library.

   use Type::Registry qw(t);
   
   t->add_types(-Standard);  # OR: t->add_types("Types::Standard");
   
   t->add_types(
      -TypeTiny => ['HashLike'],
      -Standard => ['HashRef' => { -as => 'RealHash' }],
   );

L<MooseX::Types> (and experimentally, L<MouseX::Types>) libraries can
also be added this way, but I<< cannot be followed by an arrayref of
types to import >>.

=item C<< add_type($type, $name) >>

The long-awaited singular form of C<add_types>. Given a type constraint
object, adds it to the registry with a given name. The name may be
omitted, in which case C<< $type->name >> is called, and Type::Registry
will throw an error if C<< $type >> is anonymous. If a name is explicitly
given, Type::Registry cares not one wit whether the type constraint is
anonymous.

This method can even add L<MooseX::Types> and L<MouseX::Types> type
constraints; indeed anything that can be handled by L<Types::TypeTiny>'s
C<to_TypeTiny> function. (Bear in mind that to_TypeTiny I<always> results
in an anonymous type constraint, so C<< $name >> will be required.)

=item C<< alias_type($oldname, $newname) >>

Create an alias for an existing type.

=item C<< simple_lookup($name) >>

Look up a type in the registry by name. 

Returns undef if not found.

=item C<< foreign_lookup($name) >>

Like C<simple_lookup>, but if the type name contains "::", will attempt
to load it from a type library. (And will attempt to load that module.)

=item C<< lookup($name) >>

Look up by name, with a DSL.

   t->lookup("Int|ArrayRef[Int]")

The DSL can be summed up as:

   X               type from this registry
   My::Lib::X      type from a type library
   ~X              complementary type
   X | Y           union
   X & Y           intersection
   X[...]          parameterized type
   slurpy X        slurpy type
   Foo::Bar::      class type

Croaks if not found.

=item C<< make_union(@constraints) >>,
C<< make_intersection(@constraints) >>,
C<< make_class_type($class) >>,
C<< make_role_type($role) >>

Convenience methods for creating certain common type constraints.

=item C<< AUTOLOAD >>

Overloaded to call C<lookup>.

   $registry->Str;  # like $registry->lookup("Str")

=back

=head2 Functions

=over

=item C<< t >>

This class can export a function C<< t >> which acts like
C<< "Type::Registry"->for_class($importing_class) >>.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Type-Tiny>.

=head1 SEE ALSO

L<Type::Library>.

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

