package PasskeyDemo::Model::User;

use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.01';

# punk_auth's users table, deployed by `punk sqitch deploy`. The
# password_hash column stays NULL for every account this demo makes:
# the passkey is the way in.

table 'users';
field id            => { type => 'integer', primary => 1 };
field email         => { type => 'string' };
field password_hash => { type => 'string' };
field verified      => { type => 'integer' };

1;

__END__

