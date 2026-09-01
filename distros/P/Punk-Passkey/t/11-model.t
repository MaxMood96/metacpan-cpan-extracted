#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

BEGIN {
    plan skip_all => 'Punk 0.31+ is needed to mount the plugin'
        unless eval { require Punk; Punk->VERSION('0.31'); 1 };
    plan skip_all => 'Punk::Test is needed to compile an application'
        unless eval { require Punk::Test; require Punk::Model; 1 };
}
use Punk::Passkey ();
use Punk::Plugin::Passkey ();

# The shipped model, and which model an application ends up with.
#
# Three cases, and the one that matters is the third: an application that
# has said nothing about a model must still get one, because the plugin
# reads storage through $c->model and a name that resolves to nothing is a
# 500 at the first registration rather than an error at boot.
#
# The other two are the ones that must NOT be taken over. A wrong table
# here is not a failure, it is a login that works against the wrong rows.

# ---- an in-memory backend ---------------------------------------------------
# The same shape as t/09-plugin.t's: a real Punk::Model over a real
# registry with the database swapped for a hash.

our @ROWS;
our $SEQ = 0;
{
    package PPKMem2;
    sub new { my ($c, %a) = @_; bless { primary => $a{primary} || 'id' }, $c }
    sub get { undef }
    sub search {
        return { rows => [ map { +{ %$_ } } @main::ROWS ],
                 has_more_data => 0, next => undef };
    }
    sub all    { $_[0]->search({}, {}) }
    sub count  { scalar @main::ROWS }
    sub create {
        my ($s, $data) = @_;
        my $row = { %$data, id => ++$main::SEQ };
        push @main::ROWS, $row;
        return { %$row };
    }
    sub update { undef }
    sub delete { 0 }
}

# ---- the shipped class ------------------------------------------------------

require_ok('Punk::Model::Passkey');
isa_ok('Punk::Model::Passkey', 'Punk::Model');

SKIP: {
    skip 'this Punk::Model exposes no meta', 4
        unless Punk::Model::Passkey->can('_punk_model_meta');
    my $meta = Punk::Model::Passkey->_punk_model_meta;

    is($meta->{table}, 'passkeys', 'the table the Sqitch project deploys');
    is($meta->{primary}, 'id', 'keyed on id');

    # Every column of the DDL, because the DBI backend writes only declared
    # fields: one missing here is a column that can never be written, and
    # nothing else would say so.
    is_deeply([ sort @{ $meta->{fields} } ],
              [ sort qw(id user_id credential_id public_key sign_count
                        transports aaguid label created_at last_used_at) ],
              'every column of the credential table is declared');

    # The COSE key is stored as the bytes the authenticator sent. A type
    # would be a claim about those bytes that nothing needs and that turns
    # binary into something being validated as text.
    ok(!exists $meta->{field}{public_key}{type},
       'public_key carries no type - it holds bytes, not text');
}

# ---- an application that declares nothing gets it ---------------------------

{
    package PKNoModel;
    use Punk;
    session secret => 'model-test-secret';
    host 'https://webauthn.io';
    database backend => 'PPKMem2';
    plugin 'Passkey' => { user_id => sub { 7 } };
}

my $t = Punk::Test->new('PKNoModel');

{
    my $cfg = Punk::Plugin::Passkey::state_for('PKNoModel');
    is($cfg->{model}, 'Punk::Model::Passkey',
       'an application with no model of its own is given the shipped one');
}

# and it resolves: the manage route reads the model on every request
$t->get_ok('/account/passkeys')->status_is(200);

# ---- an application that named its own keeps it -----------------------------

{
    package PKOwnNamed::Model::Passkey;
    use Punk::Model;
    table 'my_passkeys';
    field id => { type => 'integer', primary => 1 };
}
{
    package PKOwnNamed;
    use Punk;
    session secret => 'model-test-secret';
    host 'https://webauthn.io';
    database backend => 'PPKMem2';
    model 'Passkey';
    plugin 'Passkey' => { user_id => sub { 7 } };
}

Punk::Test->new('PKOwnNamed');

is(Punk::Plugin::Passkey::state_for('PKOwnNamed')->{model}, 'Passkey',
   'a model registered under the configured name is left alone');

# ---- an application relying on auto-discovery keeps its own too -------------
#
# Declared inline and never named, which is how a test application and a
# small script both do it. `require` cannot see such a class - it looks for
# a file - so a check built only on `require` would answer "they have none"
# and register the shipped class over the top.

{
    package PKOwnAuto::Model::Passkey;
    use Punk::Model;
    table 'auto_passkeys';
    field id => { type => 'integer', primary => 1 };
}
{
    package PKOwnAuto;
    use Punk;
    session secret => 'model-test-secret';
    host 'https://webauthn.io';
    database backend => 'PPKMem2';
    plugin 'Passkey' => { user_id => sub { 7 } };
}

Punk::Test->new('PKOwnAuto');

is(Punk::Plugin::Passkey::state_for('PKOwnAuto')->{model}, 'Passkey',
   'a model class discovered in the application namespace is left alone');

done_testing();
