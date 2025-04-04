# -*- perl -*-
# DO NOT EDIT - This file is generated by UMMF; http://ummf.sourceforge.net 
# From template: $Id: Perl.txt,v 1.77 2006/05/14 01:40:03 kstephens Exp $

package UMMF::MOF_1_3::Model::DirectionKind;

#use 5.6.1;
use strict;
use warnings;

#################################################################
# Version
#

our $VERSION = do { my @r = (q{1.3} =~ /\d+/g); sprintf "%d." . "%03d" x $#r, @r };


#################################################################
# Documentation
#

=head1 NAME

UMMF::MOF_1_3::Model::DirectionKind -- 

=head1 VERSION

1.3

=head1 SYNOPSIS

=head1 DESCRIPTION 

=head1 USAGE

=head1 EXPORT

=head1 METATYPE

L<UMMF::UML_1_5::Foundation::Core::Enumeration|UMMF::UML_1_5::Foundation::Core::Enumeration>

=head1 SUPERCLASSES

L<UMMF::MOF_1_3::__ObjectBase|UMMF::MOF_1_3::__ObjectBase>




=head1 ENUMERATION LITERALS


=head2 C<in_dir>




=head2 C<out_dir>




=head2 C<inout_dir>




=head2 C<return_dir>





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
use UMMF::MOF_1_3::__ObjectBase qw(:__ummf_array);


#################################################################
# Generalizations
#

use base qw(


  UMMF::MOF_1_3::__ObjectBase
  Exporter

);


#################################################################
# Exports
#

our @EXPORT_OK = qw(
      IN_DIR      OUT_DIR      INOUT_DIR      RETURN_DIR  );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

=head2 C<new>

  my $x = UMMF::MOF_1_3::Model::DirectionKind->new($literal);

Constructs new UMMF::MOF_1_3::Model::DirectionKind literal value.
C<$literal> must be one of the following:

=over 4


=item * 'in_dir'


=item * 'out_dir'


=item * 'inout_dir'


=item * 'return_dir'


=back

=cut
sub new
{
  my ($self, @args) = @_;
  my $x = pop(@args);
  __typecheck($self, $x, 'UMMF::MOF_1_3::Model::DirectionKind::new');
  $x;
}




#################################################################
# EnumerationLiterals
#


=head2 C<IN_DIR>

Returns 'in_dir'.

=cut
sub IN_DIR{
  'in_dir';
}


=head2 C<OUT_DIR>

Returns 'out_dir'.

=cut
sub OUT_DIR{
  'out_dir';
}


=head2 C<INOUT_DIR>

Returns 'inout_dir'.

=cut
sub INOUT_DIR{
  'inout_dir';
}


=head2 C<RETURN_DIR>

Returns 'return_dir'.

=cut
sub RETURN_DIR{
  'return_dir';
}




#################################################################
# Validation
#

my %__literal = 
(
    'in_dir' => 'in_dir',
    'out_dir' => 'out_dir',
    'inout_dir' => 'inout_dir',
    'return_dir' => 'return_dir',
  );

=head2 C<__validate_type>

  UMMF::MOF_1_3::Model::DirectionKind->__validate_type($value);

Returns true if C<$value> is a valid representation of L<UMMF::MOF_1_3::Model::DirectionKind|UMMF::MOF_1_3::Model::DirectionKind>.

=cut
sub __validate_type($$)
{
  my ($self, $x) = @_;

  no warnings;

  $__literal{$x}  ;
}


=head2 C<__typecheck>

  UMMF::MOF_1_3::Model::DirectionKind->__typecheck($value, $msg);

Calls C<confess()> with C<$msg> if C<<UMMF::MOF_1_3::Model::DirectionKind->__validate_type($value)>> is false.

=cut
sub __typecheck
{
  my ($self, $x, $msg) = @_;

  confess("typecheck: $msg: type '" . 'UMMF::MOF_1_3::Model::DirectionKind' . ": value '$x'")
    unless __validate_type($self, $x);
}


=head2 C<isaDirectionKind>


Returns true if receiver is a L<UMMF::MOF_1_3::Model::DirectionKind|UMMF::MOF_1_3::Model::DirectionKind>.
Other receivers will return false.

=cut
sub isaDirectionKind { 1 }


=head2 C<isaModel__DirectionKind>


Returns true if receiver is a L<UMMF::MOF_1_3::Model::DirectionKind|UMMF::MOF_1_3::Model::DirectionKind>.
Other receivers will return false.
This is the fully qualified version of the C<isaDirectionKind> method.

=cut
sub isaModel__DirectionKind { 1 }


#################################################################
# Introspection
#

=head2 C<__model_name> 

  my $name = $obj_or_package->__model_name;

Returns the UML Model name (C<'Model::DirectionKind'>) for an object or package of
this Classifier.

=cut
sub __model_name { 'Model::DirectionKind' }



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
  }

  $self->UMMF::MOF_1_3::Model::DirectionKind::___initialize;

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
  $self->UMMF::MOF_1_3::Model::DirectionKind::___create(@args);

  $self;
}




#################################################################
# Attributes
#




#################################################################
# Association
#





# End of Class DirectionKind


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

