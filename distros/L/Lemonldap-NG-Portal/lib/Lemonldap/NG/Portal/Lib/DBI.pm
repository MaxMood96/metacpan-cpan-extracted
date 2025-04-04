##@file
# DBI common functions

##@class
# DBI common functions
package Lemonldap::NG::Portal::Lib::DBI;

use DBI;
use MIME::Base64;
use strict;
use Mouse;
use Crypt::URandom;
use MIME::Base64 qw/encode_base64url/;
use Lemonldap::NG::Portal::Main::Constants qw(PE_OK PE_DONE);

extends 'Lemonldap::NG::Common::Module';

our $VERSION = '2.0.14';

# PROPERTIES

has table => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        my $conf = $_[0]->{conf};
        return $conf->{dbiUserTable} || $conf->{dbiAuthTable};
    }
);

has pivot => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        my $conf = $_[0]->{conf};
        return $conf->{userPivot} || $conf->{dbiAuthLoginCol};
    }
);

has mailField => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        my $conf = $_[0]->{conf};
        return
             $conf->{dbiMailCol}
          || $conf->{userPivot}
          || $conf->{dbiAuthLoginCol};
    }
);

# _dbh object: DB connection object
has _dbh => (
    is      => 'rw',
    lazy    => 1,
    builder => 'dbh',
);

sub dbh {
    my ($self) = @_;

    my $conf = $self->{conf};
    $self->{_dbh} = eval {
        DBI->connect_cached(
            $conf->{dbiAuthChain}, $conf->{dbiAuthUser},
            $conf->{dbiAuthPassword}, { RaiseError => 1, AutoCommit => 1, }
        );
    };
    if ($@) {
        $self->{p}->logger->error("DBI connection error: $@");
        return 0;
    }

    if ( $conf->{dbiAuthChain} =~ /^dbi:sqlite/i ) {
        $self->{_dbh}->{sqlite_unicode} = 1;
    }
    elsif ( $conf->{dbiAuthChain} =~ /^dbi:mysql/i ) {
        eval {
            $self->{_dbh}->{mysql_enable_utf8} = 1;
            $self->{_dbh}->do("set names 'utf8'");
        };
    }
    elsif ( $conf->{dbiAuthChain} =~ /^dbi:pg/i ) {
        $self->{_dbh}->{pg_enable_utf8} = 1;
    }

    return $self->{_dbh};
}

# INITIALIZATION

# All DBI modules have just to verify that DBI connection is available
sub init {
    my ($self) = @_;
    $self->_dbh
      or $self->logger->error("DBI connection has failed, but let's continue");
    unless ( $self->table ) {
        $self->logger->error(
            "SQL Table name is not set, can't load " . ref($self) );
        return 0;
    }
    return 1;
}

# RUNNING METHODS

# Return hashed password for use in SQL statement
# @param password clear password
# @param hash hash mechanism
# @return SQL statement string
sub hash_password {
    my ( $self, $password, $hash ) = @_;
    if ($hash) {
        $self->logger->debug( "Using " . uc($hash) . " to hash password" );
        return uc($hash) . "($password)";
    }

    $self->logger->debug("No password hash, using clear text for password");
    return $password;
}

# Return hashed password for use in SQL SELECT statement
# Call hash_password unless encrypt hash is choosen
# @param password clear password
# @param hash hash mechanism
# @return SQL statement string
sub hash_password_for_select {
    my ( $self, $password, $hash ) = @_;
    my $passwordCol = $self->conf->{dbiAuthPasswordCol};

    if ( $hash =~ /^encrypt$/i ) {
        return uc($hash) . "($password,$passwordCol)";
    }
    else {
        return $self->hash_password( $password, $hash );
    }
}

## @method protected Lemonldap::NG::Portal::_DBI get_password(ref dbh, string user)
# Get password from database
# @param dbh database handler
# @param user user
# @return password
sub get_password {
    my $self        = shift;
    my $dbh         = shift;
    my $user        = shift || $self->{user};
    my $table       = $self->conf->{dbiAuthTable};
    my $loginCol    = $self->conf->{dbiAuthLoginCol};
    my $passwordCol = $self->conf->{dbiAuthPasswordCol};

    my @rows = ();
    eval {
        my $sth =
          $dbh->prepare("SELECT $passwordCol FROM $table WHERE $loginCol=?");
        $sth->execute($user);
        @rows = $sth->fetchrow_array();
    };
    if ($@) {
        $self->logger->error("DBI error while getting password: $@");
        return "";
    }

    if ( @rows == 1 ) {
        $self->logger->debug("Successfully got password from database");
        return $rows[0];
    }
    else {
        $self->userLogger->warn("Unable to check password for $user");
        return "";
    }
}

