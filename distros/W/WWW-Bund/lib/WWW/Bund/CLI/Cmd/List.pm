package WWW::Bund::CLI::Cmd::List;
our $VERSION = '0.002';
# ABSTRACT: List all available APIs

use Moo;
use MooX::Cmd;
use MooX::Options;


sub execute {
    my ($self, $args, $chain) = @_;
    my $main = $chain->[0];
    $main->cmd_list();
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::List - List all available APIs

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    bund list
    bund list --output json

=head1 DESCRIPTION

CLI command for listing all registered APIs. Displays ID, title, auth type,
and tags in table format (or JSON/YAML).

See L<WWW::Bund::CLI>.

=head2 execute

Delegate to L<WWW::Bund::CLI/cmd_list>.

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
