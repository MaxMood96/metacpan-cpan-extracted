package AuthzDemo::Model::Doc;

use strict;
use warnings;
use Punk::Model;

table 'docs';
field id       => { type => 'integer', primary => 1 };
field title    => { type => 'string' };
field owner_id => { type => 'integer' };   # the column every rule asks about
field public   => { type => 'integer' };

1;
