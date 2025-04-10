package Data::Transmute;

use 5.010001;
use strict 'subs', 'vars';
use warnings;
use Log::ger;

use Ref::Util qw(is_hashref is_arrayref is_plain_hashref is_plain_arrayref);
use Scalar::Util qw(refaddr);

use Exporter qw(import);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-07-17'; # DATE
our $DIST = 'Data-Transmute'; # DIST
our $VERSION = '0.040'; # VERSION

our @EXPORT_OK = qw(transmute_data reverse_rules);

sub _rule_create_hash_key {
    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} // 1) ? is_hashref($data) : is_plain_hashref($data);

    my $name = $args{name};
    die "Rule create_hash_key: Please specify 'name'" unless defined $name;

    if (exists $data->{$name}) {
        return if $args{ignore};
        die "Rule create_hash_key: Key '$name' already exists" unless $args{replace};
    }
    die "Rule create_hash_key: Please specify 'value' or 'value_code'"
        unless exists $args{value} || $args{value_code};
    $data->{$name} = $args{value_code} ? $args{value_code}->($data->{$name}) : $args{value};
}

sub _rulereverse_create_hash_key {
    my %args = @_;
    die "Cannot generate reverse rule create_hash_key with value_code" if $args{value_code};
    die "Cannot generate reverse rule create_hash_key with ignore=1"   if $args{ignore};
    die "Cannot generate reverse rule create_hash_key with replace=1"  if $args{replace};
    [delete_hash_key => {name=>$args{name}, transmute_object=>$args{transmute_object}}];
}

sub _rule_rename_hash_key {
    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} // 1) ? is_hashref($data) : is_plain_hashref($data);

    my $from = $args{from};
    die "Rule rename_hash_key: Please specify 'from'" unless defined $from;
    my $to   = $args{to};
    die "Rule rename_hash_key: Please specify 'to'" unless defined $to;

    # noop
    return if $from eq $to;

    if (!exists($data->{$from})) {
        die "Rule rename_hash_key: Can't rename '$from' -> '$to': Old key '$from' doesn't exist" unless $args{ignore_missing_from};
        return;
    }
    if (exists $data->{$to}) {
        return if $args{ignore_existing_target};
        die "Rule rename_hash_key: Can't rename '$from' -> '$to': Target key '$from' already exists" unless $args{replace};
    }
    $data->{$to} = delete $data->{$from};
}

sub _rulereverse_rename_hash_key {
    my %args = @_;
    die "Cannot generate reverse rule rename_hash_key with ignore_missing_from=1"     if $args{ignore_missing_from};
    die "Cannot generate reverse rule rename_hash_key with ignore_existing_target=1"  if $args{ignore_existing_target};
    die "Cannot generate reverse rule rename_hash_key with replace=1"                 if $args{replace};
    [rename_hash_key => {
        from=>$args{to}, to=>$args{from},
        transmute_object=>$args{transmute_object},
    }];
}

