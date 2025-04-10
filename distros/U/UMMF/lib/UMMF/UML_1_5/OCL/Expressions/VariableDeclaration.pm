# -*- perl -*-
# DO NOT EDIT - This file is generated by UMMF; http://ummf.sourceforge.net 
# From template: $Id: Perl.txt,v 1.77 2006/05/14 01:40:03 kstephens Exp $

package UMMF::UML_1_5::OCL::Expressions::VariableDeclaration;

#use 5.6.1;
use strict;
use warnings;

#################################################################
# Version
#

our $VERSION = do { my @r = (q{1.5} =~ /\d+/g); sprintf "%d." . "%03d" x $#r, @r };


#################################################################
# Documentation
#

=head1 NAME

UMMF::UML_1_5::OCL::Expressions::VariableDeclaration -- 

=head1 VERSION

1.5

=head1 SYNOPSIS

=head1 DESCRIPTION 

=head1 USAGE

=head1 EXPORT

=head1 METATYPE

L<UMMF::UML_1_5::Foundation::Core::Class|UMMF::UML_1_5::Foundation::Core::Class>

=head1 SUPERCLASSES

L<UMMF::UML_1_5::Foundation::Core::Element|UMMF::UML_1_5::Foundation::Core::Element>




=head1 ATTRIBUTES

I<NO ATTRIBUTES>


=head1 ASSOCIATIONS


=head2 C<result> : I<THIS> C<1> E<lt>---E<gt>  C<baseExpr> : UMMF::UML_1_5::OCL::Expressions::IterateExp C<0..1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp>

=item multiplicity = C<0..1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<composite>

=item visibility = C<public>

=item container_type = C<Set::Object>

=back


=head2 C<initializedVariable> : I<THIS> C<0..1> E<lt>---E<gt>  C<initExpression> : UMMF::UML_1_5::OCL::Expressions::OclExpression C<0..1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression>

=item multiplicity = C<0..1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<none>

=item visibility = C<public>

=item container_type = C<Set::Object>

=back


=head2 C<iterators> : I<THIS> C<1..*> E<lt>---E<gt>  C<loopExpr> : UMMF::UML_1_5::OCL::Expressions::LoopExp C<0..1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp>

=item multiplicity = C<0..1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<composite>

=item visibility = C<public>

=item container_type = C<Set::Object>

=back


=head2 C<tuplePart> : I<THIS> C<0..*> E<lt>---E<gt>  C<tupleLiteralExp> : UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp C<1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp>

=item multiplicity = C<1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<none>

=item visibility = C<private>

=item container_type = C<Set::Object>

=back


=head2 C<> : I<THIS> C<1> ----E<gt>  C<type> : UMMF::UML_1_5::Foundation::Core::Classifier C<1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier>

=item multiplicity = C<1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<none>

=item visibility = C<public>

=item container_type = C<Set::Object>

=back


=head2 C<variable> : I<THIS> C<1> E<lt>----  C<> : UMMF::UML_1_5::OCL::Expressions::LetExp C<0..1>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::LetExp|UMMF::UML_1_5::OCL::Expressions::LetExp>

=item multiplicity = C<0..1>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<0>

=item aggregation = C<composite>

=item visibility = C<private>

=item container_type = C<Set::Object>

=back


=head2 C<referredVariable> : I<THIS> C<1> E<lt>---E<gt>  C<variableExp> : UMMF::UML_1_5::OCL::Expressions::VariableExp C<0..*>



=over 4

=item metatype = L<UMMF::UML_1_5::Foundation::Core::AssociationEnd|UMMF::UML_1_5::Foundation::Core::AssociationEnd>

=item type = L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>

=item multiplicity = C<0..*>

=item changeability = C<changeable>

=item targetScope = C<instance>

=item ordering = C<>

=item isNavigable = C<1>

=item aggregation = C<none>

=item visibility = C<private>

=item container_type = C<Set::Object>

=back



=head1 METHODS

=cut



#################################################################
# Dependencies
#





use Carp qw(croak confess);
use Set::Object 1.05;
use Class::Multimethods 1.70;
use Data::Dumper;
use Scalar::Util qw(weaken);
use UMMF::UML_1_5::__ObjectBase qw(:__ummf_array);


#################################################################
# Generalizations
#

use base qw(
  UMMF::UML_1_5::Foundation::Core::Element



);


#################################################################
# Exports
#

our @EXPORT_OK = qw(
);
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );





