package
	TOTPDemo::Controller::Web::Vault;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

sub contents {
    my ($c) = @_;
    return $c->page('vault', { title => 'The vault' });
}

1;

__END__
