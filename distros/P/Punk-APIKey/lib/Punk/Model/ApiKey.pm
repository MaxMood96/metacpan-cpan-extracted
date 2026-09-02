package Punk::Model::ApiKey;

use 5.010;
use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.02';

table 'api_keys';

field id           => { type => 'integer', primary => 1 };
field owner_id     => { type => 'integer' };
field kind         => { type => 'string' };
field label        => { type => 'string' };
field prefix       => { type => 'string' };
field digest       => { type => 'string' };
field scopes       => { type => 'string' };   # space separated
field rate_per_min => { type => 'integer' };
field expires      => { type => 'integer' };  # epoch; null never expires
field revoked      => { type => 'integer' };  # epoch; null is live
field last_used    => { type => 'integer' };
field created      => { type => 'integer' };

1;

__END__

=head1 NAME

Punk::Model::ApiKey - the API keys table

=head1 DESCRIPTION

The model L<Punk::Plugin::APIKey> falls back to when the application has
declared none of its own. See L<Punk::Plugin::APIKey/THE SCHEMA> for the DDL
and how the table is deployed.

An application that wants its own - a different table name, an extra column,
different spellings - declares C<MyApp::Model::ApiKey> and this class is never
registered. The plugin's C<fields> option covers the case where only the
column names differ.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
