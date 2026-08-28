#! perl

use v5.28;
use strict;
use warnings;
use DDP;

package App::CXC::usint::Filters 1.00 {

    use Moo;
    use MooX::TypeTiny;
    use Sub::HandlesVia;

    # with 'MooX::Tag::TO_JSON';

    has _filters => (
        is          => 'ro',
        to_json     => 1,
        default     => sub { {} },
        handles_via => 'Hash',
        handles     => {
            has_filter     => 'exists',
            filter         => 'get',
            filters        => 'values',
            filter_names   => 'keys',
            _add_filter    => 'set',
            _delete_filter => 'delete',
        },
    );

}

my $filters = App::CXC::usint::Filters->new;

$filters->has_filter( 'fll' );

# # $filters->_filters->{foo} = 'bar';
# $filters->_add_filter( foo => 'bar' );
# p @{ [ $filters->filters ] };

p $filters->TO_JSON;
