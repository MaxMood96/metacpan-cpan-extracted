package AuthzDemo::Model::User;

use strict;
use warnings;
use Punk::Model;

# punk_auth's users table, plus the `role` column authzdemo:user_role adds.
table 'users';
field id    => { type => 'integer', primary => 1 };
field email => { type => 'string' };
field role  => { type => 'string' };   # a rung on the `auth` ladder

1;