sub _rule_modify_hash_value {
    require Data::Cmp;

    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} // 1) ? is_hashref($data) : is_plain_hashref($data);

    my $name = $args{name};
    die "Rule modify_hash_value: Please specify 'name' (key)" unless defined $name;
    my $from = $args{from};
    my $from_exists = exists $args{from};
    my $to   = $args{to};
    die "Rule rename_hash_key: Please specify 'to' or 'to_code'"
        unless exists $args{to} || $args{to_code};

    my $errprefix = "Rule modify_hash_value: Can't modify key '$name'".
        ($from_exists ? " from '".($from // '<undef>') : "").
        ($args{to_code} ? "' using to_code" : "' to '".($to // '<undef>')."'");

    unless (exists $data->{$name}) {
        die "$errprefix: key does not exist";
    }

    my $cur = $data->{$name};

    $to = $args{to_code}->($cur) if $args{to_code};

    if ($from_exists) {
        # noop
        return unless Data::Cmp::cmp_data($from, $to);

        if (Data::Cmp::cmp_data($cur, $from)) {
            die "$errprefix: current value is not '".($cur // '<undef>')."'";
        }
    }

    $data->{$name} = $to;
}

sub _rulereverse_modify_hash_value {
    my %args = @_;
    die "Cannot generate reverse rule modify_hash_value without from" unless exists $args{from};
    die "Cannot generate reverse rule modify_hash_value with to_code" if $args{to_code};
    [modify_hash_value => {
        name => $args{name}, from => $args{to}, to => $args{from},
        transmute_object=>$args{transmute_object},
    }];
}

sub _rule_delete_hash_key {
    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} // 1) ? is_hashref($data) : is_plain_hashref($data);

    my $name = $args{name};
    die "Rule delete_hash_key: Please specify 'name'" unless defined $name;

    delete $data->{$name};
}

sub _rulereverse_delete_hash_key {
    die "Can't create reverse rule for delete_hash_key";
}

sub _rule_transmute_array_elems {
    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} //1) ? is_arrayref($data) : is_plain_arrayref($data);

    die "Rule transmute_array_elems: Please specify 'rules' or 'rules_module'"
        unless defined($args{rules}) || defined($args{rules_module});

    my $idx = -1;
  ELEM:
    for my $el (@$data) {
        $idx++;
        if (defined $args{index_is}) {
            next ELEM unless $idx == $args{index_is};
        }
        if (defined $args{index_in}) {
            next ELEM unless grep { $idx == $_ } @{ $args{index_in} };
        }
        if (defined $args{index_match}) {
            next ELEM unless $idx =~ $args{index_match};
        }
        if (defined $args{index_filter}) {
            next ELEM unless $args{index_filter}->(index=>$idx, array=>$data, rules=>$args{rules});
        }
        $el = transmute_data(
            data => $el,
            (rules        => $args{rules})        x !!(exists $args{rules}),
            (rules_module => $args{rules_module}) x !!(exists $args{rules_module}),
        );
    }
    $data;
}

sub _rulereverse_transmute_array_elems {
    my %args = @_;

    [transmute_array_elems => {
        rules => reverse_rules(
            (rules        => $args{rules})        x !!(exists $args{rules}),
            (rules_module => $args{rules_module}) x !!(exists $args{rules_module}),
        ),
        (index_is     => $args{index_is})     x !!(exists $args{index_is}),
        (index_in     => $args{index_in})     x !!(exists $args{index_in}),
        (index_match  => $args{index_match})  x !!(exists $args{index_match}),
        (index_filter => $args{index_filter}) x !!(exists $args{index_filter}),
        transmute_object=>$args{transmute_object},
    }];
}

sub _rule_transmute_hash_values {
    my %args = @_;

    my $data = $args{data};
    return unless ($args{transmute_object} //1) ? is_hashref($data) : is_plain_hashref($data);

    die "Rule transmute_hash_values: Please specify 'rules' or 'rules_module'"
        unless defined($args{rules}) || defined($args{rules_module});

  KEY:
    for my $key (keys %$data) {
        if (defined $args{key_is}) {
            next KEY unless $key eq $args{key_is};
        }
        if (defined $args{key_in}) {
            next KEY unless grep { $key eq $_ } @{ $args{key_in} };
        }
        if (defined $args{key_match}) {
            next KEY unless $key =~ $args{key_match};
        }
        if (defined $args{key_filter}) {
            next KEY unless $args{key_filter}->(key=>$key, hash=>$data, rules=>$args{rules});
        }
        $data->{$key} = transmute_data(
            data => $data->{$key},
            (rules        => $args{rules})        x !!(exists $args{rules}),
            (rules_module => $args{rules_module}) x !!(exists $args{rules_module}),
        );
    }
    $data;
}

sub _rulereverse_transmute_hash_values {
    my %args = @_;

    [transmute_hash_values => {
        rules => reverse_rules(
            (rules        => $args{rules})        x !!(exists $args{rules}),
            (rules_module => $args{rules_module}) x !!(exists $args{rules_module}),
        ),
        (key_is     => $args{key_is})     x !!(exists $args{key_is}),
        (key_in     => $args{key_in})     x !!(exists $args{key_in}),
        (key_match  => $args{key_match})  x !!(exists $args{key_match}),
        (key_filter => $args{key_filter}) x !!(exists $args{key_filter}),
        transmute_object=>$args{transmute_object},
    }];
}

sub _walk {
    my ($data, $rule_args, $seen) = @_;

    # transmute the node itself
    transmute_data(
        data => $data,
        (rules        => $rule_args->{rules})        x !!(exists $rule_args->{rules}),
        (rules_module => $rule_args->{rules_module}) x !!(exists $rule_args->{rules_module}),
    );
    my $refaddr = refaddr($data);
    return unless $refaddr;
    return if $seen->{$refaddr}++;

    if ($rule_args->{recurse_object} ?
            is_arrayref($data) : is_plain_arrayref($data)) {
        for my $elem (@$data) {
            _walk($elem, $rule_args, $seen);
        }
    } elsif ($rule_args->{recurse_object} ?
            is_hashref($data) : is_plain_hashref($data)) {
        for my $key (sort keys %$data) {
            _walk($data->{$key}, $rule_args, $seen);
        }
    }
}

sub _rule_transmute_nodes {
    my %args = @_;

    my $data = $args{data};

    die "Rule transmute_nodes: Please specify 'rules' or 'rules_module'"
        unless defined($args{rules}) || defined($args{rules_module});

    my $seen = {};
    _walk($data, \%args, $seen);
    $data;
}

sub _rulereverse_transmute_nodes {
    die "Rule transmute_nodes is not reversible";
}

sub _rules_or_rules_module {
    my $args = shift;

    my $rules = $args->{rules};
    if (!$rules) {
        if (defined $args->{rules_module}) {
            my $mod = "Data::Transmute::Rules::$args->{rules_module}";
            (my $mod_pm = "$mod.pm") =~ s!::!/!g;
            require $mod_pm;
            $rules = \@{"$mod\::RULES"};
        }
    }
    $rules or die "Please specify rules (or rules_module)";
    $rules;
}

sub transmute_data {
    my %args = @_;

    exists $args{data} or die "Please specify data";
    my $data  = $args{data};
    my $rules = _rules_or_rules_module(\%args);

    my $rulenum = 0;
    for my $rule (@$rules) {
        $rulenum++;
        if ($ENV{LOG_DATA_TRANSMUTE_STEP}) {
            log_trace "transmute_data #%d/%d: %s",
                $rulenum, scalar(@$rules), $rule;
        }
        my $funcname = "_rule_$rule->[0]";
        die "rule #$rulenum: Unknown function '$rule->[0]'"
            unless defined &{$funcname};
        my $func = \&{$funcname};
        $func->(
            %{$rule->[1] // {}},
            data => $data,
        );
    }
    $data;
}

sub reverse_rules {
    my %args = @_;

    my $rules = _rules_or_rules_module(\%args);

    my @rev_rules;
    for my $rule (@$rules) {
        my $funcname = "_rulereverse_$rule->[0]";
        my $func = \&{$funcname};
        unshift @rev_rules, $func->(
            %{$rule->[1] // {}},
        );
    }
    \@rev_rules;
}

1;
# ABSTRACT: Transmute (transform) data structure using rules data

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Transmute - Transmute (transform) data structure using rules data

=head1 VERSION

This document describes version 0.040 of Data::Transmute (from Perl distribution Data-Transmute), released on 2024-07-17.

=head1 SYNOPSIS

 use Data::Transmute qw(
     transmute_data
     reverse_rules
 );

 my $transmuted_data = transmute_data(
     data => \@data,
     rules => [

         # CREATING HASH KEY

         # this rule only applies when data is a hash, when data is not a hash
         # this will do nothing. create a single new hash key, error if key
         # already exists.
         [create_hash_key => {name=>'foo', value=>1}],

         # create another hash key, but this time ignore/noop if key already
         # exists (ignore=1). this is like INSERT IGNORE in SQL. note: this
         # makes the rule irreversible.
         [create_hash_key => {name=>'bar', value=>2, ignore=>1}],

         # create yet another key, this time replace existing keys (replace=1).
         # this is like REPLACE INTO in SQL. note: this makes the rule
         # irreversible.
         [create_hash_key => {name=>'baz', value=>3, replace=>1}],

         # compute value with coderef (supply 'value_code' instead of 'value').
         # note: this makes the rule irreversible.
         [create_hash_key => {name=>'baz', value_code=>sub {uc($_[0]}, replace=>1}],

         # RENAMING HASH KEY

         # this rule only applies when data is a hash, when data is not a hash
         # this will do nothing. rename a single key, error if old name doesn't
         # exist or new name exists.
         [rename_hash_key => {from=>'qux', to=>'quux'}],

         # rename another key, but this time ignore if old name doesn't exist
         # (ignore=1) or if new name already exists (replace=1)
         [rename_hash_key => {from=>'corge', to=>'grault', ignore_missing_from=>1, replace=>1}],


         # MODIFYING HASH VALUE

         # this rule only applies when data is a hash, when data is not a hash
         # this will do nothing. change the value of a single keypair (key
         # specified in 'name'), error if key doesn't exist or old value doesn't
         # equal specified ('from').
         [modify_hash_value => {name=>'foo', from=>'old', to=>'new'}],

         # 'from' is optional, but if you omit it, the rule becomes
         # irreversible.
         [modify_hash_value => {name=>'foo', to=>'new'}],

         # instead of specifying new value in 'to', you can compute new value
         # using 'to_code'. note: if you do this the rule becomes irreversible.
         [modify_hash_value => {name=>'foo', from_old=>'old', to_code=>sub {uc $_[0]}}],


         # DELETING HASH KEY

         # this rule only applies when data is a hash, when data is not a hash
         # this will do nothing. delete a single key, will noop if key already
         # doesn't exist.
         [delete_hash_key => {name=>'garply'}],


         # APPLYING (SUB)RULES TO ARRAY ELEMENTS

         # this rule only applies when data is an arrayref, when data is not an
         # array this will do nothing. for each array element, apply transmute
         # rules to it.
         [transmute_array_elems => {
              rules => [...],              # or 'rules_module'
          }],

         # you can select only certain elements to transmute by using one+ of:
         # index_is, index_in, index_match, index_filter.
         [transmute_array_elems => {
              rules => [...],              # or 'rules_module'
              #index_is => 1,              # only transmute 2nd element (index is 0-based)
              #index_in => [0,1,2],        # only transmute the first 3 elements
              #index_match => qr/.../,     # only transmute elements where the index matches a regex
              #index_filter => sub{...},   # only transmute elements where $filter->(index=>$index) returns true
          }],


         # APPLYING (SUB)RULES TO HASH VALUES

         # this rule only applies when data is a hashref, when data is not a
         # hash this will do nothing. for each hash value, apply transmute rules
         # to it.
         [transmute_hash_values => {
              rules => [...],            # or 'rules_module'

          }],

         # you can select only certain keys to transmute by using one+ of:
         # key_is, key_in, key_match, key_filter.
         [transmute_hash_values => {
              rules => [...],            # or 'rules_module'
              #key_is => 'foo',          # only transmute value of key 'foo'
              #key_in => ['foo', 'bar'], # only transmute value of keys 'foo', 'bar'
              #key_match => qr/.../,     # only transmute value of keys that match a regex
              #key_filter => sub{...},   # only transmute value of keys where $filter->(key=>$key) returns true
          }],


         # APPLYING (SUB)RULES TO NODES

         # this rule will transmute data, then recurse (walk) to array elements
         # (if data is an array) and hash values (if data is a hash). can handle
         # circular references. this rule is irreversible.
         [transmute_nodes => {
              rules => [...],              # or 'rules_module'
          }],

     ],
 );

You can also load rules from a C<Data::Transmute::Rules::*> module:

 transmute_data(
     data => $data,
     rules_module => 'Convert_Proj1_Data_To_Proj2', # will load Data::Transmute::Rules::Convert_Proj1_Data_To_Proj2 and read its @RULES package variable
 );

=head1 DESCRIPTION

This module provides routines to transmute (transform) a data structure in-place
using rules which is another data structure (an arrayref of rule
specifications).

One use-case for this module is to convert/upgrade configuration files.

=head1 RULES

Rules is an array of rule specifications.

Each rule specification: [$funcname, \%args]

\%args: a special arg will be inserted: C<data>.

=head2 create_hash_key

This rule only applies when data is a hash, when data is not a hash this will do
nothing. Create a single new hash key, error if key already exists.

Known arguments (C<*> means required):

=over

=item * name*

=item * value

Either C<value> or C<value_code> is required.

=item * value_code

Either C<value> or C<value_code> is required.

Instead of specifying value, you can also supply a coderef to compute the value.
The coderef will be passed the current value of the hash key (or undef if there
is none).

If you supply C<value_code>, your rule will become irreversible.

=item * ignore

Bool. If set to true, will ignore/noop if key already exists. This is like
INSERT IGNORE (INSERT OR IGNORE) in SQL.

If you set C<ignore> to true, your rule will become irreversible.

=item * replace

Bool. If set to true, will replace existing keys. This is like REPLACE INTO in
SQL.

If you set C<replace> to true, your rule will become irreversible.

=item * transmute_object

Bool, default true. By default, blessed hash is also transmuted. But if you set
this to false, blessed hash will not be touched.

=back

=head2 rename_hash_key

This rule only applies when data is a hash, when data is not a hash this will do
nothing. Rename a single key, error if old name doesn't exist or new name
exists.

Known arguments (C<*> means required):

=over

=item * from*

=item * to*

=item * ignore_missing_from

Bool. If set to true, will noop (instead of error) if old name doesn't exist.

=item * replace

Bool. If set to true, will overwrite (instead of error) when target key already
exists.

=item * transmute_object

Bool, default true. By default, blessed hash is also transmuted. But if you set
this to false, blessed hash will not be touched.

=back

=head2 modify_hash_value

This rule only applies when data is a hash, when data is not a hash this will do
nothing. Modify a single hash value from original value I<from> to new value
I<to>. Key must exist, and value must originally be I<from>.

Known arguments (C<*> means required):

=over

=item * name*

String. Key name.

=item * from*

String or undef. Original value.

=item * to

String or undef. New value.

Either C<to> or C<to_code> is required.

=item * to_code

Coderef. Instead of specifying new vlaue via C<to>, you can also supply
C<to_code> (a coderef) to compute the value. The coderef will be passed the
current value.

If you set C<to_code>, your rule will become irreversible.

=item * transmute_object

Bool, default true. By default, blessed hash is also transmuted. But if you set
this to false, blessed hash will not be touched.

=back

=head2 delete_hash_key

This rule only applies when data is a hash, when data is not a hash this will do
nothing. Delete a single key, will noop if key already doesn't exist.

Known arguments (C<*> means required):

=over

=item * name*

=item * transmute_object

Bool, default true. By default, blessed hash is also transmuted. But if you set
this to false, blessed hash will not be touched.

=back

=head2 transmute_array_elems

This rule only applies when data is an arrayref, when data is not an array this
will do nothing. for each array element, apply transmute rules to it.

Known arguments (C<*> means required):

=over

=item * rules

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * rules_module

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * index_is

=item * index_in

=item * index_match

=item * index_filter

Coderef. Only transmute elements where $coderef->(index=>$index) is true. Aside
from C<index>, the coderef will also receive these arguments: C<rules> (the
rule), C<array> (the array).

=item * transmute_object

Bool, default true. By default, blessed array is also transmuted. But if you set
this to false, blessed array will not be touched.

=back

=head2 transmute_hash_values

This rule only applies when data is a hashref, when data is not a hash this will
do nothing. For each hash value, apply transmute rules to it.

Known arguments (C<*> means required):

=over

=item * rules

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * rules_module

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * key_is

=item * key_in

=item * key_match

=item * key_filter

Coderef. Only transmute value of keys where $coderef->(key=>$key) is true. Aside
from C<key>, the coderef will also receive these arguments: C<rules> (the rule),
C<hash> (the hash).

=item * transmute_object

Bool, default true. By default, blessed hash is also transmuted. But if you set
this to false, blessed hash will not be touched.

=back

=head2 transmute_nodes

This rule will transmute data, then recurse (walk) to array elements (if data is
an array) or hash values (if data is a hash) and transmute each of those child
data. Can handle circular references.

This rule is not irreversible.

Known arguments (C<*> means required):

=over

=item * recurse_object

Boolean, default B<false>. Whether to recurse into (hash-based and array-based)
objects. By default, B<objects are not recursed>. Set this to true to recurse
into objects.

=item * rules

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * rules_module

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=back

=head1 FUNCTIONS

=head2 transmute_data

Usage:

 $data = transmute_data(%args)

Transmute data structure, die on failure. Input data is specified in the C<data>
argument, which will be modified in-place (so you'll need to clone it first if
you don't want to modify the original data). Rules is specified in C<rules>
argument.

Known arguments (C<*> means required):

=over

=item * data*

=item * rules

Array of rules. See L</RULES> for more details.

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=item * rules_module

Specify name of module (without the C<Data::Transmute::Rules::> prefix) which
contains the actual rules. The module will be loaded and the rules retrieved
from its C<@RULES> package variable.

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

=back

=head2 reverse_rules

Usage:

 my $reverse_rules = reverse_rules(rules => [...]);

Create a reverse of rules, die on failure. For example, this set of rules:

 [
   [create_hash_key => {name=>'a', value=>1}],
   [rename_hash_key => {from=>'c', to=>'d'}],
 ]

when reversed will become:

 [
   [rename_hash_key => {from=>'d', to=>'c'}],
   [delete_hash_key => {name=>'a'}],
 ]

Some rules cannot be reversed, e.g. L</delete_hash_key> so when given rules that
contain that, the function will die. A rule can only be reversed for a subset of
arguments, e.g. L</rename_hash_key> with C<ignore> set to true or C<replace> set
to true cannot be reversed.

The reverse of a set of rules can be used to reverse back a transmuted data back
to the original.

Known arguments (C<*> means required):

=over

=item * rules

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

See L</transmute_data> for more details.

=item * rules_module

Either C<rules> or C<rules_module> is required. C<rules> takes precedence over
C<rules_module>.

See L</transmute_data> for more details.

=back

=head1 ENVIRONMENT

=head2 LOG_DATA_TRANSMUTE_STEP

Boolean. If set to true, will log each transmute step (rule by rule) at the
trace level using L<Log::ger>.

=head1 TODOS

Function to mass rename keys (by regex substitution, prefix, custom Perl code,
...). But this cannot produce reverse of rule.

Function to mass delete keys (by regex, prefix, ...). But this cannot produce
reverse of rule.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Data-Transmute>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Data-Transmute>.

=head1 SEE ALSO

L<Hash::Transform> is similar in concept. It allows transforming a hash using
rules encoded in a hash. However, the rules only allow for simpler
transformations: rename a key, create a key with a specified value, create a key
that from a string-based join of other keys/strings. For more complex needs,
you'll have to supply a coderef to do the transformation yourself manually.
Another thing I find limiting is that the rules is a hash, which means there is
no way to specify order of processing. And of course, you cannot transform
non-hash data.

L<Config::Model>, which you can also use to convert/upgrade configuration files.
But I find this module slightly too heavyweight for the simpler needs that I
have, hence I created Data::Transmute.

L<Bencher::Scenarios::DataTransmute>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTOR

=for stopwords Steven Haryanto

Steven Haryanto <stevenharyanto@gmail.com>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024, 2020, 2019, 2015 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Data-Transmute>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
