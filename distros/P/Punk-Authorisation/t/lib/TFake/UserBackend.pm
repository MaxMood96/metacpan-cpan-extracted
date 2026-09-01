package TFake::UserBackend;

# An in-memory backend for the users table, which is the only table these
# tests need a fake for: the grants half runs against real SQLite, because
# the point there is the DDL.
#
# Keyed by id rather than name, and it assigns ids on create the way a
# bigserial column would.

use strict;
use warnings;

our @USERS;         # users rows
our $USER_CALLS = 0;
our $NEXT_ID    = 1;
our $DIE_USERS  = 0;

sub reset_all {
    @USERS = ();
    $USER_CALLS = 0; $NEXT_ID = 1;
    $DIE_USERS = 0;
    return;
}

sub users_rows  { \@USERS }
sub user_calls  { $USER_CALLS }
sub reset_calls { $USER_CALLS = 0; return }
sub set_users   { shift; @USERS = @_; return }
sub die_users   { shift; $DIE_USERS = $_[0]; return }

# Punk hands a backend `database`, `table`, `primary` and `columns` at
# construction (xs/model.xs:132-141), so which table this instance serves is
# known here rather than guessed per call.
sub new {
    my ($class, %o) = @_;
    return bless { table   => $o{table}   || '',
                   primary => $o{primary} || 'id' }, $class;
}

sub _store {
    my ($self) = @_;
    return (\@USERS, \$USER_CALLS, \$DIE_USERS);
}

sub _match {
    my ($self, $row, %key) = @_;
    for my $f (keys %key) {
        my $want = $key{$f};
        return 0 unless defined $row->{$f} && defined $want;
        return 0 unless "$row->{$f}" eq "$want";
    }
    return 1;
}

sub get {
    my ($self, %key) = @_;
    my ($rows, $calls, $die) = $self->_store;
    $$calls++;
    die "the database is away\n" if $$die;
    for my $r (@$rows) { return { %$r } if $self->_match($r, %key) }
    return undef;
}

sub search {
    my ($self, $filter, $opts) = @_;
    my ($rows, $calls, $die) = $self->_store;
    $$calls++;
    die "the database is away\n" if $$die;
    my @out = grep { $self->_match($_, %{ $filter || {} }) } @$rows;
    return { rows => [ map { +{ %$_ } } @out ], has_more_data => 0,
             next => undef };
}

sub count {
    my ($self, $filter) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    return scalar grep { $self->_match($_, %{ $filter || {} }) } @$rows;
}

sub all {
    my ($self) = @_;
    return $self->search({}, {});
}

sub create {
    my ($self, $data) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    my %row = %$data;
    $row{id} = $NEXT_ID++ unless defined $row{id};
    push @$rows, \%row;
    return { %row };
}

sub update {
    my ($self, $data) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    for my $r (@$rows) {
        next unless defined $r->{id} && defined $data->{id}
                 && "$r->{id}" eq "$data->{id}";
        %$r = ( %$r, %$data );
        return { %$r };
    }
    return undef;
}

sub delete {
    my ($self, %key) = @_;
    my ($rows, undef, $die) = $self->_store;
    die "the database is away\n" if $$die;
    my $before = @$rows;
    @$rows = grep { !$self->_match($_, %key) } @$rows;
    return $before - @$rows;
}

1;
