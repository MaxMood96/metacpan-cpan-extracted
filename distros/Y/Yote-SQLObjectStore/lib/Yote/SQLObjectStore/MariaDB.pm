package Yote::SQLObjectStore::MariaDB;

use 5.16.0;
use warnings;

use Yote::SQLObjectStore::MariaDB::TableManager;
use base 'Yote::SQLObjectStore::StoreBase';

use Carp qw(confess);
use DBI;
use DBD::MariaDB;

sub base_obj {
    'Yote::SQLObjectStore::MariaDB::Obj';
}

sub insert_or_replace {
    'REPLACE ';
}

sub insert_or_ignore {
    'INSERT IGNORE ';
}

sub show_tables_like {
    my ($self,$tab) = @_;
    return "SHOW TABLES LIKE '$tab'";
}

sub new {
    my ($pkg, %args ) = @_;
    $args{root_package} //= 'Yote::SQLObjectStore::MariaDB::Root';
    return $pkg->SUPER::new( %args );
}

sub connect_sql {
    my ($pkg,%args) = @_;

    my $dbh = DBI->connect( "DBI:MariaDB".($args{dbname} ? ":dbname=$args{dbname}" : ""),
                            $args{username},
                            $args{password},
                            { PrintError => 0 } );
    confess "$@ $!" unless $dbh;
    
    return $dbh;
    
}

sub make_table_manager {
    my $self = shift;
    $self->{TABLE_MANAGER} = Yote::SQLObjectStore::MariaDB::TableManager->new( $self );
}


sub has_table {
    my ($self, $table_name) = @_;
    my ($has_table) = $self->query_line( "SHOW TABLES LIKE ?", $table_name );
    return $has_table;
}

sub _start_transaction {
    my $self = shift;
    $self->query_line( "START TRANSACTION" );
}
sub _commit_transaction {
    shift->query_line( "COMMIT" );
}
sub _rollback_transaction {
    shift->query_line( "ROLLBACK" );
}


1;
