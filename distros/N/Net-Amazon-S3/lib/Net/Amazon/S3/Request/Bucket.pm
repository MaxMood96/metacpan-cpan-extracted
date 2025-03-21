package Net::Amazon::S3::Request::Bucket;
# ABSTRACT: Base class for all S3 Bucket operations
$Net::Amazon::S3::Request::Bucket::VERSION = '0.991';
use Moose 0.85;
use MooseX::StrictConstructor 0.16;
extends 'Net::Amazon::S3::Request::Service';

with 'Net::Amazon::S3::Role::Bucket';

override _request_path => sub {
	my ($self) = @_;

	return super . $self->bucket->bucket . "/";
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::Amazon::S3::Request::Bucket - Base class for all S3 Bucket operations

=head1 VERSION

version 0.991

=head1 AUTHOR

Branislav Zahradník <barney@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Amazon Digital Services, Leon Brocard, Brad Fitzpatrick, Pedro Figueiredo, Rusty Conover, Branislav Zahradník.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
