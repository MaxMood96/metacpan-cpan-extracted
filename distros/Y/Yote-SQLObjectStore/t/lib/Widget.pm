package Widget;

use 5.16.0;
use warnings;

use NotApp;

use base 'Yote::ObjectStore::Obj';

sub hi {
    return 1, "hi there";
}
sub name {
    return 1, shift->get_name;
}

sub badsend {
    return 1, NotApp->new;
}

sub attachstuff {
    my $self = shift;
    $self->set_arry( [ "ONE", { TWO => "TREE" } ] );
    $self->vol( "STUFF", "KINDA STUFF" );
    return 1, "ATTACHED";
}

1;

