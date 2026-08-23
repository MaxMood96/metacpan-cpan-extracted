package
	TOTPDemo::Model::Token;

use strict;
use warnings;
use Punk::Model;

table 'tokens';
field id => { type => 'integer', primary => 1 };

1;
