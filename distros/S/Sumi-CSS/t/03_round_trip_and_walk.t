use Test::More;
use Sumi::CSS;
use Mojo::File;
use strict;
use warnings;
use Mojo::Util qw/dumper/;

$\ = "\n"; $, = "\t";

my $dir = Mojo::File->new($0)->dirname;

for ($dir->list->grep(qr/\.css$/)->@*) {
    my $c = Sumi::CSS->new->parse($_->slurp);
    my $z = Sumi::CSS->new->parse($c->to_string);
    is_deeply($c, $z, $_);
    my $m = Sumi::CSS->new->parse($c->to_string({ minimize => 1}));
    is_deeply($c, $m, $_);
}

done_testing()