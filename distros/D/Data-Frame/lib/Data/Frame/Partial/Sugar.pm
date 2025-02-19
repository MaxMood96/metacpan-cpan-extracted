package Data::Frame::Partial::Sugar;
$Data::Frame::Partial::Sugar::VERSION = '0.006004';
# ABSTRACT: Partial class for data frame syntax sugar

use Data::Frame::Role;
use namespace::autoclean;

package Tie::Data::Frame {
$Tie::Data::Frame::VERSION = '0.006004';

    use Scalar::Util qw(weaken);
    use Types::PDL qw(Piddle);
    use Types::Standard qw(ArrayRef Value);
    use Type::Params;

    sub new {
        my ($class, $object) = @_;
        my $self = bless( { _object => $object }, $class);
        weaken( $self->{_object} );
        return $self;
    }

    sub TIEHASH {
        my $class = shift;
        return $class->new(@_);
    }

    sub object { $_[0]->{_object} }

    sub _check_key {
        my $self = shift;
        state $check = Type::Params::compile(Value | ArrayRef | Piddle);
        my ($key) = $check->(@_);
        return $key;
    }

    sub STORE {
        my ( $self, $key, $val ) = @_;
        $key = $self->_check_key($key);

        if ( Ref::Util::is_ref($key) ) {
            $self->object->slice($key) .= $val;
        } else {
            $self->object->set($key, $val);
        }
    }

    sub FETCH {
        my ( $self, $key ) = @_;
        $key = $self->_check_key($key);

        if ( Ref::Util::is_ref($key) ) {
            return $self->object->slice($key);
        } else {
            return $self->object->at($key);
        }
    }

    sub EXISTS {
        my ($self, $key) = @_;
        return $self->object->exists($key);
    }

    sub FIRSTKEY {
        my ($self) = @_;
        $self->{_list} = [ @{$self->object->names} ];
        return $self->NEXTKEY;
    }

    sub NEXTKEY {
        my ($self) = @_;
        return shift @{$self->{_list}};
    }
}

use overload (
    '%{}' => sub {    # for working with Tie::Data::Frame
        my ($self)   = @_;

        # This is brittle as we are depending on an private thing of Moo... 
        my ($caller) = caller();
        if ( $caller eq 'Method::Generate::Accessor::_Generated' ) {
            return $self;
        }
        my $tmp = $self->_tie_hash; # avoid // as breaks Devel::Cover
        $tmp = $self if !defined $tmp;
        $tmp;
    },
    fallback => 1
);

has _tie_hash => ( is => 'rw' );

method _initialize_sugar() {
    my %hash;
    tie %hash, qw(Tie::Data::Frame), $self;
    $self->_tie_hash( \%hash );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Frame::Partial::Sugar - Partial class for data frame syntax sugar

=head1 VERSION

version 0.006004

=head1 SYNOPSIS

    use Data::Frame::Examples qw(mtcars);
    
    # A key of string type does at() or set()
    my $col1 = $mtcars->{mpg};                  # $mtcars->at('mpg');
    $mtcars->{kpg} = $mtcars->{mpg} * 1.609;    # $mtcars->set('kpg', ...);

    # A key of reference does slice() 
    my $col2 = $mtcars->{ ['mpg'] };            # $mtcars->slice(['mpg']);
    my $subset = $mtcars->{ [qw(mpg cyl)] };    # $mtcars->slice([qw(mpg cyl]);

=head1 DESCRIPTION

Do not use this module in your code. This is only internally used by
L<Data::Frame>.

=head1 SEE ALSO

L<Data::Frame>

=head1 AUTHORS

=over 4

=item *

Zakariyya Mughal <zmughal@cpan.org>

=item *

Stephan Loyd <sloyd@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014, 2019-2022 by Zakariyya Mughal, Stephan Loyd.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
