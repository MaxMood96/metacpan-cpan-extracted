package Net::Amazon::EC2::TagSet;
$Net::Amazon::EC2::TagSet::VERSION = '0.36';
use Moose;

=head1 NAME

Net::Amazon::EC2::TagSet

=head1 DESCRIPTION

A class containing information about a tag.

=head1 ATTRIBUTES

=over

=item key (required)

The key of the tag.

=item value 

The value of the tag. (May be undefined if there is no value for a given key.)

=cut

has 'key'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'value' => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );

__PACKAGE__->meta->make_immutable();

=back

=head1 AUTHOR

Jeff Kim <cpan@chosec.com>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Jeff Kim. This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

no Moose;
1;

