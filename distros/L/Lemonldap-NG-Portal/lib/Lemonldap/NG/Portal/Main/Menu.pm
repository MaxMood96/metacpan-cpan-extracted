##@file
# menu for lemonldap::ng portal
package Lemonldap::NG::Portal::Main::Menu;

use strict;
use Mouse;
use Clone 'clone';
use Lemonldap::NG::Portal::Main::Constants 'URIRE';

our $VERSION = '2.18.0';

extends 'Lemonldap::NG::Portal::Main::Plugin';

# PROPERTIES

has menuModules => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        my $conf = $_[0]->{conf};
        my (@res);
        my @modules = $_[0]->_get_display_order( $conf->{portalDisplayOrder} );
        foreach (@modules) {
            my $cond = $conf->{"portalDisplay$_"} // 1;
            $_[0]->p->logger->debug("Evaluate condition $cond for module $_");
            my $tmp =
              $_[0]
              ->p->HANDLER->buildSub( $_[0]->p->HANDLER->substitute($cond) );
            push @res, [ $_, $tmp ] if $tmp;
        }
        return \@res;
    }
);

has specific      => ( is => 'rw', default => sub { {} } );
has sfManagerRule => ( is => 'rw', default => sub { 1 } );
has imgPath => (
    is      => 'rw',
    lazy    => 1,
    builder => sub {
        return $_[0]->conf->{impgPath}
          || $_[0]->conf->{staticPrefix} . '/logos';
    }
);

# INITIALIZATION

sub init {
    my ($self) = @_;

    $self->sfManagerRule(
        $self->p->buildRule( $self->conf->{sfManagerRule}, 'sfManagerRule' ) );
    $self->sfManagerRule(1) unless $self->sfManagerRule;

    # Allow custom plugins to register new menu tabs
    $self->addEntryPoint(
        does    => "Lemonldap::NG::Portal::MenuTab",
        service => "menu",
        method  => "_register_tab",
    );

    return 1;
}

# RUNNING METHODS

# Prepare menu template elements
# Returns hash (=list) containing :
#  - DISPLAY_MODULES
#  - AUTH_ERROR
#  - AUTH_ERROR_TYPE
sub params {
    my ( $self, $req ) = @_;
    $self->conf->{imgPath} ||= $self->{staticPrefix};
    my %res;
    my @defaultTabs = (qw/appslist password logout loginHistory oidcConsents/);
    my @customTabs  = split /[,\s]+/, $self->conf->{customMenuTabs} || '';

    # Modules to display
    $res{DISPLAY_MODULES} = $self->displayModules($req);

    # Display noApp message
    $res{NO_APP_ALLOWED} = $req->data->{noApp};

    $res{AUTH_ERROR_TYPE} =
      $req->error_type( $res{AUTH_ERROR} = $req->menuError );
    $res{AUTH_ERROR_ROLE} = $req->error_role;
    $res{ 'AUTH_ERROR_' . $res{AUTH_ERROR} } = 1 if $res{AUTH_ERROR};

# Display menu 2fRegisters link only if at least a 2F device is registered and rule
    $res{sfaManager} =
         $self->p->_sfEngine->display2fRegisters( $req, $req->userData )
      && $self->sfManagerRule->( $req, $req->userData );
    $self->logger->debug('Display 2fRegisters link') if $res{sfaManager};

    # Display refresh my rights unless disabled
    $res{RefreshMyRights} = $self->conf->{portalDisplayRefreshMyRights};
    $self->logger->debug('Display RefreshMyRights link')
      if $res{RefreshMyRights};

    # Display menu links only if required
    foreach (qw(ContextSwitching DecryptValue Notifications)) {
        my $plugin =
          $self->p->loadedModules->{"Lemonldap::NG::Portal::Plugins::$_"};
        $res{$_} =
            $plugin
          ? $plugin->displayLink( $req, $req->userData )
          : '';
        my $msg = "Display $_ link";
        $msg .= " -> $res{ContextSwitching}"
          if ( $_ eq 'ContextSwitching' && $res{$_} );
        $self->logger->debug($msg) if $res{$_};
        undef $plugin;
    }

    # Decide whether to display the dropdown or regular text
    $res{DropdownMenu} = 0;
    foreach (
        qw(RefreshMyRights sfaManager Notifications DecryptValue ContextSwitching)
      )
    {
        if ( $res{$_} ) {
            $res{DropdownMenu} = 1;
            last;
        }
    }

    return %res;
}

