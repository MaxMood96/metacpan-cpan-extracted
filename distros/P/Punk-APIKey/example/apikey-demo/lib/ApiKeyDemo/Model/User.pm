package ApiKeyDemo::Model::User;

use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.01';

# Every column has to be declared or it can never be written: the DBI
# backend writes only declared fields.

table 'users';

field id        => { type => 'integer', primary => 1 };
field email     => { type => 'string' };
field role      => { type => 'string' };
field suspended => { type => 'integer' };   # epoch; null is good standing
field created   => { type => 'integer' };

1;