## @method protected Lemonldap::NG::Portal::_DBI hash_password_from_database
##  (ref dbh, string dbmethod, string dbsalt, string password)
# Hash the given password calling the dbmethod function in database
# @param dbh database handler
# @param dbmethod the database method for hashing
# @param salt the salt used for hashing
# @param password the password to hash
# @return hashed password
sub hash_password_from_database {

    # Remark: database function must get hexadecimal input
    # and send back hexadecimal output
    my $self     = shift;
    my $dbh      = shift;
    my $dbmethod = shift;
    my $dbsalt   = shift;
    my $password = shift;

    # convert password to hexa
    my $passwordh = unpack "H*", $password;

    my @rows = ();
    eval {
        my $sth = $dbh->prepare("SELECT $dbmethod('$passwordh$dbsalt')");
        $sth->execute();
        @rows = $sth->fetchrow_array();
    };
    if ($@) {
        $self->logger->error(
            "DBI error while hashing with '$dbmethod' hash function: $@");
        $self->userLogger->warn("Unable to check password");
        return "";
    }

    if ( @rows == 1 ) {
        $self->logger->debug(
"Successfully hashed password with $dbmethod hash function in database"
        );

        # convert salt to binary
        my $dbsaltb = pack 'H*', $dbsalt;

        # convert result to binary
        my $res = pack 'H*', $rows[0];

        return encode_base64( $res . $dbsaltb, '' );
    }
    else {
        $self->userLogger->warn("Unable to check password with '$dbmethod'");
        return "";
    }

    # Return encode_base64(SQL_METHOD(password + salt) + salt)
}

## @method protected Lemonldap::NG::Portal::_DBI get_salt(string dbhash)
# Return salt from salted hash password
# @param dbhash hash password
# @return extracted salt
sub get_salt {
    my $self   = shift;
    my $dbhash = shift;
    my $dbsalt;

    # get rid of scheme ({sha256})
    $dbhash =~ s/^\{[^}]+\}(.*)$/$1/;

    # get binary hash
    my $decoded = &decode_base64($dbhash);

    # get last 8 bytes
    $dbsalt = substr $decoded, -8;

    # get hexadecimal version of salt
    $dbsalt = unpack "H*", $dbsalt;

    return $dbsalt;
}

## @method protected Lemonldap::NG::Portal::_DBI gen_salt()
# Generate 8 bytes of hexadecimal random salt
# @return generated salt
sub gen_salt {
    my $self = shift;
    my $dbsalt;
    my @set = ( '0' .. '9', 'A' .. 'F' );

    $dbsalt = join '' => map $set[ rand @set ], 1 .. 16;

    return $dbsalt;
}

## @method protected Lemonldap::NG::Portal::_DBI gen_salt_text()
# Generate 16 bytes of text random salt
# @return generated salt text
sub gen_salt_text {
    my $self   = shift;
    my $dbsalt = encode_base64url( Crypt::URandom::urandom(16) );
    $dbsalt =~ s/-/\./g;
    $dbsalt =~ s/_/\//g;

    return substr( $dbsalt, 0, 16 );
}

