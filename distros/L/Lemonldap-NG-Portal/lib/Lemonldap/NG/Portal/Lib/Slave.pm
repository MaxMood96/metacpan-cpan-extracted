##@file
# Slave common functions

##@class
# Slave common functions
package Lemonldap::NG::Portal::Lib::Slave;

use strict;
use Mouse;
use Net::CIDR;

our $VERSION = '2.20.0';

# RUNNING METHODS

## @method Lemonldap::NG::Portal::_Slave checkIP()
# @return true if remote IP is accredited in LL::NG conf
sub checkIP {
    my ( $self, $req ) = @_;
    my ( @networks, @IPs );
    my $remoteIP = $req->address;

    return 1
      if !$self->conf->{slaveMasterIP};

    @IPs = grep {
        if ( m#/# && Net::CIDR::cidrvalidate($_) ) {
            push @networks, $_;
            $self->logger->debug("Found netblock: $_");
            0;
        }
        elsif ( Net::CIDR::cidrvalidate($_) ) {
            $self->logger->debug("Found IP address: $_");
            1;
        }
        else {
            $self->logger->warn("Found a non valid IP: $_");
            0;
        }
    } split /[,\s]/, $self->conf->{slaveMasterIP};

    foreach (@IPs) {
        return 1
          if $remoteIP eq $_;
    }
    return 1 if Net::CIDR::cidrlookup( $remoteIP, @networks );

    $self->userLogger->warn('Client IP not accredited for Slave module');
    return 0;
}

## @method Lemonldap::NG::Portal::_Slave checkHeader()
# @return true if header content matches LL::NG conf
sub checkHeader {
    my ( $self, $req ) = @_;
    return 1
      unless ( $self->conf->{slaveHeaderName}
        && $self->conf->{slaveHeaderContent} );

    my $slave_header = 'HTTP_' . uc( $self->conf->{slaveHeaderName} );
    $slave_header =~ s/\-/_/g;
    my $headerContent = $req->env->{$slave_header};

    $self->logger->debug(
            "Required slave header: $self->{conf}->{slaveHeaderName}"
          . "\nReceived slave header content: $headerContent" );

    return 1
      if (  $headerContent
        && $self->conf->{slaveHeaderContent} =~ /\b$headerContent\b/ );

    $self->userLogger->warn('Matching header not found for Slave module ');
    return 0;
}

1;