#################################################################
# Validation
#


=head2 C<__validate_type>

  UMMF::UML_1_5::OCL::Expressions::VariableDeclaration->__validate_type($value);

Returns true if C<$value> is a valid representation of L<UMMF::UML_1_5::OCL::Expressions::VariableDeclaration|UMMF::UML_1_5::OCL::Expressions::VariableDeclaration>.

=cut
sub __validate_type($$)
{
  my ($self, $x) = @_;

  no warnings;

  UNIVERSAL::isa($x, 'UMMF::UML_1_5::OCL::Expressions::VariableDeclaration')  ;
}


=head2 C<__typecheck>

  UMMF::UML_1_5::OCL::Expressions::VariableDeclaration->__typecheck($value, $msg);

Calls C<confess()> with C<$msg> if C<<UMMF::UML_1_5::OCL::Expressions::VariableDeclaration->__validate_type($value)>> is false.

=cut
sub __typecheck
{
  my ($self, $x, $msg) = @_;

  confess("typecheck: $msg: type '" . 'UMMF::UML_1_5::OCL::Expressions::VariableDeclaration' . ": value '$x'")
    unless __validate_type($self, $x);
}


=head2 C<isaVariableDeclaration>


Returns true if receiver is a L<UMMF::UML_1_5::OCL::Expressions::VariableDeclaration|UMMF::UML_1_5::OCL::Expressions::VariableDeclaration>.
Other receivers will return false.

=cut
sub isaVariableDeclaration { 1 }


=head2 C<isaOCL__Expressions__VariableDeclaration>


Returns true if receiver is a L<UMMF::UML_1_5::OCL::Expressions::VariableDeclaration|UMMF::UML_1_5::OCL::Expressions::VariableDeclaration>.
Other receivers will return false.
This is the fully qualified version of the C<isaVariableDeclaration> method.

=cut
sub isaOCL__Expressions__VariableDeclaration { 1 }


#################################################################
# Introspection
#

=head2 C<__model_name> 

  my $name = $obj_or_package->__model_name;

Returns the UML Model name (C<'OCL::Expressions::VariableDeclaration'>) for an object or package of
this Classifier.

=cut
sub __model_name { 'OCL::Expressions::VariableDeclaration' }



=head2 C<__isAbstract>

  $package->__isAbstract;

Returns C<0>.

=cut
sub __isAbstract { 0; }


my $__tangram_schema;
=head2 C<__tangram_schema>

  my $tangram_schema $obj_or_package->__tangram_schema

Returns a HASH ref that describes this Classifier for Tangram.

See L<UMMF::Export::Perl::Tangram|UMMF::Export::Perl::Tangram>

=cut
sub __tangram_schema
{
  my ($self) = @_;

  $__tangram_schema ||=
  {
   'classes' =>
   [
     'UMMF::UML_1_5::OCL::Expressions::VariableDeclaration' =>
     {
       'table' => 'OCL__Expressions__VariableDeclaration',
       'abstract' => 0,
       'slots' => 
       { 
	 # Attributes
	 
	 # Associations
	 	 	       'baseExpr'
       => {
	 'type_impl' => 'ref',
         'class' => 'UMMF::UML_1_5::OCL::Expressions::IterateExp',

                  'null' => '1', 

                                    'col' => 'baseExpr', 

                                                                                                                   }
      ,
                  	 	       'initExpression'
       => {
	 'type_impl' => 'ref',
         'class' => 'UMMF::UML_1_5::OCL::Expressions::OclExpression',

                  'null' => '1', 

                                    'col' => 'initExpression', 

                                                                                 'aggreg' => '1', 

                                           }
      ,
                  	 	       'loopExpr'
       => {
	 'type_impl' => 'ref',
         'class' => 'UMMF::UML_1_5::OCL::Expressions::LoopExp',

                  'null' => '1', 

                                    'col' => 'loopExpr', 

                                                                                                                   }
      ,
                  	 	       'tupleLiteralExp'
       => {
	 'type_impl' => 'ref',
         'class' => 'UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp',

                                             'col' => 'tupleLiteralExp', 

                                                                                                                   }
      ,
                  	 	       'type'
       => {
	 'type_impl' => 'ref',
         'class' => 'UMMF::UML_1_5::Foundation::Core::Classifier',

                                             'col' => 'type', 

                                                                                                                   }
      ,
                  	 	                     	 	       'variableExp'
       => {
	 'type_impl' => 'iset',
         'class' => 'UMMF::UML_1_5::OCL::Expressions::VariableExp',

                           'table' => 'OCL__Expressions__VariableDeclaration__variableExp', 

                                                               'coll' => 'referredVariable',

                                                                               }
      ,
                         },
       'bases' => [  'UMMF::UML_1_5::Foundation::Core::Element',  ],
       'sql' => {

       },
     },
   ],

   'sql' =>
   {
    # Note Tangram::Ref::get_exporter() has
    # "UPDATE $table SET $self->{col} = $refid WHERE id = $id",
    # The id_col is hard-coded, 
    # Thus id_col will not work.
    #'id_col' => '__sid',
    #'class_col' => '__stype',
   },
     # 'set_id' => sub { }
     # 'get_id' => sub { }

      
  };
}