## @method protected Lemonldap::NG::Portal::_DBI get_dynamic_hash_password(ref dbh,
##  string user, string password, string table, string loginCol, string passwordCol)
# Return hashed password for use in SQL statement
# @param dbh database handler
# @param user connected user
# @param password clear password
# @param table authentication table name
# @param loginCol name of the row containing the login
# @param passwordCol name of the row containing the password
# @return hashed password
sub get_dynamic_hash_password {
    my $self        = shift;
    my $dbh         = shift;
    my $user        = shift;
    my $password    = shift;
    my $table       = shift;
    my $loginCol    = shift;
    my $passwordCol = shift;
    my $dbhash      = shift;

    # Authorized hash schemes and salted hash schemes
    my @validSchemes = split / /, $self->conf->{dbiDynamicHashValidSchemes};
    my @validSaltedSchemes = split / /,
      $self->conf->{dbiDynamicHashValidSaltedSchemes};

    my $dbscheme;    # current hash scheme stored in database
    my $dbmethod;    # static hash method corresponding to a database function
    my $dbsalt;      # current salt stored in database
    my $hash;        # hash to compute from user password

    # Get the scheme
    $dbscheme = $dbhash;
    $dbscheme =~ s/^\{([^}]+)\}.*/$1/;
    $dbscheme = "" if $dbscheme eq $dbhash;

    # check for unix style passwords
    if ( $dbscheme eq "" and $dbhash =~ /^\$(1|5|6)\$/i ) {
        $dbscheme = $1;

        #check if unix hash scheme is valid
        if ( not grep( /^unixcrypt$dbscheme$/, @validSaltedSchemes ) ) {
            $self->logger->error(
                "No valid unix hash scheme: unixcrypt$dbscheme for user $user");
            $self->userLogger->warn("Unable to check password for $user");
            return;
        }

        $self->logger->debug(
            "Using unixcrypt$dbscheme to hash salted password");

        $hash = crypt($password, $dbhash);
        return $hash;
    }

    # no hash scheme => assume clear text
    if ( $dbscheme eq "" ) {
        $self->logger->info("Password has no hash scheme");
        return $password;

    }

    # salted hash scheme
    if ( grep( /^$dbscheme$/, @validSaltedSchemes ) ) {
        $self->logger->info(
            "Valid salted hash scheme: $dbscheme found for user $user");

        # extract non salted hash scheme
        $dbmethod = $dbscheme;
        $dbmethod =~ s/^s//i;

        # extract the salt
        $dbsalt = $self->get_salt($dbhash);
        $self->logger->debug("Get salt from password: $dbsalt");

        # Hash password with given hash scheme and salt
        $hash =
          $self->hash_password_from_database( $dbh, $dbmethod, $dbsalt,
            $password );
        $hash = "{$dbscheme}$hash";

        return $hash;

    }

    # static hash scheme
    elsif ( grep( /^$dbscheme$/, @validSchemes ) ) {
        $self->logger->info(
            "Valid hash scheme: $dbscheme found for user $user");

        # Hash given password with given hash scheme and no salt
        $hash =
          $self->hash_password_from_database( $dbh, $dbscheme, "", $password );
        $hash = "{$dbscheme}$hash";

        return $hash;
    }

    # no valid hash scheme
    else {
        $self->logger->error("No valid hash scheme: $dbscheme for user $user");
        $self->userLogger->warn("Unable to check password for $user");
        return;
    }
}

# DEPRECATED: this function returned the password hash as a piece of SQL query
# which is fragile
sub dynamic_hash_password {
    my $self        = shift;
    my $dbh         = shift;
    my $user        = shift;
    my $password    = shift;
    my $table       = shift;
    my $loginCol    = shift;
    my $passwordCol = shift;
    my $dbhash      = shift;

    my $hashed_password =
      $self->get_dynamic_hash_password( $dbh, $user, $password, $table,
        $loginCol, $passwordCol, $dbhash );
    if ($hashed_password) {
        if ( $hashed_password eq $password ) {
            return "?";
        }
        else {
            return "'$hashed_password'";
        }
    }
    else {
        return "";
    }
}

## @method protected Lemonldap::NG::Portal::_DBI get_dynamic_hash_new_password(ref dbh,
##  string user, string password)
# @return hashed password
# @param dbh database handler
# @param user connected user
# @param password clear password
# @param dbscheme the scheme to use for hashing
sub get_dynamic_hash_new_password {
    my ( $self, $req_or_undef, $dbh, $user, $password ) = @_;
    my $dbscheme = $self->conf->{dbiDynamicHashNewPasswordScheme} || "";

    # Authorized hash schemes and salted hash schemes
    my @validSchemes = split / /, $self->conf->{dbiDynamicHashValidSchemes};
    my @validSaltedSchemes = split / /,
      $self->conf->{dbiDynamicHashValidSaltedSchemes};

    my $dbmethod;    # static hash method corresponding to a database function
    my $dbsalt;      # salt to generate for new hashed password
    my $hash;        # hash to compute from user password

    # no hash scheme => assume clear text
    if ( $dbscheme eq "" ) {
        $self->logger->info(
            "No hash scheme selected, storing password in clear text");
        return $password;

    }

    # Try to delegate password hashing to a plugin
    if ( my $req = $req_or_undef ) {
        my $hook_result = {};
        my $h =
          $self->p->processHook( $req, 'dbiHashPassword', $dbscheme, $password,
            $hook_result );
        if ( $h == PE_DONE ) {
            my $hashed_password = $hook_result->{hashed_password};
            if ($hashed_password) {
                return $hashed_password;
            }
            else {
                $self->logger->error(
                    "dbiHashPassword hook did not return a hashed password");
                return;
            }
        }
    }

    # Check for unix password string
    if ( $dbscheme =~ /^unixcrypt(1|5|6)$/i ) {
        $self->logger->info("Selected salted hash scheme: $dbscheme");

        $dbscheme = $1;
        $dbsalt   = gen_salt_text();
        $dbsalt   = "\$$dbscheme\$$dbsalt\$";

        $hash = crypt($password, $dbsalt);

        return $hash;

    }

    # salted hash scheme
    elsif ( grep( /^$dbscheme$/, @validSaltedSchemes ) ) {
        $self->logger->info("Selected salted hash scheme: $dbscheme");

        # extract non salted hash scheme
        $dbmethod = $dbscheme;
        $dbmethod =~ s/^s//i;

        # generate the salt
        $dbsalt = $self->gen_salt();
        $self->logger->debug("Generated salt: $dbsalt");

        # Hash given password with given hash scheme and salt
        $hash =
          $self->hash_password_from_database( $dbh, $dbmethod, $dbsalt,
            $password );
        $hash = "{$dbscheme}$hash";

        return $hash;

    }

    # static hash scheme
    elsif ( grep( /^$dbscheme$/, @validSchemes ) ) {
        $self->logger->info("Selected hash scheme: $dbscheme");

        # Hash given password with given hash scheme and no salt
        $hash =
          $self->hash_password_from_database( $dbh, $dbscheme, "", $password );
        $hash = "{$dbscheme}$hash";

        return $hash;
    }

    # no valid hash scheme
    else {
        $self->logger->error("No selected hash scheme: $dbscheme is invalid");
        $self->userLogger->warn("Unable to store password for $user");
        return;
    }
}

