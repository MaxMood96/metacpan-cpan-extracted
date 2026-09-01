package Tomba::Sources;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Sources - Email sources for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Sources;

  my $tomba = Tomba::Sources->new("ta_xxxxx", "ts_xxxxx");
  my $sources = $tomba->EmailSources("b.mohamed@tomba.io");

=head1 DESCRIPTION

Find email address source somewhere on the web.

=cut

#-------------------------------------------------------------------------------
# Email Sources
#-------------------------------------------------------------------------------

=head2 EmailSources

  my $data = $tomba->EmailSources("b.mohamed@tomba.io");

Find email address source somewhere on the web.

See L<https://docs.tomba.io/api/finder#get-email-sources>

=cut

sub EmailSources {
    my ($self, $email) = @_;
    my $params = {
        email => $email,
    };
    return $self->call(Tomba::Client::SOURCES_PATH, $params);
}

1;
__END__

=head1 AUTHOR

Mohamed Ben rebia, E<lt>b.mohamed@tomba.ioE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2023 Mohamed Benrebia <b.mohamed@tomba.io>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

L<http://www.apache.org/licenses/LICENSE-2.0>
