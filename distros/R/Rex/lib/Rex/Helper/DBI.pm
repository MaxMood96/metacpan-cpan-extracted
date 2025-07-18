#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Helper::DBI;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

BEGIN {
  use Rex::Require;
  DBI->require;
}

my %db_connections;

sub perform_request {

  my ( $dsn, $user, $pass, $req ) = @_;

  $user ||= "";
  $pass ||= "";

  my $con_key = "$dsn-$user-$pass";

  if ( !exists $db_connections{$dsn} ) {
    $db_connections{$con_key} = DBI->connect( $dsn, $user, $pass )
      or die("Cannot connect: $DBI::errstr\n");
  }

  my %res;

  my $sth = $db_connections{$con_key}->prepare($req);
  $sth->execute();

  my $i = 1;
  while ( my $ref = $sth->fetchrow_hashref() ) {
    $res{$i} = $ref;
    $i++;
  }

  return \%res;
}

1;
