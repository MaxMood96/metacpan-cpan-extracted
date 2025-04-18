package Pg::Explain::Node;

# UTF8 boilerplace, per http://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/
use v5.18;
use strict;
use warnings;
use warnings qw( FATAL utf8 );
use utf8;
use open qw( :std :utf8 );
use Unicode::Normalize qw( NFC );
use Unicode::Collate;
use Encode qw( decode );

if ( grep /\P{ASCII}/ => @ARGV ) {
    @ARGV = map { decode( 'UTF-8', $_ ) } @ARGV;
}

# UTF8 boilerplace, per http://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/

use Clone      qw( clone );
use HOP::Lexer qw( string_lexer );
use Carp;

# I'm reasonably sure that there are no infinite recusion paths, but in some cases the plan is just deep enough to cause Perl to
# issue warning about it. Since the warnings don't bring anything good to the table, let's disable them.
no warnings 'recursion';

=head1 NAME

Pg::Explain::Node - Class representing single node from query plan

=head1 VERSION

Version 2.9

=cut

our $VERSION = '2.9';

# Start counter for all node ids.
our $base_id = 1;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Pg::Explain::Node;

    my $foo = Pg::Explain::Node->new();
    ...

=head1 FUNCTIONS

=head2 id

Unique identifier of this node in this explain. It's read-only, autoincrementing integer.

=head2 actual_loops

Returns number how many times current node has been executed.

This information is available only when parsing EXPLAIN ANALYZE output - not in EXPLAIN output.

=head2 actual_rows

