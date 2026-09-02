package App::Envdoctor;

# Local-first consistency checker for environment variables.
# See App::Envdoctor::Scanner for the scanning API and bin/envdoctor for the CLI.

use strict;
use warnings;

our $VERSION = '0.1.2';

1;

__END__

=head1 NAME

App::Envdoctor - Local-first consistency checker for environment variables

=head1 SYNOPSIS

    envdoctor scan --dir .

=head1 DESCRIPTION

Reconciles the environment variables used in Perl source (C<$ENV{X}>) against
those defined in F<.env> files, reporting variables that are used but never
defined (error) and defined but never referenced (warning).

Nothing is uploaded and variable I<values> are never printed.

=head1 SEE ALSO

L<App::Envdoctor::Scanner>, L<https://github.com/arun-skg/envdoctor>

=head1 LICENSE

MIT

=cut
