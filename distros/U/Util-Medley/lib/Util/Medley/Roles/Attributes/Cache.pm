package Util::Medley::Roles::Attributes::Cache;
$Util::Medley::Roles::Attributes::Cache::VERSION = '0.062';
use Modern::Perl;
use Moose::Role;
use Util::Medley::Cache;

=head1 NAME

Util::Medley::Roles::Attributes::Cache

=head1 VERSION

version 0.062

=cut

has Cache => (
	is      => 'ro',
	isa     => 'Util::Medley::Cache',
	lazy    => 1,
	default => sub { return Util::Medley::Cache->new },
);

1;
