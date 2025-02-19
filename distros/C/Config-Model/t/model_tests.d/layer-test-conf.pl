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
# test loading layered config à la ssh_config
use strict;
use warnings;

my $home_for_test = '/home/joe' ;
Config::Model::BackendMgr::_set_test_home($home_for_test) ;

 my @config_classes = ({
    name    => "LayeredClass",
    element => [
      [qw/set_in_etc set_by_user set_in_both/] , {
            'value_type' => 'uniline',
            'type' => 'leaf',
      },
      'a_checklist' =>  {
        #'default_list' => [ qw/b c/ ],
        'type' => 'check_list',
        'choice' => [ 'a' .. 'g' ]
      },
    ],
    'rw_config' => {
        'backend' => 'perl_file',
        'config_dir' => '~/foo',
        'file' => 'config.pl',
        'default_layer' => { 
            'config_dir' => '/etc',
            'file' => 'foo-config.pl'
        }
    }
});

my @tests = ({
    name => 'mini',
    check => [
        set_in_etc => {qw/mode layered value /, 'system value'},
        set_in_both => {qw/mode layered value /, 'system value2'},
        set_in_both => {qw/mode user value /, 'user value2'},
        set_by_user => 'user value',
        a_checklist => {qw/mode layered value /,'c,e'},
        a_checklist => 'f,g',
        a_checklist => {qw/mode user value /,   'c,f,g'},
    ]
});

return {
    model_to_test => "LayeredClass",
    config_classes => \@config_classes,
    home_for_test => $home_for_test,
    tests => \@tests
};
