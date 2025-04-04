package Net::RDAP::Values;
use Carp;
use File::Basename qw(basename);
use File::Spec;
use Net::RDAP::UA;
use XML::LibXML;
use vars qw($UA $REGISTRY @EXPORT);
use constant {
    IANA_REGISTRY_URL                   => 'https://www.iana.org/assignments/rdap-json-values/rdap-json-values.xml',

    RDAP_TYPE_NOTICE_OR_REMARK_TYPE     => 'notice and remark type',        #
    RDAP_TYPE_STATUS                    => 'status',                        # these values are defined in
    RDAP_TYPE_ROLE                      => 'role',                          # RFC 7483, section 10.2.
    RDAP_TYPE_EVENT_ACTION              => 'event action',                  #
    RDAP_TYPE_DOMAIN_VARIANT_RELATION   => 'domain variant relation',       #

    RDAP_REDACTED_EXPRESSION_LANGUAGE   => 'redacted expression language',  # these values are defined in
    RDAP_REDACTED_NAME                  => 'redacted name',                 # RFC 9537

    CACHE_TTL                           => 86400,                       # this registry is fairly stable
};
use base qw(Exporter);
use strict;
use warnings;

#
# export these symbols
#
our @EXPORT = qw(
    RDAP_TYPE_NOTICE_OR_REMARK_TYPE
    RDAP_TYPE_STATUS
    RDAP_TYPE_ROLE
    RDAP_TYPE_EVENT_ACTION
    RDAP_TYPE_DOMAIN_VARIANT_RELATION
    RDAP_REDACTED_EXPRESSION_LANGUAGE
    RDAP_REDACTED_NAME
);

our ($UA, $REGISTRY);

=pod

=head1 NAME

L<Net::RDAP::Values> - a module which provides interface to the RDAP values
registry.

=head1 DESCRIPTION

The RDAP JSON Values Registry was defined in RFC 7483 and lists the
permitted values of certain RDAP object properties. This class implements
an interface to that registry.

Ironically, since the registry is only available in CSV and XML formats,
this module has to use L<XML::LibXML> in order to access the registry data
that it retrieves from the IANA web server.

=head1 METHODS

=head2 check()

    Net::RDAP::Values->check($value, $type);

    Net::RDAP::Values->check('add period', RDAP_TYPE_STATUS);

    Net::RDAP::Values->check('registration', RDAP_TYPE_EVENT_ACTION);

The C<check()> function allows you to determine if a given value is present
in the registry. You must also specify the type of the value using one of
the C<RDAP_TYPE_*> constants.

If the value is registered in the registry, this method returns a true
value, otherwise it returns C<undef>.

=cut

sub check {
    my ($self, $value, $type) = @_;

    foreach my $registered ($self->values($type)) {
        return 1 if ($registered eq $value);
    }

    return undef;
}

=pod

=head2 values()

    @values = Net::RDAP::Values->values($type);

    @values = Net::RDAP::Values->values(RDAP_TYPE_ROLE);

The C<values()> function returns a list of the permitted values for the
given value type. If you specify an invalid type, an exception is raised.

=cut

sub values {
    my ($self, $type) = @_;

    $REGISTRY = load_registry() unless ($REGISTRY);

    if (!defined($REGISTRY->{'values_by_type'}->{$type})) {
        croak(sprintf("'%s' is not a permitted value type", $type));

    } else {
        return sort @{$REGISTRY->{'values_by_type'}->{$type}};

    }
}

=pod

=head2 types()

    @types = Net::RDAP::Values->types;

The C<types()> function returns a list of all possible RDAP value types.

=cut

sub types {
    return (
        RDAP_TYPE_NOTICE_OR_REMARK_TYPE,
        RDAP_TYPE_STATUS,
        RDAP_TYPE_ROLE,
        RDAP_TYPE_EVENT_ACTION,
        RDAP_TYPE_DOMAIN_VARIANT_RELATION,
        RDAP_REDACTED_EXPRESSION_LANGUAGE,
        RDAP_REDACTED_NAME,
    );
}

=pod

=head2 description()

    $description = Net::RDAP::Values->description($value, $type);

    $description = Net::RDAP::Values->description('registration', RDAP_TYPE_EVENT_ACTION);

    use Net::RDAP::EPPStatusMap;
    $description = Net::RDAP::Values->description(epp2rdap('serverHold'), RDAP_TYPE_STATUS);

The C<description()> function returns a textual description (in English) of the value
in the registry, suitable for display to the user.

=cut

sub description {
    my ($self, $value, $type) = @_;

    $REGISTRY = load_registry() unless ($REGISTRY);

    return $REGISTRY->{'descriptions'}->{$type}->{$value};
}

sub load_registry {
    my $package = shift;

    my $file = sprintf('%s/%s-%s', File::Spec->tmpdir, $package, basename(IANA_REGISTRY_URL));

    #
    # $UA may have been injected by Net::RDAP->ua()
    #
    $UA = Net::RDAP::UA->new unless(defined($UA));

    $UA->mirror(IANA_REGISTRY_URL, $file, CACHE_TTL);

    return undef unless (-e $file);

    my $doc = XML::LibXML->load_xml('location' => $file, 'no_blanks' => 1);

    my $registry = {};

    foreach my $record ($doc->getElementsByTagName('record')) {
        my $value       = $record->getElementsByTagName('value')->shift->textContent;
        my $type        = $record->getElementsByTagName('type')->shift->textContent;
        my $description = $record->getElementsByTagName('description')->shift->textContent;

        push(@{$registry->{'value_types'}->{$value}}, $type);
        push(@{$registry->{'values_by_type'}->{$type}}, $value);
        $registry->{'descriptions'}->{$type}->{$value} = $description;
    }

    return $registry;
}

1;

__END__

=pod

=head1 EXPORTED CONSTANTS

L<Net::RDAP::Values> exports the following constants, which correspond
to the permitted types of RDAP values:

=over

=item * C<RDAP_TYPE_NOTICE_OR_REMARK_TYPE>

=item * C<RDAP_TYPE_STATUS>

=item * C<RDAP_TYPE_ROLE>

=item * C<RDAP_TYPE_EVENT_ACTION>

=item * C<RDAP_TYPE_DOMAIN_VARIANT_RELATION>

=item * C<RDAP_REDACTED_NAME>

=back

=head1 COPYRIGHT

Copyright 2018-2023 CentralNic Ltd, 2024-2025 Gavin Brown. For licensing information,
please see the C<LICENSE> file in the L<Net::RDAP> distribution.

=cut
