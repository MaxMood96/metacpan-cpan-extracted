#!/usr/bin/perl

no utf8;

# Net::Radius test input
# Made with $Id: rsa-ac-01.p 64 2007-01-09 20:01:04Z lem $

$VAR1 = {
          'packet' => 'v j���ʌ���>eAt�
�;Wait for token to change,
then enter the new tokencode: SECURID_NEXT|0=186002649;',
          'secret' => undef, 
          'description' => 'RSA ACE/Server 6.0 [020] RADIUS (on Solaris 9) - Access-Challenge',
          'authenticator' => '���ʌ���>eAt�
�',
          'identifier' => 118,
          'dictionary' => undef,
          'opts' => {
                      'output' => 'packets/rsa-ac-01',
                      'description' => 'RSA ACE/Server 6.0 [020] RADIUS (on Solaris 9) - Access-Challenge',
                      'authenticator' => '���ʌ���>eAt�
�',
                      'identifier' => 118,
                      'dont-embed-dict' => 1,
                      'dictionary' => [
                                        'dicts/dictionary'
                                      ],
                      'slots' => 2
                    },
          'slots' => 2
        };
