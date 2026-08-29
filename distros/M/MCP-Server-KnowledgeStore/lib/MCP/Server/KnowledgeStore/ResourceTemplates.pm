package MCP::Server::KnowledgeStore::ResourceTemplates;
our $VERSION = '0.001';
use v5.38;
use Mojo::Base 'MCP::Server', -signatures;

# ABSTRACT: MCP server support for resource templates and tool-call logging

use Carp         qw(croak);
use List::Util   qw(first);
use Mojo::JSON   qw(to_json);
use Scalar::Util qw(blessed);
use constant {
  INTERNAL_ERROR => -32603,
  NOT_FOUND      => -32001,
  INVALID_PARAMS => -32602,
};

sub handle ($self, $request, $context) {
  return $self->SUPER::handle($request, $context)
    unless ref $request eq 'HASH'
    && ($request->{method} // '') eq 'tools/call';

  my $params = ref $request->{params} eq 'HASH' ? $request->{params} : {};
  my $name   = $params->{name} // '';
  my $args   = ref $params->{arguments} eq 'HASH' ? $params->{arguments} : {};
  my $principal = _log_label($context->principal // 'anonymous');
  my $tool_name = _log_label($name);

  $self->log->trace(
    "[$principal] tools/call request [" . to_json($request) . ']');

  unless (first { $_->name eq $name } @{ $self->_tools($context) }) {
    $self->log->warn("[$principal] called unknown tool [$tool_name]");
    return $self->SUPER::handle($request, $context);
  }

  $self->log->info("[$principal] called [$tool_name]");
  $self->log->debug(
    "[$principal] called [$tool_name] with [" . to_json($args) . ']');

  my $response = $self->SUPER::handle($request, $context);
  if (blessed($response) && $response->isa('Mojo::Promise')) {
    return $response->then(
      sub ($reply) {
        $self->_log_tool_reply($principal, $tool_name, $reply);
        return $reply;
      }
    );
  }

  $self->_log_tool_reply($principal, $tool_name, $response);
  return $response;
}

sub _log_label ($value) {
  $value =~ s/([\[\]\\\r\n])/sprintf '\\x{%02x}', ord $1/ge;
  return $value;
}

sub _log_tool_reply ($self, $principal, $name, $reply) {
  my $failed = ref $reply eq 'HASH'
    && (exists $reply->{error}
    || ref $reply->{result} eq 'HASH' && $reply->{result}{isError});
  my $debug = $self->log->is_level('debug');
  my $error = $failed && $self->log->is_level('error');
  return unless $debug || $error;

  my $json = to_json($reply);
  $self->log->trace("[$principal] tools/call reply [$json]");
  $self->log->debug("[$principal] call [$name] reply [$json]");
  $self->log->error("[$principal] call [$name] failed [$json]") if $error;
  return;
}

sub log_transport_rejection ($self, $principal, $request, $reply) {
  $principal = _log_label($principal // 'anonymous');
  $request   = {} unless ref $request eq 'HASH';
  $reply     = {} unless ref $reply eq 'HASH';

  my $params = ref $request->{params} eq 'HASH' ? $request->{params} : {};
  my $name   = _log_label($params->{name} // $request->{method} // 'unknown');
  my $args   = ref $params->{arguments} eq 'HASH' ? $params->{arguments} : {};
  my $reason
    = ref $reply->{error} eq 'HASH'
    ? $reply->{error}{message} // 'unknown transport error'
    : 'HTTP transport rejected the request';
  $reason = _log_label($reason);

  $self->log->warn("[$principal] MCP call [$name] rejected [$reason]");
  $self->log->debug("[$principal] MCP call [$name] with ["
      . to_json($args)
      . '] reply ['
      . to_json($reply)
      . ']');
  $self->log->trace("[$principal] rejected MCP request ["
      . to_json($request)
      . '] reply ['
      . to_json($reply)
      . ']');
  return;
}

# Resource templates that this server supports
# Each template has:
#   - uri_template: URI with {param} placeholders
#   - description: Human-readable description
#   - mime_type: MIME type for responses
#   - code: Callback to generate the resource content
#   - name: Template name

sub add_template ($self, %args) {
  my $template = {
    uri_template => $args{uri_template} // croak('uri_template is required'),
    name         => $args{name}         // croak('name is required'),
    description  => $args{description}  // 'Resource template',
    mime_type    => $args{mime_type}    // 'text/plain',
    code         => $args{code}         // croak('code is required'),
  };
  push @{ $self->{_resource_templates} //= [] }, $template;
  return $template;
}

# Parse a URI template and extract parameters
# Returns: hashref of {param_name => value, ...} or undef if no match
sub _parse_template ($self, $uri_template, $uri) {

  # Convert template to regex pattern
  # First, escape all regex special characters in literal parts
  my $pattern = '';
  my $pos     = 0;
  my @param_names;

  while ($uri_template =~ /\{([a-zA-Z_][a-zA-Z0-9_]*)\}/g) {
    my $before
      = substr($uri_template, $pos, pos($uri_template) - $pos - length($&));
    my $param = $1;

    # Escape the literal text before the parameter
    $before =~ s/([\.\+\*\?\|\(\)\[\]\{\}])/\\$1/g;
    $pattern .= $before . '([^\/?#]+)';

    push @param_names, $param;
    $pos = pos($uri_template);
  }

  # Add the remaining literal text after the last parameter
  my $after = substr($uri_template, $pos);
  $after =~ s/([\.\+\*\?\|\(\)\[\]\{\}])/\\$1/g;
  $pattern .= $after;

  $pattern = "\\A$pattern\\z";

  if ($uri =~ /$pattern/) {
    my %params;

    # Values are in $1, $2, etc. - extract them from the match
    my @values = ($1, $2, $3, $4, $5, $6);
    @params{@param_names} = @values;
    return \%params;
  }
  return undef;
}

# Find matching template for a given URI
# Returns: ($template, $params_hashref) or (undef, undef) if no match
sub _match_template ($self, $uri) {
  my @templates = @{ $self->{_resource_templates} // [] };
  for my $template (@templates) {
    if (my $params = $self->_parse_template($template->{uri_template}, $uri)) {
      return ($template, $params);
    }
  }
  return (undef, undef);
}

# Override _resources to include template-based resources
sub _resources ($self, $context) {
  my @resources = $self->SUPER::_resources($context);

  # Add resource template descriptions
  my @templates = @{ $self->{_resource_templates} // [] };
  for my $template (@templates) {

    # We use the template as-is for listing
    # The actual URI will have placeholders
    push @resources, {
      uri         => $template->{uri_template},
      name        => $template->{name},
      description => $template->{description},
      mimeType    => $template->{mime_type},

      # Mark as template
      _is_template => 1,
    };
  }

  return @resources;
}

# Override _handle_resources_read to support templates
sub _handle_resources_read ($self, $params, $id, $context) {
  my $uri = $params->{uri} // '';

  # First check regular resources
  if (my $resource
    = first { $_->uri eq $uri } @{ $self->_resources($context) })
  {
    return $self->SUPER::_handle_resources_read($params, $id, $context);
  }

  # Then check resource templates
  if (my ($template, $params) = $self->_match_template($uri)) {

    # Check scope - templates don't have scopes in this simple implementation
    # If the template had scopes, we'd check them here

    # Call the template code with the extracted parameters
    my $result;
    eval { $result = $template->{code}->($template, $params, $context); };

    if ($@) {
      my $err
        = $self->_jsonrpc_error(INVALID_PARAMS, "Resource template error: $@",
        $id);
      $context->status(400) if $context->can('status');
      return $err;
    }

    if (!defined $result) {
      my $err
        = $self->_jsonrpc_error(NOT_FOUND, "Resource not found: $uri", $id);
      $context->status(404) if $context->can('status');
      return $err;
    }

    # Handle the result
    if (ref $result eq 'HASH' && exists $result->{contents}) {
      return $result;
    }

    # Wrap scalar text in text_resource format
    return { contents =>
        [{ uri => $uri, mimeType => $template->{mime_type}, text => $result }]
    };
  }

  # No match found
  my $err
    = $self->_jsonrpc_error(INVALID_PARAMS, "Resource '$uri' not found", $id);
  $context->status(404) if $context->can('status');
  return $err;
}

# Helper to create JSON-RPC error responses
sub _jsonrpc_error ($self, $code, $message, $id) {
  return {
    jsonrpc => '2.0',
    error   => { code => $code, message => $message },
    id      => $id
  };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::ResourceTemplates - MCP server support for resource templates and tool-call logging

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::ResourceTemplates;

  my $server = MCP::Server::KnowledgeStore::ResourceTemplates->new(name => 'my-server');

  # Add templates
  $server->add_template(
    uri_template => 'memory://memories/{name}',
    name => 'memory_read',
    description => 'Read a memory by name',
    mime_type => 'text/markdown',
    code => sub ($template, $params, $context) {
      my $name = $params->{name};
      # ... fetch and return content
      return "Content of memory $name";
    },
  );

=head1 DESCRIPTION

This module extends L<MCP::Server> with resource template support, allowing
URI templates with parameters like C<memory://memories/{name}> to be
registered and matched against incoming resource read requests.

Resource templates are URIs with placeholder parameters in curly braces.
When a client requests a resource with a matching URI pattern, the template's
callback is invoked with the extracted parameters.

=head1 NAME

MCP::Server::KnowledgeStore::ResourceTemplates - MCP server with resource template support

=head1 EXAMPLES

=head2 Basic Template

  $server->add_template(
    uri_template => 'file:///data/{file}',
    name => 'file_reader',
    description => 'Read files from the data directory',
    mime_type => 'text/plain',
    code => sub ($template, $params, $context) {
      my $file = $params->{file};
      # Validate and read file
      return "File content";
    },
  );

=head2 Multi-parameter Template

  $server->add_template(
    uri_template => 'memory://{kind}/{name}/revisions/{rev}',
    name => 'revision_reader',
    description => 'Read a specific revision',
    mime_type => 'text/markdown',
    code => sub ($template, $params, $context) {
      my ($kind, $name, $rev) = @{$params}{qw(kind name rev)};
      # Fetch and return content
    },
  );

=head1 METHODS

=head2 add_template

Register a new resource template.

=over

=item uri_template

Required. The URI template with parameter placeholders, e.g.,
C<memory://memories/{name}> or C<memory://memories/{name}/revisions/{revision}>.

Placeholder syntax: C<{param_name}> where param_name matches C</[a-zA-Z_][a-zA-Z0-9_]*/>.

=item name

Required. The template name.

=item description

Optional. Human-readable description. Defaults to 'Resource template'.

=item mime_type

Optional. MIME type for responses. Defaults to 'text/plain'.

=item code

Required. Callback that receives C<($template, $params, $context)> and
returns the resource content. 

The C<$params> argument is a hashref containing the extracted parameter values.

The callback should return either:

=over

=item * A hashref with C<contents> key (standard MCP resource format)

=item * A scalar (text string) which will be wrapped in text_resource format

=item * undef (resource not found, will return 404)

=back

=back

=head1 SEE ALSO

L<MCP::Server>, L<MCP::Resource>, L<MCP::Server::KnowledgeStore::Tools>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
