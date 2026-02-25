package Yote::SQLObjectStore;

use 5.16.0;
use warnings;

our $VERSION = '0.05';

sub new {
    my ($pkg, $flavor, %args) = @_;

    my $flavor_packet = $flavor eq 'SQLite' ? 'Yote::SQLObjectStore::SQLite'
        : $flavor eq 'MariaDB' ? 'Yote::SQLObjectStore::MariaDB'
        : $flavor eq 'Postgres' ? 'Yote::SQLObjectStore::Postgres'
        : $flavor;

#    die "Error, new must be called with an implementation flavor";

    my $flavor_file = $flavor_packet;
    $flavor_file =~ s/::/\//g;
    require "$flavor_file.pm";
    
    $flavor_packet->new( %args );
}


1;

=head1 NAME

Yote::SQLObjectStore - Rooted tree based Object Store atop SQL

=head1 SYNOPSIS

 my $db_type = 'MariaDB'; # or SQLite
 my %args = ( root     => 'MyProject::Root', 
              dbname   => 'myproject', 
              username => 'me', 
              password => 'plugh' );
 my $object_store = Yote::SQLObjectStore->new( $db_type, %args );

 # scan packages in given @INC_PATH for Yote::SQLObjectStore::Obj descendents and build tables for them.
 if ($object_store->needs_table_updates(@INC_PATH) {
   if (CAREFUL) {
     say join("\n", $object_store->make_all_tables_sql );
     say "\nREVIEW THE ABOVE AND RUN THE SQL IF GOOD\n";
     exit;
   } else {
     say "YOLO the tables";
     $object_store->make_all_tables;
   }
 }

 $object_store->open;

 my $users = $root->fetch_string_path( '/users' );

 my $bob = $object_store->new_obj( 'MyProject::User',    # package (see below)
                                   name     => 'robert', # fields/values
                                   email    => 'littlebobbytables@xkcd.org',
                                   password => crypt( "frobnitz" ) );
 $users->{bob} = $bob;

 $object_store->save;

 my $name = $object_store->fetch_string_path( "/users/bob/name" );
 say $name; #robert

 my $sue = $object_store->new_obj( 'MyProject::User',    # package (see below)
                                   name     => '/sue the slasher', # fields/values
                                   email    => 'hackhackslas@dnd.org',
                                   password => crypt( "zorsdfbi" ) );

 $users->{"/sue"} = $sue;

 my $sue_name = $object_store->fetch_string_path( 'users', '/sue', 'name' ) );
 say $sue_name; # /sue the slasher


 package MyProject::Root;
   use base 'Yote::SQLObjectStore::MariaDB::Obj';
   our %cols = (
      users => '*HASH<256>_*User::MyProject'
   );
 1;


 package MyProject::User;
   use base 'Yote::SQLObjectStore::MariaDB::Obj';
   our %cols = (
      name     => 'VARCHAR(256)',
      email    => 'VARCHAR(256)',
      password => 'VARCHAR(1024)',
   );
 1;  

=head1 DESCRIPTION

 table path detection
 table versioning
 path from root
 runtime type checking
 dirty detection and saving

=head1 DESIGN PHILOSOPHY

=head1 COLUMN DEFINITION

%cols attached to a Yote Obj is a package level hash of field to type.
The type may be a database type like 'VARCHAR(18)' or it may be a reference
to a HASH, ARRAY or other Yote Obj. References start with '*' followed by 'ARRAY',
'HASH\<hash key size\>', or a package name. Hashes are given a key size so the hash
database columns can be determined. If Array or Hash, a '_' followed by value type
must be given. '*ARRAY_User::MyProject' means an array of objects of type User::MyProject.
'*HASH\<256\>_*ARRAY_*' means a hash (with keys at most 256 characters) of arrays of any
reference. The value type can be a database column definition: '*ARRAY_BIGINT' for 
example.

=head1 METHODS



=cut
