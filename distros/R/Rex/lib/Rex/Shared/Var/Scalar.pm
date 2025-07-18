#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Shared::Var::Scalar;

use v5.14.4;
use warnings;

use Rex::Shared::Var::Common qw/__lock __store __retrieve/;

our $VERSION = '1.16.1'; # VERSION

sub TIESCALAR {
  my $self = { varname => $_[1], };
  bless $self, $_[0];
}

sub STORE {
  my $self  = shift;
  my $value = shift;

  return __lock sub {
    my $ref = __retrieve;
    my $ret = $ref->{ $self->{varname} } = $value;
    __store $ref;

    return $ret;
  };
}

sub FETCH {
  my $self = shift;

  return __lock sub {
    my $ref = __retrieve;
    return $ref->{ $self->{varname} };
  };
}

1;