## @method arrayref displayModules()
# List modules that can be displayed in Menu
# @return modules list
sub displayModules {
    my ( $self, $req ) = @_;
    my $displayModules = [];

    # Foreach module, eval condition
    # Store module in result if condition is valid
    foreach my $module ( @{ $self->menuModules } ) {
        $self->logger->debug("Check if $module->[0] has to be displayed");
        if ( $module->[1]->( $req, $req->userData ) ) {
            my $moduleHash = { $module->[0] => 1 };
            if ( $module->[0] eq 'Appslist' ) {
                $moduleHash->{'APPSLIST_LOOP'} = $self->appslist($req);
                $req->data->{noApp} = 1
                  unless scalar @{ $moduleHash->{'APPSLIST_LOOP'} };
            }
            elsif ( $module->[0] eq 'LoginHistory' ) {
                $moduleHash->{'SUCCESS_LOGIN'} =
                  $self->p->mkSessionArray( $req,
                    $req->{userData}->{_loginHistory}->{successLogin},
                    "", 0, 0 );
                $moduleHash->{'FAILED_LOGIN'} =
                  $self->p->mkSessionArray( $req,
                    $req->{userData}->{_loginHistory}->{failedLogin},
                    "", 0, 1 );
            }
            elsif ( $module->[0] eq 'OidcConsents' ) {
                $moduleHash->{'OIDC_CONSENTS'} =
                  $self->p->mkOidcConsent( $req, $req->userData );
            }
            elsif ( $module->[0] eq 'ChangePassword' ) {
                $moduleHash->{'PPOLICY_RULES'} = $self->p->getPpolicyRules;
            }

            # If the current entry is a plugin
            if ( $module->[2] ) {
                my $plugin_hash = $module->[2]->display($req);
                $moduleHash->{_PLUGIN}      = 1;
                $moduleHash->{_PLUGIN_LOGO} = $plugin_hash->{logo};
                $moduleHash->{_PLUGIN_NAME} = $plugin_hash->{name};
                $moduleHash->{_PLUGIN_ID}   = $plugin_hash->{name};
                $moduleHash->{_PLUGIN_HTML} = $plugin_hash->{html};
            }
            push @$displayModules, $moduleHash;
        }
    }

    return $displayModules;
}

## @method arrayref appslist()
# Returns categories and applications list as HTML::Template loop
# @return categories and applications list
sub appslist {
    my ( $self, $req ) = @_;
    my $appslist = [];

    return $appslist unless defined $self->conf->{applicationList};

    # Reset level
    my $catlevel = 0;

    my $applicationList = clone( $self->conf->{applicationList} );
    my $filteredList    = $self->_filter( $req, $applicationList );
    push @$appslist,
      $self->_buildCategoryHash( $req, "", $filteredList, $catlevel );

    # We must return an ARRAY ref
    return ( ref $appslist->[0]->{categories} eq "ARRAY" )
      ? $appslist->[0]->{categories}
      : [];
}

## @method private hashref _buildCategoryHash(string catname,hashref cathash, int catlevel)
# Build hash for a category
# @param catname Category name
# @param cathash Hash of category elements
# @param catlevel Category level
# @return Category Hash
sub _buildCategoryHash {
    my ( $self, $req, $catid, $cathash, $catlevel ) = @_;
    my $catname = $cathash->{catname} || $catid;
    my $applications;
    my $categories;

    # Extract applications from hash
    my $apphash;
    foreach my $catkey ( sort keys %$cathash ) {
        next if $catkey =~ /(type|options|catname|order)/;
        if ( $cathash->{$catkey}->{type} eq "application" ) {
            $apphash->{$catkey} = $cathash->{$catkey};
        }
    }

    # Display applications first
    if ( scalar keys %$apphash > 0 ) {
        foreach my $appkey (
            sort {
                ( $apphash->{$a}->{order} || 0 )
                  <=> ( $apphash->{$b}->{order} || 0 )
                  or $a cmp $b
            }
            keys %$apphash
          )
        {
            push @$applications,
              $self->_buildApplicationHash( $appkey, $apphash->{$appkey} );
        }
    }

    # Display subcategories
    foreach my $catkey (
        sort {
            ( $cathash->{$a}->{order} || 0 )
              <=> ( $cathash->{$b}->{order} || 0 )
              or $a cmp $b
        }
        grep { not /^(?:catname|type|options|order)$/ } keys %$cathash
      )
    {

        if ( $cathash->{$catkey}->{type} eq "category" ) {
            push @$categories,
              $self->_buildCategoryHash( $req, $catkey, $cathash->{$catkey},
                $catlevel + 1 );
        }
    }

    my $categoryHash = {
        category => 1,
        catname  => $catname,
        catid    => $catid,
        catlevel => $catlevel
    };
    $categoryHash->{applications} = $applications if $applications;
    $categoryHash->{categories}   = $categories   if $categories;
    return $categoryHash;
}

