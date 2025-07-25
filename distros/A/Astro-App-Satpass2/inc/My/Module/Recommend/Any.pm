package My::Module::Recommend::Any;

use 5.008;

use strict;
use warnings;

use Carp;
use Exporter qw{ import };

our $VERSION = '0.057';

our @EXPORT_OK = qw{ __any };

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

    foreach ( @modules ) {
	my ( $name, $version ) = split qr{ = }smx, $_, 2;
	$_ = [ $name, $version ];
    }

    return bless {
	modules	=> \@modules,
	message	=> $msg,
    }, ref $class || $class;
}

sub check {
    my ( $self ) = @_;
    my @missing;
    foreach my $m ( $self->__modules() ) {
	my $msg = $self->module_is_ok( @{ $m } )
	    or return;
	push @missing, $msg;
    }
    return @missing;
}

sub module_is_ok {
    my ( undef, $name, $version ) = @_;
    local $@ = undef;
    eval "require $name; 1"
	and eval {
	not $version
	    or $name->VERSION( $version );
    } and return;
    return $version ? "$name $version" : $name;
}

sub modules {
    my ( $self ) = @_;
    return ( map { $_->[0] } $self->__modules() );
}

sub __modules {
    my ( $self ) = @_;
    return @{ $self->{modules} };
}

sub recommend {
    my ( $self ) = @_;
    my @missing = $self->check()
	or return;
    my $tplt = @missing > 1 ?
	$self->RECOMMEND_TEMPLATE_MULTI() :
	$self->RECOMMEND_TEMPLATE_SINGLE();
    return sprintf( $tplt, join ', ', @missing ) .
	$self->{message};
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

Any or all of the module names can be optionally followed by an equals
sign (C<'='>) and the minimum required version number.

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

=head2 module_is_ok

 $rec->module_is_ok( 'Fubar', 1.2 );

This method checks to see if the given module is OK for use. To be OK
for use it must be loadable. If the optional version is given it must be
at least that version.

Despite the name, the return is a message if the module is not OK, or
nothing if it is OK.

This is really just exposed for the use of the L<check()|/check> method.

=head2 modules

 say 'Optional modules: ', join ', ', $rec->modules();

This method just returns the names of the modules with which the object
was initialized.

=head2 __modules

B<This method is private to the Astro-App-Satpass2 package.>

This method returns array references, with element 0 of each reference
being the module name, and element 1 being the version, if any.

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
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-App-Satpass2>,
L<https://github.com/trwyant/perl-Astro-App-Satpass2/issues>, or in
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
