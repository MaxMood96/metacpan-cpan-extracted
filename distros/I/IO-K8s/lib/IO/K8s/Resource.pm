package IO::K8s::Resource;
# ABSTRACT: Base class for all Kubernetes resources
our $VERSION = '1.002';
use v5.10;
use Moo;
use Import::Into;
use Package::Stash;
use Types::Standard qw( ArrayRef Bool HashRef InstanceOf Int Maybe Str );
use JSON::MaybeXS ();
use Scalar::Util qw(blessed);

# Registry: class -> attr -> { type, class, is_array, is_hash, is_bool, is_int }
# Use 'our' to make it a proper package variable accessible via symbol table
our %_attr_registry;

# Class name expansion map
my %_class_prefix = (
    'Core'           => 'IO::K8s::Api::Core',
    'Apps'           => 'IO::K8s::Api::Apps',
    'Batch'          => 'IO::K8s::Api::Batch',
    'Networking'     => 'IO::K8s::Api::Networking',
    'Rbac'           => 'IO::K8s::Api::Rbac',
    'Storage'        => 'IO::K8s::Api::Storage',
    'Policy'         => 'IO::K8s::Api::Policy',
    'Autoscaling'    => 'IO::K8s::Api::Autoscaling',
    'Admissionregistration' => 'IO::K8s::Api::Admissionregistration',
    'Coordination'   => 'IO::K8s::Api::Coordination',
    'Discovery'      => 'IO::K8s::Api::Discovery',
    'Events'         => 'IO::K8s::Api::Events',
    'Flowcontrol'    => 'IO::K8s::Api::Flowcontrol',
    'Node'           => 'IO::K8s::Api::Node',
    'Scheduling'     => 'IO::K8s::Api::Scheduling',
    'Certificates'   => 'IO::K8s::Api::Certificates',
    'Authentication' => 'IO::K8s::Api::Authentication',
    'Authorization'  => 'IO::K8s::Api::Authorization',
    'Resource'       => 'IO::K8s::Api::Resource',
    'Storagemigration' => 'IO::K8s::Api::Storagemigration',
    'Meta'           => 'IO::K8s::Apimachinery::Pkg::Apis::Meta',
    'Apiextensions'  => 'IO::K8s::ApiextensionsApiserver::Pkg::Apis::Apiextensions',
    'KubeAggregator' => 'IO::K8s::KubeAggregator::Pkg::Apis::Apiregistration',
);

# JSON encoder for serialization
has json => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_json',
);

sub _build_json {
    return JSON::MaybeXS->new(utf8 => 1, canonical => 1);
}

sub import {
    my $class = shift;
    my $caller = caller;

    # Install Moo into caller (using mst's Import::Into)
    Moo->import::into($caller);

    # Import Types::Standard into caller so they can use Str, Int, Bool directly
    Types::Standard->import::into($caller, qw( Str Int Bool ));

    # Set up inheritance via Moo's extends
    $caller->can('extends')->(__PACKAGE__);

    # Export k8s function via Package::Stash
    my $stash = Package::Stash->new($caller);
    my $captured_caller = $caller;  # Capture in own lexical
    $stash->add_symbol('&k8s', sub { IO::K8s::Resource::_k8s($captured_caller, @_) });
}


sub _expand_class {
    my ($short) = @_;

    # +FullClassName - strip + and use as-is
    return substr($short, 1) if $short =~ /^\+/;

    # Already fully qualified?
    return $short if $short =~ /^IO::K8s::/;

    # Check for prefix match (e.g., Core::V1::Pod)
    if ($short =~ /^([A-Z][a-z]+)::/) {
        my $prefix = $1;
        if (my $expansion = $_class_prefix{$prefix}) {
            $short =~ s/^$prefix/$expansion/;
            return $short;
        }
    }

    # Default: assume it's under IO::K8s::Api
    return "IO::K8s::Api::$short";
}

sub _is_type_tiny {
    my ($obj) = @_;
    return blessed($obj) && $obj->isa('Type::Tiny');
}