#################################################################
# Class Attributes
#


    

#################################################################
# Class Associations
#


    

#################################################################
# Initialization
#


=head2 C<___initialize>

Initialize all Attributes and AssociationEnds in a instance of this Classifier.
Does B<not> initalize slots in its Generalizations.

See also: C<__initialize>.

=cut
sub ___initialize
{
  my ($self) = @_;

  # Attributes



  # Associations

  # AssociationEnd 
  #  result 1
  #  <--> 
  #  baseExpr 0..1 UMMF::UML_1_5::OCL::Expressions::IterateExp.
    if ( defined $self->{'baseExpr'} ) {
    my $x = $self->{'baseExpr'};
    $self->{'baseExpr'} = undef;
    $self->set_baseExpr($x);
  }
  
  # AssociationEnd 
  #  initializedVariable 0..1
  #  <--> 
  #  initExpression 0..1 UMMF::UML_1_5::OCL::Expressions::OclExpression.
    if ( defined $self->{'initExpression'} ) {
    my $x = $self->{'initExpression'};
    $self->{'initExpression'} = undef;
    $self->set_initExpression($x);
  }
  
  # AssociationEnd 
  #  iterators 1..*
  #  <--> 
  #  loopExpr 0..1 UMMF::UML_1_5::OCL::Expressions::LoopExp.
    if ( defined $self->{'loopExpr'} ) {
    my $x = $self->{'loopExpr'};
    $self->{'loopExpr'} = undef;
    $self->set_loopExpr($x);
  }
  
  # AssociationEnd 
  #  tuplePart 0..*
  #  <--> 
  #  tupleLiteralExp 1 UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp.
    if ( defined $self->{'tupleLiteralExp'} ) {
    my $x = $self->{'tupleLiteralExp'};
    $self->{'tupleLiteralExp'} = undef;
    $self->set_tupleLiteralExp($x);
  }
  
  # AssociationEnd 
  #   1
  #  <--> 
  #  type 1 UMMF::UML_1_5::Foundation::Core::Classifier.
    if ( defined $self->{'type'} ) {
    my $x = $self->{'type'};
    $self->{'type'} = undef;
    $self->set_type($x);
  }
  
  # AssociationEnd 
  #  referredVariable 1
  #  <--> 
  #  variableExp 0..* UMMF::UML_1_5::OCL::Expressions::VariableExp.
    if ( defined $self->{'variableExp'} ) {
    my $x = $self->{'variableExp'};
        $self->{'variableExp'} = Set::Object->new();
        $self->set_variableExp(@$x);
  }
  

  $self;
}


my $__initialize_use;

=head2 C<__initialize>

Initialize all slots in this Classifier and all its Generalizations.

See also: C<___initialize>.

=cut
sub __initialize
{
  my ($self) = @_;

  # $DB::single = 1;

  unless ( ! $__initialize_use ) {
    $__initialize_use = 1;
    $self->__use('UMMF::UML_1_5::Foundation::Core::Element');
  }

  $self->UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::___initialize;
  $self->UMMF::UML_1_5::Foundation::Core::Element::___initialize;

  $self;
}
      

=head2 C<__create>

Calls all <<create>> Methods for this Classifier and all Generalizations.

