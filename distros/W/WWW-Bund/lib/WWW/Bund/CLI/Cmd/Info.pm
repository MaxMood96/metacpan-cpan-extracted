package WWW::Bund::CLI::Cmd::Info;
our $VERSION = '0.001';
# ABSTRACT: Show detailed API information

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;


sub execute {
    my ($self, $args, $chain) = @_;
    my $main = $chain->[0];

    unless (@$args) {
        warn $main->_s('err_usage_info') . "\n";
        exit(1);
    }

    my $api = $main->_resolve_api($args->[0]);
    $main->cmd_info($api);
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Cmd::Info - Show detailed API information

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    bund info autobahn
    bund info pegel --output json

=head1 DESCRIPTION

CLI command for displaying detailed information about an API: provider, auth
requirements, documentation URL, rate limits, and list of available endpoints.

See L<WWW::Bund::CLI>.

=head2 execute

Validate arguments and delegate to L<WWW::Bund::CLI/cmd_info>.

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
