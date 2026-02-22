use strict;
use warnings;
use Test::More;
use WebServer::DirIndex::CSS;

my $obj = WebServer::DirIndex::CSS->new;
ok defined $obj, 'WebServer::DirIndex::CSS->new returns an object';

my $std = $obj->css;
ok defined $std, 'css() returns a value';
like $std, qr/table/, 'css() contains table rule';
like $std, qr/\.name/, 'css() contains .name rule';
like $std, qr/\.size/, 'css() contains .size rule';

my $pretty_obj = WebServer::DirIndex::CSS->new(pretty => 1);
ok defined $pretty_obj, 'WebServer::DirIndex::CSS->new(pretty => 1) returns an object';

my $pretty = $pretty_obj->css;
ok defined $pretty, 'css(pretty) returns a value';
like $pretty, qr/body/, 'css(pretty) contains body rule';
like $pretty, qr/table/, 'css(pretty) contains table rule';
like $pretty, qr/a:link/, 'css(pretty) contains a:link rule';

isnt $std, $pretty, 'standard and pretty CSS are different';

done_testing;
