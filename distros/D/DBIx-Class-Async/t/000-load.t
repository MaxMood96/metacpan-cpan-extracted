#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 16;

BEGIN {
    use_ok('DBIx::Class::Async')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::AmbiguousColumn')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::Factory')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::MissingColumn')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::NoSuchRelationship')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::NotInStorage')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Exception::RelationshipAsColumn')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Schema')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::ResultSet')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::ResultSetColumn')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::ResultSet::Pager')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Row')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Storage')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Storage::DBI')
        || print "Bail out!\n";
    use_ok('DBIx::Class::Async::Storage::DBI::Cursor')
        || print "Bail out!\n";
}

diag( "Testing DBIx::Class::Async $DBIx::Class::Async::VERSION, Perl $], $^X" );

done_testing;
