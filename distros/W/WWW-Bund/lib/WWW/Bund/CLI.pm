package WWW::Bund::CLI;
our $VERSION = '0.001';
# ABSTRACT: CLI client for German Federal Government APIs

use Moo;
use MooX::Cmd;
use MooX::Options protect_argv => 0;
use WWW::Bund;
use WWW::Bund::Registry;
use WWW::Bund::CLI::Formatter;
use WWW::Bund::CLI::Strings;
use JSON::MaybeXS qw(encode_json);
use YAML::PP qw(Dump);
use File::ShareDir::ProjectDistDir;
use File::Spec;


option output => (
    is      => 'ro',
    format  => 's',
    short   => 'o',
    doc     => 'Output format: template, json, yaml',
    default => 'template',
);


option lang => (
    is      => 'ro',
    format  => 's',
    doc     => 'Language (de, en)',
    default => sub { $ENV{WWW_BUND_LANG} // 'de' },
);


option template => (
    is        => 'ro',
    format    => 's',
    short     => 't',
    doc       => 'Template override',
    predicate => 'has_template',
);


has strings => (
    is      => 'lazy',
    builder => sub {
        my ($self) = @_;
        WWW::Bund::CLI::Strings->new(
            lang        => $self->lang,
            strings_dir => File::Spec->catdir(dist_dir('WWW-Bund'), 'strings'),
        );
    },
);


has formatter => (
    is      => 'lazy',
    builder => sub {
        my ($self) = @_;
        my $share = dist_dir('WWW-Bund');
        my $fmt = WWW::Bund::CLI::Formatter->new(
            templates_dir => File::Spec->catdir($share, 'templates'),
            strings_dir   => File::Spec->catdir($share, 'strings'),
            lang          => $self->lang,
        );
        $fmt->template_override($self->template) if $self->has_template;
        return $fmt;
    },
);


has bund => (
    is      => 'lazy',
    builder => sub {
        WWW::Bund->new(
            registry => WWW::Bund::Registry->new(
                registry_file  => dist_file('WWW-Bund', 'registry.yml'),
                endpoints_file => dist_file('WWW-Bund', 'endpoints.yml'),
            ),
        );
    },
);


# API ID aliases for CLI convenience
my %ALIASES = (
    pegel => 'pegel_online',
);

sub _resolve_api {
    my ($self, $name) = @_;
    $name =~ s/-/_/g;
    return $ALIASES{$name} // $name;
}

sub _action_to_endpoint {
    my ($self, $api, $action) = @_;
    $action =~ s/-/_/g;
    return "${api}_${action}";
}

sub _endpoint_to_action {
    my ($self, $api, $endpoint_name) = @_;
    my $action = $endpoint_name;
    $action =~ s/^\Q${api}_\E//;
    $action =~ s/_/-/g;
    return $action;
}

sub _path_param_names {
    my ($self, $path) = @_;
    my @params;
    while ($path =~ /\{([^}]+)\}/g) {
        push @params, $1;
    }
    return @params;
}

sub _s {
    my ($self, $key, @args) = @_;
    return $self->strings->get($key, @args);
}

sub _short_alias {
    my ($self, $id) = @_;
    my %reverse = reverse %ALIASES;
    return $reverse{$id};
}

sub _format_output {
    my ($self, $data, $endpoint_name) = @_;
    print $self->formatter->format_output($data, $endpoint_name, $self->output);
}

sub execute {
    my ($self, $args, $chain) = @_;

    if (@$args) {
        warn $self->_s('err_unknown_api', $args->[0]) . "\n";
        warn $self->_s('err_see_apis') . "\n";
        exit(1);
    }

    $self->cmd_overview;
}


