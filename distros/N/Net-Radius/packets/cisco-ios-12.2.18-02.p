#!/usr/bin/perl

no utf8;

# Net::Radius test input
# Made with $Id: cisco-ios-12.2.18-02.p 64 2007-01-09 20:01:04Z lem $

$VAR1 = {
          'packet' => '� 8��Pġ��Ъ!���A�icastaneda�V)C\'.ҫ!}#!�k���',
          'secret' => undef,
          'description' => 'Cisco IOS 12.2(18)SXF3 - Access-Request',
          'authenticator' => '��Pġ��Ъ!���A�',
          'identifier' => 142,
          'dictionary' => undef,
          'opts' => {
                      'secret' => undef,
                      'output' => 'packets/cisco-ios-12.2.18-02',
                      'description' => 'Cisco IOS 12.2(18)SXF3 - Access-Request',
                      'authenticator' => '��Pġ��Ъ!���A�',
                      'identifier' => 142,
                      'dictionary' => [
                                        'dicts/dictionary'
                                      ],
                      'dont-embed-dict' => 1,
                      'noprompt' => 1,
                      'slots' => 3
                    },
          'slots' => 3
        };
