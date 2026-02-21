package Yote::SQLObjectStore::SQLite;

use 5.16.0;
use warnings;

use Yote::SQLObjectStore::SQLite::TableManager;
use base 'Yote::SQLObjectStore::StoreBase';

use DBI;

use overload
    '""' => sub { my $self = shift; "$self->{OPTIONS}{BASE_DIRECTORY}/SQLITE.db" };

sub base_obj {
    'Yote::SQLObjectStore::SQLite::Obj';
}

sub insert_or_replace {
    'INSERT OR REPLACE ';
}

sub insert_or_ignore {
    'INSERT OR IGNORE ';
}

sub show_tables_like {
    my ($self,$tab) = @_;
    "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '$tab'";
}

sub new {
    my ($pkg, %args ) = @_;
    $args{root_package} //= 'Yote::SQLObjectStore::SQLite::Root';

    my $store = $pkg->SUPER::new( %args );

    # File lock for multi-process safety
    require Yote::Locker;
    my $lock_file = "$args{BASE_DIRECTORY}/SQLITE.lock";
    $store->{LOCKER} = Yote::Locker->new($lock_file);
    $store->{LOCKER}->unlock;  # constructor starts locked; release immediately

    return $store;
}

sub make_table_manager {
    my $self = shift;
    $self->{TABLE_MANAGER} = Yote::SQLObjectStore::SQLite::TableManager->new( $self );
}


sub connect_sql {
    my ($pkg,%args) = @_;
    my $file = "$args{BASE_DIRECTORY}/SQLITE.db";
    
    my $dbh = DBI->connect( "DBI:SQLite:dbname=$file", 
                            undef, 
                            undef, 
                            { PrintError => 0 } );
    die "$@ $!" unless $dbh;
    
    return $dbh;
    
}

sub has_table {
    my ($self, $table_name) = @_;
    my ($has_table) = $self->query_line( "SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE 'TableVersions'" );
    return $has_table;
}


sub _start_transaction {
    my $self = shift;
#    $self->query_line( "BEGIN TRANSACTION" );
    $self->query_line( "SAVEPOINT SP$$" );
}
sub _commit_transaction {
    my $self = shift;
    $self->query_line( "RELEASE SP$$" );
#    $self->query_line( "COMMIT TRANSACTION" );
}
sub _rollback_transaction {
    my $self = shift;
    #    $self->query_line( "ROLLBACK TRANSACTION" );
    $self->query_line( "ROLLBACK TRANSACTION TO SP$$" );
}

1;
