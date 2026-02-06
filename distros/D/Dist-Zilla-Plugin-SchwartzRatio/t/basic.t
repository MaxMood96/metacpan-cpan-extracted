use strict;
use warnings;

use Test2::Bundle::More;

use Test::DZil;
use Dist::Zilla::Plugin::SchwartzRatio;

use Test::MockObject;
use MetaCPAN::Client;

package FakeRelease {
    use Moose;
    has version => ( is => 'ro' );
    has date    => ( is => 'ro' );
    has status => ( is => 'ro' );
}

my $fake_client = Test::MockObject->new;
my $releases = Test::MockObject->new;
$releases->set_series( 'next' => map {
        FakeRelease->new( version => '1.1.'.$_, date => '2017-01-0'.$_,
        status => $_ % 2 ? 'cpan' : 'backpan' )
    } 1..3
);

$fake_client->set_always( release => $releases );

{
    no warnings;
    sub MetaCPAN::Client::new { $fake_client }
}

my $dist_ini = dist_ini(
    {
        name     => 'DZT-Sample',
        abstract => 'Sample DZ Dist',
        author   => 'E. Xavier Ample <example@example.org>',
        license  => 'Perl_5',
        copyright_holder => 'E. Xavier Ample',
        version => '1.0.0',
    },
    qw/
        GatherDir
        FakeRelease
        SchwartzRatio
    /,
);

my $tzil = Builder->from_config(
    { dist_root => 'corpus' },
    { add_files => { 'source/dist.ini' => $dist_ini } },
);

$tzil->release;

for my $x ( 1,3) {
    ok grep { qr/v1.1.$x, 2017-01-0$x/ } map { $_->{message} } $tzil->chrome->logger->events->@*;
}

ok grep { qr/Total number.*?3/ } map { $_->{message} } $tzil->chrome->logger->events->@*;

done_testing;
