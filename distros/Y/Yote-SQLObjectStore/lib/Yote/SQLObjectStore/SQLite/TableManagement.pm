package Yote::SQLObjectStore::SQLite::TableManagement;

use 5.16.0;
use warnings;

use File::Grep qw(fgrep fmap fdo);
use Module::Load::Conditional qw(requires can_load);
use Yote::SQLObjectStore::SQLite::TableManagement;

# generate sql to make tables
# takes a list of subclasses of Yote::SQLObjectStore::Obj 
# to make tables for. also makes tables for Hash* and Array*
sub generate_base_sql {
    my ($pkg) = @_;
    
    my @tables;

    # create object index and root
    push @tables, <<"END";
CREATE TABLE IF NOT EXISTS ObjectIndex ( 
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    live BOOLEAN,
    objtable TEXT
);
END

    # make different array and hash tables
    push @tables, "CREATE TABLE IF NOT EXISTS HASH_REF (id INT, key TEXT, refid INT, UNIQUE (id,key))";

    push @tables, "CREATE TABLE IF NOT EXISTS HASH_VALUE (id INT, key TEXT, val, UNIQUE (id,key))";

    push @tables, "CREATE TABLE IF NOT EXISTS ARRAY_REF (id INT, idx INT, refid INT, UNIQUE (id,idx))";

    push @tables, "CREATE TABLE IF NOT EXISTS ARRAY_VALUE (id INT, idx INT, val, UNIQUE (id,idx))";


    return @tables;
}


sub _walk_for_perl {
    my ($root,@path) = @_;

    my @mods;

    my $path = join( '/', $root, @path );

    my @perls = map { my $fn = $_->{filename}; $fn =~ s/(.*\/)([^\/]*).pm/$2/; join( "::", @path, $fn ) }
                grep { $_->{count} } 
                fgrep { /Yote::.*::Obj/ } 
                glob "$path/*pm";

    for my $mod (@perls) {
        my @reqlist = requires( $mod );
        if (grep { $_ eq 'Yote::SQLObjectStore::SQLite::Obj' } @reqlist) {
            push @mods, $mod;
        }
    }

    # check for subdirs
    opendir my $dh, $path or return;

    for my $file (grep { $_ !~ /^..?$/ } readdir($dh)) {
        if( -d "$path/$file" ) {
            push @mods, _walk_for_perl( $root, @path, $file );
        }
    }
    return @mods;
}

sub find_obj_packages {
    my @mods;
    for my $dir (@INC) {
        next if $dir eq '.';
        # find the perl files in this directory
        push @mods, _walk_for_perl( $dir );
    }
    return @mods;
}

sub all_obj_tables_sql {
    my $pkg = shift;
    my @builds = generate_base_sql;
    my @mods = find_obj_packages;

    my %files = reverse %INC;

    my %seen;
    for my $mod (@mods) {
        my $as_path = join( '/', split( /::/, $mod)) . '.pm';
        next if $files{$as_path};
        if (can_load ( modules => { $mod => 0 }, verbose => 1)) {
            if ($seen{$mod}++) {
            } else {
                $files{$as_path} = 1;
                push @builds, $mod->make_table_sql;
                %files = reverse %INC;
            }
        }
    }

    return @builds;
}


1;
