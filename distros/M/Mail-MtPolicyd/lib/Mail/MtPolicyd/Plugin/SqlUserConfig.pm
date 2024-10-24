package Mail::MtPolicyd::Plugin::SqlUserConfig;

use Moose;
use namespace::autoclean;

our $VERSION = '2.05'; # VERSION
# ABSTRACT: mtpolicyd plugin for retrieving the user config of a user

extends 'Mail::MtPolicyd::Plugin';


use Mail::MtPolicyd::Plugin::Result;
use JSON;

has 'sql_query' => (
	is => 'rw', isa => 'Str',
	default => 'SELECT config FROM user_config WHERE address=?',
);

has '_json' => (
	is => 'ro', isa => 'JSON', lazy => 1,
	default => sub {
		return JSON->new;
	}
);

has 'field' => ( is => 'rw', isa => 'Str', default => 'recipient' );

with 'Mail::MtPolicyd::Role::Connection' => {
  name => 'db',
  type => 'Sql',
};
with 'Mail::MtPolicyd::Plugin::Role::SqlUtils';

sub _get_config {
	my ( $self, $r ) = @_;
	my $key = $r->attr( $self->field );
    if( ! defined $key || $key =~ /^\s*$/ ) {
        die('key field '.$self->field.' not defined or empty in request');
    }

	my $sth = $self->execute_sql( $self->sql_query, $key );
	my ( $json ) = $sth->fetchrow_array;
	if( ! defined $json ) {
		die( 'no user-config found for '.$key );
	}
	return $self->_json->decode( $json );
}

sub run {
	my ( $self, $r ) = @_;
	my $config;

	eval { $config = $self->_get_config($r) };
	if( $@ ) {
		$self->log($r, 'unable to retrieve user-config: '.$@);
		return;
	}

	foreach my $key ( keys %$config ) {
		$r->session->{$key} = $config->{$key};
	}

	return;
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mail::MtPolicyd::Plugin::SqlUserConfig - mtpolicyd plugin for retrieving the user config of a user

=head1 VERSION

version 2.05

=head1 DESCRIPTION

This plugin will retrieve a JSON string from an SQL database and will merge the data structure
into the current session.

This could be used to retrieve configuration values for users from a database.

=head1 PARAMETERS

=over

=item sql_query (default: SELECT config FROM user_config WHERE address=?)

The SQL query to retrieve the JSON configuration string.

The content of the first row/column is used.

=item field (default: recipient)

The request field used in the sql query to retrieve the user configuration.

=back

=head1 EXAMPLE USER SPECIFIC GREYLISTING

Create the following table in the SQL database:

 CREATE TABLE `user_config` (
   `id` int(11) NOT NULL AUTO_INCREMENT,
   `address` varchar(255) DEFAULT NULL,
   `config` TEXT NOT NULL,
   PRIMARY KEY (`id`),
   UNIQUE KEY `address` (`address`)
 ) ENGINE=MyISAM  DEFAULT CHARSET=latin1

 INSERT INTO TABLE `user_config` VALUES( NULL, 'karlson@vomdach.de', '{"greylisting":"on"}' );

In mtpolicyd.conf:

  db_dsn="dbi:mysql:mail"
  db_user=mail
  db_password=password

  <Plugin user-config>
    module = "SqlUserConfig"
    sql_query = "SELECT config FROM user_config WHERE address=?"
  </Plugin>
  <Plugin greylist>
    enabled = "off" # off by default
    uc_enabled = "greylisting" # override with value of key 'greylisting' is set in session
    module = "Greylist"
    score = -5
    mode = "passive"
  </Plugin>

=head1 AUTHOR

Markus Benning <ich@markusbenning.de>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Markus Benning <ich@markusbenning.de>.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