# DEPRECATED: this function returned the password hash as a piece of SQL query
# which is fragile
sub dynamic_hash_new_password {
    my ( $self, $dbh, $user, $password ) = @_;
    my $dbscheme = $self->conf->{dbiDynamicHashNewPasswordScheme} || "";

    # no hash scheme => assume clear text
    if ( $dbscheme eq "" ) {
        $self->logger->info(
            "No hash scheme selected, storing password in clear text");
        return "?";

    }

    my $hash =
      $self->get_dynamic_hash_new_password( undef, $dbh, $user, $password );
    if ($hash) {
        return "'$hash'";
    }
    else {
        return "";
    }
}

# This method returns undef if the validation couldn't be performed, so that
# db-side hashing can be tried next
# If validation is successful, return the boolean result
sub try_verify_hash {
    my ( $self, $req, $password, $dbhash ) = @_;

    # Try to delegate password hashing to a plugin
    my $hook_result = {};
    my $h =
      $self->p->processHook( $req, 'dbiVerifyPassword', $password, $dbhash,
        $hook_result );
    if ( $h == PE_DONE ) {
        my $result = $hook_result->{result};
        $self->logger->warn("Undefined result from dbiVerifyPassword")
          unless defined $result;
        return $result;
    }
    return;
}

# Verify user and password with SQL SELECT
# @param user user
# @param password password
# @return boolean result
sub check_password {
    my ( $self, $req_or_user, $password ) = @_;

    my $req;
    my $user;

    # If $user is an object then it's a Lemonldap::NG::Portal::Main::Request
    # object
    if ( ref($req_or_user) ) {
        $req = $req_or_user;
        $password ||= $req->data->{password};
        $user = $req->user;
    }
    else {
        $user = $req_or_user;
    }

    my $table       = $self->conf->{dbiAuthTable};
    my $loginCol    = $self->conf->{dbiAuthLoginCol};
    my $passwordCol = $self->conf->{dbiAuthPasswordCol};
    my $dynamicHash = $self->conf->{dbiDynamicHashEnabled} || 0;

    my $passwordsql;
    my $comparevalue;
    if ( $dynamicHash == 1 ) {

        my $dbh = $self->dbh;
        my $dbhash =
          $self->get_password( $dbh, $user, $table, $loginCol, $passwordCol );

        if ( !$dbhash ) {
            $self->logger->warn("Password for $user was not found in database");
            return 0;
        }

        # Hooks will not be called if this method was called without a request
        if ($req) {

            # Attempt to verify password on LemonLDAP side
            my $result = $self->try_verify_hash( $req, $password, $dbhash );

            # warning: 0 means verification failed.
            # undef means no verification was done
            if ( defined $result ) {
                return $result;
            }
        }

        # Compte hash on DB side
        $passwordsql = "?";
        $comparevalue =
          $self->get_dynamic_hash_password( $dbh, $user, $password, $table,
            $loginCol, $passwordCol, $dbhash );
    }
    else {
        # Static Password hashes
        $passwordsql =
          $self->hash_password_for_select( "?",
            $self->conf->{dbiAuthPasswordHash} );
        $comparevalue = $password;
    }

    my @rows = ();
    eval {
        my $sth = $self->dbh->prepare(
"SELECT $loginCol FROM $table WHERE $loginCol=? AND $passwordCol=$passwordsql"
        );
        $sth->execute( $user, $comparevalue );
        @rows = $sth->fetchrow_array();
    };
    if ($@) {

        # If connection isn't available, error is displayed by dbh()
        $self->logger->error("DBI error: $@") if ( $self->_dbh );
        return 0;
    }

    if ( @rows == 1 ) {
        $self->logger->debug("One row returned by SQL query");
        return 1;
    }
    else {
        $self->userLogger->warn("Bad password for $user");
        return 0;
    }

}

1;
