package Punk::Plugin::TestSchemaB;
use 5.010;
use strict;
use warnings;
use parent 'Punk::Plugin';

# A plugin that ships its schema as a Sqitch project - the shape the
# Punk-Sqitch POD shows plugin authors, with the project built by the test.
sub register {
    my ($class, $app, $opts) = @_;
    require Punk::Plugin::Sqitch;
    Punk::Plugin::Sqitch->project($app, $opts->{name} => $opts->{dir},
        (exists $opts->{engines} ? (engines => $opts->{engines}) : ()))
        if Punk::Plugin::Sqitch->can('project');
    return;
}

1;
