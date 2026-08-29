# DESCRIPTION

A [MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools) plugin registering `list_skills`,
`search_skills`, `get_skill`, `save_skill`, `list_skill_revisions`,
`mark_skill_useful`, `tag_skill` and `untag_skill` against a
[MCP::Server::KnowledgeStore::Store](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3AStore), along with the archive, restore, purge,
and archived-list tools. The tool set itself is generic; see
[MCP::Server::KnowledgeStore::Tools::Revisioned](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools%3A%3ARevisioned). This plugin configures it
for searchable skills without a `type` field.

# SYNOPSIS

    use MCP::Server::KnowledgeStore::Tools::Skill;

    MCP::Server::KnowledgeStore::Tools::Skill->register($mcp_server, $store);

# METHODS

## register

    MCP::Server::KnowledgeStore::Tools::Skill->register($server, $store);

Adds this plugin's tools to `$server` (an [MCP::Server](https://metacpan.org/pod/MCP%3A%3AServer)), backed by
`$store`. Called by ["build" in MCP::Server::KnowledgeStore::Tools](https://metacpan.org/pod/MCP%3A%3AServer%3A%3AKnowledgeStore%3A%3ATools#build) for every
installed plugin - not normally called directly.
