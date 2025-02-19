package Util::Medley::Roles::Attributes::String;
$Util::Medley::Roles::Attributes::String::VERSION = '0.062';
use Modern::Perl;
use Moose::Role;
use Util::Medley::String;

=head1 NAME

Util::Medley::Roles::Attributes::String

=head1 VERSION

version 0.062

=cut

has String => (
	is      => 'ro',
	isa     => 'Util::Medley::String',
	lazy    => 1,
	default => sub { return Util::Medley::String->new },
);

1;
