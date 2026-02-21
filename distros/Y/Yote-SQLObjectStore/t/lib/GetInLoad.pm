package GetInLoad;

use base 'Yote::ObjectStore::Obj';

sub _load {
    my $self = shift;
    $self->get_fred([]);
}

1;