See also: C<___create>.

=cut
sub __create
{
  my ($self, @args) = @_;

  # $DB::single = 1;
  $self->UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::___create(@args);
  $self->UMMF::UML_1_5::Foundation::Core::Element::___create();

  $self;
}




#################################################################
# Attributes
#




#################################################################
# Association
#


=for html <hr/>

=cut

#################################################################
# AssociationEnd result <---> baseExpr
# type = UMMF::UML_1_5::OCL::Expressions::IterateExp
# multiplicity = 0..1
# ordering = 

=head2 C<baseExpr>

  my $val = $obj->baseExpr;

Returns the AssociationEnd C<baseExpr> value of type L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp>.

=cut
sub baseExpr ($)
{
  my ($self) = @_;
		  
  $self->{'baseExpr'};
}


=head2 C<set_baseExpr>

  $obj->set_baseExpr($val);

Sets the AssociationEnd C<baseExpr> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp>.
Returns C<$obj>.

=cut
sub set_baseExpr ($$)
{
  my ($self, $val) = @_;
		  
  no warnings; # Use of uninitialized value in string ne at ...
		  
  my $old;
  if ( ($old = $self->{'baseExpr'}) ne $val ) { # Recursion lock

    if ( defined $val ) { $self->__use('UMMF::UML_1_5::OCL::Expressions::IterateExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.baseExpr") }

    # Recursion lock
        $self->{'baseExpr'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_result($self) if $old;
    $val->add_result($self)    if $val;

    }
		  
  $self;
}


=head2 C<add_baseExpr>

  $obj->add_baseExpr($val);

Adds the AssociationEnd C<baseExpr> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp>.
Throws exception if a value already exists.
Returns C<$obj>.

=cut
sub add_baseExpr ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'baseExpr'}) ne $val ) { # Recursion lock
    $self->__use('UMMF::UML_1_5::OCL::Expressions::IterateExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.baseExpr");
      
    # confess("UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::baseExpr: too many")
    # if defined $self->{'baseExpr'};

    # Recursion lock
        $self->{'baseExpr'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_result($self) if $old;
    $val->add_result($self)    if $val;

  
  }

  $self;
}


=head2 C<remove_baseExpr>

  $obj->remove_baseExpr($val);

Removes the AssociationEnd C<baseExpr> value C<$val>.
Returns C<$obj>.

=cut
sub remove_baseExpr ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'baseExpr'}) eq $val ) { # Recursion lock
    $val = $self->{'baseExpr'} = undef;         # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_result($self) if $old;
    $val->add_result($self)    if $val;

  
  }
}


=head2 C<clear_baseExpr>

  $obj->clear_baseExpr;

Clears the AssociationEnd C<baseExpr> links to L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp>.
Returns C<$obj>.

=cut
sub clear_baseExpr ($@)
{
  my ($self) = @_;

  my $old;
  if ( defined ($old = $self->{'baseExpr'}) ) { # Recursion lock
    my $val = $self->{'baseExpr'} = undef;      # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_result($self) if $old;
    $val->add_result($self)    if $val;

    }

  $self;
}


=head2 C<count_baseExpr>

  $obj->count_baseExpr;

Returns the number of elements of type L<UMMF::UML_1_5::OCL::Expressions::IterateExp|UMMF::UML_1_5::OCL::Expressions::IterateExp> associated with C<baseExpr>.

=cut
sub count_baseExpr ($)
{
  my ($self) = @_;

  my $x = $self->{'baseExpr'};

  defined $x ? 1 : 0;
}




=for html <hr/>

=cut

#################################################################
# AssociationEnd initializedVariable <---> initExpression
# type = UMMF::UML_1_5::OCL::Expressions::OclExpression
# multiplicity = 0..1
# ordering = 

=head2 C<initExpression>

  my $val = $obj->initExpression;

Returns the AssociationEnd C<initExpression> value of type L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression>.

=cut
sub initExpression ($)
{
  my ($self) = @_;
		  
  $self->{'initExpression'};
}


=head2 C<set_initExpression>

  $obj->set_initExpression($val);

Sets the AssociationEnd C<initExpression> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression>.
Returns C<$obj>.

