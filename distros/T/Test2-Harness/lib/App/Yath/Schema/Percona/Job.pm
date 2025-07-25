use utf8;
package App::Yath::Schema::Percona::Job;
our $VERSION = '2.000005';

package
    App::Yath::Schema::Result::Job;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY ANY PART OF THIS FILE

use strict;
use warnings;

use parent 'App::Yath::Schema::ResultBase';
__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "InflateColumn::Serializer",
  "InflateColumn::Serializer::JSON",
);
__PACKAGE__->table("jobs");
__PACKAGE__->add_columns(
  "job_uuid",
  { data_type => "binary", is_nullable => 0, size => 16 },
  "job_id",
  { data_type => "bigint", is_auto_increment => 1, is_nullable => 0 },
  "run_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "test_file_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "is_harness_out",
  { data_type => "tinyint", is_nullable => 0 },
  "failed",
  { data_type => "tinyint", is_nullable => 0 },
  "passed",
  { data_type => "tinyint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("job_id");
__PACKAGE__->add_unique_constraint("job_uuid", ["job_uuid"]);
__PACKAGE__->has_many(
  "jobs_tries",
  "App::Yath::Schema::Result::JobTry",
  { "foreign.job_id" => "self.job_id" },
  { cascade_copy => 0, cascade_delete => 1 },
);
__PACKAGE__->belongs_to(
  "run",
  "App::Yath::Schema::Result::Run",
  { run_id => "run_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);
__PACKAGE__->belongs_to(
  "test_file",
  "App::Yath::Schema::Result::TestFile",
  { test_file_id => "test_file_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2024-08-01 07:24:08
__PACKAGE__->inflate_column('job_uuid' => { inflate => \&App::Yath::Schema::Util::format_uuid_for_app, deflate => \&App::Yath::Schema::Util::format_uuid_for_db });
# DO NOT MODIFY ANY PART OF THIS FILE

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Yath::Schema::Percona::Job - Autogenerated result class for Job in Percona.

=head1 SEE ALSO

L<App::Yath::Schema::Overlay::Job> - Where methods that are not
auto-generated are defined.

=head1 SOURCE

The source code repository for Test2-Harness can be found at
L<http://github.com/Test-More/Test2-Harness/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/>

=cut
