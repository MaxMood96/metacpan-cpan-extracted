# DESCRIPTION

A [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools) plugin registering `list_specs`,
`search_specs`, `get_spec`, `save_spec`, `list_spec_revisions`,
`mark_spec_useful`, and the archive, restore, purge, and archived-list tools
against a [MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore). Unlike memory and skill, a
spec's `project` is required and single. A spec document belongs to exactly
one project, so there is no tag/untag pair.

# SYNOPSIS

    use MCP::Server::KnowledgeStore::Tools::Spec;

    MCP::Server::KnowledgeStore::Tools::Spec->register($mcp_server, $store);

# METHODS

## register

    MCP::Server::KnowledgeStore::Tools::Spec->register($server, $store);

Adds this plugin's tools to `$server` (an [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer)), backed by
`$store`. Called by ["build" in MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools#build) for every
installed plugin - not normally called directly.