=cut
sub set_initExpression ($$)
{
  my ($self, $val) = @_;
		  
  no warnings; # Use of uninitialized value in string ne at ...
		  
  my $old;
  if ( ($old = $self->{'initExpression'}) ne $val ) { # Recursion lock

    if ( defined $val ) { $self->__use('UMMF::UML_1_5::OCL::Expressions::OclExpression')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.initExpression") }

    # Recursion lock
        $self->{'initExpression'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_initializedVariable($self) if $old;
    $val->add_initializedVariable($self)    if $val;

    }
		  
  $self;
}


=head2 C<add_initExpression>

  $obj->add_initExpression($val);

Adds the AssociationEnd C<initExpression> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression>.
Throws exception if a value already exists.
Returns C<$obj>.

=cut
sub add_initExpression ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'initExpression'}) ne $val ) { # Recursion lock
    $self->__use('UMMF::UML_1_5::OCL::Expressions::OclExpression')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.initExpression");
      
    # confess("UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::initExpression: too many")
    # if defined $self->{'initExpression'};

    # Recursion lock
        $self->{'initExpression'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_initializedVariable($self) if $old;
    $val->add_initializedVariable($self)    if $val;

  
  }

  $self;
}


=head2 C<remove_initExpression>

  $obj->remove_initExpression($val);

Removes the AssociationEnd C<initExpression> value C<$val>.
Returns C<$obj>.

=cut
sub remove_initExpression ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'initExpression'}) eq $val ) { # Recursion lock
    $val = $self->{'initExpression'} = undef;         # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_initializedVariable($self) if $old;
    $val->add_initializedVariable($self)    if $val;

  
  }
}


=head2 C<clear_initExpression>

  $obj->clear_initExpression;

Clears the AssociationEnd C<initExpression> links to L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression>.
Returns C<$obj>.

=cut
sub clear_initExpression ($@)
{
  my ($self) = @_;

  my $old;
  if ( defined ($old = $self->{'initExpression'}) ) { # Recursion lock
    my $val = $self->{'initExpression'} = undef;      # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_initializedVariable($self) if $old;
    $val->add_initializedVariable($self)    if $val;

    }

  $self;
}


=head2 C<count_initExpression>

  $obj->count_initExpression;

Returns the number of elements of type L<UMMF::UML_1_5::OCL::Expressions::OclExpression|UMMF::UML_1_5::OCL::Expressions::OclExpression> associated with C<initExpression>.

=cut
sub count_initExpression ($)
{
  my ($self) = @_;

  my $x = $self->{'initExpression'};

  defined $x ? 1 : 0;
}




=for html <hr/>

=cut

#################################################################
# AssociationEnd iterators <---> loopExpr
# type = UMMF::UML_1_5::OCL::Expressions::LoopExp
# multiplicity = 0..1
# ordering = 

=head2 C<loopExpr>

  my $val = $obj->loopExpr;

Returns the AssociationEnd C<loopExpr> value of type L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp>.

=cut
sub loopExpr ($)
{
  my ($self) = @_;
		  
  $self->{'loopExpr'};
}


=head2 C<set_loopExpr>

  $obj->set_loopExpr($val);

Sets the AssociationEnd C<loopExpr> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp>.
Returns C<$obj>.

=cut
sub set_loopExpr ($$)
{
  my ($self, $val) = @_;
		  
  no warnings; # Use of uninitialized value in string ne at ...
		  
  my $old;
  if ( ($old = $self->{'loopExpr'}) ne $val ) { # Recursion lock

    if ( defined $val ) { $self->__use('UMMF::UML_1_5::OCL::Expressions::LoopExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.loopExpr") }

    # Recursion lock
        $self->{'loopExpr'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_iterators($self) if $old;
    $val->add_iterators($self)    if $val;

    }
		  
  $self;
}


=head2 C<add_loopExpr>

  $obj->add_loopExpr($val);

Adds the AssociationEnd C<loopExpr> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp>.
Throws exception if a value already exists.
Returns C<$obj>.

=cut
sub add_loopExpr ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'loopExpr'}) ne $val ) { # Recursion lock
    $self->__use('UMMF::UML_1_5::OCL::Expressions::LoopExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.loopExpr");
      
    # confess("UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::loopExpr: too many")
    # if defined $self->{'loopExpr'};

    # Recursion lock
        $self->{'loopExpr'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_iterators($self) if $old;
    $val->add_iterators($self)    if $val;

  
  }

  $self;
}


=head2 C<remove_loopExpr>

  $obj->remove_loopExpr($val);

Removes the AssociationEnd C<loopExpr> value C<$val>.
Returns C<$obj>.

=cut
sub remove_loopExpr ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'loopExpr'}) eq $val ) { # Recursion lock
    $val = $self->{'loopExpr'} = undef;         # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_iterators($self) if $old;
    $val->add_iterators($self)    if $val;

  
  }
}


