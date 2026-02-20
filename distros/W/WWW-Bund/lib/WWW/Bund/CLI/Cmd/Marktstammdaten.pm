package WWW::Bund::CLI::Cmd::Marktstammdaten;
our $VERSION = '0.002';
use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;

with 'WWW::Bund::CLI::Role::APICommand';

sub api_id { 'marktstammdaten' }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::Marktstammdaten

=head1 VERSION

version 0.002

=head1 SYNOPSIS

  bund marktstammdaten strom-erzeugung
  bund marktstammdaten gas-verbrauch

=head1 DESCRIPTION

Command interface for Marktstammdatenregister API (Bundesnetzagentur).

=head1 NAME

WWW::Bund::CLI::Cmd::Marktstammdaten - Energy market master data command

=head1 SEE ALSO

L<WWW::Bund::CLI>, L<WWW::Bund::CLI::Role::APICommand>

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
