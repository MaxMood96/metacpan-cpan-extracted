# Generated by Class::Inline version 0.0.1
# Date: Fri Oct 14 11:22:23 2022
use strict;
use warnings;

package App::githook::perltidy::install;BEGIN {require App::githook::perltidy;our@ISA=('App::githook::perltidy')};our$_HAS;sub App::githook::perltidy::install_CI::import {shift;$_HAS={@_ > 1 ? @_ : %{$_[0]}};$_HAS=$_HAS->{'has'}if exists$_HAS->{'has'}}our%_ATTRS;my%_BUILD_CHECK;sub new {my$class=shift;my$self={@_ ? @_ > 1 ? @_ : %{$_[0]}: ()};%_ATTRS=map {($_=>1)}keys %$self;bless$self,ref$class || $class;$_BUILD_CHECK{$class}//= do {my@possible=($class);my@BUILD;my@CHECK;while (@possible){no strict 'refs';my$c=shift@possible;push@BUILD,$c .'::BUILD' if exists &{$c .'::BUILD'};push@CHECK,$c .'::__CHECK' if exists &{$c .'::__CHECK'};push@possible,@{$c .'::ISA'}}[reverse(@CHECK),reverse(@BUILD)]};map {$self->$_}@{$_BUILD_CHECK{$class}};Carp::carp("App::githook::perltidy::install attribute '$_' unexpected")for keys%_ATTRS;$self}sub __RO {my (undef,undef,undef,$sub)=caller(1);Carp::croak("attribute $sub is read-only")}sub __CHECK {no strict 'refs';my$_attrs=*{ref($_[0]).'::_ATTRS'};map {delete$_attrs->{$_}}keys %$_HAS}sub absolute {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'absolute'}}sub force {$_[0]->__RO($_[1])if @_ > 1;$_[0]{'force'}}BEGIN {$INC{'App/githook/perltidy/install.pm'}=__FILE__}
1;
