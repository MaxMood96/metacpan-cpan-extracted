package TOTPDemo::Model::User;

use strict;
use warnings;
use Punk::Model;

table 'users';
field id => { type => 'integer', primary => 1 };

1;