=head2 C<clear_loopExpr>

  $obj->clear_loopExpr;

Clears the AssociationEnd C<loopExpr> links to L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp>.
Returns C<$obj>.

=cut
sub clear_loopExpr ($@)
{
  my ($self) = @_;

  my $old;
  if ( defined ($old = $self->{'loopExpr'}) ) { # Recursion lock
    my $val = $self->{'loopExpr'} = undef;      # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_iterators($self) if $old;
    $val->add_iterators($self)    if $val;

    }

  $self;
}


=head2 C<count_loopExpr>

  $obj->count_loopExpr;

Returns the number of elements of type L<UMMF::UML_1_5::OCL::Expressions::LoopExp|UMMF::UML_1_5::OCL::Expressions::LoopExp> associated with C<loopExpr>.

=cut
sub count_loopExpr ($)
{
  my ($self) = @_;

  my $x = $self->{'loopExpr'};

  defined $x ? 1 : 0;
}




=for html <hr/>

=cut

#################################################################
# AssociationEnd tuplePart <---> tupleLiteralExp
# type = UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp
# multiplicity = 1
# ordering = 

=head2 C<tupleLiteralExp>

  my $val = $obj->tupleLiteralExp;

Returns the AssociationEnd C<tupleLiteralExp> value of type L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp>.

=cut
sub tupleLiteralExp ($)
{
  my ($self) = @_;
		  
  $self->{'tupleLiteralExp'};
}


=head2 C<set_tupleLiteralExp>

  $obj->set_tupleLiteralExp($val);

Sets the AssociationEnd C<tupleLiteralExp> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp>.
Returns C<$obj>.

=cut
sub set_tupleLiteralExp ($$)
{
  my ($self, $val) = @_;
		  
  no warnings; # Use of uninitialized value in string ne at ...
		  
  my $old;
  if ( ($old = $self->{'tupleLiteralExp'}) ne $val ) { # Recursion lock

    if ( defined $val ) { $self->__use('UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.tupleLiteralExp") }

    # Recursion lock
        $self->{'tupleLiteralExp'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_tuplePart($self) if $old;
    $val->add_tuplePart($self)    if $val;

    }
		  
  $self;
}


=head2 C<add_tupleLiteralExp>

  $obj->add_tupleLiteralExp($val);

Adds the AssociationEnd C<tupleLiteralExp> value.
C<$val> must of type L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp>.
Throws exception if a value already exists.
Returns C<$obj>.

=cut
sub add_tupleLiteralExp ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'tupleLiteralExp'}) ne $val ) { # Recursion lock
    $self->__use('UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.tupleLiteralExp");
      
    # confess("UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::tupleLiteralExp: too many")
    # if defined $self->{'tupleLiteralExp'};

    # Recursion lock
        $self->{'tupleLiteralExp'} = $val
    ;

    # Remove and add associations with other ends.
        
    $old->remove_tuplePart($self) if $old;
    $val->add_tuplePart($self)    if $val;

  
  }

  $self;
}


=head2 C<remove_tupleLiteralExp>

  $obj->remove_tupleLiteralExp($val);

Removes the AssociationEnd C<tupleLiteralExp> value C<$val>.
Returns C<$obj>.

=cut
sub remove_tupleLiteralExp ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'tupleLiteralExp'}) eq $val ) { # Recursion lock
    $val = $self->{'tupleLiteralExp'} = undef;         # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_tuplePart($self) if $old;
    $val->add_tuplePart($self)    if $val;

  
  }
}


=head2 C<clear_tupleLiteralExp>

  $obj->clear_tupleLiteralExp;

Clears the AssociationEnd C<tupleLiteralExp> links to L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp>.
Returns C<$obj>.

