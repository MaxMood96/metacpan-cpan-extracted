# DESCRIPTION

A [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools) plugin registering `list_memories`,
`search_memories`, `get_memory`, `save_memory`,
`list_memory_revisions`, `mark_memory_useful`, `tag_memory` and
`untag_memory`, along with the archive, restore, purge, and archived-list
tools, against a [MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore). The tool set itself is
generic; see [MCP::Server::KnowledgeStore::Tools::Revisioned](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools%3A%3ARevisioned). This plugin
configures it for searchable memories with a `type` field.

# SYNOPSIS

    use MCP::Server::KnowledgeStore::Tools::Memory;

    MCP::Server::KnowledgeStore::Tools::Memory->register($mcp_server, $store);

# METHODS

## register

    MCP::Server::KnowledgeStore::Tools::Memory->register($server, $store);

Adds this plugin's tools to `$server` (an [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer)), backed by
`$store`. Called by ["build" in MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools#build) for every
installed plugin - not normally called directly.
