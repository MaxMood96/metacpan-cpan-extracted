#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_cron_env;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex -minimal;
use Rex::Commands::Cron;

use base qw(Rex::Test::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $user, $key, $value, $count ) = @_;

  my @envs         = cron env => $user => "list";
  my @matched_envs = grep { $_->{name} eq $key && $_->{value} eq $value } @envs;

  if ($count) {
    $self->ok( scalar @matched_envs == $count,
      "Found $count cron(s) env entries with $key = $value" );
  }
  else {
    $self->ok( scalar @matched_envs > 0,
      "Found cron env entry with $key = $value" );
  }
}

sub run_not_test {
  my ( $self, $user, $key, $value, $count ) = @_;

  my @envs         = cron env => $user => "list";
  my @matched_envs = grep { $_->{name} eq $key && $_->{value} eq $value } @envs;

  if ($count) {
    $self->ok( scalar @matched_envs != $count,
      "Not found $count cron(s) env entries with $key = $value" );
  }
  else {
    $self->ok( scalar @matched_envs == 0,
      "Not found cron env entry with $key = $value" );
  }
}

1;