=cut
sub clear_tupleLiteralExp ($@)
{
  my ($self) = @_;

  my $old;
  if ( defined ($old = $self->{'tupleLiteralExp'}) ) { # Recursion lock
    my $val = $self->{'tupleLiteralExp'} = undef;      # Recursion lock

    # Remove and add associations with other ends.
        
    $old->remove_tuplePart($self) if $old;
    $val->add_tuplePart($self)    if $val;

    }

  $self;
}


=head2 C<count_tupleLiteralExp>

  $obj->count_tupleLiteralExp;

Returns the number of elements of type L<UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp|UMMF::UML_1_5::OCL::Expressions::TupleLiteralExp> associated with C<tupleLiteralExp>.

=cut
sub count_tupleLiteralExp ($)
{
  my ($self) = @_;

  my $x = $self->{'tupleLiteralExp'};

  defined $x ? 1 : 0;
}




=for html <hr/>

=cut

#################################################################
# AssociationEnd  <---> type
# type = UMMF::UML_1_5::Foundation::Core::Classifier
# multiplicity = 1
# ordering = 

=head2 C<type>

  my $val = $obj->type;

Returns the AssociationEnd C<type> value of type L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier>.

=cut
sub type ($)
{
  my ($self) = @_;
		  
  $self->{'type'};
}


=head2 C<set_type>

  $obj->set_type($val);

Sets the AssociationEnd C<type> value.
C<$val> must of type L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier>.
Returns C<$obj>.

=cut
sub set_type ($$)
{
  my ($self, $val) = @_;
		  
  no warnings; # Use of uninitialized value in string ne at ...
		  
  my $old;
  if ( ($old = $self->{'type'}) ne $val ) { # Recursion lock

    if ( defined $val ) { $self->__use('UMMF::UML_1_5::Foundation::Core::Classifier')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.type") }

    # Recursion lock
        $self->{'type'} = $val
    ;

    # Remove and add associations with other ends.
          }
		  
  $self;
}


=head2 C<add_type>

  $obj->add_type($val);

Adds the AssociationEnd C<type> value.
C<$val> must of type L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier>.
Throws exception if a value already exists.
Returns C<$obj>.

=cut
sub add_type ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'type'}) ne $val ) { # Recursion lock
    $self->__use('UMMF::UML_1_5::Foundation::Core::Classifier')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.type");
      
    # confess("UMMF::UML_1_5::OCL::Expressions::VariableDeclaration::type: too many")
    # if defined $self->{'type'};

    # Recursion lock
        $self->{'type'} = $val
    ;

    # Remove and add associations with other ends.
        
  }

  $self;
}


=head2 C<remove_type>

  $obj->remove_type($val);

Removes the AssociationEnd C<type> value C<$val>.
Returns C<$obj>.

=cut
sub remove_type ($$)
{
  my ($self, $val) = @_;

  no warnings; # Use of uninitialized value in string ne at ...

  my $old;
  if ( ($old = $self->{'type'}) eq $val ) { # Recursion lock
    $val = $self->{'type'} = undef;         # Recursion lock

    # Remove and add associations with other ends.
        
  }
}


=head2 C<clear_type>

  $obj->clear_type;

Clears the AssociationEnd C<type> links to L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier>.
Returns C<$obj>.

=cut
sub clear_type ($@)
{
  my ($self) = @_;

  my $old;
  if ( defined ($old = $self->{'type'}) ) { # Recursion lock
    my $val = $self->{'type'} = undef;      # Recursion lock

    # Remove and add associations with other ends.
          }

  $self;
}


=head2 C<count_type>

  $obj->count_type;

Returns the number of elements of type L<UMMF::UML_1_5::Foundation::Core::Classifier|UMMF::UML_1_5::Foundation::Core::Classifier> associated with C<type>.

=cut
sub count_type ($)
{
  my ($self) = @_;

  my $x = $self->{'type'};

  defined $x ? 1 : 0;
}




=for html <hr/>

=cut

#################################################################
# AssociationEnd referredVariable <---> variableExp
# type = UMMF::UML_1_5::OCL::Expressions::VariableExp
# multiplicity = 0..*
# ordering = 

=head2 C<variableExp>

  my @val = $obj->variableExp;
  my $ary_val = $obj->variableExp;

