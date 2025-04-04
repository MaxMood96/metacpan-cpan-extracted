use 5.008001;
use strict;
use warnings;

package TLC::Example;

use Exporter ();
use Carp qw( croak );

our $TLC_VERSION = "0.008";
our @ISA = qw( Exporter );
our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS = (
	is     => [],
	types  => [],
	assert => [],
);

BEGIN {
	package TLC::Example::TypeConstraint;
	our $LIBRARY = "TLC::Example";

	use overload (
		fallback => !!1,
		'|'      => 'union',
		bool     => sub { !! 1 },
		'""'     => sub { shift->{name} },
		'&{}'    => sub {
			my $self = shift;
			return sub { $self->assert_return( @_ ) };
		},
	);

	sub union {
		my @types  = grep ref( $_ ), @_;
		my @checks = map $_->{check}, @types;
		bless {
			check => sub { for ( @checks ) { return 1 if $_->(@_) } return 0 },
			name  => join( '|', map $_->{name}, @types ),
			union => \@types,
		}, __PACKAGE__;
	}

	sub check {
		$_[0]{check}->( $_[1] );
	}

	sub get_message {
		sprintf '%s did not pass type constraint "%s"',
			defined( $_[1] ) ? $_[1] : 'Undef',
			$_[0]{name};
	}

	sub validate {
		$_[0]{check}->( $_[1] )
			? undef
			: $_[0]->get_message( $_[1] );
	}

	sub assert_valid {
		$_[0]{check}->( $_[1] )
			? 1
			: Carp::croak( $_[0]->get_message( $_[1] ) );
	}

	sub assert_return {
		$_[0]{check}->( $_[1] )
			? $_[1]
			: Carp::croak( $_[0]->get_message( $_[1] ) );
	}

	sub to_TypeTiny {
		if ( $_[0]{union} ) {
			require Type::Tiny::Union;
			return 'Type::Tiny::Union'->new(
				display_name     => $_[0]{name},
				type_constraints => [ map $_->to_TypeTiny, @{ $_[0]{union} } ],
			);
		}
		if ( my $library = $_[0]{library} ) {
			local $@;
			eval "require $library; 1" or die $@;
			my $type = $library->get_type( $_[0]{library_name} );
			return $type if $type;
		}
		require Type::Tiny;
		my $check = $_[0]{check};
		my $name  = $_[0]{name};
		return 'Type::Tiny'->new(
			name       => $name,
			constraint => sub { $check->( $_ ) },
			inlined    => sub { sprintf '%s::is_%s(%s)', $LIBRARY, $name, pop }
		);
	}

	sub DOES {
		return 1 if $_[1] eq 'Type::API::Constraint';
		return 1 if $_[1] eq 'Type::Library::Compiler::TypeConstraint';
		shift->SUPER::DOES( @_ );
	}
};