## @method private hashref _buildApplicationHash(string appid, hashref apphash)
# Build hash for an application
# @param $appid Application ID
# @param $apphash Hash of application elements
# @return Application Hash
sub _buildApplicationHash {
    my ( $self, $appid, $apphash ) = @_;
    my $applications;

    # Get application items
    my $appname      = $apphash->{options}->{name} || $appid;
    my $appuri       = $apphash->{options}->{uri}  || "";
    my $appdesc      = $apphash->{options}->{description};
    my $applogo      = $apphash->{options}->{logo};
    my $applogo_icon = ( $apphash->{options}->{logo} =~ /\./ ? 0 : 1 );
    my $apptip       = $apphash->{options}->{tooltip} || $appname;

    # Detect sub applications
    my $subapphash;
    foreach my $key ( sort keys %$apphash ) {
        next if $key =~ /(type|options|catname|order)/;
        if ( $apphash->{$key}->{type} eq "application" ) {
            $subapphash->{$key} = $apphash->{$key};
        }
    }

    # Display sub applications
    if ( scalar keys %$subapphash > 0 ) {
        foreach my $appkey (
            sort {
                ( $subapphash->{$a}->{order} || 0 )
                  <=> ( $subapphash->{$b}->{order} || 0 )
                  or $a cmp $b
            }
            keys %$subapphash
          )
        {
            push @$applications,
              $self->_buildApplicationHash( $appkey, $subapphash->{$appkey} );
        }
    }

    my $applicationHash = {
        application  => 1,
        appname      => $appname,
        appuri       => $appuri,
        appdesc      => $appdesc,
        applogo      => $applogo,
        applogo_icon => $applogo_icon,
        appid        => $appid,
        apptip       => $apptip,
    };
    $applicationHash->{applications} = $applications if $applications;
    return $applicationHash;
}

## @method private string _filter(hashref apphash)
# Duplicate hash reference
# Remove unauthorized menu elements
# Hide empty categories
# @param $apphash Menu elements
# @return filtered hash
sub _filter {
    my ( $self, $req, $apphash ) = @_;
    my $filteredHash;
    my $key;

    # Copy hash reference into a new hash
    foreach $key ( keys %$apphash ) {
        $filteredHash->{$key} = $apphash->{$key};
    }

    # Filter hash
    $self->_filterHash( $req, $filteredHash );

    # Hide empty categories
    $self->_isCategoryEmpty($filteredHash);

    return $filteredHash;
}

## @method private string _filterHash(hashref apphash)
# Remove unauthorized menu elements
# @param $apphash Menu elements
# @return filtered hash
sub _filterHash {
    my ( $self, $req, $apphash ) = @_;

    foreach my $key ( keys %$apphash ) {
        next if $key =~ /(type|options|catname|order)/;
        if (    $apphash->{$key}->{type}
            and $apphash->{$key}->{type} eq "category" )
        {

            # Filter the category
            $self->_filterHash( $req, $apphash->{$key} );
        }
        if (    $apphash->{$key}->{type}
            and $apphash->{$key}->{type} eq "application" )
        {

            # Find sub applications and filter them
            foreach my $appkey ( keys %{ $apphash->{$key} } ) {
                next if $appkey =~ /(type|options|catname|order)/;

                # We have sub elements, so we filter them
                $self->_filterHash( $req, $apphash->{$key} );
            }

            # Check rights
            my $appdisplay = $apphash->{$key}->{options}->{display}
              || "auto";
            $apphash->{$key}->{options}->{uri} =~ URIRE;
            my ( $vhost, $appuri ) = ( $3, $5 );
            $vhost = $self->p->HANDLER->resolveAlias($vhost);
            $appuri ||= '/';

            # Remove if display is "no" or "off"
            delete $apphash->{$key} and next if ( $appdisplay =~ /^(no|off)$/ );

            # Keep node if display is "yes" or "on"
            next if ( $appdisplay =~ /^(yes|on)$/ );

            my $cond = undef;

            # Handle partner rules (SAML, CAS or OIDC)
            if ( $appdisplay =~ /^sp:\s*(.*)$/ ) {
                my $p = $1;
                if ( my $sub = $self->p->spRules->{$p} ) {
                    eval {
                        delete $apphash->{$key}
                          unless ( $sub->( $req, $req->userData ) );
                    };
                    if ($@) {
                        $self->logger->error("Partner rule $p returns: $@");
                    }
                }
                next;
            }

            # If a specific rule exists, get it from cache or compile it
            if ( $appdisplay !~ /^auto$/i ) {
                if ( $self->specific->{$key} ) {
                    $cond = $self->specific->{$key};
                }
                else {
                    $cond = $self->specific->{$key} =
                      $self->p->HANDLER->buildSub(
                        $self->p->HANDLER->substitute($appdisplay) );
                }
            }

            # Check grant function if display is "auto" (this is the default)
            delete $apphash->{$key}
              unless (
                $self->p->HANDLER->grant(
                    $req, $req->userData, $appuri, $cond, $vhost
                )
              );
            next;
        }
    }

}

