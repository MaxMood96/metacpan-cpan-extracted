package ApiKeyDemo::Model::Note;

use strict;
use warnings;
use Punk::Model;

our $VERSION = '0.01';

table 'notes';

field id       => { type => 'integer', primary => 1 };
field owner_id => { type => 'integer' };
field body     => { type => 'string' };
field created  => { type => 'integer' };

1;
