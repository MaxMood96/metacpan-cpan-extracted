package My::Module::Recommend::Any;

use 5.006002;

use strict;
use warnings;

use Carp;
use Exporter qw{ import };

our $VERSION = '0.133';

our @EXPORT_OK = qw{ __any };

use constant ARRAY_REF	=> ref [];

use constant RECOMMEND_TEMPLATE_SINGLE	=> "    * %s is not available.\n";
use constant RECOMMEND_TEMPLATE_MULTI	=> "    * None of %s is available.\n";

sub __any {
    my ( @args ) = @_;
    return __PACKAGE__->new( @args );
}

sub new {
    my ( $class, @modules ) = @_;
    @modules > 1
	or croak 'Must specify at least one module and a message';
    my $msg = pop @modules;
    $msg =~ s/ ^\s* /      /smxg;

    return bless {
	modules	=> \@modules,
	message	=> $msg,
    }, ref $class || $class;
}

sub check {
    my ( $self ) = @_;
    my @missing;
    foreach my $m ( @{ $self->{modules} } ) {
	$self->__is_module_available( $m )
	    and return;
	push @missing, $m;
    }
    return @missing;
}

sub __is_module_available {
    my ( undef, $m ) = @_;
    my ( $mod, $ver ) = ARRAY_REF eq ref $m ? @{ $m } : ( $m );
    my @eval = ( "require $mod;" );
    defined $ver
	and push @eval, "$mod->VERSION( $ver );";
    eval "@eval 1;"
	and return $m;
    return;
}

sub modules {
    my ( $self ) = @_;
    return (
	map { ARRAY_REF eq ref $_ ? $_->[0] : $_ }
	@{ $self->{modules} }
    );
}

*test_without = \&modules;

sub recommend {
    my ( $self ) = @_;
    my @missing = $self->check()
	or return;
    my $tplt = @missing > 1 ?
	$self->RECOMMEND_TEMPLATE_MULTI() :
	$self->RECOMMEND_TEMPLATE_SINGLE();
    return sprintf( $tplt, join ', ', _module_stringify( @missing ) ) .
	$self->{message};
}

sub _module_stringify {
    my @arg = @_;
    my @rslt;
    foreach my $m ( @arg ) {
	push @rslt, ARRAY_REF eq ref $m ? "@{ $m }" : $m;
    }
    return @rslt;
}

1;

__END__

=head1 NAME

My::Module::Recommend::Any - Recommend unless any of a list of modules is installed.

=head1 SYNOPSIS

 use My::Module::Recommend::Any qw{ __any };
 
 my $rec = __any( Fubar => <<'EOD' );
       This module is needed to frozz a gaberbucket. If your
       gaberbucket does not need frozzing you do not need this module.
 EOD
 print $rec->recommend();
 
 my $rec2 = __any( [ Bazzle => 3.14 ] => <<'EOD' );
       At least version 3.14 of this module is needed to mangle
       the blitherskeen.
 EOD
 print $rec2->recommend();

=head1 DESCRIPTION

This module is private to this package, and may be changed or retracted
without notice. Documentation is for the benefit of the author only.

This module checks whether B<any> modules in given list are installed.
If not, it is capable of generating an explanatory message.

I am using this rather than the usual install tools' recommendation
machinery for greater flexibility, and because I personally have found
their output rather Draconian, and my correspondance indicates that my
users do too.

=head1 METHODS

This class supports the following methods which are private to this
package and can be changed or retracted without notice.

=head2 new

 my $rec = My::Module::Recommend::Any->new( Foo => "bar\n" );

This static method instantiates the object. The arguments are module
names, of which at least one must be installed. The last argument,
however, is text giving the reason you need one of the modules.

If you need to specify a minimum version of the module, pass a reference
to an array whose first element is the module name and whose second
element is the version number.

=head2 __any

 my $rec = __any( Foo => "bar\n" );

This convenience subroutine (B<not> method) wraps L<new()|/new>. It is
not exported by default, but can be requested explicitly.

=head2 check

 $rec->check()
     and warn 'Modules are missing';

This method checks to see if any of the given modules are installed. The
check is by C<eval "require $module_name; 1"> on each module. If at
least one of the modules are installed it returns nothing. If not, it
returns the names of the missing modules in list context, and the number
of missing modules in scalar context.

=head2 modules

 say 'Optional modules: ', join ', ', $rec->modules();

This method just returns the names of the modules with which the object
was initialized.

=head2 test_without

 say 'Test without: ', join ', ', $rec->test_without();

This method returns the names of the modules to test without. At this
level of the hierarchy it is a synonym for L<modules()|/modules>.

=head2 recommend

 my $msg;
 defined( $msg = $rec->recommend() )
     and print $msg;

This method computes and returns a recommendation on modules to install.
This will consist of a line of text listing the missing modules followed
by the explanatory text with which the object was initialized. If no
modules are needed it returns nothing.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-satpass>,
L<https://github.com/trwyant/perl-Astro-Coord-ECI/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Tom Wyant (wyant at cpan dot org)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
