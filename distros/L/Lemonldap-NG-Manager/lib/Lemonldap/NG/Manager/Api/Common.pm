package Lemonldap::NG::Manager::Api::Common;

our $VERSION = '2.19.0';

package Lemonldap::NG::Manager::Api;

use strict;
use Exporter 'import';
use Lemonldap::NG::Manager::Build::Attributes;
use Lemonldap::NG::Manager::Build::CTrees;

our @EXPORTS = qw(&_listAttributes);

# use Scalar::Util 'weaken'; ?

my @arrayize = qw(
  oidcRPMetaDataOptionsRedirectUris
  oidcRPMetaDataOptionsPostLogoutRedirectUris
  oidcRPMetaDataOptionsAdditionalAudiences
  casAppMetaDataOptionsService
  oidcRPMetaDataOptionsRequestUris
);

sub _mustArrayizeOption {
    my ( $self, $option ) = @_;
    return ( grep { $_ eq $option } @arrayize ) ? 1 : 0;
}

sub _isSimpleKeyValueHash {
    my ( $self, $hash ) = @_;
    return 0 if ( ref($hash) ne "HASH" );

    foreach ( keys %$hash ) {
        return 0 if ( ref( $hash->{$_} ) ne '' || ref($_) ne '' );
    }

    return 1;
}

sub _getDefaultValues {
    my ( $self, $rootNode ) = @_;
    my @allAttrs     = $self->_listAttributes($rootNode);
    my $defaultAttrs = Lemonldap::NG::Manager::Build::Attributes::attributes();
    my $attrs        = {};

    foreach my $attr (@allAttrs) {
        $attrs->{$attr} = $defaultAttrs->{$attr}->{default}
          if ( defined $defaultAttrs->{$attr}
            && defined $defaultAttrs->{$attr}->{default} );
    }

    return $attrs;
}

sub _hasAllowedAttributes {
    my ( $self, $attributes, $rootNode ) = @_;
    my @allowedAttributes = $self->_listAttributes($rootNode);

    foreach my $attribute ( keys %{$attributes} ) {
        if ( length( ref($attribute) ) ) {
            return {
                res => "ko",
                msg => "Invalid input: Attribute $attribute is not a string."
            };
        }
        unless ( grep { $_ eq $attribute } @allowedAttributes ) {
            return {
                res => "ko",
                msg => "Invalid input: Attribute $attribute does not exist."
            };
        }
    }

    return { res => "ok" };
}

sub _listAttributes {
    my ( $self, $rootNode ) = @_;
    my $mainTree   = Lemonldap::NG::Manager::Build::CTrees::cTrees();
    my $rootNodes  = [ grep { ref($_) eq "HASH" } @{ $mainTree->{$rootNode} } ];
    my @attributes = map { $self->_listNodeAttributes($_) } @$rootNodes;

    return @attributes;
}

sub _listNodeAttributes {
    my ( $self, $node ) = @_;
    my @attributes =
      map { ref($_) eq "HASH" ? $self->_listNodeAttributes($_) : $_ }
      @{ $node->{nodes} };

    return @attributes;
}

sub _translateOptionApiToConf {
    my ( $self, $optionName, $prefix ) = @_;

    # For consistency
    $optionName =~ s/^clientId$/clientID/;

    return $prefix . "MetaDataOptions" . ( ucfirst $optionName );
}

sub _translateOptionConfToApi {
    my ( $self, $optionName ) = @_;
    $optionName =~ s/^(\w+)MetaDataOptions//;

    $optionName = lcfirst $optionName;

    # iDToken looks ugly
    $optionName =~ s/^iDToken/IDToken/;

    # For consistency
    $optionName =~ s/^clientID/clientId/;
    return $optionName;
}

sub _translateValueConfToApi {
    my ( $self, $optionName, $optionValue ) = @_;

    if ( $self->_mustArrayizeOption($optionName))
    {
        return [ split( /\s+/, $optionValue, ) ];
    }
    else {
        return $optionValue;
    }
}

sub _translateValueApiToConf {
    my ( $self, $optionName, $optionValue ) = @_;

    if ( $self->_mustArrayizeOption($optionName) ) {
        die "$optionName is not an array\n"
          unless ( ref($optionValue) eq "ARRAY" );
        return join( ' ', @{$optionValue} );
    }

    # Translate JSON booleans to integers
    elsif ( JSON::is_bool($optionValue) ) {
        return $optionValue ? 1 : 0;
    }
    else {
        return $optionValue;
    }
}

sub _getRegexpFromPattern {
    my ( $self, $pattern ) = @_;
    return unless ( $pattern =~ /[\w\.\-\*]+/ );

    # . is allowed, and must be escaped
    $pattern =~ s/\./\\\./g;
    $pattern =~ s/\*/\.\*/g;

    # anchor string, unless * was provided
    $pattern = "^$pattern\$" if ( $pattern =~ /\*/ );

    return qr/$pattern/;
}

sub _getPersistentMod {
    my ($self) = @_;
    my $mod = $self->sessionTypes->{persistent};
    $mod->{options}->{backend} = $mod->{module};
    return $mod;
}

sub _getSSOMod {
    my ($self) = @_;
    my $mod = $self->sessionTypes->{global};
    $mod->{options}->{backend} = $mod->{module};
    return $mod;
}

sub _saveApplyConf {
    my ( $self, $conf ) = @_;
    $self->_confAcc->saveConf($conf);
    $self->applyConf($conf);
}

1;