# Any
{
	my $type;
	sub Any () {
		$type ||= bless( { check => \&is_Any, name => "Any", library => "Types::Standard", library_name => "Any" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Any ($) {
		(!!1)
	}

	sub assert_Any ($) {
		(!!1) ? $_[0] : Any->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Any"} = [ qw( Any is_Any assert_Any ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Any"} };
	push @{ $EXPORT_TAGS{"types"} },  "Any";
	push @{ $EXPORT_TAGS{"is"} },     "is_Any";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Any";

}

# Array
{
	my $type;
	sub Array () {
		$type ||= bless( { check => \&is_Array, name => "Array", library => "Types::Standard", library_name => "ArrayRef" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Array ($) {
		(ref($_[0]) eq 'ARRAY')
	}

	sub assert_Array ($) {
		(ref($_[0]) eq 'ARRAY') ? $_[0] : Array->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Array"} = [ qw( Array is_Array assert_Array ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Array"} };
	push @{ $EXPORT_TAGS{"types"} },  "Array";
	push @{ $EXPORT_TAGS{"is"} },     "is_Array";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Array";

}

# Directory
{
	my $type;
	sub Directory () {
		$type ||= bless( { check => \&is_Directory, name => "Directory", library => "Types::Path::Tiny", library_name => "Dir" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Directory ($) {
		do {  (do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) })&& (-d $_[0]) }
	}

	sub assert_Directory ($) {
		do {  (do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) })&& (-d $_[0]) } ? $_[0] : Directory->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Directory"} = [ qw( Directory is_Directory assert_Directory ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Directory"} };
	push @{ $EXPORT_TAGS{"types"} },  "Directory";
	push @{ $EXPORT_TAGS{"is"} },     "is_Directory";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Directory";

}

# File
{
	my $type;
	sub File () {
		$type ||= bless( { check => \&is_File, name => "File", library => "Types::Path::Tiny", library_name => "File" }, "TLC::Example::TypeConstraint" );
	}

	sub is_File ($) {
		do {  (do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) })&& (-f $_[0]) }
	}

	sub assert_File ($) {
		do {  (do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) })&& (-f $_[0]) } ? $_[0] : File->get_message( $_[0] );
	}

	$EXPORT_TAGS{"File"} = [ qw( File is_File assert_File ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"File"} };
	push @{ $EXPORT_TAGS{"types"} },  "File";
	push @{ $EXPORT_TAGS{"is"} },     "is_File";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_File";

}

