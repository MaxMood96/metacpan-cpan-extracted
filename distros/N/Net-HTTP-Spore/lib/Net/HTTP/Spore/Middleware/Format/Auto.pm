package Net::HTTP::Spore::Middleware::Format::Auto;
$Net::HTTP::Spore::Middleware::Format::Auto::VERSION = '0.09';
use Moose;
use MooseX::Types::Moose qw/HashRef Object/;
extends 'Net::HTTP::Spore::Middleware::Format';

use Try::Tiny;

has serializer => (
    is      => 'rw',
    isa     => HashRef [Object],
    lazy    => 1,
    default => sub { {} },
);

sub call {
    my ( $self, $req ) = @_;

    my $formats = $req->env->{'spore.format'};

    foreach my $format (@$formats) {
        my $cls = "Net::HTTP::Spore::Middleware::Format::" . $format;
        if ( Class::MOP::load($cls) ) {
            my $s = $cls->new;
            $self->serializer->{$format} = $s;
            try {
                if ( $req->env->{'spore.payload'} ) {
                    $req->env->{'spore.payload'} =
                      $s->encode( $req->env->{'spore.payload'} );
                    $req->header( $s->content_type );
                }
                $req->header( $s->accept_type );
                $req->env->{$self->serializer_key} = 1;
            };
            last if $req->env->{$self->serializer_key} == 1;
        }
    }

    return $self->response_cb(
        sub {
            my $res = shift;
            return $res;
        }
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::HTTP::Spore::Middleware::Format::Auto

=head1 VERSION

version 0.09

=head1 DESCRIPTION

B<NOT WORKING>

=head1 AUTHORS

=over 4

=item *

Franck Cuny <franck.cuny@gmail.com>

=item *

Ash Berlin <ash@cpan.org>

=item *

Ahmad Fatoum <athreef@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Linkfluence.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
