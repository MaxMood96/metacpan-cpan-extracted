package TFake;

# Loads the fakes the tests share. Each lives in its own file because
# Punk::Model resolves a backend and a model class by `require`ing the path
# their name implies - a file holding several packages defines them but is
# never found by that.

use strict;
use warnings;
use TFake::KeyBackend ();
use TFake::Model::ApiKey ();
use TFake::Model::User ();

1;