# Hash
{
	my $type;
	sub Hash () {
		$type ||= bless( { check => \&is_Hash, name => "Hash", library => "Types::Standard", library_name => "HashRef" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Hash ($) {
		(ref($_[0]) eq 'HASH')
	}

	sub assert_Hash ($) {
		(ref($_[0]) eq 'HASH') ? $_[0] : Hash->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Hash"} = [ qw( Hash is_Hash assert_Hash ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Hash"} };
	push @{ $EXPORT_TAGS{"types"} },  "Hash";
	push @{ $EXPORT_TAGS{"is"} },     "is_Hash";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Hash";

}

# Integer
{
	my $type;
	sub Integer () {
		$type ||= bless( { check => \&is_Integer, name => "Integer", library => "Types::Standard", library_name => "Int" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Integer ($) {
		(do { my $tmp = $_[0]; defined($tmp) and !ref($tmp) and $tmp =~ /\A-?[0-9]+\z/ })
	}

	sub assert_Integer ($) {
		(do { my $tmp = $_[0]; defined($tmp) and !ref($tmp) and $tmp =~ /\A-?[0-9]+\z/ }) ? $_[0] : Integer->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Integer"} = [ qw( Integer is_Integer assert_Integer ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Integer"} };
	push @{ $EXPORT_TAGS{"types"} },  "Integer";
	push @{ $EXPORT_TAGS{"is"} },     "is_Integer";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Integer";

}

# NonEmptyString
{
	my $type;
	sub NonEmptyString () {
		$type ||= bless( { check => \&is_NonEmptyString, name => "NonEmptyString", library => "Types::Common::String", library_name => "NonEmptyStr" }, "TLC::Example::TypeConstraint" );
	}

	sub is_NonEmptyString ($) {
		((do {  defined($_[0]) and do { ref(\$_[0]) eq 'SCALAR' or ref(\(my $val = $_[0])) eq 'SCALAR' } }) && (length($_[0]) > 0))
	}

	sub assert_NonEmptyString ($) {
		((do {  defined($_[0]) and do { ref(\$_[0]) eq 'SCALAR' or ref(\(my $val = $_[0])) eq 'SCALAR' } }) && (length($_[0]) > 0)) ? $_[0] : NonEmptyString->get_message( $_[0] );
	}

	$EXPORT_TAGS{"NonEmptyString"} = [ qw( NonEmptyString is_NonEmptyString assert_NonEmptyString ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"NonEmptyString"} };
	push @{ $EXPORT_TAGS{"types"} },  "NonEmptyString";
	push @{ $EXPORT_TAGS{"is"} },     "is_NonEmptyString";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_NonEmptyString";

}

# Null
{
	my $type;
	sub Null () {
		$type ||= bless( { check => \&is_Null, name => "Null", library => "Types::Standard", library_name => "Undef" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Null ($) {
		(!defined($_[0]))
	}

	sub assert_Null ($) {
		(!defined($_[0])) ? $_[0] : Null->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Null"} = [ qw( Null is_Null assert_Null ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Null"} };
	push @{ $EXPORT_TAGS{"types"} },  "Null";
	push @{ $EXPORT_TAGS{"is"} },     "is_Null";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Null";

}

# Number
{
	my $type;
	sub Number () {
		$type ||= bless( { check => \&is_Number, name => "Number", library => "Types::Standard", library_name => "Num" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Number ($) {
		(do {  use Scalar::Util (); defined($_[0]) && !ref($_[0]) && Scalar::Util::looks_like_number($_[0]) })
	}

	sub assert_Number ($) {
		(do {  use Scalar::Util (); defined($_[0]) && !ref($_[0]) && Scalar::Util::looks_like_number($_[0]) }) ? $_[0] : Number->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Number"} = [ qw( Number is_Number assert_Number ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Number"} };
	push @{ $EXPORT_TAGS{"types"} },  "Number";
	push @{ $EXPORT_TAGS{"is"} },     "is_Number";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Number";

}

# Object
{
	my $type;
	sub Object () {
		$type ||= bless( { check => \&is_Object, name => "Object", library => "Types::Standard", library_name => "Object" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Object ($) {
		(do {  use Scalar::Util (); Scalar::Util::blessed($_[0]) })
	}

	sub assert_Object ($) {
		(do {  use Scalar::Util (); Scalar::Util::blessed($_[0]) }) ? $_[0] : Object->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Object"} = [ qw( Object is_Object assert_Object ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Object"} };
	push @{ $EXPORT_TAGS{"types"} },  "Object";
	push @{ $EXPORT_TAGS{"is"} },     "is_Object";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Object";

}

# Path
{
	my $type;
	sub Path () {
		$type ||= bless( { check => \&is_Path, name => "Path", library => "Types::Path::Tiny", library_name => "Path" }, "TLC::Example::TypeConstraint" );
	}

	sub is_Path ($) {
		(do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) })
	}

	sub assert_Path ($) {
		(do { use Scalar::Util (); Scalar::Util::blessed($_[0]) and $_[0]->isa(q[Path::Tiny]) }) ? $_[0] : Path->get_message( $_[0] );
	}

	$EXPORT_TAGS{"Path"} = [ qw( Path is_Path assert_Path ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"Path"} };
	push @{ $EXPORT_TAGS{"types"} },  "Path";
	push @{ $EXPORT_TAGS{"is"} },     "is_Path";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_Path";

}

# String
{
	my $type;
	sub String () {
		$type ||= bless( { check => \&is_String, name => "String", library => "Types::Standard", library_name => "Str" }, "TLC::Example::TypeConstraint" );
	}

	sub is_String ($) {
		do {  defined($_[0]) and do { ref(\$_[0]) eq 'SCALAR' or ref(\(my $val = $_[0])) eq 'SCALAR' } }
	}

	sub assert_String ($) {
		do {  defined($_[0]) and do { ref(\$_[0]) eq 'SCALAR' or ref(\(my $val = $_[0])) eq 'SCALAR' } } ? $_[0] : String->get_message( $_[0] );
	}

	$EXPORT_TAGS{"String"} = [ qw( String is_String assert_String ) ];
	push @EXPORT_OK, @{ $EXPORT_TAGS{"String"} };
	push @{ $EXPORT_TAGS{"types"} },  "String";
	push @{ $EXPORT_TAGS{"is"} },     "is_String";
	push @{ $EXPORT_TAGS{"assert"} }, "assert_String";

}


1;
__END__

=head1 NAME

TLC::Example - type constraint library

=head1 TYPES

This type constraint library is even more basic that L<Type::Tiny>. Exported
types may be combined using C<< Foo | Bar >> but parameterized type constraints
like C<< Foo[Bar] >> are not supported.

=head2 B<Any>

Based on B<Any> in L<Types::Standard>.

The C<< Any >> constant returns a blessed type constraint object.
C<< is_Any($value) >> checks a value against the type and returns a boolean.
C<< assert_Any($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Any );

=head2 B<Array>

Based on B<ArrayRef> in L<Types::Standard>.

The C<< Array >> constant returns a blessed type constraint object.
C<< is_Array($value) >> checks a value against the type and returns a boolean.
C<< assert_Array($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Array );

=head2 B<Directory>

Based on B<Dir> in L<Types::Path::Tiny>.

The C<< Directory >> constant returns a blessed type constraint object.
C<< is_Directory($value) >> checks a value against the type and returns a boolean.
C<< assert_Directory($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Directory );

=head2 B<File>

Based on B<File> in L<Types::Path::Tiny>.

The C<< File >> constant returns a blessed type constraint object.
C<< is_File($value) >> checks a value against the type and returns a boolean.
C<< assert_File($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :File );

=head2 B<Hash>

Based on B<HashRef> in L<Types::Standard>.

The C<< Hash >> constant returns a blessed type constraint object.
C<< is_Hash($value) >> checks a value against the type and returns a boolean.
C<< assert_Hash($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Hash );

=head2 B<Integer>

Based on B<Int> in L<Types::Standard>.

The C<< Integer >> constant returns a blessed type constraint object.
C<< is_Integer($value) >> checks a value against the type and returns a boolean.
C<< assert_Integer($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Integer );

=head2 B<NonEmptyString>

Based on B<NonEmptyStr> in L<Types::Common::String>.

The C<< NonEmptyString >> constant returns a blessed type constraint object.
C<< is_NonEmptyString($value) >> checks a value against the type and returns a boolean.
C<< assert_NonEmptyString($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :NonEmptyString );

=head2 B<Null>

Based on B<Undef> in L<Types::Standard>.

The C<< Null >> constant returns a blessed type constraint object.
C<< is_Null($value) >> checks a value against the type and returns a boolean.
C<< assert_Null($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Null );

=head2 B<Number>

Based on B<Num> in L<Types::Standard>.

The C<< Number >> constant returns a blessed type constraint object.
C<< is_Number($value) >> checks a value against the type and returns a boolean.
C<< assert_Number($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Number );

=head2 B<Object>

Based on B<Object> in L<Types::Standard>.

The C<< Object >> constant returns a blessed type constraint object.
C<< is_Object($value) >> checks a value against the type and returns a boolean.
C<< assert_Object($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Object );

=head2 B<Path>

Based on B<Path> in L<Types::Path::Tiny>.

The C<< Path >> constant returns a blessed type constraint object.
C<< is_Path($value) >> checks a value against the type and returns a boolean.
C<< assert_Path($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :Path );

=head2 B<String>

Based on B<Str> in L<Types::Standard>.

The C<< String >> constant returns a blessed type constraint object.
C<< is_String($value) >> checks a value against the type and returns a boolean.
C<< assert_String($value) >> checks a value against the type and throws an error.

To import all of these functions:

  use TLC::Example qw( :String );

=head1 TYPE CONSTRAINT METHODS

For any type constraint B<Foo> the following methods are available:

 Foo->check( $value )         # boolean
 Foo->get_message( $value )   # error message, even if $value is ok 
 Foo->validate( $value )      # error message, or undef if ok
 Foo->assert_valid( $value )  # returns true, dies if error
 Foo->assert_return( $value ) # returns $value, or dies if error
 Foo->to_TypeTiny             # promotes the object to Type::Tiny

Objects overload stringification to return their name and overload
coderefification to call C<assert_return>.

The objects as-is can be used in L<Moo> or L<Mite> C<isa> options.

 has myattr => (
   is => 'rw',
   isa => Foo,
 );

They cannot be used as-is in L<Moose> or L<Mouse>, but can be promoted
to Type::Tiny and will then work:

 has myattr => (
   is => 'rw',
   isa => Foo->to_TypeTiny,
 );

=cut

