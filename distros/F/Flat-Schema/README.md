# NAME

Flat::Schema - Deterministic schema contracts for flat files

# WHY THIS EXISTS (IN ONE PARAGRAPH)

In real ETL work, yesterday's CSV becomes today's "contract" whether you meant it or not.
Flat::Schema makes that contract explicit: generate a deterministic schema from what you
observed, record ambiguity as issues, and give the next step (validation) something
stable to enforce.

# SYNOPSIS

Basic usage:

    use Flat::Profile;
    use Flat::Schema;

    my $profile = Flat::Profile->profile_file(
        file => "data.csv",
    );

    my $schema = Flat::Schema->from_profile(
        profile => $profile,
    );

    print Flat::Schema->new()->to_json(schema => $schema);

With overrides:

    my $schema = Flat::Schema->from_profile(
        profile   => $profile,
        overrides => [
            { column_index => 0, set => { type => 'integer', nullable => 0 } },
            { column_index => 3, set => { name => 'created_at', type => 'datetime' } },
        ],
    );

# DESCRIPTION

Flat::Schema consumes reports produced by [Flat::Profile](https://metacpan.org/pod/Flat%3A%3AProfile) and generates a
deterministic, inspectable schema contract describing what tabular data
**should** look like.

It is the second module in the Flat::\* series:

- Flat::Profile — What the data looks like
- Flat::Schema — What the data should look like
- Flat::Validate — Does the data conform (planned)

The schema is a canonical Perl data structure that:

- Is stable and deterministic (identical inputs → identical output)
- Is serializable to JSON and YAML
- Captures inference decisions and ambiguity as issues
- Can be consumed by Flat::Validate or other tooling

# REAL-WORLD USE CASES (THE STUFF YOU ACTUALLY DO)

## 1) Vendor “helpfully” changes a column (integer → text)

You ingest daily files and one day a numeric column starts containing
values like `N/A`, `unknown`, or `ERR-17`. Your pipeline should not silently
coerce this into zero or drop rows.

Workflow:

1. Profile last-known-good
2. Generate schema (your contract)
3. Validate future drops against the schema

A typical override when you decide "we accept this as string now":

    my $schema = Flat::Schema->from_profile(
        profile   => $profile,
        overrides => [
            { column_index => 7, set => { type => 'string' } },
        ],
    );

Flat::Schema will record that the override conflicts with what it inferred, and
that record is useful during incident review.

## 2) Columns that are “nullable in real life” even if today they are not

Data often arrives complete in a sample window and then starts missing values
in production. In v1, nullability is intentionally simple:

    nullable = true iff null_count > 0

If you know a field is nullable even if today it isn't, force it:

    overrides => [
        { column_index => 2, set => { nullable => 1 } },  # allow missing later
    ],

## 3) Timestamp confusion: date vs datetime vs “whatever the exporter did”

When temporal evidence mixes, Flat::Schema chooses predictability over cleverness.

- date + datetime → datetime
- temporal + non-temporal → string (and it tells you)

This prevents “maybe parseable” data from becoming quietly wrong later.

## 4) “Header row roulette” and naming cleanup

You may get headers like `Customer ID`, `customer_id`, `CUSTID`, or no header at all.
Schema stores both:

- `index` always
- `name` when available

If you need normalized naming for downstream systems:

    overrides => [
        { column_index => 0, set => { name => 'customer_id' } },
    ],

## 5) Reproducible artifacts for tickets, audits, and “what changed?”

Sometimes the most important feature is being able to paste the schema into a ticket,
diff it in Git, or keep it as a build artifact.

Flat::Schema’s serializers are deterministic by design. If the schema changes, it is
because the inputs changed (profile or overrides), not because hash order shifted.

# SCHEMA STRUCTURE (AT A GLANCE)

A generated schema contains:

    {
        schema_version => 1,
        generator      => { name => "Flat::Schema", version => "0.01" },
        profile        => { ... },
        columns        => [ ... ],
        issues         => [ ... ],
    }

Each column contains:

    {
        index      => 0,
        name       => "id",
        type       => "integer",
        nullable   => 0,
        length     => { min => 1, max => 12 },  # optional
        overrides  => { ... },                  # optional
        provenance => {
            basis         => "profile",
            rows_observed => 1000,
            null_count    => 0,
            null_rate     => { num => 0, den => 1000 },
            overrides     => [ "type", "nullable" ],  # optional
        },
    }

# TYPE INFERENCE (v1)

Type inference is based solely on evidence provided by Flat::Profile.

Scalar widening order:

    boolean → integer → number → string

Temporal handling:

    date + datetime → datetime
    temporal + non-temporal → string (with warning)

Mixed evidence is widened and recorded as an issue.

# NULLABILITY INFERENCE (v1)

Rules:

- nullable = true iff null\_count > 0
- If rows\_profiled == 0, all columns are nullable
- All-null columns emit warning `all_null_column`
- Zero profiled rows emits warning `no_rows_profiled`

# USER OVERRIDES (v1)

Overrides are applied after inference.

Supported fields:

- type
- nullable
- name
- length (min/max)

Overrides:

- Are index-based (column\_index required)
- May conflict with inferred values (recorded as warnings)
- Are recorded in column.overrides
- Are recorded in provenance.overrides
- Emit an informational `override_applied` issue

Overrides referencing unknown columns cause a hard error.

# DETERMINISTIC SERIALIZATION

Flat::Schema includes built-in deterministic JSON and YAML serializers.

Same input profile + same overrides → identical JSON/YAML.

This is required for reproducible pipelines and meaningful diffs.

# STATUS

Implemented in v1:

- Canonical schema structure
- Deterministic serialization
- Type inference
- Nullability inference
- User overrides (index-based)

Future releases may expand the type lattice, constraint modeling, and schema evolution.

# AUTHOR

Sergio de Sousa <sergio@serso.com>

# LICENSE

This library is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.