Returns the AssociationEnd C<variableExp> values of type L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>.
In array context, returns all the objects in the Association.
In scalar context, returns an array ref of all the objects in the Association.

=cut
sub variableExp ($)
{
  my ($self) = @_;

    my $x = $self->{'variableExp'};

  # confess("Container for variableExp $x is not a blessed ref: " . Data::Dumper->new([ $self ], [qw($self)])->Maxdepth(2)->Dump()) if $x && ref($x) !~ /::/;
 
  wantarray ? ($x ? $x->members() : ()) : [ $x ? $x->members() : () ];
  
}


=head2 C<set_variableExp>

  $obj->set_variableExp(@val);

Sets the AssociationEnd C<variableExp> value.
Elements of C<@val> must of type L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>.
Returns C<$obj>.

=cut
sub set_variableExp ($@)
{
  my ($self, @val) = @_;
  
  $self->clear_variableExp;
  $self->add_variableExp(@val);
}


=head2 C<add_variableExp>

  $obj->add_variableExp(@val);

Adds AssociationEnd C<variableExp> values.
Elements of C<@val> must of type L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>.
Returns C<$obj>.

=cut
sub add_variableExp ($@)
{
  my ($self, @val) = @_;
  
    my $x = $self->{'variableExp'} ||= Set::Object->new();
    my $old; # Place holder for other MACRO.
  
  for my $val ( @val ) {
    # Recursion lock
        next if $x->includes($val);
        $self->__use('UMMF::UML_1_5::OCL::Expressions::VariableExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.variableExp");

    # Recursion lock
        $x->insert($val);
    # weaken?
    
    # Remove and add associations with other ends.
        
    $old->remove_referredVariable($self) if $old;
    $val->add_referredVariable($self)    if $val;

    }
  
  $self;
}


=head2 C<remove_variableExp>

  $obj->remove_variableExp(@val);

Removes the AssociationEnd C<variableExp> values C<@val>.
Elements of C<@val> must of type L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>.
Returns C<$obj>.

=cut
sub remove_variableExp ($@)
{
  my ($self, @val) = @_;
  
    my $x = $self->{'variableExp'} ||= Set::Object->new();
  
  for my $old ( @val ) {
    # Recursion lock
        next unless $x->includes($old);
    
    my $val = $old;
      
    $self->__use('UMMF::UML_1_5::OCL::Expressions::VariableExp')->__typecheck($val, "UMMF::UML_1_5::OCL::Expressions::VariableDeclaration.variableExp");

    # Recursion lock
        $x->remove($old);
    
    $val = undef;

    # Remove associations with other ends.

        
    $old->remove_referredVariable($self) if $old;
    $val->add_referredVariable($self)    if $val;

  ;

  }
  
  $self;
}


=head2 C<clear_variableExp>

  $obj->clear_variableExp;

Clears the AssociationEnd C<variableExp> links to L<UMMF::UML_1_5::OCL::Expressions::VariableExp|UMMF::UML_1_5::OCL::Expressions::VariableExp>.
Returns C<$obj>.

=cut
sub clear_variableExp ($) 
{
  my ($self) = @_;
  
    my $x = $self->{'variableExp'} ||= Set::Object->new();
  
  my $val; # Place holder for other MACRO.
  
    $self->{'variableExp'} = Set::Object->new(); # Recursion lock
  for my $old ( $x->members() ) {     # Recursion lock
  
    # Remove associations with other ends.

        
    $old->remove_referredVariable($self) if $old;
    $val->add_referredVariable($self)    if $val;

  ;

  }
  
  $self;
}


=head2 C<count_variableExp>

  $obj->count_variableExp;

Returns the number of elements associated with C<variableExp>.

=cut
sub count_variableExp ($)
{
  my ($self) = @_;

  my $x = $self->{'variableExp'};

    defined $x ? $x->size : 0;
  }







# End of Class VariableDeclaration


=pod

=for html <hr/>

I<END OF DOCUMENT>

=cut

############################################################################

1; # is true!

############################################################################

### Keep these comments at end of file: kstephens@users.sourceforge.net 2003/04/06 ###
### Local Variables: ###
### mode:perl ###
### perl-indent-level:2 ###
### perl-continued-statement-offset:0 ###
### perl-brace-offset:0 ###
### perl-label-offset:0 ###
### End: ###

