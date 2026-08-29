# DESCRIPTION

A [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools) plugin registering `list_agents`,
`get_agent`, `save_agent`, `tag_agent` and `untag_agent` against a
[MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore). Agent definitions are stored as opaque
blobs, global by name (not scoped to one project the way a spec is) -
see ["agents" in MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore#agents). Which projects an agent suits
is the same many-to-many tag idea as memory/skill, not a copy per
project.

# SYNOPSIS

    use MCP::Server::KnowledgeStore::Tools::Agent;

    MCP::Server::KnowledgeStore::Tools::Agent->register($mcp_server, $store);

# METHODS

## register

    MCP::Server::KnowledgeStore::Tools::Agent->register($server, $store);

Adds this plugin's tools to `$server` (an [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer)), backed by
`$store`. Called by ["build" in MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools#build) for every
installed plugin - not normally called directly.
