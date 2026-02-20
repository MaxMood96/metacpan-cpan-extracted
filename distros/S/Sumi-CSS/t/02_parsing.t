use Test::More;
use Sumi::CSS;
use Mojo::File;
use strict;

$\ = "\n"; $, = "\t";

my $dir = Mojo::File->new($0)->dirname;

for ($dir->list->grep(qr/\.css$/)->@*) {
    my $c = Sumi::CSS->new->parse($_->slurp);
    my $p = do($_ =~ s/\.css/.pl/r);
    is_deeply($c, $p, $_)
}

done_testing()