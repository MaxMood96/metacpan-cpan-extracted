package WebService::Hydra::Exception::InvalidToken;
use strict;
use warnings;
use Object::Pad;

our $VERSION = '0.005'; ## VERSION

class WebService::Hydra::Exception::InvalidToken :isa(WebService::Hydra::Exception) {

    sub BUILDARGS {
        my ($class, %args) = @_;

        $args{message}  //= 'Invalid token';
        $args{category} //= 'client';

        return %args;
    }
}

1;