## @method private void _isCategoryEmpty(hashref apphash)
# Check if a category is empty
# @param $apphash Menu elements
# @return boolean
sub _isCategoryEmpty {
    my $self = shift;
    my ($apphash) = @_;
    my $key;

    # Test sub categories
    foreach $key ( keys %$apphash ) {
        next if $key =~ /(type|options|catname|order)/;
        if (    $apphash->{$key}->{type}
            and $apphash->{$key}->{type} eq "category" )
        {
            delete $apphash->{$key}
              if $self->_isCategoryEmpty( $apphash->{$key} );
        }
    }

    # Test this category
    if ( $apphash->{type} and $apphash->{type} eq "category" ) {

        # Temporary store 'options'
        my $tmp_options = $apphash->{options};
        my $tmp_catname = $apphash->{catname};
        my $tmp_order   = $apphash->{order};

        delete $apphash->{type};
        delete $apphash->{options};
        delete $apphash->{catname};
        delete $apphash->{order};

        if ( scalar( keys %$apphash ) ) {

            # There are sub categories or sub applications
            # Restore type and options
            $apphash->{type}    = "category";
            $apphash->{options} = $tmp_options;
            $apphash->{catname} = $tmp_catname;
            $apphash->{order}   = $tmp_order;

            # Return false
            return 0;
        }
        else {

            # Return true
            return 1;
        }
    }
    return 0;
}

sub _register_tab {
    my ( $self, $plugin ) = @_;

    my $rule_text = $plugin->rule // "1";
    my $name      = $plugin->name;

    if ( !$name ) {
        $self->logger->warn("Could not load custom menu tab: missing name");
        return;
    }

    my $compiled_rule =
      $self->p->buildRule( $rule_text, "Rule for $name custom tab" );
    if ( !$compiled_rule ) {
        return;
    }

    push @{ $self->menuModules }, [ $name, $compiled_rule, $plugin ];

    # Sort menuModules array
    @{ $self->menuModules } = $self->_sort_menu( $self->menuModules,
        $self->conf->{portalDisplayOrder} );
    return;
}

# This function does the sorting work and should be easy to test
sub _sort_menu {
    my ( $self, $menuToSort, $displayOrderString ) = @_;

    my @order = $self->_get_display_order($displayOrderString);
    my $orderhash;
    @$orderhash{@order} = 1 .. @order;

    # If the position of unknown plugins was not specified, put them at the end
    $orderhash->{_unknown} //= @order + 1;

    return sort { _sort_menu_helper( $orderhash, $a, $b ) } @$menuToSort;
}

# Sort helper based on portalDisplayOrder
# orderhash is a name => position hash
# You can use "_unknown" in portalDisplayOrder as a placeholder for plugins of unknown position
sub _sort_menu_helper {
    my ( $orderhash, $a, $b ) = @_;

    return ( $orderhash->{ $a->[0] } || $orderhash->{_unknown} || 0 )
      <=> ( $orderhash->{ $b->[0] } || $orderhash->{_unknown} || 0 );
}

sub _get_display_order {
    my ( $self, $displayOrderString ) = @_;
    my %hash;
    return grep { !$hash{$_}++ } split /[,\s]+/, $displayOrderString,;
}

1;
