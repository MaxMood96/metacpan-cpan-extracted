package TFake::Model::User;

use strict;
use warnings;
use Punk::Model;

table 'users';
field id        => { type => 'integer', primary => 1 };
field email     => { type => 'string' };
field role      => { type => 'string' };
field verified  => { type => 'integer' };
field suspended => { type => 'integer' };

1;
