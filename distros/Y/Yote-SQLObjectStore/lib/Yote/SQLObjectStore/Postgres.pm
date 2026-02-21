package Yote::SQLObjectStore::Postgres;

use 5.16.0;
use warnings;

use Yote::SQLObjectStore::Postgres::TableManager;
use base 'Yote::SQLObjectStore::StoreBase';

use Carp qw(confess);
use DBI;
use DBD::Pg;

sub base_obj {
    'Yote::SQLObjectStore::Postgres::Obj';
}

sub insert_or_replace {
    # Rows are always deleted first in TiedHash/TiedArray save_sql,
    # so a plain INSERT is safe here.
    'INSERT ';
}

sub insert_or_ignore {
    # Not currently used in the codebase.
    'INSERT ';
}

sub show_tables_like {
    my ($self,$tab) = @_;
    $tab = lc $tab;
    return "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE '$tab'";
}

sub new {
    my ($pkg, %args ) = @_;
    $args{root_package} //= 'Yote::SQLObjectStore::Postgres::Root';
    return $pkg->SUPER::new( %args );
}

sub connect_sql {
    my ($pkg,%args) = @_;

    my $dsn = "DBI:Pg";
    $dsn .= ":dbname=$args{dbname}" if $args{dbname};
    $dsn .= ";host=$args{host}" if $args{host};
    $dsn .= ";port=$args{port}" if $args{port};

    my $dbh = DBI->connect( $dsn,
                            $args{username},
                            $args{password},
                            { PrintError => 0 } );
    confess "$@ $!" unless $dbh;

    return $dbh;

}

sub make_table_manager {
    my $self = shift;
    $self->{TABLE_MANAGER} = Yote::SQLObjectStore::Postgres::TableManager->new( $self );
}


sub insert_get_id {
    my ($self, $query, @qparams ) = @_;
    $query .= " RETURNING id";
    my $dbh = $self->dbh;
    my $sth = $self->sth( $query );
    my $res = $sth->execute( @qparams );
    if (!defined $res) {
        die $sth->errstr;
    }
    my ($id) = $sth->fetchrow_array;
    return $id;
}

sub has_table {
    my ($self, $table_name) = @_;
    my ($has_table) = $self->query_line( "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename=?", lc $table_name );
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
