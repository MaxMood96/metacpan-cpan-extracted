package Tomba::Count;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Count - Email count for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Count;

  my $tomba = Tomba::Count->new("ta_xxxxx", "ts_xxxxx");
  my $count = $tomba->Count("tomba.io");

=head1 DESCRIPTION

Returns total email addresses found for one domain.

=cut

#-------------------------------------------------------------------------------
# Email Count
#-------------------------------------------------------------------------------

=head2 Count

  my $data = $tomba->Count("tomba.io");

Returns total email addresses found for one domain.

See L<https://docs.tomba.io/api/finder#get-email-count>

=cut

sub Count {
    my ($self, $domain) = @_;
    my $params = {
        domain => $domain,
    };
    return $self->call(Tomba::Client::COUNT_PATH, $params);
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