sub _k8s {
    my ($caller, $name, $type_spec, $required_marker) = @_;

    # Ensure the registry entry exists
    $_attr_registry{$caller} = {} unless exists $_attr_registry{$caller};

    my %info;
    my $isa;
    my $required = $required_marker && $required_marker eq 'required' ? 1 : 0;

    # Check for ! suffix on strings (legacy/alternative required syntax)
    if (!ref $type_spec && !_is_type_tiny($type_spec) && $type_spec =~ s/!$//) {
        $required = 1;
    } elsif (ref $type_spec eq 'ARRAY' && !_is_type_tiny($type_spec->[0]) && $type_spec->[0] =~ s/!$//) {
        $required = 1;
    }

    # Handle Type::Tiny objects directly (Str, Int, Bool)
    if (_is_type_tiny($type_spec)) {
        my $type_name = $type_spec->name;
        if ($type_name eq 'Str') {
            $info{is_str} = 1;
        } elsif ($type_name eq 'Int') {
            $info{is_int} = 1;
        } elsif ($type_name eq 'Bool') {
            $info{is_bool} = 1;
        }
        $isa = $required ? $type_spec : Maybe[$type_spec];
    } elsif (!ref $type_spec) {
        if ($type_spec eq 'Str') {
            $info{is_str} = 1;
            $isa = $required ? Str : Maybe[Str];
        } elsif ($type_spec eq 'Int') {
            $info{is_int} = 1;
            $isa = $required ? Int : Maybe[Int];
        } elsif ($type_spec eq 'Bool') {
            $info{is_bool} = 1;
            $isa = $required ? Bool : Maybe[Bool];
        } else {
            my $full_class = _expand_class($type_spec);
            $info{is_object} = 1;
            $info{class} = $full_class;
            $isa = $required ? InstanceOf[$full_class] : Maybe[InstanceOf[$full_class]];
        }
    } elsif (ref $type_spec eq 'ARRAY') {
        my $inner = $type_spec->[0];
        # Handle [Str] with Type::Tiny object
        if (_is_type_tiny($inner)) {
            my $type_name = $inner->name;
            if ($type_name eq 'Str') {
                $info{is_array_of_str} = 1;
            } elsif ($type_name eq 'Int') {
                $info{is_array_of_int} = 1;
            }
            $isa = $required ? ArrayRef[$inner] : Maybe[ArrayRef[$inner]];
        } elsif ($inner eq 'Str') {
            $info{is_array_of_str} = 1;
            $isa = $required ? ArrayRef[Str] : Maybe[ArrayRef[Str]];
        } elsif ($inner eq 'Int') {
            $info{is_array_of_int} = 1;
            $isa = $required ? ArrayRef[Int] : Maybe[ArrayRef[Int]];
        } else {
            my $full_class = _expand_class($inner);
            $info{is_array_of_objects} = 1;
            $info{class} = $full_class;
            $isa = $required ? ArrayRef[InstanceOf[$full_class]] : Maybe[ArrayRef[InstanceOf[$full_class]]];
        }
    } elsif (ref $type_spec eq 'HASH') {
        my ($inner) = keys %$type_spec;
        if ($inner eq 'Str') {
            $info{is_hash_of_str} = 1;
            # Use plain HashRef without inner constraint - K8s has nested hashes
            # in fields like fieldsV1, annotations, labels which can have any structure
            $isa = $required ? HashRef : Maybe[HashRef];
        } else {
            my $full_class = _expand_class($inner);
            $info{is_hash_of_objects} = 1;
            $info{class} = $full_class;
            $isa = $required ? HashRef[InstanceOf[$full_class]] : Maybe[HashRef[InstanceOf[$full_class]]];
        }
    }


    # Register - use hash slice to copy values, not reference
    $_attr_registry{$caller}{$name} = { %info };
    no strict 'refs';
    push @{"${caller}::_k8s_attributes"}, $name;

    # Only create the attribute if it doesn't already exist (e.g., from a role)
    return if $caller->can($name);

    # Call Moo's has
    my $has = $caller->can('has');
    $has->($name, is => 'rw', isa => $isa, ($required ? (required => 1) : ()));
}

# Get attribute info
sub _k8s_attr_info {
    my ($class) = @_;
    $class = ref($class) if ref($class);
    return $_attr_registry{$class} // {};
}

# Get attribute list
sub _k8s_attributes {
    my ($self) = @_;
    my $class = ref($self) || $self;
    no strict 'refs';
    return \@{"${class}::_k8s_attributes"};
}

sub TO_JSON {
    my $self = shift;
    my %data;
    my $attrs = $self->_k8s_attributes;
    my $info = _k8s_attr_info($self);

    # Add apiVersion, kind, and metadata for APIObjects (those with the role)
    if ($self->can('_is_resource') && $self->_is_resource) {
        $data{apiVersion} = $self->api_version if $self->api_version;
        $data{kind} = $self->kind if $self->kind;
        # metadata comes from the Role, not from k8s DSL
        if ($self->can('metadata') && $self->metadata) {
            $data{metadata} = $self->metadata->TO_JSON;
        }
    }

    for my $attr (@$attrs) {
        my $value = $self->$attr;
        next unless defined $value;

        my $attr_info = $info->{$attr} // {};

        if ($attr_info->{is_bool}) {
            $data{$attr} = $value ? JSON::MaybeXS::true : JSON::MaybeXS::false;
        } elsif ($attr_info->{is_int}) {
            $data{$attr} = int($value);
        } elsif ($attr_info->{is_object} && blessed($value) && $value->can('TO_JSON')) {
            $data{$attr} = $value->TO_JSON;
        } elsif ($attr_info->{is_array_of_objects}) {
            $data{$attr} = [ map { $_->TO_JSON } @$value ];
        } elsif ($attr_info->{is_hash_of_objects}) {
            $data{$attr} = { map { $_ => $value->{$_}->TO_JSON } keys %$value };
        } elsif (ref $value eq 'ARRAY') {
            $data{$attr} = $value;
        } elsif (ref $value eq 'HASH') {
            $data{$attr} = $value;
        } else {
            $data{$attr} = $value;
        }
    }
    return \%data;
}

