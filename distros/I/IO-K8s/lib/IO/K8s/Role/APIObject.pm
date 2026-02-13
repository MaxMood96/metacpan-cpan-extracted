package IO::K8s::Role::APIObject;
# ABSTRACT: Role for top-level Kubernetes API objects
our $VERSION = '1.000';
use Moo::Role;
use Types::Standard qw( InstanceOf Maybe );


has metadata => (
    is => 'rw',
    isa => Maybe[InstanceOf['IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta']],
);


# Map IO::K8s short group names to full Kubernetes API group names
my %API_GROUP_MAP = (
    rbac                  => 'rbac.authorization.k8s.io',
    networking            => 'networking.k8s.io',
    storage               => 'storage.k8s.io',
    admissionregistration => 'admissionregistration.k8s.io',
    certificates          => 'certificates.k8s.io',
    coordination          => 'coordination.k8s.io',
    events                => 'events.k8s.io',
    scheduling            => 'scheduling.k8s.io',
    authentication        => 'authentication.k8s.io',
    authorization         => 'authorization.k8s.io',
    node                  => 'node.k8s.io',
    discovery             => 'discovery.k8s.io',
    flowcontrol           => 'flowcontrol.apiserver.k8s.io',
);

# Derive apiVersion from class name
# IO::K8s::Api::Core::V1::Pod -> v1
# IO::K8s::Api::Apps::V1::Deployment -> apps/v1
# IO::K8s::Api::Rbac::V1::Role -> rbac.authorization.k8s.io/v1
sub api_version {
    my ($self) = @_;
    my $class = ref($self) || $self;

    if ($class =~ /^IO::K8s::Api::(\w+)::(\w+)::/) {
        my ($group, $version) = ($1, $2);
        $version = lc($version);
        return $version if $group eq 'Core';
        my $group_lc = lc($group);
        return ($API_GROUP_MAP{$group_lc} // $group_lc) . '/' . $version;
    }
    return undef;
}


sub kind {
    my ($self) = @_;
    my $class = ref($self) || $self;

    if ($class =~ /::(\w+)$/) {
        return $1;
    }
    return undef;
}


sub resource_plural { undef }


sub _is_resource { 1 }

sub to_yaml {
    my ($self) = @_;
    require YAML::PP;
    my $yp = YAML::PP->new(schema => [qw/JSON/], boolean => 'JSON::PP');
    return $yp->dump_string($self->TO_JSON);
}


sub save {
    my ($self, $file) = @_;
    open my $fh, '>', $file or die "Cannot write to $file: $!";
    print $fh $self->to_yaml;
    close $fh;
    return $self;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::K8s::Role::APIObject - Role for top-level Kubernetes API objects

=head1 VERSION

version 1.000

=head1 DESCRIPTION

This role is automatically applied when using C<IO::K8s::APIObject>.
It provides the C<metadata> attribute and auto-derives C<apiVersion> and C<kind>
from the class name.

Note: The metadata attribute is registered in IO::K8s::APIObject's import
to ensure proper class registration for inflation.

=head2 metadata

Standard object's metadata. See L<IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta>.

=head2 api_version

Returns the Kubernetes API version derived from the class name.

    $pod->api_version;  # "v1"
    $deployment->api_version;  # "apps/v1"

=head2 kind

Returns the Kubernetes kind derived from the class name.

    $pod->kind;  # "Pod"
    $deployment->kind;  # "Deployment"

=head2 resource_plural

Returns the plural resource name for URL building, or C<undef> to use
automatic pluralization. Override this in CRD classes where the plural
name is not simply the lowercased kind with an "s" appended:

    sub resource_plural { 'staticwebsites' }

=head2 to_yaml

    my $yaml = $pod->to_yaml;

Serialize the object to YAML format suitable for C<kubectl apply -f>.

=head2 save

    $pod->save('pod.yaml');

Save the object to a YAML file. Returns the object for chaining.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/pplu/io-k8s-p5/issues>.

=head2 IRC

Join C<#kubernetes> on C<irc.perl.org> or message Getty directly.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHORS

=over 4

=item *

Torsten Raudssus <torsten@raudssus.de>

=item *

Jose Luis Martinez <jlmartinez@capside.com> (original author, inactive)

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by CAPSiDE.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
