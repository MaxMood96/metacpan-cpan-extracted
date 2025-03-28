#!/usr/bin/perl

no utf8;

# Net::Radius test input
# Made with $Id: bin2packet 67 2007-01-14 18:51:42Z lem $

$VAR1 = {
          'packet' => ')��BV.�AXzPƂb|��5CNT-BRAS-02-172.16.74.2 eth 0/2/2/2:260.11@dinamico  �J���	aba_512 CNT-BRAS-02-172.16.74.2(   )    *  �B+ ��,#CNT-BRA02202026000011336432002618-   .   2/  00  _4    5    7J��=   00:17:08:2f:2c:c9W,CNT-BRAS-02-172.16.74.2 eth 0/2/2/2:260.11      [  �<"200.11.174.235 00:17:08:2f:2c:c9 �  �  �  �      
:�
dinamico256',
          'secret' => 'br@5hu',
          'description' => 'Huawei Quidway® ME60 - Accounting-Request #2',
          'authenticator' => '�BV.�AXzPƂb|��',
          'identifier' => 41,
          'dictionary' => bless( {
                                   'packet' => undef,
                                   'vsattr' => {
                                                 '2011' => {
                                                             'Output-Average-Rate' => [
                                                                                        '5',
                                                                                        'integer'
                                                                                      ],
                                                             'Qos-Profile' => [
                                                                                '31',
                                                                                'string'
                                                                              ],
                                                             'Product-ID' => [
                                                                               '255',
                                                                               'string'
                                                                             ],
                                                             'Connect-ID' => [
                                                                               '26',
                                                                               'integer'
                                                                             ],
                                                             'Input-Average-Rate' => [
                                                                                       '2',
                                                                                       'integer'
                                                                                     ],
                                                             'Domain-Name' => [
                                                                                '138',
                                                                                'string'
                                                                              ],
                                                             'Startup-Stamp' => [
                                                                                  '59',
                                                                                  'integer'
                                                                                ],
                                                             'Ip-Host-Addr' => [
                                                                                 '60',
                                                                                 'string'
                                                                               ],
                                                             'Output-Peak-Rate' => [
                                                                                     '6',
                                                                                     'integer'
                                                                                   ],
                                                             'Version' => [
                                                                            '254',
                                                                            'string'
                                                                          ],
                                                             'Priority' => [
                                                                             '22',
                                                                             'integer'
                                                                           ],
                                                             'Input-Peak-Rate' => [
                                                                                    '3',
                                                                                    'integer'
                                                                                  ]
                                                           }
                                               },
                                   'rattr' => {
                                                '32' => [
                                                          'NAS-Identifier',
                                                          'string'
                                                        ],
                                                '11' => [
                                                          'Filter-Id',
                                                          'string'
                                                        ],
                                                '53' => [
                                                          'Acct-Output-Gigawords',
                                                          'integer'
                                                        ],
                                                '7' => [
                                                         'Framed-Protocol',
                                                         'integer'
                                                       ],
                                                '2' => [
                                                         'User-Password',
                                                         'string'
                                                       ],
                                                '48' => [
                                                          'Acct-Output-Packets',
                                                          'integer'
                                                        ],
                                                '42' => [
                                                          'Acct-Input-String',
                                                          'integer'
                                                        ],
                                                '87' => [
                                                          'NAS-Port-Id',
                                                          'string'
                                                        ],
                                                '1' => [
                                                         'User-Name',
                                                         'string'
                                                       ],
                                                '77' => [
                                                          'Connect-Info',
                                                          'string'
                                                        ],
                                                '46' => [
                                                          'Acct-Session-Time',
                                                          'integer'
                                                        ],
                                                '44' => [
                                                          'Acct-Session-Id',
                                                          'string'
                                                        ],
                                                '55' => [
                                                          'Event-Timestamp',
                                                          'date'
                                                        ],
                                                '6' => [
                                                         'Service-Type',
                                                         'integer'
                                                       ],
                                                '40' => [
                                                          'Acct-Status-Type',
                                                          'integer'
                                                        ],
                                                '61' => [
                                                          'NAS-Port-Type',
                                                          'integer'
                                                        ],
                                                '41' => [
                                                          'Acct-Delay-Time',
                                                          'integer'
                                                        ],
                                                '47' => [
                                                          'Acct-Input-Packets',
                                                          'integer'
                                                        ],
                                                '52' => [
                                                          'Acct-Input-Gigawords',
                                                          'integer'
                                                        ],
                                                '8' => [
                                                         'Framed-IP-Address',
                                                         'ipaddr'
                                                       ],
                                                '4' => [
                                                         'NAS-IP-Address',
                                                         'ipaddr'
                                                       ],
                                                '45' => [
                                                          'Acct-Authentic',
                                                          'integer'
                                                        ],
                                                '43' => [
                                                          'Acct-Output-String',
                                                          'integer'
                                                        ],
                                                '31' => [
                                                          'Calling-Station-Id',
                                                          'string'
                                                        ],
                                                '5' => [
                                                         'NAS-Port',
                                                         'integer'
                                                       ]
                                              },
                                   'vendors' => {
                                                  'Huawei' => '2011'
                                                },
                                   'rpacket' => undef,
                                   'val' => {
                                              '6' => {
                                                       'Framed-User' => '2'
                                                     },
                                              '61' => {
                                                        'Ethernet' => '15'
                                                      },
                                              '7' => {
                                                       'PPP' => '1'
                                                     }
                                            },
                                   'rvsaval' => {
                                                  '2011' => {}
                                                },
                                   'attr' => {
                                               'NAS-Port-Type' => [
                                                                    '61',
                                                                    'integer'
                                                                  ],
                                               'Acct-Input-String' => [
                                                                        '42',
                                                                        'integer'
                                                                      ],
                                               'Acct-Session-Id' => [
                                                                      '44',
                                                                      'string'
                                                                    ],
                                               'Acct-Output-Gigawords' => [
                                                                            '53',
                                                                            'integer'
                                                                          ],
                                               'Service-Type' => [
                                                                   '6',
                                                                   'integer'
                                                                 ],
                                               'Acct-Output-String' => [
                                                                         '43',
                                                                         'integer'
                                                                       ],
                                               'Acct-Authentic' => [
                                                                     '45',
                                                                     'integer'
                                                                   ],
                                               'Acct-Status-Type' => [
                                                                       '40',
                                                                       'integer'
                                                                     ],
                                               'Connect-Info' => [
                                                                   '77',
                                                                   'string'
                                                                 ],
                                               'Acct-Output-Packets' => [
                                                                          '48',
                                                                          'integer'
                                                                        ],
                                               'NAS-IP-Address' => [
                                                                     '4',
                                                                     'ipaddr'
                                                                   ],
                                               'NAS-Port-Id' => [
                                                                  '87',
                                                                  'string'
                                                                ],
                                               'Filter-Id' => [
                                                                '11',
                                                                'string'
                                                              ],
                                               'Acct-Session-Time' => [
                                                                        '46',
                                                                        'integer'
                                                                      ],
                                               'Calling-Station-Id' => [
                                                                         '31',
                                                                         'string'
                                                                       ],
                                               'Framed-Protocol' => [
                                                                      '7',
                                                                      'integer'
                                                                    ],
                                               'User-Name' => [
                                                                '1',
                                                                'string'
                                                              ],
                                               'Event-Timestamp' => [
                                                                      '55',
                                                                      'date'
                                                                    ],
                                               'User-Password' => [
                                                                    '2',
                                                                    'string'
                                                                  ],
                                               'NAS-Identifier' => [
                                                                     '32',
                                                                     'string'
                                                                   ],
                                               'Acct-Input-Gigawords' => [
                                                                           '52',
                                                                           'integer'
                                                                         ],
                                               'Framed-IP-Address' => [
                                                                        '8',
                                                                        'ipaddr'
                                                                      ],
                                               'Acct-Input-Packets' => [
                                                                         '47',
                                                                         'integer'
                                                                       ],
                                               'NAS-Port' => [
                                                               '5',
                                                               'integer'
                                                             ],
                                               'Acct-Delay-Time' => [
                                                                      '41',
                                                                      'integer'
                                                                    ]
                                             },
                                   'rvsattr' => {
                                                  '2011' => {
                                                              '6' => [
                                                                       'Output-Peak-Rate',
                                                                       'integer'
                                                                     ],
                                                              '3' => [
                                                                       'Input-Peak-Rate',
                                                                       'integer'
                                                                     ],
                                                              '138' => [
                                                                         'Domain-Name',
                                                                         'string'
                                                                       ],
                                                              '26' => [
                                                                        'Connect-ID',
                                                                        'integer'
                                                                      ],
                                                              '2' => [
                                                                       'Input-Average-Rate',
                                                                       'integer'
                                                                     ],
                                                              '22' => [
                                                                        'Priority',
                                                                        'integer'
                                                                      ],
                                                              '59' => [
                                                                        'Startup-Stamp',
                                                                        'integer'
                                                                      ],
                                                              '254' => [
                                                                         'Version',
                                                                         'string'
                                                                       ],
                                                              '60' => [
                                                                        'Ip-Host-Addr',
                                                                        'string'
                                                                      ],
                                                              '255' => [
                                                                         'Product-ID',
                                                                         'string'
                                                                       ],
                                                              '31' => [
                                                                        'Qos-Profile',
                                                                        'string'
                                                                      ],
                                                              '5' => [
                                                                       'Output-Average-Rate',
                                                                       'integer'
                                                                     ]
                                                            }
                                                },
                                   'rval' => {
                                               '6' => {
                                                        '2' => 'Framed-User'
                                                      },
                                               '61' => {
                                                         '15' => 'Ethernet'
                                                       },
                                               '7' => {
                                                        '1' => 'PPP'
                                                      }
                                             },
                                   'vsaval' => {}
                                 }, 'Net::Radius::Dictionary' ),
          'opts' => {
                      'identifier' => 41,
                      'authenticator' => '�BV.�AXzPƂb|��',
                      'dictionary' => [
                                        'minidict'
                                      ],
                      'secret' => 'br@5hu',
                      'slots' => 23,
                      'output' => 'huawei-me60-acctreq-02',
                      'description' => 'Huawei Quidway® ME60 - Accounting-Request #2'
                    },
          'slots' => 23
        };