sub to_json {
    my $self = shift;
    return $self->json->encode($self->TO_JSON);
}

sub TO_YAML {
    my $self = shift;
    require YAML::PP;
    return YAML::PP::Dump($self->TO_JSON);
}

sub to_yaml {
    my $self = shift;
    return $self->TO_YAML;
}

sub FROM_HASH {
    my ($class, $hash) = @_;
    return $class->new(%$hash);
}

sub from_json {
    my ($class, $json_str) = @_;
    state $json = JSON::MaybeXS->new;
    return $class->FROM_HASH($json->decode($json_str));
}

# Compare local class attributes against OpenAPI schema
# Returns hashref with differences:
#   missing_locally  => [ attrs in schema but not in class ]
#   missing_in_schema => [ attrs in class but not in schema ]
#   type_mismatch    => [ { attr => $name, local => $type, schema => $type } ]
sub compare_to_schema {
    my ($class, $schema) = @_;
    $class = ref($class) if ref($class);

    my $local_attrs = $_attr_registry{$class} // {};
    my $schema_props = $schema->{properties} // {};

    my %result = (
        missing_locally   => [],
        missing_in_schema => [],
        type_mismatch     => [],
    );

    # Check schema properties against local attributes
    for my $prop (keys %$schema_props) {
        if (!exists $local_attrs->{$prop}) {
            # Special case: metadata comes from Role, not k8s DSL
            next if $prop eq 'metadata' && $class->can('metadata');
            # apiVersion and kind also come from Role
            next if ($prop eq 'apiVersion' || $prop eq 'kind') && $class->can('_is_resource');
            push @{$result{missing_locally}}, $prop;
        } else {
            # Compare types
            my $local_type = _describe_local_type($local_attrs->{$prop});
            my $schema_type = _describe_schema_type($schema_props->{$prop});
            if ($local_type ne $schema_type) {
                push @{$result{type_mismatch}}, {
                    attr   => $prop,
                    local  => $local_type,
                    schema => $schema_type,
                };
            }
        }
    }

    # Check local attributes not in schema
    for my $attr (keys %$local_attrs) {
        if (!exists $schema_props->{$attr}) {
            push @{$result{missing_in_schema}}, $attr;
        }
    }

    return \%result;
}

sub _describe_local_type {
    my ($info) = @_;
    return 'string'  if $info->{is_str};
    return 'integer' if $info->{is_int};
    return 'boolean' if $info->{is_bool};
    return 'array<string>'  if $info->{is_array_of_str};
    return 'array<integer>' if $info->{is_array_of_int};
    return 'array<object>'  if $info->{is_array_of_objects};
    return 'hash<string>'   if $info->{is_hash_of_str};
    return 'hash<object>'   if $info->{is_hash_of_objects};
    return 'object'         if $info->{is_object};
    return 'unknown';
}

sub _describe_schema_type {
    my ($prop) = @_;
    return 'object' if $prop->{'$ref'};
    my $type = $prop->{type} // 'unknown';
    if ($type eq 'array') {
        my $items = $prop->{items} // {};
        if ($items->{'$ref'}) {
            return 'array<object>';
        }
        my $item_type = $items->{type} // 'unknown';
        return "array<$item_type>";
    }
    if ($type eq 'object' && $prop->{additionalProperties}) {
        my $add = $prop->{additionalProperties};
        if ($add->{'$ref'}) {
            return 'hash<object>';
        }
        my $val_type = $add->{type} // 'unknown';
        return "hash<$val_type>";
    }
    return $type;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::K8s::Resource - Base class for all Kubernetes resources

=head1 VERSION

version 1.002

=head1 SYNOPSIS

    package IO::K8s::Api::Core::V1::Pod;
    use IO::K8s::Resource;

    k8s apiVersion => 'Str';
    k8s kind => 'Str';
    k8s metadata => 'Meta::V1::ObjectMeta';
    k8s spec => 'Core::V1::PodSpec';

    1;

=head1 DESCRIPTION

Base class that sets up Moo, inheritance, and provides the C<k8s> DSL.
Just C<use IO::K8s::Resource;> - no need for C<use Moo> or C<extends>.

=head1 NAME

IO::K8s::Resource - Base class for Kubernetes resources

=head1 EXPORTED FUNCTIONS

=head2 k8s

    k8s name => 'Str';
    k8s replicas => 'Int';
    k8s suspend => 'Bool';
    k8s spec => 'Core::V1::PodSpec';           # Short class name
    k8s containers => ['Core::V1::Container']; # Array of objects
    k8s labels => { Str => 1 };                # Hash of strings

Short class names are auto-expanded:

    Core::V1::Pod      -> IO::K8s::Api::Core::V1::Pod
    Meta::V1::ObjectMeta -> IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta

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

Jose Luis Martinez <jlmartin@cpan.org> (original author, inactive)

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by Jose Luis Martinez.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
