#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
use Config::Model::BackendMgr;
use strict;
use warnings;

my @config_classes = ([
    name => 'Host',

    element => [
        [qw/ipaddr alias/] => {
            type       => 'leaf',
            value_type => 'uniline',
        },
        dummy => {qw/type leaf value_type uniline/},
    ]
]);

push @config_classes, [
    name => 'Hosts',

    rw_config => {
        backend     => 'cds_file',
        config_dir  => '/etc/',
        file        => 'hosts.cds',
    },

    element => [
        record => {
            type  => 'hash',
            index_type => 'string',
            write_empty_value => 1,
            cargo => {
                type              => 'node',
                config_class_name => 'Host',
            },
        },
    ]
];

my @tests = (
    {
        name  => 'basic',
        check => [
            'record:localhost ipaddr' => '127.0.0.1',
            'record:bilbo ipaddr' => '192.168.0.1'
        ]
    },
);

return {
    tests => \@tests,
    model_to_test => "Hosts",
    config_classes => \@config_classes,
    conf_dir => '/etc',
    conf_file_name => 'hosts.cds'
};
