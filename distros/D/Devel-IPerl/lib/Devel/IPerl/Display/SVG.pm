package Devel::IPerl::Display::SVG;
$Devel::IPerl::Display::SVG::VERSION = '0.012';
use strict;
use warnings;

use Moo;
with qw(Devel::IPerl::Display::Role::Displayable Devel::IPerl::Display::Role::MIMESource Devel::IPerl::Display::Role::WebImage);

sub _as_text_plain {
	'[SVG image]', # TODO get dimensions?
}
sub _build_mimetype { 'image/svg+xml' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::IPerl::Display::SVG

=head1 VERSION

version 0.012

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Zakariyya Mughal.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
