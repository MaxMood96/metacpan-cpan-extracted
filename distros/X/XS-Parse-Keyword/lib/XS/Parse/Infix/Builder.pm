#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2021 -- leonerd@leonerd.org.uk

package XS::Parse::Infix::Builder 0.48;

use v5.14;
use warnings;

=head1 NAME

C<XS::Parse::Infix::Builder> - build-time support for C<XS::Parse::Infix>

=head1 SYNOPSIS

=for highlighter language=perl

In F<Build.PL>:

   use XS::Parse::Infix::Builder;

   my $build = Module::Build->new(
      ...,
      configure_requires => {
         ...
         'XS::Parse::Infix::Builder' => 0,
      }
   );

   XS::Parse::Infix::Builder->extend_module_build( $build );

   ...

=head1 DESCRIPTION

This module provides a build-time helper to assist authors writing XS modules
that use L<XS::Parse::Infix>. It prepares a L<Module::Build>-using
distribution to be able to make use of C<XS::Parse::Infix>.

=cut

require XS::Parse::Infix::Builder_data;

=head1 FUNCTIONS

=cut

=head2 write_XSParseInfix_h

   XS::Parse::Infix::Builder->write_XSParseInfix_h;

This method no longer does anything I<since version 0.43>.

=cut

sub write_XSParseInfix_h
{
}

=head2 extra_compiler_flags

   @flags = XS::Parse::Infix::Builder->extra_compiler_flags;

Returns a list of extra flags that the build scripts should add to the
compiler invocation. This enables the C compiler to find the
F<XSParseInfix.h> file.

=cut

sub extra_compiler_flags
{
   shift;

   require File::ShareDir;
   require File::Spec;
   require XS::Parse::Infix;

   return "-I" . File::Spec->catdir( File::ShareDir::module_dir( "XS::Parse::Infix" ), "include" ),
      XS::Parse::Infix::Builder_data->BUILDER_CFLAGS;
}

=head2 extend_module_build

   XS::Parse::Infix::Builder->extend_module_build( $build );

A convenient shortcut for performing all the tasks necessary to make a
L<Module::Build>-based distribution use the helper.

=cut

sub extend_module_build
{
   my $self = shift;
   my ( $build ) = @_;

   # preserve existing flags
   my @flags = @{ $build->extra_compiler_flags };
   push @flags, $self->extra_compiler_flags;

   $build->extra_compiler_flags( @flags );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
