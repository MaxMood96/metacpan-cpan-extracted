use utf8;
package TaskPipe::Schema::Result::TpXbranchError;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

TaskPipe::Schema::Result::TpXbranchError

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<tp_xbranch_error>

=cut

__PACKAGE__->table("tp_xbranch_error");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 xbranch_id

  data_type: 'bigint'
  is_nullable: 1

=head2 error_id

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "xbranch_id",
  { data_type => "bigint", is_nullable => 1 },
  "error_id",
  { data_type => "bigint", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<xbranch_id_error_id_unique>

=over 4

=item * L</xbranch_id>

=item * L</error_id>

=back

=cut

__PACKAGE__->add_unique_constraint("xbranch_id_error_id_unique", ["xbranch_id", "error_id"]);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-10-28 19:18:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qdwTRRzvTeTeAsDIvaQcPg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
