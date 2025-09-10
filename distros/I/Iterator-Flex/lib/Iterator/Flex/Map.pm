package Iterator::Flex::Map;

# ABSTRACT: Map Iterator Class

use strict;
use warnings;
use experimental 'signatures';

our $VERSION = '0.29';

use Iterator::Flex::Utils qw( STATE THROW EXHAUSTION :IterAttrs :IterStates );
use Iterator::Flex::Factory;
use Ref::Util;
use parent 'Iterator::Flex::Base';

use namespace::clean;






























sub new ( $class, $code, $iterable, $pars = {} ) {
    $class->_throw( parameter => q{'code' parameter is not a coderef} )
      unless Ref::Util::is_coderef( $code );

    $class->SUPER::new( { code => $code, src => $iterable }, $pars );
}

sub construct ( $class, $state ) {

    $class->_throw( parameter => q{'state' parameter must be a HASH reference} )
      unless Ref::Util::is_hashref( $state );

    my ( $code, $src ) = @{$state}{qw[ code src ]};

    $src
      = Iterator::Flex::Factory->to_iterator( $src, { ( +EXHAUSTION ) => THROW } );

    my @values;
    my $self;
    my $iterator_state;

    return {
        ( +_NAME ) => 'imap',

        ( +_SELF ) => \$self,

        ( +STATE ) => \$iterator_state,

        ( +NEXT ) => sub {
            return $self->signal_exhaustion if $iterator_state == IterState_EXHAUSTED;

            ## no critic( Until )
            until ( @values ) {
                @values = eval {
                    my $value = $src->();
                    local $_ = $value;
                    $code->();
                };
                if ( $@ ne q{} ) {
                    die $@
                      unless Ref::Util::is_blessed_ref( $@ )
                      && $@->isa( 'Iterator::Flex::Failure::Exhausted' );
                    return $self->signal_exhaustion;
                }
            }
            return shift @values;
        },

        ( +RESET )    => sub { @values = () },
        ( +REWIND )   => sub { @values = () },
        ( +_DEPENDS ) => $src,
    };
}


__PACKAGE__->_add_roles( qw[
      State::Closure
      Next::ClosedSelf
      Reset::Closure
      Rewind::Closure
] );

1;

#
# This file is part of Iterator-Flex
#
# This software is Copyright (c) 2018 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

Iterator::Flex::Map - Map Iterator Class

=head1 VERSION

version 0.29

=head1 METHODS

=head2 new

  $iterator = Ierator::Flex::Map->new( $coderef, $iterable, ?\%pars );

Returns an iterator equivalent to running C<map> on C<$iterable> with
the specified code.  If C<$coderef> returns a list, the elements will
be returned singly.

C<CODE> is I<not> run if C<$iterable> is exhausted.

C<$iterable> is converted into an iterator via L<Iterator::Flex::Factory/to_iterator> if required.

The optional C<%pars> hash may contain standard L<signal
parameters|Iterator::Flex::Manual::Overview/Signal Parameters>.

The iterator supports the following capabilities:

=over

=item next

=item reset

=item rewind

=back

=head1 INTERNALS

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-iterator-flex@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Iterator-Flex>

=head2 Source

Source is available at

  https://gitlab.com/djerius/iterator-flex

and may be cloned from

  https://gitlab.com/djerius/iterator-flex.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Iterator::Flex|Iterator::Flex>

=back

=head1 AUTHOR

Diab Jerius <djerius@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
