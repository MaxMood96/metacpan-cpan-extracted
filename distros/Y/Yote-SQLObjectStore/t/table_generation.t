#!/usr/bin/perl
use strict;
use warnings;

use lib './t/lib';
use lib './lib';

use Yote::SQLObjectStore;
use Yote::SQLObjectStore::TableManager;
use File::Temp qw/ tempdir /;
use Test::More;

# Test that generate_table_from_module recursively creates tables
# for all referenced modules, including through shared ARRAY_REF
# and HASH_*_REF tables.

sub make_store {
    my $dir = tempdir( CLEANUP => 1 );
    return Yote::SQLObjectStore->new( 'SQLite', BASE_DIRECTORY => $dir );
}

subtest 'recursive table generation via generate_table_from_module' => sub {
    my $store = make_store();
    my $manager = $store->get_table_manager;
    my $name2table = {};

    # Load only the parent — it uses its children
    require SQLite::Library;

    $manager->generate_table_from_module( $name2table, 'SQLite::Library' );

    my @tables = sort keys %$name2table;

    # Library references *ARRAY_*Book and *HASH<128>_*Author
    # Book references *Author (direct), *ARRAY_TEXT (chapters), *HASH<64>_TEXT (metadata)
    # Author references *ARRAY_*Book
    #
    # Expected tables:
    #   Library_SQLite           - the parent
    #   Book_Library_SQLite      - Book (reached via Library->books array AND Author->books)
    #   Author_Library_SQLite    - Author (reached via Library->authors hash)
    #   ARRAY_REF                - shared typed array ref table
    #   ARRAY_TEXT               - value array for chapters
    #   HASH_128_REF             - shared typed hash ref table (Library->authors)
    #   HASH_64_Text             - value hash for Book->metadata

    ok( exists $name2table->{'Library_SQLite'},
        'parent Library table created' );

    ok( exists $name2table->{'Book_Library_SQLite'},
        'child Book table created via *ARRAY_* reference' );

    ok( exists $name2table->{'Author_Library_SQLite'},
        'child Author table created via *HASH<128>_* reference' );

    ok( exists $name2table->{'ARRAY_REF'},
        'shared ARRAY_REF table created' );

    ok( exists $name2table->{'ARRAY_TEXT'},
        'ARRAY_TEXT table created for Book chapters' );

    ok( exists $name2table->{'HASH_128_REF'},
        'HASH_128_REF table created for Library->authors' );

    ok( exists $name2table->{'HASH_64_TEXT'},
        'HASH_64_TEXT table created for Book->metadata' );
};

subtest 'shared ARRAY_REF does not prevent second referenced module table' => sub {
    # This is the core bug that was fixed: when two different modules
    # are referenced via *ARRAY_*, they both use the ARRAY_REF table.
    # The early return on ARRAY_REF existing must not prevent the
    # second module's table from being created.

    my $store = make_store();
    my $manager = $store->get_table_manager;
    my $name2table = {};

    require SQLite::Library::Author;

    # Author has *ARRAY_*Book. Generate Author's table first.
    $manager->generate_table_from_module( $name2table, 'SQLite::Library::Author' );

    ok( exists $name2table->{'ARRAY_REF'},
        'ARRAY_REF created from Author->books' );
    ok( exists $name2table->{'Book_Library_SQLite'},
        'Book table created from Author->books reference' );

    # Now generate Library. Library also has *ARRAY_*Book (already done)
    # AND *HASH<128>_*Author. The ARRAY_REF table already exists,
    # but Library should still be created and Author should still be followed.
    $manager->generate_table_from_module( $name2table, 'SQLite::Library' );

    ok( exists $name2table->{'Library_SQLite'},
        'Library table created even though ARRAY_REF already existed' );
    ok( exists $name2table->{'Author_Library_SQLite'},
        'Author table created via hash reference from Library' );
};

subtest 'tables are actually created in SQLite' => sub {
    my $dir = tempdir( CLEANUP => 1 );
    my $store = Yote::SQLObjectStore->new( 'SQLite', BASE_DIRECTORY => $dir );

    local @INC = ( './lib', './t/lib' );
    $store->make_all_tables( @INC );
    $store->open;

    # Query sqlite_schema for our test tables
    my @expected = (
        'Library_SQLite',
        'Book_Library_SQLite',
        'Author_Library_SQLite',
    );

    for my $table (@expected) {
        my ($found) = $store->query_line(
            "SELECT name FROM sqlite_schema WHERE type='table' AND name=?", $table
        );
        ok( $found, "table $table exists in SQLite database" );
    }

    # Verify columns on Book table
    my ($book_sql) = $store->query_line(
        "SELECT sql FROM sqlite_schema WHERE name='Book_Library_SQLite'"
    );
    like( $book_sql, qr/\btitle\b/,    'Book table has title column' );
    like( $book_sql, qr/\bauthor\b/,   'Book table has author column' );
    like( $book_sql, qr/\bchapters\b/, 'Book table has chapters column' );
    like( $book_sql, qr/\bmetadata\b/, 'Book table has metadata column' );
};

done_testing;
