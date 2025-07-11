use strict;
use Test::More;
use lib qw(./lib ./blib/lib);
use Sisimai::SMTP::Reply;
use Sisimai::SMTP::Status;
use Sisimai::SMTP::Command;

my $Package = 'Sisimai::SMTP::Reply';
my $Methods = { 'class' => ['test', 'find'], 'object' => [] };

use_ok $Package;
can_ok $Package, @{ $Methods->{'class'} };

MAKETEST: {
    my $smtperrors = [
        'smtp; 250 2.1.5 Ok',
        'smtp; 550 5.1.1 <kijitora@example.co.jp>... User Unknown',
        'smtp; 550 Unknown user kijitora@example.jp',
        "smtp; 550 5.7.1 can't determine Purported ",
        'SMTP; 550 5.2.1 The email account that you tried to reach is disabled. g0000000000ggg.00',
        'smtp; 550 Unknown user kijitora@example.co.jp',
        'smtp; 550 5.1.1 <kijitora@example.jp>... User unknown',
        'smtp; 550 5.1.1 <kijitora@example.or.jp>... User unknown',
        'smtp; 550 5.2.1 <filtered@example.co.jp>... User Unknown',
        'smtp; 550 5.1.1 <userunknown@example.co.jp>... User Unknown',
        'smtp; 550 Unknown user kijitora@example.net',
        'smtp; 550 5.1.1 Address rejected',
        'smtp; 450 4.1.1 <kijitora@example.org>: Recipient address',
        'smtp; 452 4.3.2 Connection rate limit exceeded.',
        'smtp; 553 5.1.8 <root@vagrant-centos65.vagrantup.com>...',
        'smtp; 553 5.1.8 <root@vagrant-centos65.vagrantup.com>...',
        'smtp; 553 5.1.8 <root@vagrant-centos65.vagrantup.com>...',
        'smtp; 550 5.1.1 <userunknown@cubicroot.jp>... User Unknown',
        'smtp; 550 5.2.1 <kijitora@example.jp>... User Unknown',
        'smtp; 550 5.2.2 <noraneko@example.jp>... Mailbox Full',
        'smtp; 550 5.1.6 recipient no longer on server: kijitora@example.go.jp',
        'smtp; 550 5.7.1 Unable to relay for relay_failed@testreceiver.com',
        'smtp; 550 Access from ip address 87.237.123.24 blocked. Visit',
        'SMTP; 550 5.1.1 <userunknown@bouncehammer.jp>... User Unknown',
        q|smtp;  550 'arathib@vnet.IBM.COM' is not a|,
        'smtp; 550 user unknown',
        'smtp; 421 connection timed out',
        'smtp;550 5.2.1 <kijitora@example.jp>... User Unknown',
        'smtp; 550 5.7.1 Message content rejected, UBE, id=00000-00-000',
        '550 5.1.1 sid=i01K1n00l0kn1Em01 Address rejected foobar@foobar.com. [code=28] ',
        '554 imta14.emeryville.ca.mail.comcast.net comcast 192.254.113.140 Comcast block for spam.  Please see http://postmaster.comcast.net/smtp-error-codes.php#BL000000 ',
        'SMTP; 550 5.1.1 User unknown',
        'smtp; 550 5.1.1 <kijitora@example.jp>... User Unknown',
        'smtp; 550 5.2.1 <mikeneko@example.jp>... User Unknown',
        'smtp; 550 5.2.2 <sabineko@example.jp>... Mailbox Full',
        'SMTP; 550 5.1.1 <userunknown@bouncehammer.jp>... User Unknown',
        'SMTP; 550 5.1.1 <userunknown@example.org>... User Unknown',
        'SMTP; 550 5.2.1 <filtered@example.com>... User Unknown',
        'SMTP; 550 5.1.1 <userunknown@example.co.jp>... User Unknown',
        'SMTP; 553 5.1.8 <httpd@host1.mx.example.jp>... Domain of sender',
        'SMTP; 552 5.2.3 Message size exceeds fixed maximum message size (10485760)',
        'SMTP; 550 5.6.9 improper use of 8-bit data in message header',
        'SMTP; 554 5.7.1 <kijitora@example.org>: Relay access denied',
        'SMTP; 450 4.7.1 Access denied. IP name lookup failed [192.0.2.222]',
        'SMTP; 554 5.7.9 Header error',
        'SMTP; 450 4.7.1 <c135.kyoto.example.ne.jp[192.0.2.56]>: Client host rejected: may not be mail exchanger',
        'SMTP; 554 IP=192.0.2.254 - A problem occurred. (Ask your postmaster for help or to contact neko@example.org to clarify.) (BL)',
        'SMTP; 551 not our user',
        'SMTP; 550 Unknown user kijitora@ntt.example.ne.jp',
        'SMTP; 554 5.4.6 Too many hops',
        'SMTP; 551 not our customer',
        'SMTP; 550-5.7.1 [180.211.214.199       7] Our system has detected that this message is',
        'SMTP; 550 Host unknown',
        'SMTP; 550 5.1.1 <=?utf-8?B?8J+QiPCfkIg=?=@example.org>... User unknown',
        'smtp; 550 kijitora@example.com... No such user',
        'smtp; 554 Service currently unavailable',
        'smtp; 554 Service currently unavailable',
        'smtp; 550 maria@dest.example.net... No such user',
        q|smtp; 5.1.0 - Unknown address error 550-'5.7.1 <000001321defbd2a-788e31c8-2be1-422f-a8d4-cf7765cc9ed7-000000@email-bounces.amazonses.com>... Access denied' (delivery attempts: 0)|,
        q|smtp; 5.3.0 - Other mail system problem 550-'Unknown user this-local-part-does-not-exist-on-the-server@docomo.ne.jp' (delivery attempts: 0)|,
        'smtp; 550 5.2.2 <kijitora@example.co.jp>... Mailbox Full',
        'smtp; 550 5.2.2 <sabineko@example.jp>... Mailbox Full',
        'smtp; 550 5.1.1 <mikeneko@example.jp>... User Unknown',
        'smtp; 550 5.1.1 <kijitora@example.co.jp>... User Unknown',
        'SMTP; 553 Invalid recipient destinaion@example.net (Mode: normal)',
        'smtp; 550 5.1.1 RCP-P2 http://postmaster.facebook.com/response_codes?ip=192.0.2.135#rcp Refused due to recipient preferences',
        'SMTP; 550 5.1.1 RCP-P1 http://postmaster.facebook.com/response_codes?ip=192.0.2.54#rcp ',
        'smtp;550 5.2.2 <kijitora@example.jp>... Mailbox Full',
        'smtp;550 5.1.1 <kijitora@example.jp>... User Unknown',
        'smtp;554 The mail could not be delivered to the recipient because the domain is not reachable. Please check the domain and try again (-1915321397:308:-2147467259)',
        'smtp;550 5.1.1 <sabineko@example.co.jp>... User Unknown',
        'smtp;550 5.2.2 <mikeneko@example.co.jp>... Mailbox Full',
        'smtp;550 Requested action not taken: mailbox unavailable (-2019901852:4030:-2147467259)',
        'smtp;550 5.1.1 <kijitora@example.or.jp>... User unknown',
        '550 5.1.1 <kijitora@example.jp>... User Unknown ',
        '550 5.1.1 <this-local-part-does-not-exist-on-the-server@example.jp>... ',
    ];

    my $v = '';
    is $Package->test(''), 0,  '->test() returns 0';
    is $Package->find(''), "", '->find() returns ""';

    for my $e ( @$smtperrors ) {
        $v = $Package->find($e);
        ok $e, 'Error message text = '.$e;
        like $v, qr/\A[2345][0-5][0-9]\z/, 'SMTP Reply Code = '.$v;
        ok $Package->test($v), '->test('.$v.') returns 1';
    }
    is $Package->find('x-unix; Quota exceeded message delivery failed to'), '';

    for my $e ( 235, 334, 354 ) { is $Package->test($e), 1 }
    for my $e ( qw|101 192 210 230 240 270 365 386 499 567 640 727| ) {
        is $Package->test($e), 0, '->test('.$e.') returns 0';
    }

    for my $e (422, 432, 500, 501, 502, 503, 504, 521, 523, 524, 525, 534, 535, 538, 556) {
        my $v = $Package->associatedwith($e);
        isa_ok $v, "ARRAY";
        is scalar @$v, 3;
        is(Sisimai::SMTP::Command->test($v->[0]), 1) if length $v->[0];
        is(Sisimai::SMTP::Status->test($v->[1]),  1) if length $v->[1];
        ok $v->[2];
    }
}

done_testing;

