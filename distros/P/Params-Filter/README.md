# Params::Filter

Secure field filtering for parameter construction.

## Description

`Params::Filter` provides lightweight parameter filtering that checks only for the presence or absence of specified fields. It does NOT validate values - no type checking, truthiness testing, or lookups.

This module separates field filtering from value validation:

- **Field filtering** (this module) - Check which fields are present/absent
- **Value validation** (later step) - Check if field values are correct

## Why Use This Module

- **Security** - Sensitive fields (passwords, SSNs, credit cards) never reach your validation code or database statements
- **Compliance** - Automatically excludes fields that shouldn't be processed or stored (e.g., GDPR, PCI-DSS)
- **Consistency** - Converts varying incoming data formats to consistent key-value pairs
- **Correctness** - Ensures only expected fields are processed, preventing accidental data leakage
- **Maintainability** - Clear separation between data filtering (what fields to accept) and validation (whether values are correct)

## Installation

```bash
perl Makefile.PL
make
make test
make install
```

## Quick Start

### Functional Interface

```perl
use Params::Filter qw/filter/;

# Define filter rules
my @required_fields = qw(name email);
my @accepted_fields = qw(phone city state zip);
my @excluded_fields = qw(ssn password);

# Apply filter to incoming data
my ($filtered_data, $status) = filter(
    $incoming_params,    # From web form, CLI, API, etc.
    \@required_fields,
    \@accepted_fields,
    \@excluded_fields,
);

if ($filtered_data) {
    process_user($filtered_data);
} else {
    die "Filtering failed: $status";
}
```

### Object-Oriented Interface

```perl
use Params::Filter;

# Create a reusable filter object
my $user_filter = Params::Filter->new_filter({
    required => ['username', 'email'],
    accepted => ['first_name', 'last_name', 'phone', 'bio'],
    excluded => ['password', 'ssn', 'credit_card'],
});

# Apply to multiple data sources
my ($user1, $msg1) = $user_filter->apply($web_form_data);
my ($user2, $msg2) = $user_filter->apply($api_request_data);
my ($user3, $msg3) = $user_filter->apply($db_record_data);

if ($user1) {
    process_user($user1);
} else {
    return_error($msg1);
}
```

### Closure Interface (Maximum Speed)

```perl
use Params::Filter qw/make_filter/;

# Create a high-performance filter closure
my $fast_filter = make_filter(
    [qw(id username)],      # required
    [qw(email bio)],        # accepted
    [qw(password token)],   # excluded
);

# Apply to high-volume data streams
for my $record (@large_dataset) {
    my $filtered = $fast_filter->($record);
    next unless $filtered;  # Skip if required fields missing
    process($filtered);
}

# Wildcard example - accept everything except sensitive fields
my $safe_filter = make_filter(
    [qw(id type)],
    ['*'],                      # accept all other fields
    [qw(password token ssn)],   # but exclude these
);

my $log_entry = $safe_filter->($incoming_data);
log_to_file($log_entry);  # Passwords, tokens, SSNs never logged
```

The closure interface provides maximum performance for hot code paths. It creates a specialized, optimized closure based on your configuration and can be faster than hand-written Perl filtering code.

### Security Example

```perl
# Remove sensitive fields early in processing pipeline
my $user_filter = Params::Filter->new_filter({
    required => ['username', 'email'],
    accepted => ['name', 'bio'],
    excluded => ['password', 'ssn', 'credit_card', 'admin_token'],
});

# Even if malicious user submits admin_token, it never reaches validation
my ($filtered, $msg) = $user_filter->apply($untrusted_input);
# Excluded fields are removed before any downstream processing
```

### When to Use This Module

Use `Params::Filter` when you have:

- Known parameters for downstream processes (API calls, method arguments, database operations)
- Incoming data from external sources (web forms, APIs, databases, user input)
- No guarantee that incoming data is consistent or complete
- Multiple data instances to process with the same rules
- A distinction between missing and "false" data

### When NOT to Use This Module

If you're constructing both the filter rules AND the data structure at the same point in your code, you probably don't need this module. The expected use is to apply pre-defined rules to data that may be inconsistent or incomplete. If there isn't repetition or an unknown/unreliable data structure, this might be overkill.

## Documentation

For comprehensive documentation, see:

```bash
perldoc Params::Filter
```

The POD documentation includes:

- **Full API Reference** - Complete parameter documentation
- **Input Parsing** - How the module handles hashrefs, arrayrefs, and scalars
- **Return Values** - Success/failure modes and status messages
- **Wildcard Support** - Accept all fields except exclusions
- **Modifier Methods** - Dynamic configuration with `set_required()`, `set_accepted()`, `set_excluded()`
- **Debug Mode** - Development-time warnings
- **Complete Examples** - Form filtering, multi-source data, environment-specific configs, complex data flows

## Examples Directory

The `examples/` directory contains working scripts demonstrating various features:

- `basic_usage.pl` - Simple form input filtering
- `oo_interface.pl` - Reusable filter objects
- `closure_interface.pl` - High-performance closure interface
- `wildcard.pl` - Wildcard acceptance patterns
- `error_handling.pl` - Error handling strategies
- `debug_mode.pl` - Development-time warnings
- `modifier_methods.pl` - Dynamic configuration
- `advanced_filtering.pl` - Complex filtering patterns
- `arrayref_input.pl` - Various input formats
- `edge_cases.pl` - Unusual input formats
- `strict_construction.pl` - Required-field validation

## Features

- **Three interfaces**: Functional, OO, or Closure (for maximum speed)
- **Security-first**: Excludes sensitive fields before they reach validation code
- **Fail-closed**: Returns immediately on missing required parameters
- **Non-destructive**: Allows multiple filters without affecting original data
- **No value checking**: Only presence/absence of fields
- **Debug mode**: Optional warnings about unrecognized or excluded fields
- **Perl 5.36+**: Modern Perl with signatures and post-deref
- **No dependencies**: Only core Perl's Exporter

## Author

Bruce Van Allen <bva@cruzio.com>

## License

perl_5

## Copyright

Copyright (C) 2026, Bruce Van Allen
