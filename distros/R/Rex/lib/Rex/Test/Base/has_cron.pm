#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_cron;

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

  my @crons         = cron list => $user;
  my @matched_crons = grep { $_->{$key} eq $value } @crons;

  if ($count) {
    $self->ok( scalar @matched_crons == $count,
      "Found $count cron(s) with $key = $value" );
  }
  else {
    $self->ok( scalar @matched_crons > 0, "Found cron with $key = $value" );
  }
}

sub run_not_test {
  my ( $self, $user, $key, $value, $count ) = @_;

  my @crons         = cron list => $user;
  my @matched_crons = grep { $_->{$key} eq $value } @crons;

  if ($count) {
    $self->ok( scalar @matched_crons != $count,
      "Not found $count cron(s) with $key = $value" );
  }
  else {
    $self->ok( scalar @matched_crons == 0,
      "Not found cron with $key = $value" );
  }
}

1;
