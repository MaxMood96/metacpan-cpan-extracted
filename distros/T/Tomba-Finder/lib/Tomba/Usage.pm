package Tomba::Usage;

use strict;
use warnings;
use parent 'Tomba::Client';

=head1 NAME

Tomba::Usage - Usage statistics for the Tomba.io API

=head1 SYNOPSIS

  use Tomba::Usage;

  my $tomba = Tomba::Usage->new("ta_xxxxx", "ts_xxxxx");
  my $usage = $tomba->Usage();

=head1 DESCRIPTION

Check your monthly requests.

=cut

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------

=head2 Usage

  my $data = $tomba->Usage();

Check your monthly requests.

See L<https://docs.tomba.io/api/account#get-usage>

=cut

sub Usage {
    my ($self) = @_;
    return $self->call(Tomba::Client::USAGE_PATH);
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
