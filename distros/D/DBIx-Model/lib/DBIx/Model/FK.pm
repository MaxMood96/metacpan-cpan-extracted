package DBIx::Model::FK;
use strict;
use warnings;
use Scalar::Util qw/weaken/;
use Types::Standard qw/ArrayRef/;

our $VERSION = '0.0.1';
our $INLINE  = {
    _columns => {
        is       => 'ro',
        isa      => ArrayRef,
        init_arg => 'columns',
        required => 1,
    },
    table => {
        is       => 'ro',
        required => 1,
        weaken   => 1,
    },
    _to_columns => {
        is       => 'ro',
        isa      => ArrayRef,
        init_arg => 'to_columns',
        required => 1,
    },
    to_table => {
        is       => 'ro',
        required => 1,
        weaken   => 1,
    },
};

sub BUILD {
    my $self = shift;

    my @list = @{ $self->_columns };
    foreach my $i ( 0 .. $#list ) {
        weaken( $self->_columns->[$i] );
        $self->_columns->[$i]->bump_ref_count;
    }

    @list = @{ $self->_to_columns };
    foreach my $i ( 0 .. $#list ) {
        weaken( $self->_to_columns->[$i] );
        $self->_to_columns->[$i]->bump_target_count;
    }
}

sub as_string {
    my $self   = shift;
    my $prefix = shift;
    my $str =
        $prefix
      . "FOREIGN KEY("
      . join( ',', map { $_->name } $self->columns )
      . ') REFERENCES '
      . $self->to_table->name . '('
      . join( ',', map { $_->name } $self->to_columns ) . ')';

    return $str;
}

sub columns {
    my $self = shift;
    return @{ $self->_columns } if wantarray;
    return $self->_columns;
}

sub to_columns {
    my $self = shift;
    return @{ $self->_to_columns } if wantarray;
    return $self->_to_columns;
}

### DO NOT EDIT BELOW! (generated by Class::Inline v0.0.1)
#<<<
  require Carp;require Scalar::Util;our@ATTRS_UNEX=(undef);sub new {my$class=
  shift;my$self={@_ ? @_ > 1 ? @_ : %{$_[0]}: ()};map {local$Carp::CarpLevel=
  $Carp::CarpLevel + 1;Carp::croak(
  "missing attribute DBIx::Model::FK::$_ is required")unless exists$self->{$_}
  }'columns','to_columns','table','to_table';$self->{'_columns'}=delete$self->
  {'columns'}if exists$self->{'columns'};$self->{'_to_columns'}=delete$self->{
  'to_columns'}if exists$self->{'to_columns'};if (@ATTRS_UNEX){map {local
  $Carp::CarpLevel=$Carp::CarpLevel + 1;Carp::carp(
  "DBIx::Model::FK attribute '$_' unexpected");delete$self->{$_ }}sort grep {
  not exists$INLINE->{$_ }}keys %$self}else {@ATTRS_UNEX=map {delete$self->{$_
  };$_}grep {not exists$INLINE->{$_ }}keys %$self}bless$self,ref$class ||
  $class;map {$self->{$_ }=eval {$INLINE->{$_ }->{'isa'}->($self->{$_ })};
  Carp::croak(qq{DBIx::Model::FK::$_ value invalid ($@)})if $@}grep {exists
  $self->{$_ }}'_columns','_to_columns';map {Scalar::Util::weaken($self->{$_ }
  )}grep {exists($self->{$_})&& defined$self->{$_ }}'table','to_table';my
  @check=('DBIx::Model::FK');my@parents;while (@check){no strict 'refs';my$c=
  shift@check;push@parents,@{$c .'::ISA'};push@check,@{$c .'::ISA'}}map {$_->
  BUILD()if exists &{$_.'::BUILD'}}reverse@parents;$self->BUILD()if exists &{
  'BUILD'};$self}sub __ro {my (undef,undef,undef,$sub)=caller(1);local
  $Carp::CarpLevel=$Carp::CarpLevel + 1;Carp::croak(
  "attribute $sub is read-only (value: '" .($_[1]// 'undef')."')")}sub
  _columns {$_[0]->__ro($_[1])if @_ > 1;$_[0]{'_columns'}}sub _to_columns {$_[
  0]->__ro($_[1])if @_ > 1;$_[0]{'_to_columns'}}sub table {$_[0]->__ro($_[1])
  if @_ > 1;$_[0]{'table'}}sub to_table {$_[0]->__ro($_[1])if @_ > 1;$_[0]{
  'to_table'}}
#>>>
### DO NOT EDIT ABOVE! (generated by Class::Inline v0.0.1)

1;