Returns amount of rows current node returnes in single execution (i.e. if given node was executed 10 times, you have to multiply actual_rows by 10, to get full number of returned rows.

This information is available only when parsing EXPLAIN ANALYZE output - not in EXPLAIN output.

=head2 actual_time_first

Returns time (in miliseconds) how long it took PostgreSQL to return 1st row from given node.

This information is available only when parsing EXPLAIN ANALYZE output - not in EXPLAIN output.

=head2 actual_time_last

Returns time (in miliseconds) how long it took PostgreSQL to return all rows from given node. This number represents single execution of the node, so if given node was executed 10 times, you have to multiply actual_time_last by 10 to get total time of running of this node.

This information is available only when parsing EXPLAIN ANALYZE output - not in EXPLAIN output.

=head2 estimated_rows

Returns estimated number of rows to be returned from this node.

=head2 estimated_row_width

Returns estimated width (in bytes) of single row returned from this node.

=head2 estimated_startup_cost

Returns estimated cost of starting execution of given node. Some node types do not have startup cost (i.e., it is 0), but some do. For example - Seq Scan has startup cost = 0, but Sort node has
startup cost depending on number of rows.

This cost is measured in units of "single-page seq scan".

=head2 estimated_total_cost

Returns estimated full cost of given node. 

This cost is measured in units of "single-page seq scan".

=head2 workers_launched

How many worker processes this node launched.

=head2 workers

How many workers was this node processed on. Always set to at least 1.

=head2 type

Textual representation of type of current node. Some types for example:

=over

=item * Index Scan

=item * Index Scan Backward

=item * Limit

=item * Nested Loop

=item * Nested Loop Left Join

=item * Result

=item * Seq Scan

=item * Sort

=back

=head2 buffers

Information about inclusive buffers usage in given node. It's either undef, or object of Pg::Explain::Buffers class.

=cut

=head2 scan_on

Hashref with extra information in case of table scans.

For Seq Scan it contains always 'table_name' key, and optionally 'table_alias' key.

For Index Scan and Backward Index Scan, it also contains (always) 'index_name' key.

=head2 extra_info

ArrayRef of strings, each contains textual information (leading and tailing spaces removed) for given node.

This is not always filled, as it depends heavily on node type and PostgreSQL version.

=head2 sub_nodes

ArrayRef of Pg::Explain::Node objects, which represent sub nodes.

For more details, check ->add_sub_node method description.

=head2 initplans

ArrayRef of Pg::Explain::Node objects, which represent init plan.

For more details, check ->add_initplan method description.

=head2 initplans_metainfo

ArrayRef of Hashrefs, where each hashref can contains:

=over

=item * 'name' - name of the InitPlan, generally number

=item * 'returns' - string listing what the initplan returns. Generally a list of $X values (where X is 0 or positive integer) separated by comma.

=back

For more details, check ->add_initplan method description.

=head2 subplans

ArrayRef of Pg::Explain::Node objects, which represent sub plan.

For more details, check ->add_subplan method description.

=head2 ctes

HashRef of Pg::Explain::Node objects, which represent CTE plans.

For more details, check ->add_cte method description.

=head2 cte_order

ArrayRef of names of CTE nodes in given node.

For more details, check ->add_cte method description.

=head2 never_executed

Returns true if given node was not executed, according to plan.

=head2 parent

Parent node of current node, or undef if it's top node.

=head2 exclusive_fix

Numeric value that will be added to total_exclusive_time. It is set by Pg::Explain::check_for_exclusive_time_fixes method once after parsing the explain.

=cut

sub id                     { my $self = shift; return $self->{ 'id' }; }
sub actual_loops           { my $self = shift; $self->{ 'actual_loops' }           = $_[ 0 ] if 0 < scalar @_; return $self->{ 'actual_loops' }; }
sub actual_rows            { my $self = shift; $self->{ 'actual_rows' }            = $_[ 0 ] if 0 < scalar @_; return $self->{ 'actual_rows' }; }
sub actual_time_first      { my $self = shift; $self->{ 'actual_time_first' }      = $_[ 0 ] if 0 < scalar @_; return $self->{ 'actual_time_first' }; }
sub actual_time_last       { my $self = shift; $self->{ 'actual_time_last' }       = $_[ 0 ] if 0 < scalar @_; return $self->{ 'actual_time_last' }; }
sub cte_order              { my $self = shift; $self->{ 'cte_order' }              = $_[ 0 ] if 0 < scalar @_; return $self->{ 'cte_order' }; }
sub ctes                   { my $self = shift; $self->{ 'ctes' }                   = $_[ 0 ] if 0 < scalar @_; return $self->{ 'ctes' }; }
sub estimated_rows         { my $self = shift; $self->{ 'estimated_rows' }         = $_[ 0 ] if 0 < scalar @_; return $self->{ 'estimated_rows' }; }
sub estimated_row_width    { my $self = shift; $self->{ 'estimated_row_width' }    = $_[ 0 ] if 0 < scalar @_; return $self->{ 'estimated_row_width' }; }
sub estimated_startup_cost { my $self = shift; $self->{ 'estimated_startup_cost' } = $_[ 0 ] if 0 < scalar @_; return $self->{ 'estimated_startup_cost' }; }
sub estimated_total_cost   { my $self = shift; $self->{ 'estimated_total_cost' }   = $_[ 0 ] if 0 < scalar @_; return $self->{ 'estimated_total_cost' }; }
sub extra_info             { my $self = shift; $self->{ 'extra_info' }             = $_[ 0 ] if 0 < scalar @_; return $self->{ 'extra_info' }; }
sub initplans              { my $self = shift; $self->{ 'initplans' }              = $_[ 0 ] if 0 < scalar @_; return $self->{ 'initplans' }; }
sub initplans_metainfo     { my $self = shift; $self->{ 'initplans_metainfo' }     = $_[ 0 ] if 0 < scalar @_; return $self->{ 'initplans_metainfo' }; }
sub never_executed         { my $self = shift; $self->{ 'never_executed' }         = $_[ 0 ] if 0 < scalar @_; return $self->{ 'never_executed' }; }
sub parent                 { my $self = shift; $self->{ 'parent' }                 = $_[ 0 ] if 0 < scalar @_; return $self->{ 'parent' }; }
sub scan_on                { my $self = shift; $self->{ 'scan_on' }                = $_[ 0 ] if 0 < scalar @_; return $self->{ 'scan_on' }; }
sub sub_nodes              { my $self = shift; $self->{ 'sub_nodes' }              = $_[ 0 ] if 0 < scalar @_; return $self->{ 'sub_nodes' }; }
sub subplans               { my $self = shift; $self->{ 'subplans' }               = $_[ 0 ] if 0 < scalar @_; return $self->{ 'subplans' }; }
sub type                   { my $self = shift; $self->{ 'type' }                   = $_[ 0 ] if 0 < scalar @_; return $self->{ 'type' }; }
sub workers_launched       { my $self = shift; $self->{ 'workers_launched' }       = $_[ 0 ] if 0 < scalar @_; return $self->{ 'workers_launched' }; }
sub workers                { my $self = shift; $self->{ 'workers' }                = $_[ 0 ] if 0 < scalar @_; return $self->{ 'workers' } || 1; }
sub buffers                { my $self = shift; $self->{ 'buffers' }                = $_[ 0 ] if 0 < scalar @_; return $self->{ 'buffers' }; }
sub exclusive_fix          { my $self = shift; $self->{ 'exclusive_fix' }          = $_[ 0 ] if 0 < scalar @_; return $self->{ 'exclusive_fix' } // 0; }

=head2 new

Object constructor.

=cut

sub new {
    my $class = shift;
    my $self  = bless { 'id' => $base_id++ }, $class;

    my %args;
    if ( 0 == scalar @_ ) {
        croak( 'Args should be passed as either hash or hashref' );
    }
    if ( 1 == scalar @_ ) {
        if ( 'HASH' eq ref $_[ 0 ] ) {
            %args = @{ $_[ 0 ] };
        }
        else {
            croak( 'Args should be passed as either hash or hashref' );
        }
    }
    elsif ( 1 == ( scalar( @_ ) % 2 ) ) {
        croak( 'Args should be passed as either hash or hashref' );
    }
    else {
        %args = @_;
    }
    croak( 'type has to be passed to constructor of explain node' ) unless defined $args{ 'type' };

    # Backfill costs if they are not given from plan
    for my $key ( qw( estimated_rows estimated_row_width estimated_startup_cost estimated_total_cost ) ) {
        $args{ $key } = 0 unless defined $args{ $key };
    }

    @{ $self }{ keys %args } = values %args;

    if (
        $self->type =~ m{ \A (
            (?: Parallel \s+ )?
            (?: Seq \s Scan | Tid \s+ Scan | Bitmap \s+ Heap \s+ Scan | Foreign \s+ Scan | Update | Insert | Delete )
        ) \s on \s (\S+) (?: \s+ (\S+) ) ? \z }xms
       )
    {
        $self->type( $1 );
        $self->scan_on( { 'table_name' => $2, } );
        $self->scan_on->{ 'table_alias' } = $3 if defined $3;
    }
    elsif ( $self->type =~ m{ \A ( Bitmap \s+ Index \s+ Scan) \s on \s (\S+) \z }xms ) {
        $self->type( $1 );
        $self->scan_on( { 'index_name' => $2, } );
    }
    elsif ( $self->type =~ m{ \A ( (?: Parallel \s+ )? Index (?: \s Only )? \s Scan (?: \s Backward )? ) \s using \s (\S+) \s on \s (\S+) (?: \s+ (\S+) ) ? \z }xms ) {
        $self->type( $1 );
        $self->scan_on(
            {
                'index_name' => $2,
                'table_name' => $3,
            }
        );
        $self->scan_on->{ 'table_alias' } = $4 if defined $4;
    }
    elsif ( $self->type =~ m{ \A ( CTE \s Scan ) \s on \s (\S+) (?: \s+ (\S+) ) ? \z }xms ) {
        $self->type( $1 );
        $self->scan_on( { 'cte_name' => $2, } );
        $self->scan_on->{ 'cte_alias' } = $3 if defined $3;
    }
    elsif ( $self->type =~ m{ \A ( WorkTable \s Scan ) \s on \s (\S+) (?: \s+ (\S+) ) ? \z }xms ) {
        $self->type( $1 );
        $self->scan_on( { 'worktable_name' => $2, } );
        $self->scan_on->{ 'worktable_alias' } = $3 if defined $3;
    }
    elsif ( $self->type =~ m{ \A ( Function \s Scan ) \s on \s (\S+) (?: \s+ (\S+) )? \z }xms ) {
        $self->type( $1 );
        $self->scan_on( { 'function_name' => $2, } );
        $self->scan_on->{ 'function_alias' } = $3 if defined $3;
    }
    elsif ( $self->type =~ m{ \A ( Subquery \s Scan ) \s on \s (.+) \z }xms ) {
        $self->type( $1 );
        my $name = $2;
        $name =~ s{\A"(.*)"\z}{$1};
        $self->scan_on( { 'subquery_name' => $name, } );
    }
    return $self;
}

=head2 explain

Returns/sets Pg::Explain for this node.

Also, calls $explain->node( $id, $self );

=cut

sub explain {
    my $self    = shift;
    my $explain = shift;
    if ( defined $explain ) {
        $self->{ 'explain' } = $explain;
        $explain->node( $self->id, $self );
    }
    return $self->{ 'explain' };
}

=head2 add_extra_info

Adds new line of extra information to explain node.

It will be available at $node->extra_info (returns arrayref)

Extra_info is used by some nodes to provide additional information. For example
- for Sort nodes, they usually contain informtion about used memory, used sort
method and keys.

=cut

sub add_extra_info {
    my $self = shift;
    if ( $self->extra_info ) {
        push @{ $self->extra_info }, @_;
    }
    else {
        $self->extra_info( [ @_ ] );
    }
    return;
}

=head2 add_trigger_time

Adds new information about trigger time.

It will be available at $node->trigger_times (returns arrayref)

=cut

sub add_trigger_time {
    my $self = shift;
    if ( $self->trigger_times ) {
        push @{ $self->trigger_times }, @_;
    }
    else {
        $self->trigger_times( [ @_ ] );
    }
    return;
}

=head2 add_subplan

Adds new subplan node.

It will be available at $node->subplans (returns arrayref)

Example of plan with subplan:

 # explain select *, (select oid::int4 from pg_class c2 where c2.relname = c.relname) - oid::int4 from pg_class c;
                                               QUERY PLAN
 ------------------------------------------------------------------------------------------------------
  Seq Scan on pg_class c  (cost=0.00..1885.60 rows=227 width=200)
    SubPlan
      ->  Index Scan using pg_class_relname_nsp_index on pg_class c2  (cost=0.00..8.27 rows=1 width=4)
            Index Cond: (relname = $0)
 (4 rows)


=cut

sub add_subplan {
    my $self  = shift;
    my @nodes = map { $_->parent( $self ); $_ } @_;
    if ( $self->subplans ) {
        push @{ $self->subplans }, @nodes;
    }
    else {
        $self->subplans( [ @nodes ] );
    }
    return;
}

=head2 add_initplan

Adds new initplan node.

Expects to get node object and hashred with metainformation.

It will be available at $node->initplans (returns arrayref) and $node->initplans_metainfo (also arrayref);

Example of plan with initplan:

 # explain analyze select 1 = (select 1);
                                          QUERY PLAN
 --------------------------------------------------------------------------------------------
  Result  (cost=0.01..0.02 rows=1 width=0) (actual time=0.033..0.035 rows=1 loops=1)
    InitPlan
      ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.003..0.005 rows=1 loops=1)
  Total runtime: 0.234 ms
 (4 rows)

=cut

sub add_initplan {
    my $self = shift;
    my ( $node, $node_info ) = @_;

    $self->initplans( [] )          unless $self->initplans;
    $self->initplans_metainfo( [] ) unless $self->initplans_metainfo;

    $node->parent( $self );
    push @{ $self->initplans },          $node;
    push @{ $self->initplans_metainfo }, $node_info;
    return;
}

=head2 add_cte

Adds new cte node. CTE has to be named, so this function requires 2 arguments: name, and cte object itself.

It will be available at $node->cte( name ), or $node->ctes (returns hashref).

Since we need order (ctes are stored unordered, in hash), there is also $node->cte_order() which returns arrayref of names.

=cut

sub add_cte {
    my $self = shift;
    my ( $name, $cte ) = @_;
    $cte->parent( $self );

    if ( $self->ctes ) {
        $self->ctes->{ $name } = $cte;
        push @{ $self->cte_order }, $name;
    }
    else {
        $self->ctes( { $name => $cte } );
        $self->cte_order( [ $name ] );
    }
    return;
}

=head2 cte

Returns CTE object that has given name.

=cut

sub cte {
    my $self = shift;
    my $name = shift;
    return $self->ctes->{ $name };
}

=head2 add_sub_node

Adds new sub node.

It will be available at $node->sub_nodes (returns arrayref)

Sub nodes are nodes that are used by given node as data sources.

For example - "Join" node, has 2 sources (sub_nodes), which are table scans (Seq Scan, Index Scan or Backward Index Scan) over some tables.

Example plan which contains subnode:

 # explain select * from test limit 1;
                           QUERY PLAN
 --------------------------------------------------------------
  Limit  (cost=0.00..0.01 rows=1 width=4)
    ->  Seq Scan on test  (cost=0.00..14.00 rows=1000 width=4)
 (2 rows)

Node 'Limit' has 1 sub_plan, which is "Seq Scan"

=cut

sub add_sub_node {
    my $self  = shift;
    my @nodes = map { $_->parent( $self ); $_ } @_;
    if ( $self->sub_nodes ) {
        push @{ $self->sub_nodes }, @nodes;
    }
    else {
        $self->sub_nodes( [ @nodes ] );
    }
    return;
}

=head2 get_struct

Function which returns simple, not blessed, hashref with all information about given explain node and it's children.

This can be used for debug purposes, or as a base to print information to user.

Output looks like this:

 {
     'estimated_rows'         => '10000',
     'estimated_row_width'    => '148',
     'estimated_startup_cost' => '0',
     'estimated_total_cost'   => '333',
     'scan_on'                => { 'table_name' => 'tenk1', },
     'type'                   => 'Seq Scan',
 }

=cut

sub get_struct {
    my $self  = shift;
    my $reply = {};

    $reply->{ 'estimated_row_width' }    = $self->estimated_row_width         if defined $self->estimated_row_width;
    $reply->{ 'estimated_rows' }         = $self->estimated_rows              if defined $self->estimated_rows;
    $reply->{ 'estimated_startup_cost' } = 0 + $self->estimated_startup_cost  if defined $self->estimated_startup_cost;    # "0+" to remove .00 in case of integers
    $reply->{ 'estimated_total_cost' }   = 0 + $self->estimated_total_cost    if defined $self->estimated_total_cost;      # "0+" to remove .00 in case of integers
    $reply->{ 'actual_loops' }           = $self->actual_loops                if defined $self->actual_loops;
    $reply->{ 'actual_rows' }            = $self->actual_rows                 if defined $self->actual_rows;
    $reply->{ 'actual_time_first' }      = 0 + $self->actual_time_first       if defined $self->actual_time_first;         # "0+" to remove .00 in case of integers
    $reply->{ 'actual_time_last' }       = 0 + $self->actual_time_last        if defined $self->actual_time_last;          # "0+" to remove .00 in case of integers
    $reply->{ 'type' }                   = $self->type                        if defined $self->type;
    $reply->{ 'scan_on' }                = clone( $self->scan_on )            if defined $self->scan_on;
    $reply->{ 'extra_info' }             = clone( $self->extra_info )         if defined $self->extra_info;
    $reply->{ 'initplans_metainfo' }     = clone( $self->initplans_metainfo ) if defined $self->initplans_metainfo;

    $reply->{ 'is_analyzed' } = $self->is_analyzed;

    $reply->{ 'sub_nodes' } = [ map { $_->get_struct } @{ $self->sub_nodes } ] if defined $self->sub_nodes;
    $reply->{ 'initplans' } = [ map { $_->get_struct } @{ $self->initplans } ] if defined $self->initplans;
    $reply->{ 'subplans' }  = [ map { $_->get_struct } @{ $self->subplans } ]  if defined $self->subplans;

    $reply->{ 'buffers' } = $self->buffers->get_struct() if $self->buffers;

    $reply->{ 'cte_order' } = clone( $self->cte_order ) if defined $self->cte_order;
    if ( defined $self->ctes ) {
        $reply->{ 'ctes' } = {};
        while ( my ( $key, $cte_node ) = each %{ $self->ctes } ) {
            my $struct = $cte_node->get_struct;
            $reply->{ 'ctes' }->{ $key } = $struct;
        }
    }
    return $reply;
}

=head2 total_inclusive_time

Method for getting total node time, summarized with times of all subnodes, subplans and initplans - which is basically ->actual_loops * ->actual_time_last.

=cut

sub total_inclusive_time {
    my $self = shift;
    return unless defined $self->actual_time_last;
    return unless defined $self->actual_loops;
    return $self->actual_loops * $self->actual_time_last / $self->workers;
}

=head2 total_rows

Method for getting total number of rows returned by current node. This takes into account parallelization and multiple loops.

=cut

sub total_rows {
    my $self = shift;
    return unless defined $self->actual_time_last;
    return unless defined $self->actual_loops;
    return $self->actual_loops * $self->actual_rows if 1 == $self->workers;
    return $self->workers * $self->actual_rows;
}

=head2 total_rows_removed

Sum of rows removed by:

=over

=item * Conflict Filter

=item * Filter

=item * Index Recheck

=item * Join Filter

=back

in given node.

=cut

sub total_rows_removed {
    my $self = shift;
    return 0 unless $self->extra_info;
    my $removed = 0;
    for my $line ( @{ $self->extra_info } ) {
        next unless $line =~ m{^Rows Removed by (?:Conflict Filter|Filter|Index Recheck|Join Filter): (\d+)$};
        $removed += $1;
    }
    return $self->actual_loops * $removed if 1 == $self->workers;
    return $self->workers * $removed;
}

=head2 total_exclusive_time

Method for getting total node time, without times of subnodes - which amounts to time PostgreSQL spent running this paricular node.

=cut

sub total_exclusive_time {
    my $self = shift;

    my $time = $self->total_inclusive_time;
    return unless defined $time;

    for my $node ( map { @{ $_ } } grep { defined $_ } ( $self->sub_nodes ) ) {
        $time -= ( $node->total_inclusive_time || 0 );
    }

    for my $plan ( map { @{ $_ } } grep { defined $_ } ( $self->subplans ) ) {
        $time -= ( $plan->total_inclusive_time || 0 );
    }

    # Apply fix from ->exclusive_fix
    $time += $self->exclusive_fix;

    # ignore negative times - these come from rounding errors on nodes with loops > 1.
    return 0 if $time < 0;

    return $time;
}

=head2 total_exclusive_buffers

Method for getting total buffers used by node, without buffers used by subnodes.

=cut

sub total_exclusive_buffers {
    my $self = shift;

    return unless $self->buffers;

    my @nodes = grep { $_->buffers } $self->all_subnodes;
    return $self->buffers if 0 == scalar @nodes;

    my $sub_node_buffers = $nodes[ 0 ]->buffers;
    shift @nodes;
    for my $n ( @nodes ) {
        $sub_node_buffers = $sub_node_buffers + $n->buffers;
    }

    return $self->buffers - $sub_node_buffers;
}

=head2 all_subnodes

Returns list of all subnodes of current node.

=cut

sub all_subnodes {
    my $self  = shift;
    my @nodes = ();
    push @nodes, @{ $self->sub_nodes }   if $self->sub_nodes;
    push @nodes, @{ $self->initplans }   if $self->initplans;
    push @nodes, @{ $self->subplans }    if $self->subplans;
    push @nodes, values %{ $self->ctes } if $self->ctes;
    return @nodes;
}

=head2 all_recursive_subnodes

Returns list of all subnodes of current node and its subnodes, and their subnodes, and ...

=cut

sub all_recursive_subnodes {
    my $self  = shift;
    my @nodes = ();
    push @nodes, @{ $self->sub_nodes }   if $self->sub_nodes;
    push @nodes, @{ $self->initplans }   if $self->initplans;
    push @nodes, @{ $self->subplans }    if $self->subplans;
    push @nodes, values %{ $self->ctes } if $self->ctes;

    return map { $_, $_->all_recursive_subnodes } @nodes;
}

=head2 all_parents

Returns list of all nodes that are "above" given node in explain.

List can be empty if it's top level node.

=cut

sub all_parents {
    my $self    = shift;
    my @nodes   = ();
    my $current = $self;
    while ( my $next = $current->parent ) {
        unshift @nodes, $next;
        $current = $next;
    }
    return @nodes;
}

=head2 is_analyzed

Returns 1 if the explain node it represents was generated by EXPLAIN ANALYZE. 0 otherwise.

=cut

sub is_analyzed {
    my $self = shift;

    return defined $self->actual_loops || $self->never_executed ? 1 : 0;
}

=head2 as_text

Returns textual representation of explain nodes from given node down.

This is used to build textual explains out of in-memory data structures.

=cut

sub as_text {
    my $self   = shift;
    my $prefix = shift;
    $prefix = '' unless defined $prefix;

    $prefix .= '->  ' if '' ne $prefix;
    my $prefix_on_spaces = $prefix . "  ";
    $prefix_on_spaces =~ s/[^ ]/ /g;

    my $heading_line = $self->type;

    if ( $self->scan_on ) {
        my $S = $self->scan_on;
        if ( $S->{ 'cte_name' } ) {
            $heading_line .= " on " . $S->{ 'cte_name' };
            $heading_line .= " " . $S->{ 'cte_alias' } if $S->{ 'cte_alias' };
        }
        elsif ( $S->{ 'function_name' } ) {
            $heading_line .= " on " . $S->{ 'function_name' };
            $heading_line .= " " . $S->{ 'function_alias' } if $S->{ 'function_alias' };
        }
        elsif ( $S->{ 'index_name' } ) {
            if ( $S->{ 'table_name' } ) {
                $heading_line .= " using " . $S->{ 'index_name' } . " on " . $S->{ 'table_name' };
                $heading_line .= " " . $S->{ 'table_alias' } if $S->{ 'table_alias' };
            }
            else {
                $heading_line .= " on " . $S->{ 'index_name' };
            }
        }
        elsif ( $S->{ 'subquery_name' } ) {
            $heading_line .= " on " . $S->{ 'subquery_name' },;
        }
        elsif ( $S->{ 'worktable_name' } ) {
            $heading_line .= " on " . $S->{ 'worktable_name' },;
            $heading_line .= " " . $S->{ 'worktable_alias' } if $S->{ 'worktable_alias' };
        }
        else {
            $heading_line .= " on " . $S->{ 'table_name' };
            $heading_line .= " " . $S->{ 'table_alias' } if $S->{ 'table_alias' };
        }
    }
    $heading_line .= sprintf '  (cost=%.2f..%.2f rows=%s width=%d)', $self->estimated_startup_cost, $self->estimated_total_cost, $self->estimated_rows, $self->estimated_row_width;
    if ( $self->is_analyzed ) {
        my $inner;
        if ( $self->never_executed ) {
            $inner = 'never executed';
        }
        elsif ( defined $self->actual_time_last ) {
            $inner = sprintf 'actual time=%.3f..%.3f rows=%s loops=%d', $self->actual_time_first, $self->actual_time_last, $self->actual_rows, $self->actual_loops;
        }
        else {
            $inner = sprintf 'actual rows=%s loops=%d', $self->actual_rows, $self->actual_loops;
        }
        $heading_line .= " ($inner)";
    }

    my @lines = ();

    push @lines, $prefix . $heading_line;
    if ( $self->extra_info ) {
        push @lines, $prefix_on_spaces . "  " . $_ for @{ $self->extra_info };
    }
    my $textual = join( "\n", @lines ) . "\n";
    if ( $self->buffers ) {
        my $buf_info = $self->buffers->as_text;
        $buf_info =~ s/^/${prefix_on_spaces}/gm;
        $textual .= $buf_info . "\n";
    }

    if ( $self->cte_order ) {
        for my $cte_name ( @{ $self->cte_order } ) {
            $textual .= $prefix_on_spaces . "CTE " . $cte_name . "\n";
            $textual .= $self->cte( $cte_name )->as_text( $prefix_on_spaces . "    " );
        }
    }

    if ( $self->initplans ) {
        for my $i ( 0 .. $#{ $self->initplans } ) {
            my $ip   = $self->initplans->[ $i ];
            my $meta = $self->initplans_metainfo->[ $i ];
            my $init_name;
            if ( $meta ) {
                $init_name = sprintf "InitPlan %d (returns %s)\n", $meta->{ 'name' }, $meta->{ 'returns' };
            }
            else {
                $init_name = "InitPlan\n";
            }
            $textual .= $prefix_on_spaces . $init_name;
            $textual .= $ip->as_text( $prefix_on_spaces . "  " );
        }
    }
    if ( $self->sub_nodes ) {
        $textual .= $_->as_text( $prefix_on_spaces ) for @{ $self->sub_nodes };
    }
    if ( $self->subplans ) {
        for my $ip ( @{ $self->subplans } ) {
            $textual .= $prefix_on_spaces . "SubPlan\n";
            $textual .= $ip->as_text( $prefix_on_spaces . "  " );
        }
    }
    return $textual;
}

=head2 anonymize_gathering

First stage of anonymization - gathering of all possible strings that could and should be anonymized.

=cut

sub anonymize_gathering {
    my $self       = shift;
    my $anonymizer = shift;

    if ( $self->scan_on ) {
        $anonymizer->add( values %{ $self->scan_on } );
    }

    if ( $self->cte_order ) {
        $anonymizer->add( $self->{ 'cte_order' } );
    }

    if ( $self->extra_info ) {
        for my $line ( @{ $self->extra_info } ) {
            my $copy = $line;
            if ( $copy =~ m{^Foreign File:\s+(\S.*?)\s*$} ) {
                $anonymizer->add( $1 );
                next;
            }
            next unless $copy =~ s{^((?:Join Filter|Index Cond|Recheck Cond|Hash Cond|Merge Cond|Filter|Group Key|Sort Key|Output|One-Time Filter):\s+)(.*)$}{$2};
            my $prefix = $1;
            my $lexer  = $self->_make_lexer( $copy );
            while ( my $x = $lexer->() ) {
                next unless ref $x;
                $anonymizer->add( $x->[ 1 ] ) if $x->[ 0 ] =~ m{\A (?: STRING_LITERAL | QUOTED_IDENTIFIER | IDENTIFIER ) \z}x;
            }
        }
    }

    for my $key ( qw( sub_nodes initplans subplans ) ) {
        next unless $self->{ $key };
        $_->anonymize_gathering( $anonymizer ) for @{ $self->{ $key } };
    }

    if ( $self->{ 'ctes' } ) {
        $_->anonymize_gathering( $anonymizer ) for values %{ $self->{ 'ctes' } };
    }
    return;
}

=head2 _make_lexer

Helper function which creates HOP::Lexer based lexer for given line of input

=cut

sub _make_lexer {
    my $self = shift;
    my $data = shift;

    ## Got from PostgreSQL 9.2devel with:
    # SQL # with z as (
    # SQL #     select
    # SQL #         typname::text as a,
    # SQL #         oid::regtype::text as b
    # SQL #     from
    # SQL #         pg_type
    # SQL #     where
    # SQL #         typrelid = 0
    # SQL #         and typnamespace = 11
    # SQL # ),
    # SQL # d as (
    # SQL #     select a from z
    # SQL #     union
    # SQL #     select b from z
    # SQL # ),
    # SQL # f as (
    # SQL #     select distinct
    # SQL #         regexp_replace(
    # SQL #             regexp_replace(
    # SQL #                 regexp_replace( a, '^_', '' ),
    # SQL #                 E'\\[\\]$',
    # SQL #                 ''
    # SQL #             ),
    # SQL #             '^"(.*)"$',
    # SQL #             E'\\1'
    # SQL #         ) as t
    # SQL #     from
    # SQL #         d
    # SQL # )
    # SQL # select
    # SQL #     t
    # SQL # from
    # SQL #     f
    # SQL # order by
    # SQL #     length(t) desc,
    # SQL #     t asc;

    # Following regexp was generated by feeding list from above query to:
    # use Regexp::List;
    # my $q = Regexp::List->new();
    # print = $q->list2re( @_ );
    # It is faster than normal alternative regexp like:
    # (?:timestamp without time zone|timestamp with time zone|time without time zone|....|xid|xml)
    my $any_pgtype =
qr{(?-xism:(?=[abcdfgilmnoprstuvx])(?:t(?:i(?:me(?:stamp(?:\ with(?:out)?\ time\ zone|tz)?|\ with(?:out)?\ time\ zone|tz)?|nterval|d)|s(?:(?:tz)?range|vector|query)|(?:xid_snapsho|ex)t|rigger)|c(?:har(?:acter(?:\ varying)?)?|i(?:dr?|rcle)|string)|d(?:ate(?:range)?|ouble\ precision)|l(?:anguage_handler|ine|seg)|re(?:g(?:proc(?:edure)?|oper(?:ator)?|c(?:onfig|lass)|dictionary|type)|fcursor|ltime|cord|al)|p(?:o(?:lygon|int)|g_node_tree|ath)|a(?:ny(?:e(?:lement|num)|(?:non)?array|range)?|bstime|clitem)|b(?:i(?:t(?:\ varying)?|gint)|o(?:ol(?:ean)?|x)|pchar|ytea)|f(?:loat[48]|dw_handler)|in(?:t(?:2(?:vector)?|4(?:range)?|8(?:range)?|e(?:r[nv]al|ger))|et)|o(?:id(?:vector)?|paque)|n(?:um(?:range|eric)|ame)|sm(?:allint|gr)|m(?:acaddr|oney)|u(?:nknown|uid)|v(?:ar(?:char|bit)|oid)|x(?:id|ml)|gtsvector))};

    my @input_tokens = (
        [ 'STRING_LITERAL',    qr{'(?:''|[^']+)+'} ],
        [ 'PGTYPECAST',        qr{::"?_?$any_pgtype"?(?:\[\])?} ],
        [ 'QUOTED_IDENTIFIER', qr{"(?:""|[^"]+)+"} ],
        [ 'AND',               qr{\bAND\b}i ],
        [ 'ANY',               qr{\bANY\b}i ],
        [ 'ARRAY',             qr{\bARRAY\b}i ],
        [ 'AS',                qr{\bAS\b}i ],
        [ 'ASC',               qr{\bASC\b}i ],
        [ 'CASE',              qr{\bCASE\b}i ],
        [ 'CAST',              qr{\bCAST\b}i ],
        [ 'CHECK',             qr{\bCHECK\b}i ],
        [ 'COLLATE',           qr{\bCOLLATE\b}i ],
        [ 'COLUMN',            qr{\bCOLUMN\b}i ],
        [ 'CURRENT_CATALOG',   qr{\bCURRENT_CATALOG\b}i ],
        [ 'CURRENT_DATE',      qr{\bCURRENT_DATE\b}i ],
        [ 'CURRENT_ROLE',      qr{\bCURRENT_ROLE\b}i ],
        [ 'CURRENT_TIME',      qr{\bCURRENT_TIME\b}i ],
        [ 'CURRENT_TIMESTAMP', qr{\bCURRENT_TIMESTAMP\b}i ],
        [ 'CURRENT_USER',      qr{\bCURRENT_USER\b}i ],
        [ 'DEFAULT',           qr{\bDEFAULT\b}i ],
        [ 'DESC',              qr{\bDESC\b}i ],
        [ 'DISTINCT',          qr{\bDISTINCT\b}i ],
        [ 'DO',                qr{\bDO\b}i ],
        [ 'ELSE',              qr{\bELSE\b}i ],
        [ 'END',               qr{\bEND\b}i ],
        [ 'EXCEPT',            qr{\bEXCEPT\b}i ],
        [ 'FALSE',             qr{\bFALSE\b}i ],
        [ 'FETCH',             qr{\bFETCH\b}i ],
        [ 'FOR',               qr{\bFOR\b}i ],
        [ 'FOREIGN',           qr{\bFOREIGN\b}i ],
        [ 'FROM',              qr{\bFROM\b}i ],
        [ 'IN',                qr{\bIN\b}i ],
        [ 'INITIALLY',         qr{\bINITIALLY\b}i ],
        [ 'INTERSECT',         qr{\bINTERSECT\b}i ],
        [ 'INTO',              qr{\bINTO\b}i ],
        [ 'LEADING',           qr{\bLEADING\b}i ],
        [ 'LIMIT',             qr{\bLIMIT\b}i ],
        [ 'LOCALTIME',         qr{\bLOCALTIME\b}i ],
        [ 'LOCALTIMESTAMP',    qr{\bLOCALTIMESTAMP\b}i ],
        [ 'NOT',               qr{\bNOT\b}i ],
        [ 'NULL',              qr{\bNULL\b}i ],
        [ 'OFFSET',            qr{\bOFFSET\b}i ],
        [ 'ON',                qr{\bON\b}i ],
        [ 'ONLY',              qr{\bONLY\b}i ],
        [ 'OR',                qr{\bOR\b}i ],
        [ 'ORDER',             qr{\bORDER\b}i ],
        [ 'PLACING',           qr{\bPLACING\b}i ],
        [ 'PRIMARY',           qr{\bPRIMARY\b}i ],
        [ 'REFERENCES',        qr{\bREFERENCES\b}i ],
        [ 'RETURNING',         qr{\bRETURNING\b}i ],
        [ 'SESSION_USER',      qr{\bSESSION_USER\b}i ],
        [ 'SOME',              qr{\bSOME\b}i ],
        [ 'SYMMETRIC',         qr{\bSYMMETRIC\b}i ],
        [ 'THEN',              qr{\bTHEN\b}i ],
        [ 'TO',                qr{\bTO\b}i ],
        [ 'TRAILING',          qr{\bTRAILING\b}i ],
        [ 'TRUE',              qr{\bTRUE\b}i ],
        [ 'UNION',             qr{\bUNION\b}i ],
        [ 'UNIQUE',            qr{\bUNIQUE\b}i ],
        [ 'USER',              qr{\bUSER\b}i ],
        [ 'USING',             qr{\bUSING\b}i ],
        [ 'WHEN',              qr{\bWHEN\b}i ],
        [ 'WHERE',             qr{\bWHERE\b}i ],
        [ 'CAST:',             qr{::}i ],
        [ 'COMMA',             qr{,}i ],
        [ 'DOT',               qr{\.}i ],
        [ 'LEFT_PARENTHESIS',  qr{\(}i ],
        [ 'RIGHT_PARENTHESIS', qr{\)}i ],
        [ 'DOT',               qr{\.}i ],
        [ 'STAR',              qr{[*]} ],
        [ 'OP',                qr{[+=/<>!~@-]} ],
        [ 'NUM',               qr{-?(?:\d*\.\d+|\d+)} ],
        [ 'IDENTIFIER',        qr{[a-z_][a-z0-9_]*}i ],
        [ 'SPACE',             qr{\s+} ],
    );
    return string_lexer( $data, @input_tokens );
}

=head2 anonymize_substitute

Second stage of anonymization - actual changing strings into anonymized versions.

=cut

sub anonymize_substitute {
    my $self       = shift;
    my $anonymizer = shift;

    if ( $self->scan_on ) {
        while ( my ( $key, $value ) = each %{ $self->scan_on } ) {
            $self->scan_on->{ $key } = $anonymizer->anonymized( $value );
        }
    }

    if ( $self->cte_order ) {
        my @new_order = ();
        for my $cte_name ( @{ $self->cte_order } ) {
            my $new_name = $anonymizer->anonymized( $cte_name );
            push @new_order, $new_name;
            $self->ctes->{ $new_name } = delete $self->{ 'ctes' }->{ $cte_name };
        }
        $self->cte_order( \@new_order );
    }

    if ( $self->extra_info ) {
        my @new_extra_info = ();
        for my $line ( @{ $self->extra_info } ) {
            if ( $line =~ m{^(Foreign File:\s+)(\S.*?)(\s*)$} ) {
                push @new_extra_info, $1 . $anonymizer->anonymized( $2 ) . $3;
                next;
            }
            unless ( $line =~ s{^((?:Join Filter|Index Cond|Recheck Cond|Hash Cond|Merge Cond|Filter|Group Key|Sort Key|Output|One-Time Filter):\s+)(.*)$}{$2} ) {
                push @new_extra_info, $line;
                next;
            }
            my $output = $1;
            my $lexer  = $self->_make_lexer( $line );
            while ( my $x = $lexer->() ) {
                if ( ref $x ) {
                    if ( $x->[ 0 ] eq 'STRING_LITERAL' ) {
                        $output .= "'" . $anonymizer->anonymized( $x->[ 1 ] ) . "'";
                    }
                    elsif ( $x->[ 0 ] eq 'QUOTED_IDENTIFIER' ) {
                        $output .= '"' . $anonymizer->anonymized( $x->[ 1 ] ) . '"';
                    }
                    elsif ( $x->[ 0 ] eq 'IDENTIFIER' ) {
                        $output .= $anonymizer->anonymized( $x->[ 1 ] );
                    }
                    else {
                        $output .= $x->[ 1 ];
                    }
                }
                else {
                    $output .= $x;
                }
            }
            push @new_extra_info, $output;
        }
        $self->{ 'extra_info' } = \@new_extra_info;
    }

    for my $key ( qw( sub_nodes initplans subplans ) ) {
        next unless $self->{ $key };
        $_->anonymize_substitute( $anonymizer ) for @{ $self->{ $key } };
    }

    if ( $self->{ 'ctes' } ) {
        $_->anonymize_substitute( $anonymizer ) for values %{ $self->{ 'ctes' } };
    }
    return;
}

=head1 AUTHOR

hubert depesz lubaczewski, C<< <depesz at depesz.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<depesz at depesz.com>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Pg::Explain::Node

=head1 COPYRIGHT & LICENSE

Copyright 2008-2023 hubert depesz lubaczewski, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Pg::Explain::Node
