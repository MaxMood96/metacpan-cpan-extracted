use v5.42;
use Test2::V0;
use lib 'lib', '../lib';
use Acme::Selection::RarestFirst;
use Acme::Bitfield;
#
subtest 'Rarest First Picking' => sub {
    isa_ok my $sel = Acme::Selection::RarestFirst->new( size => 5 ), ['Acme::Selection::RarestFirst'];
    my $my_bf = Acme::Bitfield->new( size => 5 );

    # We leave 3 and 4 at 0 copies (absolute rarest)
    # 0 -> 3 copies
    # 1 -> 1 copy
    # 2 -> 2 copies
    isa_ok my $p0 = Acme::Bitfield->new( size => 5 ), ['Acme::Bitfield'];
    $p0->set(0);
    isa_ok my $p1 = Acme::Bitfield->new( size => 5 ), ['Acme::Bitfield'];
    $p1->set($_) for ( 0, 1, 2 );
    isa_ok my $p2 = Acme::Bitfield->new( size => 5 ), ['Acme::Bitfield'];
    $p2->set($_) for ( 0, 2 );
    #
    $sel->update( $p0, 1 );
    $sel->update( $p1, 1 );
    $sel->update( $p2, 1 );
    #
    is $sel->get_availability(0), 3, '0 has 3 copies';
    is $sel->get_availability(1), 1, '1 has 1 copy';
    is $sel->get_availability(2), 2, '2 has 2 copies';
    is $sel->get_availability(3), 0, '3 has 0 copies';

    # First pick should be 3 or 4 (both have 0)
    my $first = $sel->pick($my_bf);
    ok $first == 3 || $first == 4, 'Picked a 0-copy item ($first)';

    # Mark both 0-copy items as done
    $my_bf->set(3);
    $my_bf->set(4);

    # Next pick should be 1 (1 copy)
    is $sel->pick($my_bf), 1, 'Next picked 1-copy item';

    # Mark 1 as done
    $my_bf->set(1);
    is $sel->pick($my_bf), 2, 'Then picked 2-copy item';
};
subtest 'Priority Overriding' => sub {
    isa_ok my $sel   = Acme::Selection::RarestFirst->new( size => 5 ), ['Acme::Selection::RarestFirst'];
    isa_ok my $my_bf = Acme::Bitfield->new( size => 5 ),               ['Acme::Bitfield'];

    # Ensure everything has at least 1 copy so priorities work correctly
    isa_ok my $base = Acme::Bitfield->new( size => 5 ), ['Acme::Bitfield'];
    $base->fill();
    $sel->update( $base, 1 );

    # 0 is rare (1 copy)
    # 1 is common (10 copies)
    isa_ok my $p1 = Acme::Bitfield->new( size => 5 ), ['Acme::Bitfield'];
    $p1->set(1);
    $sel->update( $p1, 9 );

    # Normal picks one of the rare ones
    is $sel->pick($my_bf), in_set( 0, 2, 3, 4 ), 'Normally picks rarest';

    # High priority for 1
    my $priorities = [ 1, 10, 1, 1, 1 ];
    is $sel->pick( $my_bf, $priorities ), 1, 'Picks higher priority even if common';
};
#
done_testing;
