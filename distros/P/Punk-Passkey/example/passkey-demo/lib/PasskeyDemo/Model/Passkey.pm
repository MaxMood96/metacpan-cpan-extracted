package PasskeyDemo::Model::Passkey;

use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.01';

table 'passkeys';
field id            => { type => 'integer', primary => 1 };
field user_id       => { type => 'integer' };
field credential_id => { type => 'string' };
field public_key    => { type => 'string' };
field sign_count    => { type => 'integer' };
field label         => { type => 'string' };
field aaguid        => { type => 'string' };
field created_at    => { type => 'integer' };
field last_used_at  => { type => 'integer' };

1;

__END__

