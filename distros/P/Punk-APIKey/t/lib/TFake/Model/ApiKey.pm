package TFake::Model::ApiKey;

use strict;
use warnings;
use Punk::Model;

table 'api_keys';
field id           => { type => 'integer', primary => 1 };
field owner_id     => { type => 'integer' };
field kind         => { type => 'string' };
field label        => { type => 'string' };
field prefix       => { type => 'string' };
field digest       => { type => 'string' };
field scopes       => { type => 'string' };
field rate_per_min => { type => 'integer' };
field expires      => { type => 'integer' };
field revoked      => { type => 'integer' };
field last_used    => { type => 'integer' };
field created      => { type => 'integer' };

1;