sub cmd_overview {
    my ($self) = @_;
    my $reg = $self->bund->registry;


    print $self->_s('title') . "\n\n";

    # Categorize APIs
    my $all_apis = $reg->list;
    my (@available, @needs_auth, @not_implemented);

    for my $api (@$all_apis) {
        my $id = $api->{id};
        my $endpoints = $reg->endpoints_for_api($id);
        my $ep_count = scalar @$endpoints;
        my $auth = $api->{auth} // 'none';

        if ($ep_count == 0) {
            push @not_implemented, $api;
        } elsif ($auth ne 'none') {
            push @needs_auth, { %$api, ep_count => $ep_count };
        } else {
            push @available, { %$api, ep_count => $ep_count };
        }
    }

    # Available APIs (public, have endpoints)
    if (@available) {
        print $self->_s('available_apis') . "\n";
        for my $api (sort { $a->{id} cmp $b->{id} } @available) {
            my $short = $self->_short_alias($api->{id});
            my $name = $short ? "$api->{id} ($short)" : $api->{id};
            printf "  %-22s %-38s %s\n",
                $name, $api->{title}, $self->_s('endpoints', $api->{ep_count});
        }
        print "\n";
    }

    # APIs needing auth (have endpoints but require keys)
    if (@needs_auth) {
        print $self->_s('apis_auth') . "\n";
        for my $api (sort { $a->{id} cmp $b->{id} } @needs_auth) {
            printf "  %-22s %-38s %s\n",
                $api->{id}, $api->{title}, $api->{auth};
        }
        print "\n";
    }

    # Not yet implemented: split into auth-needed vs public
    if (@not_implemented) {
        my @need_key = grep { ($_->{auth} // 'none') ne 'none' } @not_implemented;
        my @public   = grep { ($_->{auth} // 'none') eq 'none' } @not_implemented;

        if (@public) {
            print $self->_s('not_impl_public') . "\n  ";
            my @names = sort map { $_->{id} } @public;
            _print_wrapped(\@names);
        }
        if (@need_key) {
            print $self->_s('not_impl_auth') . "\n  ";
            my @names = sort map { $_->{id} } @need_key;
            _print_wrapped(\@names);
        }
    }

    print $self->_s('usage') . "\n";
    for my $key (qw(usage_api usage_call usage_info usage_list usage_json usage_yaml usage_tmpl usage_lang)) {
        print $self->_s($key) . "\n";
    }
}

sub _print_wrapped {
    my ($names) = @_;
    my $line = '';
    for my $name (@$names) {
        if (length($line) + length($name) + 2 > 76) {
            print "$line\n  ";
            $line = '';
        }
        $line .= ', ' if $line;
        $line .= $name;
    }
    print "$line\n\n" if $line;
}

sub cmd_list {
    my ($self) = @_;
    my $all = $self->bund->registry->list;


    if ($self->output eq 'json') {
        print encode_json($all), "\n";
        return;
    }

    if ($self->output eq 'yaml') {
        print Dump($all);
        return;
    }

    printf "%-25s %-40s %-8s %s\n",
        $self->_s('list_id'), $self->_s('list_title'),
        $self->_s('list_auth'), $self->_s('list_tags');
    print "-" x 100, "\n";

    for my $api (@$all) {
        my $tags = join(', ', @{$api->{tags} || []});
        printf "%-25s %-40s %-8s %s\n",
            $api->{id}, $api->{title}, $api->{auth} // 'none', $tags;
    }
}

sub cmd_info {
    my ($self, $api_id) = @_;
    my $reg = $self->bund->registry;
    my $info = eval { $reg->info($api_id) };


    unless ($info) {
        warn $self->_s('err_unknown_api_name', $api_id) . "\n";
        return;
    }

    if ($self->output eq 'json') {
        print encode_json($info), "\n";
        return;
    }

    if ($self->output eq 'yaml') {
        print Dump($info);
        return;
    }

    printf "%s - %s\n", $info->{id}, $info->{title};
    printf "%-10s %s\n", $self->_s('info_provider'), $info->{provider} // '-';
    printf "%-10s %s\n", $self->_s('info_auth'), $info->{auth} // 'none';
    printf "%-10s %s\n", $self->_s('info_docs'), $info->{docs_url} // '-';
    printf "%-10s %s\n", $self->_s('info_tags'), join(', ', @{$info->{tags} || []});

    if ($info->{rate_limit}) {
        printf "%-10s %s\n", $self->_s('info_rate'), $info->{rate_limit};
    }

    # Show endpoints
    my $endpoints = $reg->endpoints_for_api($api_id);
    if (@$endpoints) {
        print "\n" . $self->_s('endpoints_header') . "\n";
        for my $ep (sort { $a->{name} cmp $b->{name} } @$endpoints) {
            my $action = $self->_endpoint_to_action($api_id, $ep->{name});
            my @params = $self->_path_param_names($ep->{path});
            my @qparams = @{$ep->{query_params} // []};
            my $param_str = join(' ',
                (map { "<$_>" } @params),
                (map { "[$_]" } @qparams),
            );
            $param_str = " $param_str" if $param_str;
            printf "  %-30s %s %s\n", $action . $param_str, uc($ep->{method}), $ep->{path};
        }
    }
}

sub cmd_api_help {
    my ($self, $api_id) = @_;
    my $reg = $self->bund->registry;
    my $info = eval { $reg->info($api_id) };


    unless ($info) {
        warn $self->_s('err_unknown_api_name', $api_id) . "\n";
        return;
    }

    printf "%s - %s", $info->{id}, $info->{title};
    printf " (%s)", $info->{provider} if $info->{provider};
    print "\n\n";

    my $endpoints = $reg->endpoints_for_api($api_id);

    unless (@$endpoints) {
        print $self->_s('no_endpoints') . "\n";
        printf $self->_s('spec_hint', $info->{spec_url}) . "\n" if $info->{spec_url};
        return;
    }

    print $self->_s('commands_header') . "\n";
    my $first_action;
    my $first_example;

    for my $ep (sort { $a->{name} cmp $b->{name} } @$endpoints) {
        my $action = $self->_endpoint_to_action($api_id, $ep->{name});
        my @params = $self->_path_param_names($ep->{path});
        my @qparams = @{$ep->{query_params} // []};
        my $param_str = join(' ',
            (map { "<$_>" } @params),
            (map { "[$_]" } @qparams),
        );
        $param_str = " $param_str" if $param_str;
        printf "  %-35s %s %s\n", $action . $param_str, uc($ep->{method}), $ep->{path};

        unless ($first_action) {
            $first_action = $action;
            my @all = (@params, @qparams);
            $first_example = @all
                ? "bund $api_id $action " . join(' ', map { "VALUE" } @all)
                : "bund $api_id $action";
        }
    }

    # Show shorthand alias
    my $short = $self->_short_alias($api_id);
    if ($short) {
        print "\n" . $self->_s('alias_hint', $short, $api_id) . "\n";
    }

    print "\n" . $self->_s('example') . " $first_example\n" if $first_example;
}

sub cmd_call {
    my ($self, $api, $action, @args) = @_;

    my $endpoint_name = $self->_action_to_endpoint($api, $action);


    # Look up endpoint
    my $ep = eval { $self->bund->registry->endpoint($endpoint_name) };
    unless ($ep) {
        warn $self->_s('err_unknown_cmd', $action) . "\n";
        warn $self->_s('err_see_cmds', $api) . "\n";
        return 1;
    }

    # Parse args: positional go to path params, --key=value to query params
    my @path_params = $self->_path_param_names($ep->{path});
    my %params;
    my @positional;

    for my $arg (@args) {
        if ($arg =~ /^--([^=]+)=(.*)/) {
            $params{$1} = $2;
        } elsif ($arg =~ /^--([^=]+)/) {
            $params{$1} = shift @args // '';
        } else {
            push @positional, $arg;
        }
    }

    # Map positional args to path params
    for my $i (0 .. $#path_params) {
        unless (defined $positional[$i]) {
            warn $self->_s('err_missing_arg', $path_params[$i]) . "\n";
            my $param_str = join(' ', map { "<$_>" } @path_params);
            warn $self->_s('err_usage_call', $api, $action, $param_str) . "\n";
            return 1;
        }
        $params{$path_params[$i]} = $positional[$i];
    }

    # Map remaining positional args to query_params (if endpoint defines them)
    my @query_params = @{$ep->{query_params} // []};
    for my $i (0 .. $#query_params) {
        my $pos_idx = scalar(@path_params) + $i;
        last unless defined $positional[$pos_idx];
        $params{$query_params[$i]} = $positional[$pos_idx];
    }

    # Execute
    my $data = eval {
        $self->bund->call($api, $endpoint_name, params => \%params);
    };

    if ($@) {
        my $err = $@;
        $err =~ s/ at .+ line \d+\.\n?$//;
        warn $self->_s('err_error', $err) . "\n";
        return 1;
    }

    $self->_format_output($data, $endpoint_name);
    return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI - CLI client for German Federal Government APIs

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    # Command line usage
    bund                            # Overview
    bund list                       # List all APIs
    bund info autobahn              # Show API details
    bund autobahn roads             # Execute API call
    bund autobahn webcams A7        # With parameters
    bund pegel stations --output json
    bund nina warnings 091620000000 --lang en

    # Library usage
    use WWW::Bund::CLI;

    my $cli = WWW::Bund::CLI->new_with_cmd(
        output => 'json',
        lang   => 'de',
    );

=head1 DESCRIPTION

Root CLI application using L<MooX::Cmd> for command dispatch. Provides global
options (C<--output>, C<--lang>, C<--template>) and discovery commands (C<list>,
C<info>).

API-specific commands are implemented as subcommands in
C<WWW::Bund::CLI::Cmd::*> modules. Most use L<WWW::Bund::CLI::Role::APICommand>
for uniform dispatch.

=head2 Global Options

=over

=item * C<--output>, C<-o> - Output format: template (default), json, yaml

=item * C<--lang> - Language (de, en, fr, es, it, nl, pl). Defaults to C<$ENV{WWW_BUND_LANG}> or 'de'

=item * C<--template>, C<-t> - Override template file path

=back

=head2 Commands

=over

=item * C<list> - List all APIs (see L<WWW::Bund::CLI::Cmd::List>)

=item * C<info E<lt>apiE<gt>> - Show API details (see L<WWW::Bund::CLI::Cmd::Info>)

=item * C<autobahn> - Autobahn API (see L<WWW::Bund::CLI::Cmd::Autobahn>)

=item * C<pegel> - Pegel Online API (see L<WWW::Bund::CLI::Cmd::Pegel>)

=item * C<nina> - NINA warnings (see L<WWW::Bund::CLI::Cmd::Nina>)

=item * C<tagesschau> - Tagesschau news (see L<WWW::Bund::CLI::Cmd::Tagesschau>)

=item * C<bundestag> - Bundestag data (see L<WWW::Bund::CLI::Cmd::Bundestag>)

=item * C<dwd> - DWD weather warnings (see L<WWW::Bund::CLI::Cmd::Dwd>)

=item * And 12 more... (see subcommand modules)

=back

=head2 Multi-language Support

The CLI is available in 7 language-specific wrappers:

=over

=item * C<bund> - German (default)

=item * C<bunden> - English

=item * C<bundfr> - French

=item * C<bundes> - Spanish

=item * C<bundit> - Italian

=item * C<bundnl> - Dutch

=item * C<bundpl> - Polish

=back

Each wrapper sets C<WWW_BUND_LANG> to pre-select the language.

=head2 output

Output format: C<template> (default), C<json>, or C<yaml>.

Template mode uses YAML templates from C<share/templates/{lang}/> to format
output as tables, lists, or records.

=head2 lang

Language for CLI strings and templates. Supported: de, en, fr, es, it, nl, pl.

Defaults to C<$ENV{WWW_BUND_LANG}> or C<de>.

=head2 template

Override template file path for output formatting. Useful for custom templates.

=head2 strings

L<WWW::Bund::CLI::Strings> instance for localized CLI messages.

=head2 formatter

L<WWW::Bund::CLI::Formatter> instance for template-based output formatting.

=head2 bund

L<WWW::Bund> client instance for making API calls.

=head2 execute

Default command when no subcommand is given. Shows overview or error if
unknown API is specified.

=head2 cmd_overview

Display categorized overview of all APIs: available (public with endpoints),
needs auth, and not yet implemented (split by public vs auth-required).

=head2 cmd_list

List all APIs in table format (or JSON/YAML if requested). Shows ID, title,
auth type, and tags.

=head2 cmd_info

    $cli->cmd_info($api_id);

Show detailed information about an API: provider, auth, docs, rate limit,
and list of available endpoints with parameters.

=head2 cmd_api_help

    $cli->cmd_api_help($api_id);

Show help for a specific API: available actions (endpoints) with parameter
signatures and usage example.

Called when an API command is invoked without action (e.g., C<bund autobahn>).

=head2 cmd_call

    my $rc = $cli->cmd_call($api_id, $action, @args);

Execute an API call with argument parsing. Returns exit code (0 on success, 1 on error).

Arguments can be positional or named:

=over

=item * Positional args are mapped to path parameters first, then query parameters

=item * C<--key=value> or C<--key value> for explicit parameter assignment

=back

Output is formatted according to C<--output> option.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
