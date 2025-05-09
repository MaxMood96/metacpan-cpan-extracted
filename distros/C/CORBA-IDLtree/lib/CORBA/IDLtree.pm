# CORBA/IDLtree.pm   IDL to symbol tree translator
# This module is distributed under the same terms as Perl itself.
# Copyright  (C) 1998-2025, O. Kellogg <olivermkellogg@gail.com>
# Main Authors:  Oliver Kellogg, Heiko Schroeder
#
# -----------------------------------------------------------------------------
# Ver. |   Date   | Recent changes (for complete history see file Changes)
# -----+----------+------------------------------------------------------------
# 2.06  2025-04-20  * In the SUBORDINATES of ENUM, when $enable_comments is set
#                     change the layout for a comment to conform to the REMARK
#                     node layout.
#                   * Change sub info to only print if $verbose is set.
#                   * Fix handling of annotations applied on members of
#                     constructed types.
#                   * On encountering unknown annotation, downgrade severity
#                     from error to warning.
# 2.05  2021/06/13  * Increase minimum required perl version to 5.8 due to
#                     addition of "use utf8".
#                   * Add handling of Windows CP-1252 character encoding in
#                     input file:
#                     - Add `use utf8`.
#                     - Require module Encode::Guess.
#                     - In sub get_items:
#                       - On encountering a non printable character call
#                         Encode::Guess->guess.
#                       - If the call returns a ref then a decoder was found
#                         and no special action is required.
#                       - If the call returns "No appropriate encodings found"
#                         then assign $l from Encode::decode("cp-1252", $l).
#                       - If the call returns none of the above then print a
#                         warning "Unsupported character encoding" and replace
#                         the non printable characters in $l by space.
#                     - In sub Parse_File_i case $file case $emucpp call to
#                       `open $in`, the encoding directive for UTF-8 is no
#                       longer needed due to use of Encode::Guess (see above).
#                   * In sub skip_input fix handling of preprocessor directives
#                     where the "#" is not placed in column 1 but is preceded by
#                     whitespace.
#                   * Fix sub scoped_name in case of chained module reopenings.
#
# 2.04  2020/06/20  * In sub Parse_File_i case $file case $emucpp open $in
#                     with encoding(UTF-8) to ensure that IDL files are parsed
#                     as utf8.
#                   * New sub discard_bom discards a possible Unicode or UTF-8
#                     BOM (Byte Order Mark) at the start of the given line.
#                     In sub get_items add optional argument $firstline.
#                     If $firstline is given and true then discard_bom will be
#                     called on the first line read from file.
#                     In sub Parse_File_i outer while-loop add local
#                     $firstline for call to sub get_items.
#                   * New sub has_default_branch checks whether the given union
#                     subordinates contain a DEFAULT branch.  This fixes a bug
#                     related to checking that a union has an enum type as its
#                     switch and does not have a default branch.
#                     A false warning was generated in case the default branch
#                     was preceded by a comment.
#                   * Improvements to preprocessor emulation:
#                     - Support "#if defined XYZ" without parentheses around
#                       the symbol.  Fix evaluation of the symbol.
#                     - Do not attempt evaluating preprocessor directives when
#                       inside multi line comments.
#                     - Fix handling of #endif in nested #if/#ifdef/#ifndef.
#                   * In @annoDefs add java_mapping annotations defined by the
#                     IDL4 to Java mapping proposal.
# 2.03  2019/04/27  * Fixed a bug related to Dump_Symbols whereby when using
#                     a string array ref as the optional argument, repeated
#                     calls to the sub would accumulate the text.
#                   * In sub parse_members, optional argument $comment fixes
#                     processing of trailing comment at members of struct,
#                     exception, and valuetype.
# 2.02  2018/08/15  * Fixed a few typos in documentation.
#                   * Added support for IDL4 struct inheritance defined by the
#                     Building Block Extended Data-Types:
#                     In case of STRUCT, the first SUBORDINATES element of may
#                     be a reference to a further STRUCT node instead of the
#                     reference to quintuplet. In this case, the first element
#                     indicates the IDL4 parent struct type of the current
#                     struct.  The function isnode() can be used for detecting
#                     this case. The support for IDL4 struct inheritance is
#                     implemented in sub Parse_File_i case $kw eq 'struct'.
#                   * In sub is_elementary_type return early on undefined
#                     $tdesc.
#                   * In sub info check for valid $currfile and @infilename
#                     before accessing $infilename[$currfile].
#                   * In sub error avoid code duplication by reusing the
#                     implementation of sub info.
#                   * In sub dump_symbols_internal handling of METHOD, pop
#                     @arg only if @arg is non empty and $arg[-1] contains
#                     the exception list.  We need these extra tests because
#                     METHODs in VALUETYPEs do not have an exception list as
#                     the last element of the SUBORDINATES.
#                   * In sub dump_symbols_internal handling of REMARK nodes,
#                     on calling sub dump_comment swap elements of anonymous
#                     constructed array: $name comes first, then $subord.
#                     (COMMENT nodes use the same layout.)
# 2.01  2018/01/23  * Fixed parsing of named argument values in sub
#                     parse_annotation_app:  At case
#                       @$argref && $argref->[0] eq '('
#                     while-loop over @$argref case
#                       $val =~ /^[a-z]/i and $argref->[0] eq '='
#                     for-loop of $ai case
#                       $adef[$ai]->[1] eq $parname,
#                     after assigning $param_index execute `last' instead of
#                     `return'.
#                   * Declared globals %annoEnum and @annoDefs as `our' to
#                     make them accessible from outside.
#                   * Added 'port' to global %keywords.
#                   * Fixed calls to sub annotation so that more than one
#                     annotation may accumulate on a given IDL item.
#                   * Fixed changelog entry for v. 1.6 modification of REMARK
#                     NAME/SUBORDINATES.
# 2.00  2018/01/05  * Fixed parsing of parameterless annotation with empty
#                     @$argref in sub parse_annotation_app.
#                   * Changed version numbering to conform to CPAN format.
#                   * Based distro on skeleton generated by module-starter.
#                   * Started converting inline documentation to POD format.
#  1.6  2018/01/01  * Fixed parsing of inheritance from an absolute qualified
#                     superclass such as e.g.
#                     valuetype vt : ::absolute::qualified::superclass {...};
#                   * Added variable $global_idlfile, a copy of the file name
#                     passed into the most recent call to Parse_File.
#                   * Simplified the REMARK node as follows:
#                     - Its NAME contains the starting line number of the
#                       comment lines.
#                     - Its SUBORDINATES points to a simple array of lines.
#                       The file name and line number elements are no longer
#                       part of the lines array.
#                   * The COMMENT element now points to a tuple of (starting)
#                     line number and reference to simple array of lines.
#                     I.e. the file name and line number elements are no
#                     longer part of the lines array.
#                   * Added support for IDL4 standard annotations and user
#                     defined @annotation.  See below for documentation on
#                     the new node element ANNOTATIONS.
#                     IDL4 annotations are currently supported in the
#                     following locations:
#                     - Type declarations
#                     - Member declarations of structured types
#                     - Enum literal value declarations
#                     Modified the node structure of these constructs
#                     accordingly.
#                   * New sub enum_literals returns the net literals of an
#                     ENUM.  It is intended to shield against the node
#                     structure change at enum literals. Direct usages of
#                     enum SUBORDINATES should be replaced by calls to this
#                     sub when possible.
#                   * Removed support for non standard enum value repre-
#                     sentation as in: enum MyEnum { zero=0, one=1 };
#                     This is superseded by the @value annotation.
#  1.5  2017/07/23  The SCOPEREF of a MODULE now points to the previous
#                   opening of the module.
#                   Changed the COMMENT node element and the NAME element of
#                   the REMARK node as follows: Each element in the comment
#                   array is a ref to an array that contains the name of the
#                   file, the line number, and the comment text in that order.

package CORBA::IDLtree;

require Carp;
require Encode::Guess;

use 5.008_003;
use strict 'vars';
use utf8;
use warnings;
use Exporter qw(import);
use Math::BigInt;
use Config;

# @EXPORT = ();
# @EXPORT_OK = ();  # &Parse_File, &Dump_Symbols, and all the constants subs

use vars qw(@include_path %defines $cache_trees $global_idlfile
            $n_errors $enable_comments $struct2vt $vt2struct
            $cache_statistics $string_bound $permissive
            $long_double_supported $union_default_null_allowed
            $leading_underscore_allowed);

=head1 NAME

CORBA::IDLtree - OMG IDL to symbol tree translator

=head1 VERSION

Version 2.05

=cut

our $VERSION = '2.06';

=head1 SYNOPSIS

Subroutine Parse_File is the universal entry point (to be called by the
main program.)
It takes an IDL file name as the input parameter and parses that file,
constructing one or more symbol trees for the outermost declarations
encountered. It returns a reference to an array containing references
to those trees.
In case of errors during parsing, Parse_File returns 0.

Usage:

    use CORBA::IDLtree;

    my $ref_to_array_of_outermost_declarations = CORBA::IDLtree::Parse_File("myfile.idl");

    $ref_to_array_of_outermost_declarations or die "File had syntax errors\n";
    foreach my $node (@$ref_to_array_of_outermost_declarations) {
        # Query $node->[TYPE] to find out what each node is;
        # use $node->[SUBORDINATES] according to the $node->[TYPE].
        # For example:
        if ($node->[CORBA::IDLtree::TYPE] == CORBA::IDLtree::MODULE) {
            foreach my $subnode @{$node->[CORBA::IDLtree::SUBORDINATES]}) {
                # Assuming your "sub process" codes your business logic:
                &process($subnode);
            }
        } elsif ($node->[CORBA::IDLtree::TYPE] == CORBA::IDLtree::...) {
            # And so on, decode and process all the types you need ...
            # For further details see the demo application in subdir demoapp.
        }
    }

=head1 STRUCTURE OF THE SYMBOL TREE

A "thing" in the symbol tree can be either a reference to a node, or a
reference to an array of references to nodes.

Each node is a six element array with the elements

      [0] => TYPE (MODULE|INTERFACE|STRUCT|UNION|ENUM|TYPEDEF|CHAR|...)
      [1] => NAME
      [2] => SUBORDINATES
      [3] => ANNOTATIONS
      [4] => COMMENT
      [5] => SCOPEREF

The C<TYPE> element, instead of holding a type ID number (see the following
list under C<SUBORDINATES>), can also be a reference to the node defining the
type. When the C<TYPE> element can contain either a type ID or a reference to
the defining node, we will call it a I<type descriptor>.
Which of the two alternatives is in effect can be determined via the
C<isnode> function.

The C<NAME> element, unless specified otherwise, simply holds the name string
of the respective IDL syntactic item.

The C<SUBORDINATES> element depends on the type ID:

=over

=item MODULE or INTERFACE

Reference to an array of nodes (symbols) which are defined
within the module or interface. In the case of C<INTERFACE>,
element [0] in this array will contain a reference to a
further array which in turn contains references to the
parent interfaceZ<>(s) if inheritance is used, or the null
value if the current interface is not derived by
inheritance. Element [1] is the "local/abstract" flag
which is C<ABSTRACT> for abstract interfaces, or C<LOCAL> for
interfaces declared local.

=item INTERFACE_FWD

Reference to the node of the full interface declaration.

=item STRUCT or EXCEPTION

Reference to an array of node references representing the
member components of the struct or exception.
Each member representative node is a quintuplet consisting
of (C<TYPE>, C<NAME>, <dimref>, C<ANNOTATIONS>, C<COMMENT>).
The <dimref> is a reference to a list of dimension numbers,
or is 0 if no dimensions were given.
In case of STRUCT, the first element may be a reference to a
further STRUCT node instead of the reference to quintuplet.
In this case, the first element indicates the IDL4 parent
struct type of the current struct. The function isnode() can
be used for detecting this case.

=item UNION

Similar to C<STRUCT>/C<EXCEPTION>, reference to an array of
nodes. For union members, the member node has the same
structure as for STRUCT/EXCEPTION.
However, the first node contains a type descriptor for
the discriminant type. The switch node does not follow the
usual quadruplet structure of members; it is a single item.
The C<TYPE> of a member node may also be C<CASE> or C<DEFAULT>.
When the TYPE is CASE or DEFAULT, this means that the
following member node will be the union branch controlled
by the CASE or DEFAULT.
For C<CASE>, the C<NAME> is unused, and the C<SUBORDINATES> contains
a reference to a list of the case values for the following
member node.
For C<DEFAULT>, both the C<NAME> and the C<SUBORDINATES> are unused.

=item ENUM

Reference to an array where each element is a further reference to
an array.
In this array,

=over

=item * if C<$enable_comments> is set then the first element may be
numeric. In that case the element represents a comment using the same
layout as the REMARK node. The number is the starting line number of
the comment; the second element is unused, and the third element is a
reference to array containing the comment lines.

=item * otherwise the element describes an enum value. It then consists
of three elements: The first element is the enum literal value.  The
second element is a reference to an array of annotations as described
in the C<ANNOTATIONS> documentation (see below).  The third element is
a reference to the trailing comment list.

=back

=item TYPEDEF

Reference to a two-element array: element 0 contains a
reference to the type descriptor of the original type;
element 1 contains a reference to an array of dimension
expressions, or the null value if no dimensions are given.
When given, the dimension expressions are plain strings.

=item SEQUENCE

As a special case, the C<NAME> element of a C<SEQUENCE> node
does not contain a name (as sequences are anonymous
types), but instead is used to hold the bound number.
If the bound number is 0 then it is an unbounded
sequence. The C<SUBORDINATES> element contains the type
descriptor of the base type of the sequence. This
descriptor could itself be a reference to a C<SEQUENCE>
defining node (that is, a nested sequence definition.)

=item BOUNDED_STRING

Bounded strings are treated as a special case of sequence.
They are represented as references to a node that has
C<BOUNDED_STRING> or C<BOUNDED_WSTRING> as the type ID, the bound
number in the C<NAME>, and the C<SUBORDINATES> element is unused.

=item CONST

Reference to a two-element array. Element 0 is a type
descriptor of the const's type; element 1 is a reference
to an array containing the RHS expression symbols.

=item FIXED

Reference to a two-element array. Element 0 contains the
digit number and element 1 contains the scale factor.
The C<NAME> component in a C<FIXED> node is unused.

=item VALUETYPE

Uses the following structure:

      [0] => $is_abstract (boolean)
      [1] => reference to a tuple (two-element list) containing
             inheritance related information:
             [0] => $is_truncatable (boolean)
             [1] => \@ancestors (reference to array containing
                    references to ancestor nodes)
      [2] => \@members: reference to array containing references
             to tuples (two-element lists) of the form:
             [0] => 0|PRIVATE|PUBLIC
                    A zero for this value means the element [1]
                    contains a reference to a declaration, such
                    as a METHOD or ATTRIBUTE.
                    In case of METHOD, the first element in the
                    method node subordinates (i.e., the return
                    type) may be FACTORY.
                    However, unlike interface methods, the last
                    element is _not_ a reference to the 'raises'
                    list.  Support for 'raises' of valuetype
                    methods may be added in a future version.
             [1] => reference to the defining node.
                    In case of PRIVATE or PUBLIC state member,
                    the SUBORDINATES of the defining node
                    contains a dimref (reference to dimensions
                    list, see STRUCT.)

=item VALUETYPE_BOX

Reference to the defining type node.

=item VALUETYPE_FWD

Reference to the node of the full valuetype declaration.

=item NATIVE

Subordinates unused.

=item ATTRIBUTE

Reference to a two-element array; element 0 is the read-
only flag (0 for read/write attributes), element 1 is a
type descriptor of the attribute's type.

=item METHOD

Reference to a variable length array; element 0 is a type
descriptor for the return type. Elements 1 and following
are references to parameter descriptor nodes with the
following structure:

      elem. 0 => parameter type descriptor
      elem. 1 => parameter name
      elem. 2 => parameter mode (IN, OUT, or INOUT)

The last element in the variable-length array is a
reference to the "raises" list. This list contains
references to the declaration nodes of exceptions raised,
or is empty if there is no "raises" clause.

=item INCFILE

Reference to an array of nodes (symbols) which are defined
within the include file. The Name element of this node
contains the include file name.

=item PRAGMA_PREFIX

Subordinates unused.

=item PRAGMA_VERSION

Version string.

=item PRAGMA_ID

ID string.

=item PRAGMA

This is for the general case of pragmas that are none
of the above, i.e. pragmas unknown to IDLtree.
The C<NAME> holds the pragma name, and C<SUBORDINATES>
holds all further text appearing after the pragma name.

=item REMARK

The C<NAME> of the node contains the starting line number
of the comment text.
The C<SUBORDINATES> component contains a reference to a list
of comment lines. The comment lines are not newline
terminated.
The source line number of each comment line can be
computed by adding the starting line number and the
array index of the comment line.
By default, C<REMARK> nodes will not be generated;
generation of C<REMARK> nodes can be enabled by setting the
$enable_comments global variable to non zero.

=back

The C<ANNOTATIONS> element holds the reference to an array of annotation nodes
if IDL4 style annotations are present (if no annotations are present then
the ANNOTATIONS element holds 0).
Each entry in this array is an array reference.  The first element in the
array referenced is the index to an entry in @annoDefs (see comments at
declaration of @annoDefs).  The following elements contain the concrete
values for the parameters, in the order as defined by the entry in
@annoDefs.  If the user omitted the value of the parameter then the
default as specified by the entry in @annoDefs is filled in.

The C<COMMENT> element holds the comment text that follows the IDL declaration
on the same line. Usually this is just a single line. However, if a multi-
line comment is started on the same line after a declaration, the multi-line
comment may extend to further lines - therefore we use a list of lines.
The lines in this list are not newline terminated.  The C<COMMENT> field is a
reference to a tuple of starting line number and reference to the line list,
or contains 0 if no trailing comment is present at the IDL item.

The C<SCOPEREF> element is a reference back to the node of the module or
interface enclosing the current node. If the current node is already
at the global scope level then the C<SCOPEREF> is 0.
Special case: For a reopened module, the C<SCOPEREF> points to the previous
opening of the same module. In case of multiple reopenings, each reopening
points to the previous opening. The C<SCOPEREF> of the initial module finally
points to the enclosing scope.
All nodes have this element except for the parameter nodes of methods and
the component nodes of structs/unions/exceptions.

=head1 CLASS VARIABLES

=head2 Variables that can be set by client code

=over

=item @CORBA::IDLtree::include_path

Paths where to look for included IDL files.

=item %CORBA::IDLtree::defines

Symbol definitions for preprocessor.

=item $CORBA::IDLtree::cache_trees

Values 0 or 1, default 0.
By default, do not cache trees of C<#include>d files.

=item $CORBA::IDLtree::enable_comments

Values 0 or 1, default 0.
By default, do not generate C<REMARK> nodes.

=item $CORBA::IDLtree::struct2vt

Values 0 or 1, default 0.
Change struct into equivalent valuetype

=item $CORBA::IDLtree::vt2struct

Values 0 or 1, default 0.
Change valuetype into equivalent struct

=item $CORBA::IDLtree::cache_statistics

Values 0 or 1, default 0.
Print cache statistics

=item $CORBA::IDLtree::long_double_supported

Values 0 or 1, default 0.
Switch on support for IDL C<long double>.

=item $CORBA::IDLtree::union_default_null_allowed

Values 0 or 1, default 1.
Switch off permission that a C<union>'s C<default> branch may be empty.

=item $CORBA::IDLtree::leading_underscore_allowed

Value 1 will remove the leading underscore.
Value 2 will preserve the leading underscore.

=item $CORBA::IDLtree::permissive

Values 0 or 1, default 0.
By default, misuse of IDL keywords as identifiers is a hard error.

=back

=head2 Variables written by CORBA::IDLtree

These are to be considered read-only from outside:

=over

=item $CORBA::IDLtree::n_errors

Cumulative number of errors for a C<Parse_File> call.

=item $CORBA::IDLtree::global_idlfile

Copy of filename passed into most recent call of sub Parse_File

=back

=cut

# User definable auxiliary data for Parse_File:
@include_path = ();     # Paths where to look for included IDL files
%defines = ();          # Symbol definitions for preprocessor
$cache_trees = 0;       # By default, do not cache trees of #included files
$enable_comments = 0;   # By default, do not generate REMARK nodes.
$struct2vt = 0;         # change struct into equivalent valuetype
$vt2struct = 0;         # change valuetype into equivalent struct
$cache_statistics = 0;  # print cache statistics

$long_double_supported = 0;
$union_default_null_allowed = 1;
$leading_underscore_allowed = 0;  # value 1 will remove the leading underscore
                                  # value 2 will preserve the leading underscore
$permissive = 0;        # By default, misuse of IDL keywords is a hard error

# Variables written by CORBA::IDLtree (to be considered read-only from outside)

$n_errors = 0;          # Cumulative number of errors for a Parse_File call.
$global_idlfile = "";   # Copy of filename passed into most recent call of
                        # sub Parse_File

# Internal variables (should not be visible)

my $is64bit = $Config{ivsize} >= 8;

our $verbose = 0;          # report progress to stdout, set via sub set_verbose

my $comment_directives = undef;  # may be set to an IDLtree::Comment_Directives
                                 # object or derivative via set_directive_object

my %active_defines = ();  # used by #ifdef / #ifndef / #define / #undef processing

=head1 CONSTANTS

=head2 Constants for accessing the elements of a node

=over 2

=item Constants for indexing the elements of a node

As explained in STRUCTURE OF THE SYMBOL TREE, each node is represented as a
six element array. These constants are intended for indexing the array:

     sub TYPE ()         { 0 }
     sub NAME ()         { 1 }
     sub SUBORDINATES () { 2 }
     sub MODE ()         { 2 }
     sub ANNOTATIONS ()  { 3 }
     sub COMMENT ()      { 4 }
     sub SCOPEREF ()     { 5 }

The constant C<MODE> is an alias of C<SUBORDINATES> for method parameter nodes.

=cut

sub TYPE ()         { 0 }
sub NAME ()         { 1 }
sub SUBORDINATES () { 2 }
sub MODE ()         { 2 } # alias of SUBORDINATES (for method parameter nodes)
sub ANNOTATIONS ()  { 3 }
sub COMMENT ()      { 4 }
sub SCOPEREF ()     { 5 }

=item Method parameter modes

      sub IN ()    { 1 }
      sub OUT ()   { 2 }
      sub INOUT () { 3 }

=cut

sub IN ()    { 1 }
sub OUT ()   { 2 }
sub INOUT () { 3 }

=item Meanings of the TYPE entry in the symbol node

      sub NONE ()            { 0 }   # error/illegality value
      sub BOOLEAN ()         { 1 }
      sub OCTET ()           { 2 }
      sub CHAR ()            { 3 }
      sub WCHAR ()           { 4 }
      sub SHORT ()           { 5 }
      sub LONG ()            { 6 }
      sub LONGLONG ()        { 7 }
      sub USHORT ()          { 8 }
      sub ULONG ()           { 9 }
      sub ULONGLONG ()       { 10 }
      sub FLOAT ()           { 11 }
      sub DOUBLE ()          { 12 }
      sub LONGDOUBLE ()      { 13 }
      sub STRING ()          { 14 }
      sub WSTRING ()         { 15 }
      sub OBJECT ()          { 16 }
      sub TYPECODE ()        { 17 }
      sub ANY ()             { 18 }
      sub FIXED ()           { 19 }  # node
      sub BOUNDED_STRING ()  { 20 }  # node
      sub BOUNDED_WSTRING () { 21 }  # node
      sub SEQUENCE ()        { 22 }  # node
      sub ENUM ()            { 23 }  # node
      sub TYPEDEF ()         { 24 }  # node
      sub NATIVE ()          { 25 }  # node
      sub STRUCT ()          { 26 }  # node
      sub UNION ()           { 27 }  # node
      sub CASE ()            { 28 }
      sub DEFAULT ()         { 29 }
      sub EXCEPTION ()       { 30 }  # node
      sub CONST ()           { 31 }  # node
      sub MODULE ()          { 32 }  # node
      sub INTERFACE ()       { 33 }  # node
      sub INTERFACE_FWD ()   { 34 }  # node
      sub VALUETYPE ()       { 35 }  # node
      sub VALUETYPE_FWD ()   { 36 }  # node
      sub VALUETYPE_BOX ()   { 37 }  # node
      sub ATTRIBUTE ()       { 38 }  # node
      sub ONEWAY ()          { 39 }  # implies "void" as the return type
      sub VOID ()            { 40 }
      sub FACTORY ()         { 41 }
      sub METHOD ()          { 42 }  # node
      sub INCFILE ()         { 43 }  # node
      sub PRAGMA_PREFIX ()   { 44 }  # node
      sub PRAGMA_VERSION ()  { 45 }  # node
      sub PRAGMA_ID ()       { 46 }  # node
      sub PRAGMA ()          { 47 }  # node
      sub REMARK ()          { 48 }  # node
      sub NUMBER_OF_TYPES () { 49 }

The constant C<FACTORY> can only occur as the return type of a method in a valuetype.

=cut

# If these codes are changed then @predef_types must be changed accordingly.
sub NONE ()            { 0 }   # error/illegality value
sub BOOLEAN ()         { 1 }
sub OCTET ()           { 2 }
sub CHAR ()            { 3 }
sub WCHAR ()           { 4 }
sub SHORT ()           { 5 }
sub LONG ()            { 6 }
sub LONGLONG ()        { 7 }
sub USHORT ()          { 8 }
sub ULONG ()           { 9 }
sub ULONGLONG ()       { 10 }
sub FLOAT ()           { 11 }
sub DOUBLE ()          { 12 }
sub LONGDOUBLE ()      { 13 }
sub STRING ()          { 14 }
sub WSTRING ()         { 15 }
sub OBJECT ()          { 16 }
sub TYPECODE ()        { 17 }
sub ANY ()             { 18 }
sub FIXED ()           { 19 }  # node
sub BOUNDED_STRING ()  { 20 }  # node
sub BOUNDED_WSTRING () { 21 }  # node
sub SEQUENCE ()        { 22 }  # node
sub ENUM ()            { 23 }  # node
sub TYPEDEF ()         { 24 }  # node
sub NATIVE ()          { 25 }  # node
sub STRUCT ()          { 26 }  # node
sub UNION ()           { 27 }  # node
sub CASE ()            { 28 }
sub DEFAULT ()         { 29 }
sub EXCEPTION ()       { 30 }  # node
sub CONST ()           { 31 }  # node
sub MODULE ()          { 32 }  # node
sub INTERFACE ()       { 33 }  # node
sub INTERFACE_FWD ()   { 34 }  # node
sub VALUETYPE ()       { 35 }  # node
sub VALUETYPE_FWD ()   { 36 }  # node
sub VALUETYPE_BOX ()   { 37 }  # node
sub ATTRIBUTE ()       { 38 }  # node
sub ONEWAY ()          { 39 }  # implies "void" as the return type
sub VOID ()            { 40 }
sub FACTORY ()         { 41 }  # treated as return type of METHOD;
                               #   can only occur inside valuetype
sub METHOD ()          { 42 }  # node
sub INCFILE ()         { 43 }  # node
sub PRAGMA_PREFIX ()   { 44 }  # node
sub PRAGMA_VERSION ()  { 45 }  # node
sub PRAGMA_ID ()       { 46 }  # node
sub PRAGMA ()          { 47 }  # node
sub REMARK ()          { 48 }  # node
sub NUMBER_OF_TYPES () { 49 }

# special type code used for filling @typestack
sub ANNOTATION    { &NUMBER_OF_TYPES }

=item Interface/valuetype flag values

      sub ABSTRACT      { 1 }
      sub LOCAL         { 2 }
      sub TRUNCATABLE   { 2 }
      sub CUSTOM        { 3 }

=cut

sub ABSTRACT      { 1 }
sub LOCAL         { 2 }
sub TRUNCATABLE   { 2 }
sub CUSTOM        { 3 }

=item Valuetype member flags

      sub PRIVATE       { 1 }
      sub PUBLIC        { 2 }

=back

=cut

sub PRIVATE       { 1 }
sub PUBLIC        { 2 }

=head1 SUBROUTINES

=head2 Parse_File

Parses the file name given as argument.
Returns reference to array of nodes representing the top level (global)
declarations in the file.
Returns 0 if the file had syntax errors.
C<Parse_File> writes the error messages to C<STDERR>.

=cut

sub Parse_File;

sub set_directive_object {
    $comment_directives = shift;
}

=head2 Dump_Symbols

Symbol tree dumper (for debugging etc.) reconstructs the IDL source notation
from the parsed symbol tree.
Parameters:

=over

=item 1.

Reference to a symbol array (return value from a previous call to Parse_File).

=item 2.

Optional parameter controlling the output:

=over

=item *

If given as string then it is the name of a file into which to dump the IDL source.

=item *

If given as array reference then the IDL source will be placed in the
referenced array, one line per element, where each line is not newline
terminated.

=item *

If the optional parameter is not given or is given as C<undef> then the IDL
source will be dumped to C<STDOUT>.

=back

=back

=cut

sub Dump_Symbols;

sub Version ()
{
    for ('$Revision: 30679 $') { #'){
        /: *(\S+)/ and return $VERSION . "_" . $1;
    }
    return $VERSION;
}

=head2 is_elementary_type

Given a node reference, returns the type constant if the node prepresents
an elementary type. Returns 0 if the type is not elementary.

=head2 predef_type

Given a type name (as string), returns the type constant if the type name
is that of an elementary type. Returns 0 if the type is not elementary.

=head2 isnode

Given a "thing", returns 1 if it is a reference to a node, 0 otherwise.

=head2 is_scope

Given a "thing", returns 1 if it's a ref to a C<MODULE>, C<INTERFACE>, or
C<INCFILE> node.

=head2 find_node

Looks up a name in the symbol treeZ<>(s) constructed so far.
Returns the node ref if found, else 0.

=head2 typeof

Given a type descriptor, returns the type as a string in IDL syntax.

=head2 set_verbose

Call this to make the parser tell us what it's doing.

=head2 is_a

Determine if typeid is of given type, recursing through C<TYPEDEF>s.

=head2 root_type

Get the original type of a C<TYPEDEF>, i.e. recurse through all non array
C<TYPEDEF>s until the original type is reached.

=head2 is_pragma

Return 1 if the given type constant or node is a pragma.

=head2 files_included

Returns an array with the names of files #included.

=head2 get_scalar_default

Get default value for type.
Uses comment directives object if available.

=head2 idlsplit

Splits a given IDL expression into its individual
tokens.  Returns the tokens as a list.
Example: The call

    idlsplit("(m_a::myconst+1.0) / scale")

returns the list

    "(", "m_a::myconst", "+", "1.0", ")", "/", "scale"

=head2 is_valid_identifier

Returns 1 if the argument is a valid IDL identifier.

=head2 scoped_name

Expects a symbol node as the input argument and
returns its fully qualified name in IDL syntax.

=head2 collect_includes

Utility for collecting C<#include>d files.
Parameters:

=over

=item 1.

Reference to node list to analyze.

=item 2.

Reference to hash in which to add the includefile names encountered.
The includefile names are added as key fields of the hash.
The value fields are not used.

=back

=head2 get_numeric

Computes numeric value of expression.

=head2 enum_literals

The C<SUBORDINATES> of C<ENUM> contains more than just the actual enum literal
values (the additional data are: annotations, trailing comments).
This is a convenience subroutine which returns the net literals of the given
C<$enumnode[SUBORDINATES]>.

=cut

sub is_elementary_type;
sub predef_type;
sub isnode;
sub is_scope;
sub find_node;
sub typeof;
sub set_verbose;
sub is_a;
sub root_type;
sub is_pragma;
sub files_included;
sub get_scalar_default;
sub idlsplit;
sub is_valid_identifier;
sub scoped_name;
sub collect_includes;
sub get_numeric;
sub enum_literals;

# Internal subroutines (should not be visible)

sub use_system_preprocessor;  # Attempt to use the system preprocessor if
                              #  one is found.
                              #  Takes no arguments.
                              #  NOTE: Due to variations in preprocessor
                              #  options and behavior, this might not work
                              #  on your system.
                              #  If use_system_preprocessor is not called
                              #  then the IDLtree parser attempts to do the
                              #  preprocessing itself.
sub in_annotation_def;        # Returns true while parsing an @annotation.
sub get_items;
sub unget_items;
sub check_name;
sub curr_scope;
sub scope_names;
sub find_node_i;
sub parse_sequence;
sub parse_type;
sub parse_members;
sub error;
sub info;
sub abort;
sub require_end_of_stmt;
sub get_files_included;
sub dump_symbols_internal;

# Start of implementation

# Auxiliary (non-visible) global stuff ########################################

# Annotation enumeration types (auxiliary to declaring @annoDefs).
# User defined annotation enumeration types are added here when they arise.
our %annoEnum = (
    "AutoidKind"        => [ "SEQUENTIAL", "HASH" ],
    "ExtensibilityKind" => [ "FINAL", "APPENDABLE", "MUTABLE" ],
    "PlacementKind"     => [ "BEGIN_FILE",
                              "BEFORE_DECLARATION",
                               "BEGIN_DECLARATION",
                               "END_DECLARATION",
                              "AFTER_DECLARATION",
                             "END_FILE" ],
    # IDL4 to Java mapping
    "NamingConvention"  => [ "IDL_NAMING_CONVENTION",
                             "JAVA_NAMING_CONVENTION" ]
  );

# Predefined annotation definitions.
# User defined annotation definitions are appended here when they arise.
# Each element in @annoDefs is a reference to an array:
# The first element in the array is the annotation name.
# The following elements in the array represent the parameters of the
# annotation (if the annotation has no parameters then there will be no
# further elements). Each parameter is represented as a reference to a
# triplet (three element array).  The first element in the triplet is
# either a type number (one of the values BOOLEAN, OCTET, CHAR, SHORT,
# LONG, LONGLONG, USHORT, ULONG, ULONGLONG, FLOAT, STRING, ANY) or a
# reference to an entry in %annoEnum.  The second element in the triplet
# is the parameter name.  The third element in the triplet is the default
# value if a default is given, or is undef if no default is given.

our @annoDefs = (
    [ "id",              [ ULONG, "value", undef ] ],
    [ "autoid",          [ "AutoidKind", "value", "HASH" ] ],
    [ "optional",        [ BOOLEAN, "value", "TRUE" ] ],
    [ "position",        [ USHORT, "value", undef ] ],
    [ "value",           [ ANY, "value", undef ] ],
    [ "extensibility",   [ "ExtensibilityKind", "value", undef ] ],
    [ "final" ],
    [ "appendable" ],
    [ "mutable" ],
    [ "key",             [ BOOLEAN, "value", "TRUE" ] ],
    [ "must_understand", [ BOOLEAN, "value", "TRUE" ] ],
    [ "default_literal" ],
    [ "default",         [ ANY, "value", undef ] ],
    [ "range",           [ ANY, "min", undef ],  [ ANY, "max", undef ] ],
    [ "min",             [ ANY, "value", undef ] ],
    [ "max",             [ ANY, "value", undef ] ],
    [ "unit",            [ STRING, "value", undef ] ],
    [ "bit_bound",       [ USHORT, "value", undef ] ],
    [ "external",        [ BOOLEAN, "value", "TRUE" ] ],
    [ "nested",          [ BOOLEAN, "value", "TRUE" ] ],
    [ "verbatim",        [ STRING, "language", "*" ],
                         [ "PlacementKind", "placement", "BEFORE_DECLARATION" ],
                         [ STRING, "text", undef ] ],
    [ "service",         [ STRING, "platform", "*" ] ],
    [ "oneway",          [ BOOLEAN, "value", "TRUE" ] ],
    [ "ami",             [ BOOLEAN, "value", "TRUE" ] ],
    # IDL4 to Java mapping
    [ "java_mapping",    [ STRING,  "constants_container",  "Constants" ],
                         [ BOOLEAN, "promote_integer_width",    "FALSE" ],
                         [ "NamingConvention", "apply_naming_convention",
                                                "IDL_NAMING_CONVENTION" ],
                         [ STRING,  "string_type",             "String" ] ]
  );

# Temporary store collecting annotations will be flushed when the construct
# to annotate is seen.
# The structure of @annotations is that of the ANNOTATIONS element in tree
# nodes (see documentation at beginning of file):
# Each entry in this array is an array reference.  The first element in the
# array referenced is a reference to an entry in @annoDefs.  The following
# elements contain the concrete values for the parameters, in the order as
# defined by the entry in @annoDefs.  If the user omitted the value of the
# parameter then the default as specified by the entry in @annoDefs is
# filled in.
my @annotations = ();

{
    # general symbol cache class, used for include file cache and
    # node cache
    package CORBA::IDLtree::Cache;

    sub new {
        my $class = shift;
        $class = ref($class) || $class;

        my $this = bless {}, $class;
        $this->clear();
        return $this;
    }

    sub clear {
        my $this = shift;

        %{$this->{_cache}} = ();
        $this->{_hits} = 0;
        $this->{_queries} = 0;
        return $this;
    }

    # if $value is true add under the name $name
    # to the cache
    sub add {
        my $this = shift;
        my ($name, $value) = @_;

        if ($value) {
            if (exists $this->{_cache}{$name}) {
                my $existing = $this->{_cache}{$name};
                if ($existing != $value) {
                    # This happens when adding the reopening of a known module.
                    # The cache only holds the last reopening.
                    CORBA::IDLtree::info("CORBA::IDLtree::Cache::add($name): replacing "
                         . "$existing (" . CORBA::IDLtree::typeof($existing)
                         . ") by $value (" . CORBA::IDLtree::typeof($value) . ")");
                }
            }
            $this->{_cache}{$name} = $value;
        }
        return $this;
    }

    # get entry for $name or undef if $name is not known
    sub get {
        my $this = shift;
        my ($name) = @_;

        $this->{_queries}++;
        if (exists $this->{_cache}{$name}) {
            $this->{_hits}++;
            return $this->{_cache}{$name};
        }
        return undef;
    }

    # return hits / queries ratio
    sub ratio {
        my $this = shift;
        return $this->{_hits}." / ".$this->{_queries};
    }

    # return known names
    sub symbols {
        my $this = shift;
        return keys %{$this->{_cache}};
    }
}

# The @predef_types array must have the types in the same order as
# the numeric order of type identifying constants defined above.
my @predef_types = qw/ none boolean octet char wchar short long long_long
                       unsigned_short unsigned_long unsigned_long_long
                       float double long_double string wstring Object
                       TypeCode any fixed bounded_string bounded_wstring
                       sequence enum typedef native struct union case default
                       exception const module interface interface_fwd
                       valuetype valuetype_fwd valuetype_box
                       attribute oneway void factory method
                       include pragma_prefix pragma_version pragma_id pragma /;

# list of all IDL keywords (as of CORBA 3.0) in lower case
# used to check for name conflicts
my %keywords = map { $_ => undef } qw/
  abstract any attribute boolean case char component const
  consumes context custom default double emits enum exception
  eventtype factory false finder fixed float getraises home
  import in inout interface local long module multiple native
  object octet oneway out port primarykey private provides public
  publishes raises readonly setraises sequence short string
  struct supports switch true truncatable typedef typeid
  typeprefix unsigned union uses valuebase valuetype void
  wchar wstring/;

my @infilename = ();    # infilename and line_number move in parallel.
my @line_number = ();
my @remark = ();        # Auxiliary to comment processing
my @post_comment = ();  # Auxiliary to comment processing
my @global_items = ();  # Auxiliary to sub unget_items
my $findnode_cache = new CORBA::IDLtree::Cache();
   # Auxiliary to find_node_i(): cache for lookups
my $abstract = 0;       # can also contain LOCAL (for interfaces)
my $currfile = -1;
my $starting_line_number_of_remark = 0;  # 0 = there is no pre comment
my $line_number_of_post_comment    = 0;  # 0 = there is no post comment
my $emucpp = 1;         # use C preprocessor emulation
my $locale_was_determined = 0;
my $locale = undef;

sub locate_executable {
    # FIXME: this is probably another reinvention of the wheel.
    # Should look for builtin Perl solution or CPAN module that does this.
    my $executable = shift;
    # my $pathsep = $Config{'path_sep'};
    my $pathsep = ':';
    my $fully_qualified_name = "";
    my @dirs = split(/$pathsep/, $ENV{'PATH'});
    foreach (@dirs) {
        my $fqn = "$_/$executable";
        if (-e $fqn) {
            $fully_qualified_name = $fqn;
            last;
        }
    }
    $fully_qualified_name;
}


sub idlsplit {
    my $str = shift;
    my $in_preprocessor = $str =~ /^\s*#/;
    my $in_string = 0;
    my $in_lit = 0;
    my $in_space = 0;
    my $i;
    my @out = ();
    my $ondx = -1;
    for ($i = 0; $i < length($str); $i++) {
        my $ch = substr($str, $i, 1);
        if ($in_string) {
            $out[$ondx] .= $ch;
            if ($ch eq '"' and substr($str, $i-1, 1) ne "\\") {
                $in_string = 0;
            }
        } elsif ($ch eq '"') {
            $in_string = 1;
            $out[++$ondx] = $ch;
        } elsif ($ch eq "'") {
            my $endx = index $str, "'", $i + 2;
            if ($endx < $i + 2) {
                error "cannot find closing apostrophe of char literal";
                return @out;
            }
            $out[++$ondx] = substr($str, $i, $endx - $i + 1);
            # print "idlsplit: $out[$ondx]\n";
            $i = $endx;
        } elsif ($ch =~ /[a-z_0-9\.]/i) {
            if (! $in_lit) {
                $in_lit = 1;
                $ondx++;
            }
            $out[$ondx] .= $ch;
        } elsif ($in_lit) {
            $in_lit = 0;
            # do preprocessor substitution
            if (exists $active_defines{$out[$ondx]}) {
                my $value = $active_defines{$out[$ondx]};
                if ("$value" ne "") {
                    my @addl = idlsplit($value);
                    pop @out;          # remove original symbol
                    push @out, @addl;  # add replacement text
                    $ondx = $#out;
                }
            }
            if ($ch !~ /\s/) {
                $out[++$ondx] = $ch;
            }
        } elsif ($ch !~ /\s/) {
            $out[++$ondx] = $ch;
        }
    }
    if ($in_lit) {
        # do preprocessor substitution
        if (exists $active_defines{$out[$ondx]}) {
            my $value = $active_defines{$out[$ondx]};
            if ("$value" ne "") {
                my @addl = idlsplit($value);
                pop @out;          # remove original symbol
                push @out, @addl;  # add replacement text
                $ondx = $#out;
            }
        }
    }
    # For simplification of further processing:
    # 1. Turn extra-long and unsigned types into single keyword
    #      long double => long_double
    #      unsigned short => unsigned_short
    # 2. Put scoped names back together, e.g. 'A' ':' ':' 'B' => 'A::B'
    #    Also, discard global-scope designators. (leading ::)
    # 3. Put the sign and value of negative numbers back together
    # 4. Put bounded string type (string<bound>) into one element
    for ($i = 0; $i < $#out; $i++) {
        if ($out[$i] eq 'long') {
            if ($out[$i+1] eq 'double' && !$long_double_supported) {
                error("ERROR: long double not supported");
            }
            if ($out[$i+1] eq 'long' or $out[$i+1] eq 'double') {
                $out[$i] .= '_' . $out[$i + 1];
                splice @out, $i + 1, 1;
            }
        } elsif ($out[$i] eq 'unsigned') {
            if ($out[$i+1] eq 'short' or $out[$i+1] eq 'long') {
                $out[$i] .= '_' . $out[$i + 1];
                splice @out, $i + 1, 1;
                if ($out[$i+1] eq 'long') {
                    $out[$i] .= '_long';
                    splice @out, $i + 1, 1;
                }
            }
        } elsif ($out[$i] eq ':' and $out[$i+1] eq ':') {
            # remove "::"
            # except when inheriting from an absolute qualified superclass
            # such as:  valuetype vt : ::absolute::qualified::superclass {
            #               ...
            #            };
            # here, we need to preserve the first ':' as inheritance intro
            unless ($i < $#out - 1 && $out[$i+2] eq ':') {
                splice @out, $i, 2;
                if ($i > 0) {
                    my $prev = $out[$i - 1];
                    if ($prev =~ /\w$/ and !exists($keywords{$prev})) {
                        if ($out[$i - 1] eq 'CORBA') {
                            $out[$i - 1] = $out[$i];   # discard CORBA namespace
                        } else {
                            $out[$i - 1] .= '::' . $out[$i];
                        }
                        splice @out, $i--, 1;
                    }
                }
            }
        # } elsif ($out[$i] eq '@' and $out[$i+1] =~ /^\w/) {
        #     # Put annotation '@' together with its identifier
        #     $out[$i] .= $out[$i + 1];
        #     splice @out, $i + 1, 1;
        } elsif ($out[$i] eq '-' and $out[$i+1] =~ /^\d/) {
            if ($i == 0 || $out[$i-1] eq '(' || $out[$i-1] eq '='
                || $in_preprocessor) {
                $out[$i] .= $out[$i + 1];
                splice @out, $i + 1, 1;
            }
        }
        # Restore floating point scientific notation (e.g. 10.0e-3)
        if ($out[$i] =~ /^[\-\d][\d\.]*e$/i and
            $out[$i+1] eq '+' || $out[$i+1] eq '-') {
            $out[$i] .= $out[$i + 1] . $out[$i + 2];
            splice @out, $i + 1, 2;
        }
    }
    # Bounded strings are special-cased:
    # compress the notation "string<bound>" into one element
    for ($i = 0; $i < $#out - 1; $i++) {
        if ($out[$i] =~ /^w?string$/
            and $out[$i+1] eq '<' && $out[$i+3] eq '>') {
            my $bound = $out[$i+2];
            $out[$i] .= '<' . $bound . '>';
            splice @out, $i + 1, 3;
        }
    }
    @out;
}


sub is_elementary_type {
    # Returns the type index of an elementary type,
    # or 0 if the type is not elementary.
    my $tdesc = shift;                 # argument: a type descriptor
    unless (defined $tdesc) {
        error("CORBA::IDLtree::is_elementary_type called on undefined tdesc"
              . Carp::longmess());
        return 0;
    }
    my $recurse_into_typedef = 0;      # optional argument
    if (@_) {
        $recurse_into_typedef = shift;
    }
    my $rv = 0;
    if ($tdesc >= BOOLEAN && $tdesc <= ANY) {
        # For our purposes, sequences, bounded strings, enums, structs, and
        # unions do not count as elementary types. They are represented as a
        # further node, i.e. the argument to is_elementary_type is not a
        # numeric constant but instead contains a reference to the defining
        # node.
        $rv = $tdesc;
    } elsif ($recurse_into_typedef && isnode($tdesc) &&
             $$tdesc[TYPE] == TYPEDEF) {
        my @origtype_and_dim = @{$$tdesc[SUBORDINATES]};
        my $dimref = $origtype_and_dim[1];
        unless ($dimref && @{$dimref}) {
            $rv = is_elementary_type($origtype_and_dim[0], 1);
        }
    }
    $rv;
}


sub predef_type {
    my $idltype = shift;
    my $i;
    for ($i = 1; $i <= $#predef_types; $i++) {
        if ($idltype eq $predef_types[$i]) {
            if ($string_bound and $idltype =~ /^w?string$/) {
                info("bounding $idltype to $string_bound");
                $idltype .= "<$string_bound>";
            } else {
                return $i;
            }
        }
    }
    if ($idltype =~ /^(w?string)\s*<(\d+)\s*>/) {
        my $type;
        $type = ($1 eq "wstring" ? BOUNDED_WSTRING : BOUNDED_STRING);
        my $bound = $2;
        return [ $type, $bound, 0, 0, 0, curr_scope ];
    }
    0;
}


sub is_valid_identifier {
    my $name = shift;
    if ($name !~ /^[a-z_:]/i || ($name =~ /^_/ && !$leading_underscore_allowed)) {
        return 0;  # illegal first character
    }
    $name !~ /[^a-z0-9_:\.]/i
}

sub check_name {
    my $name = shift;
    my $msg = "name";
    if (@_) {
        $msg = shift;
    }
    unless (is_valid_identifier($name)) {
        unless ($name =~ /^w?string<.*>$/) {
            error "illegal $msg: $name";
        }
    }
    if (exists $keywords{lc($name)}) {
        if ($permissive) {
            info "WARNING: illegal $msg: '$name' is an IDL keyword";
        } else {
            error "illegal $msg: '$name' is an IDL keyword";
        }
    }
    # according to spec, a leading underscore disables keyword check but
    # is not part of the identifier
    unless ($leading_underscore_allowed > 1) {
      $name =~ s/^_//;
    }
    return $name;
}

sub check_typename {
    my $name = shift;
    my $msg = "name";
    if (@_) {
        $msg = shift;
    }
    unless (is_valid_identifier($name)) {
        unless ($name =~ /^w?string<.*>$/) {
            error "illegal $msg: $name";
        }
    }
    my $pt = predef_type($name);
    if ((ref($pt) ? $pt->[0] : $pt) < TYPEDEF) {
        # elementary type => OK
        return $name;
    }
    if (exists $keywords{lc($name)}) {
        if ($permissive) {
            info "WARNING: illegal $msg: '$name' is an IDL keyword";
        } else {
            error "illegal $msg: '$name' is an IDL keyword";
        }
    }
    # according to spec, a leading underscore disables keyword check but
    # is not part of the identifier
    $name =~ s/^_//;
    return $name;
}

my @scopestack = ();
    # The scope stack. Elements in this stack are references to
    # MODULE or INTERFACE nodes.

sub curr_scope {
    ($#scopestack < 0 ? 0 : $scopestack[$#scopestack]);
}

sub annotation {
    my $retval = 0;
    if (@annotations) {
        $retval = [ @annotations ];
        @annotations = ();
    }
    return $retval;
}

sub comment {
    my $cmnt = 0;
    if (@post_comment) {
        $cmnt = [ $line_number_of_post_comment, [ @post_comment ] ];
        @post_comment = ();
        $line_number_of_post_comment = 0;
    }
    return $cmnt;
}


sub parse_sequence {
    my ($argref, $symroot) = @_;
    if (shift @{$argref} ne '<') {
        error "expecting '<'";
        return 0;
    }
    my $nxtarg = shift @{$argref};
    my $type = predef_type $nxtarg;
    if (! $type) {
        $type = find_node_i($nxtarg, $symroot);
        if (! $type) {
            error "unknown sequence type";
            return 0;
        }
    } elsif ($type == SEQUENCE) {
        $type = parse_sequence($argref, $symroot);
    }
    my $bound = 0;
    $nxtarg = shift @{$argref};
    if ($nxtarg eq ',') {
        $bound = shift @{$argref};
        $nxtarg = shift @{$argref};
    }
    if ($nxtarg ne '>') {
        error "expecting '<'";
        return 0;
    }
    return [SEQUENCE, $bound, $type, annotation, comment, curr_scope];
}


sub parse_type {
    my ($typename, $argref, $symtreeref) = @_;
    my $type;
    if ($typename eq 'fixed') {
        if (shift @{$argref} ne '<') {
            error "expecting '<' after 'fixed'";
            return 0;
        }
        my $digits = shift @{$argref};
        if ($digits =~ /\D/) {
            error "digit number in 'fixed' must be constant";
            return 0;
        }
        if (shift @{$argref} ne ',') {
            error "expecting comma in 'fixed'";
            return 0;
        }
        my $scale = shift @{$argref};
        if ($scale =~ /\D/) {
            error "scale number in 'fixed' must be constant";
            return 0;
        }
        if (shift @{$argref} ne '>') {
            error "expecting '>' at end of 'fixed'";
            return 0;
        }
        my @digits_and_scale = ($digits, $scale);
        $type = [ FIXED, "", \@digits_and_scale, annotation, comment, curr_scope ];
    } elsif ($typename =~ /^(w?string)<([\w:]+)>$/) {   # bounded string
        my $t;
        $t = ($1 eq "wstring" ? BOUNDED_WSTRING : BOUNDED_STRING);
        my $bound = $2;
        if ($bound !~ /^\d/) {
            my $boundtype = find_node_i($bound, $symtreeref);
            if (isnode $boundtype) {
                my @node = @{$boundtype};
                if ($node[TYPE] == CONST) {
                    my($basetype, $expr_ref) = @{$node[SUBORDINATES]};
                    my @expr = @{$expr_ref};
                    if (scalar(@expr) > 1 or $expr[0] !~ /^\d/) {
                        error("string bound expressions"
                              . " are not yet implemented");
                    }
                    $bound = $expr[0];
                } else {
                    error "illegal type for string bound";
                }
            } else {
                error "Cannot resolve string bound";
            }
        }
        $type = [ $t, $bound, 0, annotation, comment, curr_scope ];
    } elsif ($typename eq 'sequence') {
        $type = parse_sequence($argref, $symtreeref);
    } else {
        $type = find_node_i($typename, $symtreeref);
    }
    $type;
}


sub parse_members {
    # params:   \@symbols, \@arg, $structref_or_vt_access
    #           If the structref_or_vt_access is a reference then we
    #           assume to be parsing a struct and the member data are stored
    #           in the list referenced by $structref.
    #           If the structref_or_vt_access is not a reference then we
    #           assume to be parsing a valuetype state member. In that case
    #           $structref_or_vt_access contains the value &PRIVATE or
    #           &PUBLIC indicating the access of the state member.
    #           The valuetype member is directly added to @$symtreeref.
    # returns:  -1 for error;
    #            0 for success with enclosing scope still open;
    #            1 for success with enclosing scope closed (i.e. seen '};')
    my($symtreeref, $argref, $structref_or_vt_access, $comment) = @_;
    my $structref = 0;
    my $value_member_flag = 0;
    if (ref $structref_or_vt_access) {
        $structref = $structref_or_vt_access;
    } else {
        $value_member_flag = $structref_or_vt_access;
    }
    while (@{$argref}) {    # We're up here for a TYPE name
        my $first_thing = shift @{$argref};  # but it could also be '}'
        while ($first_thing eq '@') {
            my $ann = shift @{$argref};
            parse_annotation_app($ann, $argref);
            $first_thing = shift @{$argref};
        }
        if ($first_thing eq '}') {
            unshift @{$argref}, '}';
            return 1;   # return value signals closing of scope.
        }
        my $component_type = parse_type($first_thing, $argref, $symtreeref);
        if (! $component_type) {
            error "unknown type $first_thing";
            return -1;  # return value signals error.
        }
        if (in_annotation_def()) {
            my $component_name = shift @{$argref};
            my $default;
            if (@{$argref}) {
                my $next = shift @{$argref};
                if ($next eq 'default') {
                    $default = shift @{$argref};
                }
            }
            push @{$structref}, [ $component_type, $component_name, $default ];
            if (@{$argref}) {
                my $next = shift @{$argref};
                unless ($next eq ';') {
                    error("parse_members($first_thing) : found '$next' (expecting ';')");
                    return -1;
                }
            }
            next;
        }
        if (! is_type($component_type)) {
            error "$first_thing is not a type";
            return -1;
        }
        while (@{$argref}) {    # We're here for VARIABLE name(s)
            $first_thing = shift @{$argref};
            while ($first_thing eq '@') {
                my $ann = shift @{$argref};
                parse_annotation_app($ann, $argref);
                $first_thing = shift @{$argref};
            }
            if ($first_thing eq '}') {
                unshift @{$argref}, '}';
                error "parse_members: unexpected '}'";
                return 1;   # return value signals closing of scope.
            }
            my $component_name = $first_thing;
            $component_name = check_name($component_name);
            my @dimensions = ();
            my $nxtarg = "";
            while (@{$argref}) {    # We're here for a variable's DIMENSIONS
                $nxtarg = shift @{$argref};
                if ($nxtarg eq '[') {
                    my $dim = shift @{$argref};
                    if (shift @{$argref} ne ']') {
                        error "expecting ']'";
                        return -1;
                    }
                    push @dimensions, $dim;
                } elsif ($nxtarg eq ',' || $nxtarg eq ';') {
                    last;
                } else {
                    error "component declaration syntax error";
                    return -1;
                }
            }
            my $dimref = 0;
            if (@dimensions) {
                $dimref = [ @dimensions ];
                unless ($permissive) {
                    info "$component_name : array members are DEPRECATED";
                }
            }
            # check for duplicate component names
            my $name_found = "";
            if ($value_member_flag) {
                for (@$symtreeref) {
                    my $type = $_->[TYPE];
                    if (isnode($type) && $type->[NAME] eq $component_name) {
                        $name_found = $component_name;
                        last;
                    }
                }
            } else {
                for (@$structref) {
                    next unless ref $_;
                    next if $_->[TYPE] == CASE || $_->[TYPE] == DEFAULT;
                    if ($_->[TYPE] != REMARK && $_->[NAME] eq $component_name) {
                        $name_found = $component_name;
                        last;
                    }
                }
            }
            if ($name_found) {
                error "duplicate component name $name_found";
                return -1;
            }
            unless (defined $comment) {
                $comment = comment();
            }
            my $member_node = [ $component_type, $component_name, $dimref,
                                annotation(), $comment ];
            if ($value_member_flag) {
                push @{$symtreeref}, [ $value_member_flag, $member_node ];
            } else {
                push @{$structref}, $member_node;
            }
            last if ($nxtarg eq ';');
        }
    }
    0   # return value signals success with scope still open.
}


my @prev_symroots = ();
    # Stack of the roots of previously constructed symtrees.
    # Used by find_node_i() for identifying symbols.
    # Elements are added to/removed from the front of this,
    # i.e. using unshift/shift (as opposed to push/pop.)

my @fh = qw/ IN0 IN1 IN2 IN3 IN4 IN5 IN6 IN7 IN8 IN9/;
    # Input file handles (constants)

# Cache of previously parsed includefiles
my $includecache = new CORBA::IDLtree::Cache();
my $did_emucppmsg = 0;  # auxiliary to sub emucppmsg

my @struct = ();       # Temporary storage for struct/union/exception/
                       # @annotation definition members.
my @typestack = ();    # For struct/union/exception, typestack, namestack, and
my @namestack = ();    # cmntstack move in parallel.
                       # For valuetypes, only typestack is used.
                       # For annotation definitions, @struct is flushed to
                       # @annoDefs.

my @annostack = ();    # The annotation stack stores the concrete annotations
    # given on a struct/union/exception/valuetype declaration, e.g.
    #   @external
    #   struct mystruct {
    #     ...
    #   };
    # It is needed because the node is not constructed until the end of the
    # structure declaration, and members may have own annotations which would
    # overwrite the annotations of the type.

my @cmntstack = (); # The comment stack stores a trailing comment on the
    # struct/union/exception declaration line, e.g.
    #   struct mystruct {  // This comment is stored in @cmntstack.
    #     ...
    #   };
    # It is needed because the node is not constructed until the end of the
    # structure declaration, and members may have trailing comments which
    # would overwrite the single post_comment buffer.

sub in_annotation_def() {
    return (@typestack && $typestack[$#typestack] == ANNOTATION);
}

sub set_verbose {
    if (@_) {
        $verbose = shift;
    } else {
        $verbose = 1;
    }
}

sub emucppmsg {
    if (! $did_emucppmsg) {
        info("// using preprocessor emulation");
        $did_emucppmsg = 1;
    }
}

sub use_system_preprocessor {
    $emucpp = 0;
}

sub eval_preproc_expr {
    my @arg = @_;
    my $symbol = shift @arg;
    if ($symbol eq 'defined') {
        $arg[0] eq '(' and shift @arg;   # discard open-paren
        $symbol = shift @arg;
        $arg[0] eq ')' and shift @arg;   # discard close-paren
        if (@arg or $symbol !~ /^\d+$/) {
            # There is more than the closing paren or
            # $symbol has an unimplemented (non numeric) value
            error "warning: #if not fully implemented\n";
        }
        return $symbol;
    } elsif ($symbol =~ /^[A-z]/) {
        # NB: sub idlsplit has already done symbol substitution
        error "built-in preprocessor does not know how to interpret $symbol";
        return 0;
    } elsif ($symbol !~ /^\d+$/) {
        error "warning: #if expressions not yet implemented\n";
    }
    $symbol
}

sub skip_input {
    my $count = 0;
    my $in = $fh[$#infilename];
    my $in_comment = 0;
    while (<$in>) {
        $line_number[$currfile]++;
        chomp;
        my $l = $_;
        if ($in_comment) {
            if ($l =~ /\*\//) {
                $in_comment = 0;
            }
            next;
        }
        my $cstart = index($l, "/*");
        if ($cstart >= 0) {
            my $cstop  = index($l, "*/");
            if ($cstop > $cstart) {
                my $pre = "";
                if ($cstart > 0) {
                    $pre = substr($l, 0, $cstart);
                }
                $cstop += 2;
                my $post = "";
                if ($cstop < length($l)) {
                    $post = substr($l, $cstop);
                }
                $l = $pre . $post;
            } else {
                $in_comment = 1;
                next;
            }
        }
        next unless ($l =~ /^\s*#/);
        my @arg = idlsplit($l);
        my $kw = shift @arg;
        # print (join ('|', @arg) . "\n");
        my $directive = shift @arg;
        if ($count == 0) {
            if ($directive eq 'else' || $directive eq 'endif') {
                return;
            }
            if ($directive eq 'elif') {
                if (eval_preproc_expr @arg) {
                    return;
                }
                next;
            }
        }
        if ($directive eq 'if' ||
            $directive eq 'ifdef' ||
            $directive eq 'ifndef') {
            $count++;
        } elsif ($directive eq 'endif') {
            $count--;
        }
        # For #elif, the count remains the same.
    }
    error "skip_input: fell off end of file";
}

# If the given line begins with the Unicode or UTF-8 BOM (Byte Order Mark) then
# discard the BOM in the returned line.
sub discard_bom {
    my $line = shift;
    if (length($line) > 2) {
        # Check for UTF-8 BOM (Byte Order Mark) 0xEF,0xBB,0xBF
        my $ord0 = ord(substr($line, 0, 1));
        if ($ord0 == 0xFEFF) {
            $line = substr($line, 1);         # Unicode
        } elsif ($ord0 == 0xEF) {
            my $ord1 = ord(substr($line, 1, 1));
            my $ord2 = ord(substr($line, 2, 1));
            if ($ord1 == 0xBB && $ord2 == 0xBF) {
                $line = substr($line, 3);     # UTF-8
            }
        }
    }
    return $line;
}

sub get_items {  # returns empty list for end-of-file or fatal error
    my $in = shift;
    my $firstline;
    if (@_) {
        $firstline = shift;
    }
    my @items = ();
    if (@global_items) {
        @items = @global_items;
        @global_items = ();
        return @items;
    }
    my $first = 1;
    my $in_comment = 0;
    my $seen_token = 0;
    my $line = "";
    $starting_line_number_of_remark = 0;
    $line_number_of_post_comment    = 0;
    my $l;
    @remark = ();
    @post_comment = ();
    line:
    while (($l = <$in>)) {
        $line_number[$currfile]++;
        chomp $l;
        $l =~ s/\r//g;  # zap DOS line ending
        if ($firstline) {
            $l = discard_bom($l);
            $firstline = 0;
        }
        if ($l =~ /[^\t\f[:print:]]/) {
            my $decoder = Encode::Guess->guess($l);
            unless (ref $decoder) {
                # info($decoder);
                if ($decoder =~ /No appropriate encodings found/) {
                    $l = Encode::decode("cp-1252", $l);
                } else {
                    info "Unsupported character encoding - $decoder";
                    $l =~ s/[^\t\f[:print:]]/ /g;
                }
            }
        }
        if ($l =~ /^\s*$/) {           # empty
            if ($in_comment) {
                if ($seen_token) {
                    push @post_comment, "";
                } else {
                    push @remark, "";
                }
            }
            next;
        }
        if ($in_comment) {
            if ($l =~ /\/\*/) {
                info "warning: nested comments not supported!";
            }
            if ($l =~ /\*\//) {
                my $cpos = index($l, "*/");
                my $cmnt = substr($l, 0, $cpos);
                $cmnt =~ s/\s*$//;
                $l = substr($l, $cpos+2);
                #my $cmnt = $l;
                #$cmnt =~ s/\s*\*\/.*$//;
                if ($seen_token) {
                    push @post_comment, $cmnt;
                } else {
                    push @remark, $cmnt;
                }
                $in_comment = 0;     # end of multi-line comment
                #$l =~ s/^.*\*\///;
                if ($seen_token) {
                    if ($l !~ /^\s*$/) {
                        error "unsupported comment/token combination";
                    }
                    last;
                }
                next if ($l =~ /^\s*$/);
            } else {
                if ($seen_token) {
                    push @post_comment, $l;
                } else {
                    push @remark, $l;
                }
                next;
            }
        }
        if ($l =~ /^\s*\/\/(.*)/) {  # single-line comment by itself
            my $cmnt = $1;
            unless (@remark) {
                $starting_line_number_of_remark = $line_number[$currfile];
            }
            push @remark, $cmnt;
            next;
        }
        while ($l =~ /\/\*/) {       # start of multi-line comment
            my $cpos = index($l, "/*");
            my $cend = index($l, "*/", $cpos+2);
            my $cmnt = "";
            if ($cend > 0) {
                # start and end on the same line
                # extract comment block
                $cmnt = substr($l, $cpos+2, $cend-$cpos-2);
                substr($l, $cpos, $cend-$cpos+2) = "";
            } else {
                # only start found, extract comment part
                $cmnt = substr($l, $cpos+2);
                $l = substr($l, 0, $cpos);
                # comment continues on next line
                $in_comment = 1;
            }
            $cmnt =~ s/\s*$//;
            #my $cmnt = $l;
            #$cmnt =~ s/^.*\/\*//;  # remove comment start and stuff before
            #$cmnt =~ s/\*\/.*$//;  # remove comment end and stuff after (if any)
            #if ($l =~ /\*\//) {
            #    # remove comment
            #    $l =~ s/\/\*.*\*\///;
            #} else {
            #    $in_comment = 1;
            #    # remove start of comment
            #    $l =~ s/\/\*.*$//;
            #}
            unless (defined($line_number[$currfile])) {
                die("CORBA::IDLtree::get_items line_number of $currfile undefined (1)\n");
            }
            if ($l =~ /^\s*$/) {       # If there is nothing else on the line
                push @remark, $cmnt;   # then declare it a prefixed comment;
                $starting_line_number_of_remark = $line_number[$currfile];
                next line;
            } else {
                push @post_comment, $cmnt;  # else declare it a trailing comment.
                $line_number_of_post_comment = $line_number[$currfile];
            }
        }
        if ($l =~ /\/\/(.*)$/) {
            my $cmnt = $1;
            unless ($cmnt =~ /^\s*$/) {
                unless (defined($line_number[$currfile])) {
                    die("CORBA::IDLtree::get_items line_number of $currfile undefined (2)\n");
                }
                $line_number_of_post_comment = $line_number[$currfile];
                push @post_comment, $cmnt;
            }
            $l =~ s/\/\/.*$//;         # discard trailing comment
        }
        $l =~ s/^\s+//;                # discard leading whitespace
        $l =~ s/\s+$//;                # discard trailing whitespace
        if ($first) {
            $first = 0;
        } else {
            $l = " $l";
        }
        $line .= $l;
        if (($line =~ /^#/)          # preprocessor directive
         or ($line =~ /\@/ and $line !~ /\@annotation\b/)  # annotation
         or ($line =~ /[;,":{]$/)) { #" characters declared to denote eol.
            $seen_token = 1;
            last unless $in_comment;
        }
    }
    if ($in_comment) {
        error "end of file reached while comment still open";
        $in_comment = 0;
    }
    if (! $line) {
        return ();
    }
    # sub idlsplit also does preprocessor symbol substitution.
    my @arg = idlsplit($line);
    my @tmp = @arg;
    if ($tmp[0] ne '#') {
        return @arg;
    }
    shift @tmp;  # discard '#'
    my $directive = shift @tmp;
    if ($directive eq 'if' || $directive eq 'elif') {
        emucppmsg;
        skip_input unless (eval_preproc_expr @tmp);
        @arg = get_items($in);
    } elsif ($directive eq 'ifdef') {
        my $symbol = shift @tmp;
        emucppmsg;
        skip_input unless ($symbol =~ /^\d/);
        @arg = get_items($in);
    } elsif ($directive eq 'ifndef') {
        my $symbol = shift @tmp;
        emucppmsg;
        skip_input if ($symbol =~ /^\d/);
        @arg = get_items($in);
    } elsif ($directive eq 'define') {
        my $symbol = shift @tmp;
        my $value = 1;
        emucppmsg;
        if (@tmp) {
            $value = join(' ', @tmp);
            info("// defining $symbol as $value");
        }
        if (exists $active_defines{$symbol} and
            $value ne $active_defines{$symbol}) {
            if ($cache_trees) {
                error("Redefinition of $symbol may lead to " .
                      "erroneous trees when cache_trees is used");
            } else {
                info "info: redefining $symbol";
            }
        }
        $active_defines{$symbol} = $value;
        @arg = get_items($in);
    } elsif ($directive eq 'undef') {
        my $symbol = shift @tmp;
        emucppmsg;
        if (exists $active_defines{$symbol}) {
            if ($cache_trees) {
                error("#undef of $symbol may lead to " .
                      "erroneous trees when cache_trees is used");
            }
            delete $active_defines{$symbol};
        }
        @arg = get_items($in);
    } elsif ($directive eq 'else') {
        # We only get to see the #else here if we were not skipping
        # the preceding #if or #elif.
        skip_input;
        @arg = get_items($in);
    } elsif ($directive eq 'endif') {
        @arg = get_items($in);
    }
    @arg;
}

sub unget_items {
    @global_items = @_;
}


sub isname {
    my $txt = shift;
    $txt =~ /^[A-Za-z]/
}

# check if the path given by the strings in @parts leads to
# the given $scope starting at the referring scope $refscope.
# return the absolute path if the path is OK, undef otherwise
sub check_scope {
    my ($scope, $refscope, @parts) = @_;
    my $p = join("::", get_scope($scope));

    if (@parts == 0) {
        # special case: both elements are in top-level scope
        if (! $refscope && $p eq "") {
            return $p;
        }
        # no scope given, must be in the referring scope or
        # its ancestors
        for (my $s = $refscope; $s; $s = $s->[SCOPEREF]) {
            return $p if $scope == $s;
        }
        return undef;
    }

    # the specified parts must either be an absolute
    # path to $scope or start at the referring scope
    # or one of its ancestors
    # (a path starting with "::" is always absolute,
    # though the parser can't handle this right now!)
    my $is_abs = $parts[0] eq "";
    shift @parts if $is_abs;

    # check absolute path first
    return $p if join("::", @parts) eq $p;

    unless ($is_abs) {
        # try possible "relative" paths
        for (my @anc = get_scope($refscope); @anc; pop @anc) {
            return $p if join("::", (@anc, @parts)) eq $p;
        }
    }

    # wrong scope given
    return undef;
}

# In the SUBORDINATES of ENUM there may be remark nodes or trailing comment
# nodes.  Function enum_literals returns the net literals stripped of any
# remark nodes or trailing comment info.
# It expects the SUBORDINATES of the enum node as the argument and
# returns the extracted list.
sub enum_literals {
    my ($enum_subordinate) = @_;
    unless (ref $enum_subordinate) {
        # Possible misuse - generate warning?
        return ();
    }
    my @values = ();
    foreach my $elem (@{$enum_subordinate}) {
        unless (ref($elem) eq "ARRAY") {
            Carp::cluck("enum_literals: IDLtree internal error" .
                        "- enum subordinates should be ARRAY\n");
            last;
        }
        $elem->[0] =~ /^\d/ and next;  # remark node
        push @values, $elem->[0];
    }
    return @values;
}

# check if the given literal correctly identifies
# an enumeration member of the enumeration type $type
# as referenced from the referring scope $refscope
# if $refscope is not specified, curr_scope() is used.
sub check_enum_literal {
    my ($type, $literal, $refscope) = @_;

    $refscope = curr_scope() unless defined $refscope;

    my $found = 0;
    my @p = (split "::", $literal);
    my $e = pop @p;
    my $s = check_scope($type->[SCOPEREF], $refscope, @p);
    if (defined $s) {
        foreach (enum_literals($type->[SUBORDINATES])) {
            $found = 1, last if $_ eq $e;
        }
    }
    return $found;
}

sub check_union_case {
    my ($symroot, $known_cases, $case) = @_;

    my $i = 0;
    if ($case->[TYPE] == DEFAULT) {
        foreach (@$known_cases) {
            next if $i++ == 0;
            if ($_->[TYPE] == DEFAULT) {
                error "duplicate default label";
                return undef;
            }
        }
    } else {
        my $type = root_type($known_cases->[TYPE]);
        my $c;
        if (is_a($type, ENUM)) {
            # check if value is part of enumeration
            foreach $c (@{$case->[SUBORDINATES]}) {
                unless (check_enum_literal($type, $c)) {
                    error "invalid case value $c";
                    return undef;
                }
            }
        } elsif (is_a($type, BOOLEAN)) {
            foreach $c (@{$case->[SUBORDINATES]}) {
                unless ($c eq "TRUE" || $c eq "FALSE") {
                    error "invalid case value $c";
                    return undef;
                }
            }
        } elsif (is_a($type, CHAR)) {
            foreach $c (@{$case->[SUBORDINATES]}) {
                unless ($c =~ /^'.*'$/ || $c =~ /^\d+$/) {
                    error "invalid case value $c";
                    return undef;
                }
            }
        } else {
            # must be integer
            foreach $c (@{$case->[SUBORDINATES]}) {
                unless ($c =~ /^[-+]?\d+$/) {
                    my $resolved_const = get_numeric($symroot, $c, curr_scope);
                    unless ($resolved_const =~ /^[-+]?\d+$/) {
                        error "invalid case value $c";
                        return undef;
                    }
                }
            }
        }
        foreach (@$known_cases) {
            next if $i++ == 0;
            next unless $_->[TYPE] == CASE;
            foreach (@{$_->[SUBORDINATES]}) {
                foreach $c (@{$case->[SUBORDINATES]}) {
                    if ($c eq $_) {
                        error "duplicate case label $c";
                        return undef;
                    }
                }
            }
        }
    }
    return 1;
}


sub Parse_File {
    my $filename = shift;
    if ($cache_trees) {
        my $incfile_contents_ref = $includecache->get($filename);
        if ($incfile_contents_ref) {
            bless($incfile_contents_ref, "CORBA::IDLtree");
            return $incfile_contents_ref;
        }
    } else {
        $includecache->clear();    # Roots of previously parsed includefiles
        $findnode_cache->clear();  # Flush the find_node_i() cache
    }
    $global_idlfile = $filename;
    @infilename = ();    # infilename and line_number move in parallel.
    @line_number = ();
    $n_errors = 0;       # auxiliary to sub error
    @remark = ();        # Auxiliary to comment processing
    @post_comment = ();  # Auxiliary to comment processing
    $abstract = 0;
    $currfile = -1;
    $did_emucppmsg = 0;  # auxiliary to sub emucppmsg
    @scopestack = ();
    @prev_symroots = ();
    %active_defines = %defines;
    unless ($locale_was_determined) {
        foreach my $env ('LANG', 'LOCALE', 'LC_ALL') {
            if (exists $ENV{$env}) {
                my $lang = $ENV{$env};
                if ($lang && $lang ne "C") {
                    $locale = $lang;
                    last;
                }
            }
        }
        $locale_was_determined = 1;
    }
    my $res = Parse_File_i($filename);
    if ($cache_statistics) {
        print "Node cache: " . $findnode_cache->ratio()."\n";
        print "Include cache: " . $includecache->ratio()."\n";
    }
    if ($res && !@$res) {
        warn "Warning: CORBA::IDLtree::Parse_File: $filename is empty\n";
        $res = 0;
    } elsif ($cache_trees) {
        # Put the main unit in the include cache, too
        # (it may be #included by a subsequent main file.)
        $includecache->add($filename, $res);
    }
    return $res;
}

# the function changes the passed in struct node
# into an "equivalent" valuetype
sub convert_to_valuetype {
    my ($node) = @_;

    # just in case...
    return  unless $node->[TYPE] == STRUCT;

    # first, convert the members to public state members
    foreach (@{$node->[SUBORDINATES]}) {
        my $membertype = $_->[TYPE];
        if ($membertype == REMARK) {
            $_ = [ 0, $_ ];
        } else {
            if (isnode($membertype) &&
                ($membertype->[TYPE] == CORBA::IDLtree::BOUNDED_STRING ||
                 $membertype->[TYPE] == CORBA::IDLtree::BOUNDED_WSTRING)) {
                # Ad hoc member type declaration shall have its own
                # enclosing valuetype as the SCOPEREF
                $membertype->[SCOPEREF] = $node;
            }
            $_ = [ PUBLIC, $_ ];
        }
    }
    # now, change the subordinates:
    $node->[SUBORDINATES] = [
                             0,   # abstract
                             [ 0, # is_truncatable
                               0  # ancestors
                             ],
                             $node->[SUBORDINATES], # members
                            ];
    # change the type into VALUETYPE
    $node->[TYPE] = VALUETYPE;
}

# Parses an annotation application.
# Parsing of an @annotation definition is not done here.
# Expects the annotation name as the first parameter and possible
# annotation arguments by an array reference in the second parameter.
# Is expected to be called not too long after get_items (the sub may find
# that too many args were returned by get_items and may therefore call
# unget_items).
# Returns 1 on success, 2 on unknown annotation, 0 on error.
sub parse_annotation_app {
    my ($ann, $argref) = @_;
    my ($index) = grep { $annoDefs[$_]->[0] eq $ann } 0..$#annoDefs;
    unless (defined $index) {
        warn "Unknown annotation \@$ann\n";
        if ($argref->[0] eq '(') {
            my $seen_closing_parenth = 0;
            while (@$argref) {
                 if ($argref->[0] eq ')') {
                     $seen_closing_parenth = 1;
                     last;
                 }
                 shift @$argref;
            }
            unless ($seen_closing_parenth) {
                error "Missing closing parenthesis for annotation arguments";
                return 0;
            }
        }
        return 2;
    }
    my @adef = @{$annoDefs[$index]};
    shift @adef;  # discard name
    my @anode = ($index);
    my @anargs;
    if (@adef) {
        @anargs = map { undef } @adef;
        unless ($argref && @$argref) {
            error("parse_annotation_app: internal error"
                  . " (get_items returned insufficient args)\n"
                  . Carp::longmess());
            return 0;
        }
    }
    if (@$argref && $argref->[0] eq '(') {
        unless (@adef) {
            error "Annotation \@$ann does not require arguments";
            return 0;
        }
        shift @$argref;
        my $closing_parenth_seen = 0;
        my $upcounter = 0;
        while (@$argref) {
            my $val = shift @$argref;
            if ($val eq ')') {
                $closing_parenth_seen = 1;
                last;
            }
            $val eq ',' and next;
            if ($val =~ /^[a-z]/i and $argref->[0] eq '=') {
                my $parname = $val;
                shift @$argref;
                unless (@$argref) {
                    error "Annotation \@$ann no value given for $parname";
                    return 0;
                }
                my $param_index = undef;
                for (my $ai = 0; $ai < scalar(@adef); ++$ai) {
                    if ($adef[$ai]->[1] eq $parname) {
                        $param_index = $ai;
                        last;
                    }
                }
                unless (defined $param_index) {
                    error "Annotation \@$ann unknown parameter given: $parname";
                    return 0;
                }
                $val = shift @$argref;
                my $type = $adef[$param_index]->[0];
                if (exists $annoEnum{$type}) {
                    my $enumvalues = $annoEnum{$type};
                    unless (grep { $_ eq $val } @{$enumvalues}) {
                        error "Annotation \@$ann parameter $parname illegal value: $val";
                        return 0;
                    }
                }
                $anargs[$param_index] = $val;
            } else {
                my $type = $adef[$upcounter]->[0];
                if (exists $annoEnum{$type}) {
                    my $enumvalues = $annoEnum{$type};
                    unless (grep { $_ eq $val } @{$enumvalues}) {
                        error("Annotation \@$ann parameter " . $adef[$upcounter]->[1]
                              . " illegal value: $val");
                        return 0;
                    }
                }
                $anargs[$upcounter] = $val;
                ++$upcounter;
            }
        }
        unless ($closing_parenth_seen) {
            error "Annotation \@$ann syntax error: require closing parenthesis";
            return 0;
        }
    }
    if (@adef) {
        for (my $i = 0; $i < scalar(@adef); ++$i) {
            unless (defined $anargs[$i]) {
                my $parname = $adef[$i]->[1];
                my $default = $adef[$i]->[2];
                if (defined $default) {
                    $anargs[$i] = $default;
                    info("Annotation \@$ann using default value for parameter $parname");
                } else {
                    error("Annotation \@$ann no value given for parameter $parname");
                    return 0;
                }
            }
        }
        push @anode, @anargs;
    }
    push @annotations, [ @anode ];
}

# Check whether the given union subordinates contain a DEFAULT branch.
sub has_default_branch {
    my $union_subord = shift;
    my @members = @{$union_subord};
    for (my $i = $#members; $i > 0; --$i) {
        if ($members[$i]->[TYPE] == DEFAULT) {
            return 1;
        }
    }
    return 0;
}

# Push subordinate - just like perl push() but hides
# different structure of valuetype subordinates.
sub pushsub {
    my($symbols, $noderef, $in_valuetype) = @_;
    if ($in_valuetype && !$vt2struct) {
        push @$symbols, [ 0, $noderef ];
    } else {
        push @$symbols, $noderef;
    }
}

sub Parse_File_i {
    my ($file, $input_filehandle, $symb, $in_valuetype) = @_;

    my @vt_inheritance = (0, 0);
    my $in;
    my $custom = 0;
    $abstract = 0;
    if ($file) {        # Process a new file (or includefile if cpp emulated)
        -e "$file" or abort("Cannot find file $file");
        # remove "//" from filename to ensure correct filename match
        $file =~ s:/+:/:g;
        push @infilename, $file;
        push @line_number, 0;
        $currfile = $#infilename;
        $in = $fh[$currfile];
        my $cppcmd = "";
        unless ($emucpp) {
            # Try to find and run the C preprocessor.
            # Use `cpp' in preference of `cc -E' if the former can be found.
            # If no preprocessor can be found, we will try to emulate it.
            if (locate_executable 'cpp') {
                $cppcmd = 'cpp';
            } elsif (locate_executable 'gcc') {
                $cppcmd = 'gcc -E -x c++';
            } else {
                $emucpp = 1;
            }
        }
        if ($emucpp) {
            open($in, , '<', $file) or abort("Cannot open file $file");
        } else {
            my $cpp_args = "";
            foreach (keys %defines) {
                $cpp_args .= " -D$_=" . $defines{$_};
            }
            foreach (@include_path) {
                $cpp_args .= " -I$_";
            }
            open($in, "$cppcmd $cpp_args $file |")
                 or abort("Cannot open file $file");
        }
        info("// processing: $file");
    } elsif ("$input_filehandle") {
        $in = $input_filehandle;  # Process a module or interface within file.
    }

    # symbol tree that will be constructed here
    my $symbols;
    if ($symb) {
        $symbols = $symb;
    } else {
        $symbols = [ ];
    }
    # @struct, @typestack, @namestack, @cmntstack used to be my() vars here.
    # They were moved to the global scope in order to support #include
    # statements at arbitrary locations.
    my @arg;
    my $firstline = 1;
    while ((@arg = get_items($in, $firstline))) {
        $firstline = 0;
        if ($verbose > 1) {   # "super verbose mode"
            my $line = join(' ', @arg);
            info("IDLtree: parsing $line");
        }
        if ($enable_comments && @remark) {
            my $remnode_ref = [ REMARK, $starting_line_number_of_remark, [ @remark ], 0, 0, curr_scope ];
            if (@typestack) {
                push @struct, $remnode_ref;
            } else {
                pushsub($symbols, $remnode_ref, $in_valuetype);
            }
            @remark = ();
            $starting_line_number_of_remark = 0;
        }
        my $cmnt = comment;
        KEYWORD:
        my $kw = shift @arg;
        if ($kw eq '#') {
            my $directive = shift @arg;
            if ($directive eq 'pragma') {
                my @pragma_node;
                $directive = shift @arg;
                if ($directive eq 'prefix') {
                    my $prefix = shift @arg;
                    if (substr($prefix, 0, 1) ne '"') {
                        error "prefix should be given in double quotes";
                    } else {
                        $prefix = substr($prefix, 1);
                        if (substr($prefix, length($prefix) - 1) ne '"') {
                            error "missing closing quote";
                        } else {
                            $prefix = substr($prefix, 0, length($prefix) - 1);
                        }
                    }
                    @pragma_node = (PRAGMA_PREFIX, $prefix, 0, 0, $cmnt,
                                    curr_scope);
                } elsif ($directive eq 'version') {
                    my $unitname = shift @arg;
                    my $vstring = shift @arg;
                    @pragma_node = (PRAGMA_VERSION, $unitname, $vstring, 0, $cmnt,
                                    curr_scope);
                } elsif (uc($directive) eq 'ID') {
                    my $unitname = shift @arg;
                    my $idstring = shift @arg;
                    @pragma_node = (PRAGMA_ID, $unitname, $idstring, 0, $cmnt,
                                    curr_scope);
                } else {
                    my $rest_of_line = join ' ', @arg;
                    @pragma_node = (PRAGMA, $directive, $rest_of_line, 0, $cmnt,
                                    curr_scope);
                }
                push @$symbols, \@pragma_node;
            } elsif ($directive eq 'include') {
                my $filename = shift @arg;
                emucppmsg;
                if ($filename eq '<') {
                    # try to convert filename in '<...>' to "normal" string
                    $filename = '"';
                    my $t;
                    while (@arg) {
                        $t = shift @arg;
                        if ($t eq '>') {
                            $filename .= '"';
                            last;
                        }
                        $filename .= $t;
                    }
                }
                if (substr($filename, 0, 1) ne '"') {
                    error "include file name should be given in double quotes or < >";
                } else {
                    $filename = substr($filename, 1);
                    if (substr($filename, length($filename) - 1) ne '"') {
                        error "missing closing quote";
                    } else {
                        $filename = substr($filename, 0, length($filename) - 1);
                    }
                }
                $filename =~ s/\\/\//g;  # convert DOS path to Unix
                my $found = 1;
                if (not -e "$filename") {
                    $found = 0;
                    foreach (@include_path) {
                        if (-e "$_/$filename") {
                            $filename = "$_/$filename";
                            $found = 1;
                            last;
                        }
                    }
                }
                $found or abort ("Cannot find file $filename");
                my $in_global_scope = 1;
                if (@typestack || @scopestack) {
                    $in_global_scope = 0;
                }
                my $include_node = [ INCFILE, $filename, 0, 0, $cmnt, curr_scope ];
                my $incfile_contents_ref = $includecache->get($filename);
                if ($incfile_contents_ref) {
                    $include_node->[SUBORDINATES] = $incfile_contents_ref;
                    push @$symbols, $include_node;
                } else {
                    unshift @prev_symroots, $symbols;
                    $incfile_contents_ref = [];
                    $include_node->[SUBORDINATES] = $incfile_contents_ref;
                    # add include file node early so that find_node_i
                    # can use it
                    # @todo THIS CANNOT WORK - $symbols is local in this sub
                    #       and is not passed into the Parse_file_i call.
                    push @$symbols, $include_node;
                    Parse_File_i($filename, undef, $incfile_contents_ref)
                      or abort("can't go on, sorry");
                    $includecache->add($filename, $incfile_contents_ref);
                    shift @prev_symroots;
                    pop @scopestack if $in_global_scope;
                }
                unless ($in_global_scope) {
                    # Quick fix for Ada code generator:
                    # replace the INCFILE node by the symbols if not
                    # in global scope
                    pop @$symbols;
                    foreach (@$incfile_contents_ref) {
                        push @$symbols, $_
                    }
                }
            } elsif ($directive =~ /^\d/) {
                # It's an output from the C preprocessor generated for
                # a "#include"
                my $linenum = $directive;
                $linenum =~ s/^(\d+)/$1/;
                my $filename = shift @arg;
                $filename = substr($filename, 1, length($filename) - 2);
                $filename =~ s@^./@@;
                $filename =~ s:/+:/:g;
                if ($filename eq $infilename[$currfile]) {
                    $line_number[$currfile] = $linenum;
                    next;
                }
                my $seen_file = 0;
                my $i;
                for ($i = 0; $i <= $#infilename; $i++) {
                    if ($filename eq $infilename[$i]) {
                        $currfile = $i;
                        $line_number[$currfile] = $linenum;
                        $seen_file = 1;
                        last;
                    }
                }
                last if ($seen_file);
                push @infilename, $filename;
                $currfile = $#infilename;
                $line_number[$currfile] = $linenum;
                unshift @prev_symroots, $symbols;
                my $incfile_contents_ref = Parse_File_i("", $in, []);
                $incfile_contents_ref or abort("can't go on, sorry");
                shift @prev_symroots;
                my @include_node = (INCFILE, $filename,
                                    $incfile_contents_ref, 0, $cmnt, curr_scope);
                push @$symbols, \@include_node;
            } elsif ($directive eq 'if' ||
                     $directive eq 'ifdef' ||
                     $directive eq 'ifndef' ||
                     $directive eq 'elif' ||
                     $directive eq 'else' ||
                     $directive eq 'endif' ||
                     $directive eq 'define' ||
                     $directive eq 'undef') {
                # Sanity check only -
                # preprocessor conditions and definitions were already handled
                # in sub get_items and do not appear here.
                error "internal error - seen #$directive in Parse_File_i\n";
            } else {
                info "ignoring preprocessor directive \#$directive\n";
            }
            next;

        } elsif ($kw eq '@') {
            my $ann = shift @arg;
            if ($ann eq "annotation") {
                my $name = check_name(shift @arg);
                push @typestack, ANNOTATION;
                push @namestack, $name;
                if (shift @arg ne '{') {
                    error "expecting '{'";
                    next;
                }
                @struct = ();
                if (@arg) {
                    if ($arg[0] eq '}' or
                            parse_members($symbols, \@arg, \@struct) == 1) {
                        # end of type declaration was encountered
                        push @annoDefs, [ $name, @struct ];
                        pop @namestack;
                        pop @typestack;
                        @struct = ();
                    }
                }
            } else {
                parse_annotation_app($ann, \@arg);
                if (@arg) {
                    unget_items(@arg);
                }
            }
            next;

        } elsif ($kw eq "\}") {
            if (shift @arg ne ';') {
                error "missing ';'";
            }
            unless (@typestack) {  # must be closing of module, interface, or valuetype
                if (@scopestack) {
                    pop @scopestack;
                } else {
                    # did not see a '{'
                    error("unexpected \};");
                }
                return $symbols;
            }
            if ($in_valuetype) {
                error "Parse_File_i internal: in_valuetype true on non empty typestack";
                return $symbols;
            }
            if (in_annotation_def()) {
                pop @typestack;
                my $anno = pop @namestack;
                push @annoDefs, [ $anno, @struct ];
                @struct = ();
                next;
            }
            my $type = pop @typestack;
            my $name = pop @namestack;
            my $anno = pop @annostack;
            my $cmnt = pop @cmntstack;
            if ($type == UNION && is_a($struct[0], ENUM)) {
                # For the case of ENUM, check that all enum values
                # are covered by CASEs.
                # No check possible if DEFAULT given.
                unless (has_default_branch(\@struct)) {
                    my $enumtype = root_type($struct[0]);
                    my %lits_given = ();
                    my $umember;
                    foreach $umember (@struct) {
                        if ($umember->[TYPE] == CASE) {
                            foreach (@{$umember->[SUBORDINATES]}) {
                                my $stripped_lit = $_;
                                $stripped_lit =~ s/^.*:://;
                                $lits_given{$stripped_lit} = 1;
                            }
                        }
                    }
                    foreach (enum_literals($enumtype->[SUBORDINATES])) {
                        my $lit = ref($_) ? $_->[0] : $_;
                        if (defined($lit) && !defined($lits_given{$lit})) {
                            info("$name info: no case for enum value "
                                 . $lit . " given");
                        }
                    }
                }
            }
            my @structnode = ($type, $name, [ @struct ], $anno, $cmnt, curr_scope);
            if ($struct2vt && $type == STRUCT) {
                convert_to_valuetype(\@structnode);
            }
            pushsub($symbols, [ @structnode ]);
            @struct = ();
            next;

        } elsif ($kw eq 'module') {
            my $name = check_name(shift @arg);
            error("expecting '{'") if (shift(@arg) ne '{');
            my $subord;
            my $fullname = join('::', scope_names(), $name);
            my $scope = curr_scope();
            # See if the full name is in the findnode_cache already.
            # This can happen in the case of reopened modules.
            # The findnode_cache always contains the most recently seen
            # reopening of a module.
            my $module = $findnode_cache->get($fullname);
            if ($module) {
                # If this is a reopening then our SCOPEREF shall point to
                # the previous opening of the module.
                $scope = $module;
            }
            $subord = [ ];
            $module = [ MODULE, $name, $subord, annotation, $cmnt, $scope ];
            $findnode_cache->add($fullname, $module);
            push @$symbols, $module;
            unshift @prev_symroots, $symbols;
            push @scopestack, $module;
            Parse_File_i("", $in, $subord) or abort("can't go on, sorry");
            unless ($module) {
                shift @prev_symroots;
            }
            next;

        } elsif ($kw eq 'interface') {
            my $name = check_name(shift @arg);
            my $symnode = [ INTERFACE, $name, undef, annotation, $cmnt, curr_scope ];
            my $lasttok = pop(@arg);
            if ($lasttok eq ';') {
                $symnode->[TYPE] = INTERFACE_FWD;
                push @$symbols, $symnode;
                next;
            } elsif ($lasttok ne '{') {
                push @arg, $lasttok;
                if (! require_end_of_stmt(\@arg, $in, '{')) {
                    error "expecting '{'";
                    next;
                }
            }
            my $fwd = find_node_i($name, $symbols);
            if ($fwd) {
                if ($$fwd[TYPE] != INTERFACE_FWD) {
                    error "type of interface fwd decl is not INTERFACE_FWD";
                    next;
                }
                $$fwd[SUBORDINATES] = $symnode;
            }
            my @ancestor = ();
            if (@arg) {    # we have ancestors
                if (shift @arg ne ':') {
                    error "syntax error";
                    next;
                } elsif (! @arg) {
                    error "expecting ancestor(s)";
                    next;
                }
                my $i;  # "use strict" wants it.
                for ($i = 0; $i < @arg; $i++) {
                    my $name = check_name($arg[$i], "ancestor name");
                    my $ancestor_node = find_node_i($name, $symbols);
                    if (! $ancestor_node) {
                        error "could not find ancestor $name";
                        next;
                    }
                    push @ancestor, $ancestor_node;
                    if ($i < $#arg) {
                        if ($arg[++$i] ne ',') {
                            error "expecting comma separated list of ancestors";
                            last;
                        }
                    }
                }
            }
            my $subord = [ \@ancestor, $abstract ];
            $symnode->[SUBORDINATES] = $subord;
            push @$symbols, $symnode;
            unshift @prev_symroots, $symbols;
            push @scopestack, $symnode;
            Parse_File_i("", $in, $subord)
              or abort("can't go on, sorry");
            shift @prev_symroots;
            $abstract = 0;
            next;

        } elsif ($kw eq 'local') {
            $abstract = LOCAL;
            goto KEYWORD;

        } elsif ($kw eq 'abstract') {
            $abstract = ABSTRACT;
            goto KEYWORD;

        } elsif ($kw eq 'custom') {
            $custom = 1;
            goto KEYWORD;

        } elsif ($kw eq 'valuetype') {
            my $name = check_name(shift @arg);
            my $anno = annotation;
            my $symnode = [ VALUETYPE, $name, 0, $anno, $cmnt, curr_scope ];
            if ($vt2struct) {
                push @typestack, STRUCT;
                push @namestack, $name;
                push @annostack, $anno;
                push @cmntstack, $cmnt;
                @struct = ();
            } else {
                push @$symbols, $symnode;
            }
            my $nxttok = shift @arg;
            if ($nxttok eq ';') {
                $symnode->[TYPE] = VALUETYPE_FWD;
                # Aliased to $symbols[$#symbols]
                next;
            }
            my @ancestors = ();  # do the inheritance jive
            my $seen_ancestors = 0;
            if ($nxttok eq ':') {
                if (($nxttok = shift @arg) eq 'truncatable') {
                    $vt_inheritance[0] = 1;
                    $nxttok = shift @arg;
                }
                while (isname($nxttok) and $nxttok ne 'supports') {
                    my $anc_type = find_node_i($nxttok, $symbols);
                    if (! isnode($anc_type)
                        || ($$anc_type[TYPE] != VALUETYPE &&
                            $$anc_type[TYPE] != VALUETYPE_BOX &&
                            $$anc_type[TYPE] != VALUETYPE_FWD)) {
                        error "ancestor $nxttok must be valuetype";
                    } else {
                        push @ancestors, $anc_type;
                    }
                    last unless (($nxttok = shift @arg) eq ',');
                    $nxttok = shift @arg;
                }
                $seen_ancestors = 1;
            }
            if ($nxttok eq 'supports') {
                while (isname($nxttok = shift @arg)) {
                    my $anc_type = find_node_i($nxttok, $symbols);
                    if (! $anc_type) {
                        error "unknown ancestor $nxttok";
                    } elsif (! isnode($anc_type)
                             || $$anc_type[TYPE] != INTERFACE
                             || $$anc_type[TYPE] != INTERFACE_FWD) {
                        error "ancestor $nxttok must be interface";
                    } else {
                        push @ancestors, $anc_type;
                    }
                    last unless (($nxttok = shift @arg) eq ',');
                }
                $seen_ancestors = 1;
            }
            if ($seen_ancestors) {
                if ($nxttok ne '{') {
                    error "expecting '{' at valuetype declaration";
                }
                $vt_inheritance[1] = [ @ancestors ];
            } elsif (isname $nxttok) {
                # suspect a value box
                my $type = parse_type($nxttok, \@arg, $symbols);
                if ($type) {
                    $symnode->[TYPE] = VALUETYPE_BOX;
                    $symnode->[SUBORDINATES] = $type;
                    # Aliased to $symbols[$#symbols]
                } else {
                    error "value box: unknown type $nxttok";
                }
                next;
            } elsif ($nxttok ne '{') {
                error "expecting '{' at valuetype declaration";
            }
            my $fwd = find_node_i($name, $symbols);
            if (ref($fwd) && $$fwd[TYPE] == VALUETYPE_FWD) {
                $$fwd[SUBORDINATES] = $symnode;
            }

            unless ($vt2struct) {
                my $declarations = [ ];
                my $obvsub = [ $abstract, [ @vt_inheritance ], $declarations ];
                $symnode->[SUBORDINATES] = $obvsub;
                unshift @prev_symroots, $symbols;
                push @scopestack, $symnode;
                Parse_File_i("", $in, $declarations, 1) or abort("can't go on, sorry");
                # The closing brace and ";" was seen in Parse_File_i and @scopestack
                # was popped there.
                shift @prev_symroots;
            }
            $abstract = 0;
            @vt_inheritance = (0, 0);
            next;

        } elsif ($kw eq 'public' or $kw eq 'private') {
            unless ($in_valuetype) {
                error "'$kw' is only permitted in valuetypes";
                next;
            }
            if ($abstract) {
                error "state members not permitted in abstract valuetype";
                next;
            }
            if ($vt2struct) {
                if (parse_members($symbols, \@arg, \@struct) == 1) {
                    # end of type declaration was encountered
                    my $type = pop @typestack;
                    my $name = pop @namestack;
                    my $initial_cmnt = pop @cmntstack;
                    my @node = ($type, $name, [ @struct ], 0, $initial_cmnt, curr_scope);
                    push @$symbols, [ @node ];
                    @struct = ();
                }
            } else {
                my $vt_access;
                if ($kw eq 'public') {
                    $vt_access = PUBLIC;
                } else {
                    $vt_access = PRIVATE;
                }
                if (parse_members($symbols, \@arg, $vt_access, $cmnt) == 1) {
                    # end of type declaration was encountered
                    if (@scopestack) {
                        pop @scopestack;
                    } else {
                        error "internal error - scopestack is empty";
                    }
                    return $symbols;
                }
            }
            next;

        } elsif ($kw eq 'struct' or $kw eq 'exception') {
            my $type;
            $type = ($kw eq 'struct' ? STRUCT : EXCEPTION);
            my $name = check_name(shift @arg);
            my $anno = annotation;
            push @typestack, $type;
            push @namestack, $name;
            push @annostack, $anno;
            push @cmntstack, $cmnt;
            @struct = ();
            my $nxt = shift @arg;
            if ($type == STRUCT && $nxt eq ':') {
                my $parent_type = shift @arg;
                my $parent = parse_type($parent_type, \@arg, $symbols);
                if (isnode($parent) && $parent->[TYPE] == STRUCT) {
                    push @struct, $parent;
                } else {
                    error "expecting a struct type as parent of $name";
                }
                $nxt = shift @arg;
            }
            if ($nxt ne '{') {
                error "expecting '{'";
                next;
            }
            if (@arg) {
                if ($arg[0] eq '}' or
                        parse_members($symbols, \@arg, \@struct, $cmnt) == 1) {
                    # end of type declaration was encountered
                    my $node = [ $type, $name, [ @struct ], $anno, $cmnt, curr_scope ];
                    if ($struct2vt && $type == STRUCT) {
                        convert_to_valuetype($node);
                    }
                    push @$symbols, $node;
                    pop @cmntstack;
                    pop @annostack;
                    pop @namestack;
                    pop @typestack;
                    @struct = ();
                }
            }
            next;

        } elsif ($kw eq 'union') {
            my $name = check_name(shift @arg, "type name");
            my $anno = annotation;
            push @typestack, UNION;
            push @namestack, $name;
            push @annostack, $anno;
            push @cmntstack, $cmnt;
            if (shift(@arg) ne 'switch') {
                error "union: expecting keyword 'switch'";
                next;
            }
            my $nxt = shift @arg;
            if ($nxt ne '(') {
                error "expecting '('";
                next;
            }
            $nxt = shift @arg;
            while ($nxt eq '@') {
                my $annoName = shift @arg;
                parse_annotation_app($annoName, \@arg);
                $nxt = shift @arg;
            }
            my $switchtypename = $nxt;
            my $switchtype = find_node_i($switchtypename, $symbols);
            if (! $switchtype) {
                error "unknown type of switch variable";
                next;
            } elsif (isnode $switchtype) {
                my $typ = ${$switchtype}[TYPE];
                if ($typ < BOOLEAN ||
                     ($typ > ULONG && $typ != ENUM && $typ != TYPEDEF)) {
                    error "illegal switch variable type (node; $typ)";
                    next;
                }
            } elsif ($switchtype < BOOLEAN || $switchtype > ULONGLONG) {
                error "illegal switch variable type ($switchtype)";
                next;
            }
            error("expecting ')'") if (shift @arg ne ')');
            error("expecting '{'") if (shift @arg ne '{');
            error("ignoring excess characters") if (@arg);
            @struct = ($switchtype);
            next;

        } elsif ($kw eq 'case' or $kw eq 'default') {
            my @node;
            my @casevals = ();
            if ($kw eq 'case') {
                while (@arg) {
                    push @casevals, shift @arg;
                    if (shift @arg ne ':') {
                        error "expecting ':'";
                        last;
                    }
                    last unless (@arg);
                    last unless ($arg[0] eq 'case');
                    shift @arg;
                }
                if (! @arg) {
                    # Peek ahead at following lines.  If they contain further
                    # CASEs then append them to @casevals.
                    while ((@arg = get_items($in))) {
                        $kw = shift @arg;
                        unless ($kw eq 'case') {
                            unshift @arg, $kw;
                            unget_items(@arg);
                            @arg = ();
                            last;
                        }
                        if ($arg[$#arg] eq ';') {
                            pop @arg;
                        }
                        while (@arg) {
                            push @casevals, shift @arg;
                            if (shift @arg ne ':') {
                                error "expecting ':'";
                                last;
                            }
                            last unless (@arg);
                            last unless ($arg[0] eq 'case');
                            shift @arg;
                        }
                        last if (@arg);
                    }
                }
                @node = (CASE, "", \@casevals);
            } else {
                if (shift @arg ne ':') {
                    error "expecting ':'";
                    next;
                }
                @node = (DEFAULT, "", 0);
            }
            check_union_case($symbols, \@struct, \@node);
            push @struct, \@node;
            if (@arg) {
                if (parse_members($symbols, \@arg, \@struct) == 1) {
                    # end of type declaration was encountered
                    if ($#typestack < 0) {
                        error "internal error 1";
                        next;
                    }
                    my $type = pop @typestack;
                    my $name = pop @namestack;
                    my $anno = pop @annostack;
                    my $initial_cmnt = pop @cmntstack;
                    if ($initial_cmnt) {
                        if ($cmnt && $cmnt != $initial_cmnt) {
                            push @{$initial_cmnt->[1]}, @{$cmnt->[1]};
                        }
                        $cmnt = $initial_cmnt;
                    }
                    if ($type != UNION) {
                        error "internal error 2";
                        next;
                    }
                    my @unionnode = ($type, $name, [ @struct ], $anno, $cmnt,
                                     curr_scope);
                    push @$symbols, [ @unionnode ];
                    @struct = ();
                }
            }
            next;

        } elsif ($kw eq 'enum') {
            my $typename = check_name(shift @arg, "type name");
            if (shift @arg ne '{') {
                error("expecting '{'");
                next;
            }
            my $anno = annotation;
            my @values = ();
            @arg = get_items($in) unless @arg;
            while (1) {
                my $lit = shift @arg;
                if (in_annotation_def()) {
                    unless ($lit =~ /^\w+$/) {
                        error("illegal enum value at $lit");
                        $lit = check_name($lit);
                    }
                    push @values, $lit;
                } else {
                    if ($enable_comments && @remark) {
                        push @values, [ $starting_line_number_of_remark, "", [ @remark ]];
                        $starting_line_number_of_remark = 0;
                        @remark = ();
                    }
                    while ($lit eq '@') {
                        my $annoName = shift @arg;
                        parse_annotation_app($annoName, \@arg);
                        $lit = shift @arg;
                    }
                    $lit = check_name($lit);   # must be a literal
                    unless ($lit =~ /^\w+$/) {
                        last;  # error message was already produced by sub check_name
                    }
                    push @values, [ $lit, annotation, comment ];
                }
                if (@arg) {
                    my $nxt = shift @arg;
                    $nxt eq '}' and last;
                    unless ($nxt eq ',') {
                        error "syntax error at $nxt (expecting ',')";
                        last;
                    }
                }
            } continue {
                @arg = get_items($in) unless @arg;
            }
            if (in_annotation_def()) {
                $annoEnum{$typename} = [ @values ];
            } else {
                my $node = [ ENUM, $typename, [ @values ], $anno, $cmnt, curr_scope ];
                push @$symbols, $node;
            }
            next;
        }

        if (! require_end_of_stmt(\@arg, $in)) {
            error "statement not terminated";
            next;
        }

        if ($kw eq 'native') {
            my $name = check_name(shift @arg, "type name");
            my $node = [ NATIVE, $name, 0, annotation, $cmnt, curr_scope ];
            pushsub($symbols, $node, $in_valuetype);

        } elsif ($kw eq 'const') {
            my $type = shift @arg;
            my $name = shift @arg;
            if (shift(@arg) ne '=') {
                error "expecting '='";
                next;
            }
            my $typething = find_node_i($type, $symbols);
            unless ($typething) {
                error "unknown const type $type";
                next;
            }
            # Check basic validity of the RHS expression.
            foreach (@arg) {
                next if (/^\d/ or /^\.\d/ or /^-\d/);   # numeric constant
                next if (/^'.*'$/ or /^".*"$/);         # character or string
                next if is_valid_identifier $_;         # identifier
                # Check against predefined operands.
                my $arg = $_;
                my @operands = ( '+', '-', '*', '/', '%', '<<', '>>', '~',
                                 '^', '|', '&', '!', '||', '&&', '==', '!=',
                                 '<', '>', '<=', '>=' );
                my $is_operand = 0;
                foreach (@operands) {
                    if ($arg eq $_) {
                        $is_operand = 1;
                        last;
                    }
                }
                next if $is_operand;
                error "unknown token in CONST: $arg";
            }
            my @tuple = ($typething, [ @arg ]);
            if (isnode $typething) {
                my $id = ${$typething}[TYPE];
                if ($id < ENUM || $id > TYPEDEF) {
                    error "expecting type";
                    next;
                }
            }
            my $node = [ CONST, $name, \@tuple, annotation, $cmnt, curr_scope ];
            pushsub($symbols, $node, $in_valuetype);

        } elsif ($kw eq 'typedef') {
            my $oldtype = check_typename(shift @arg, "name of original type");
            # TO BE DONE: oldtype is STRUCT or UNION
            my $existing_typenode = parse_type($oldtype, \@arg, $symbols);
            if (! $existing_typenode) {
                error "typedef: unknown type $oldtype";
                next;
            }
            my $newtype = check_name(shift @arg, "name of newly defined type");
            my @dimensions = ();
            while (@arg) {
                if (shift(@arg) ne '[') {
                    error "expecting '['";
                    last;
                }
                my $dim;
                my $token;
                while (@arg) {
                    $token = shift(@arg);
                    last if ($token eq ']');
                    if ($dim) {
                        $dim .= ' ';
                    }
                    $dim .= $token;
                }
                unless ($dim) {
                    error "expecting dimension";
                    last;
                }
                unless ($token eq ']') {
                    error "expecting ']'";
                    last;
                }
                push @dimensions, $dim;
            }
            my @subord = ($existing_typenode, [ @dimensions ]);
            my $node = [ TYPEDEF, $newtype, \@subord, annotation, $cmnt, curr_scope ];
            pushsub($symbols, $node, $in_valuetype);

        } elsif ($kw eq 'readonly' or $kw eq 'attribute') {
            my $readonly = 0;
            if ($kw eq 'readonly') {
                if (shift(@arg) ne 'attribute') {
                    error "expecting keyword 'attribute'";
                    next;
                }
                $readonly = 1;
            }
            my $typename = shift @arg;
            my $type = parse_type($typename, \@arg, $symbols);
            if (! $type) {
                error "unknown type $typename";
                next;
            }
            my @subord = ($readonly, $type);
            my $name = check_name(shift @arg);
            my $node = [ ATTRIBUTE, $name, \@subord, annotation, $cmnt, curr_scope ];
            pushsub($symbols, $node, $in_valuetype);

        } elsif (grep /\(/, @arg) {   # Method declaration
            my $rettype;
            my @subord;
            if ($kw eq 'oneway') {
                if (shift(@arg) ne 'void') {
                    error "expecting keyword 'void' after oneway";
                    next;
                }
                $rettype = ONEWAY;
            } elsif ($kw eq 'void') {
                $rettype = VOID;
            } elsif ($in_valuetype and $kw eq 'factory') {
                $rettype = FACTORY;
            } else {
                $rettype = parse_type($kw, \@arg, $symbols);
                if (! $rettype) {
                    error "unknown return type $kw";
                    next;
                }
            }
            @subord = ($rettype);
            my $name = check_name(shift @arg, "method name");
            if (shift(@arg) ne '(') {
                error "expecting opening parenthesis";
                next;
            } elsif (pop(@arg) ne ')') {
                error "expecting closing parenthesis";
                next;
            }
            my @exception_list = ();
            my $expecting_exception_list = 0;
            while (@arg) {
                my $m = shift @arg;
                my $typename = shift @arg;
                my $pname = shift @arg;
                if ($m eq ')') {
                    if ($typename ne 'raises') {
                        error "expecting keyword 'raises'";
                    } elsif ($pname ne '(') {
                        error "expecting '(' after 'raises'";
                    } else {
                        $expecting_exception_list = 1;
                    }
                    last;
                }
                my $pmode = ($m eq 'in'    ? &IN :
                             $m eq 'out'   ? &OUT :
                             $m eq 'inout' ? &INOUT : 0);
                unless ($pmode) {
                    error("$name parameter $pname : bad mode $m (expecting 'in', 'out', or 'inout')");
                    last;
                }
                if ($rettype == FACTORY && $pmode != IN) {
                    error("$name: FACTORY parameter $pname must have mode 'in'");
                    last;
                }
                my $ptype = find_node_i($typename, $symbols);
                if (! $ptype) {
                    error "unknown type of parameter $pname";
                    last;
                }
                my @param_node = ($ptype, $pname);
                push @param_node, $pmode;
                push @subord, [ @param_node ];
                if (@arg and $arg[0] eq ',') {
                    shift @arg;
                }
            }
            my @node = (METHOD, $name, [ @subord ], annotation, $cmnt, curr_scope);
            if ($expecting_exception_list) {
                while (@arg) {
                    my $exc_name = shift @arg;
                    my $exc_type = find_node_i($exc_name, $symbols);
                    if (! $exc_type) {
                        error "unknown exception $exc_name";
                        last;
                    } elsif (${$exc_type}[TYPE] != EXCEPTION) {
                        error "cannot raise $exc_name (not an exception)";
                        last;
                    }
                    push @exception_list, $exc_type;
                    if (@arg and shift @arg ne ',') {
                        error "expecting ',' in exception list";
                        last;
                    }
                }
            }
            if ($in_valuetype) {
                if (@exception_list) {
                    error "'raises' not yet supported in valuetype methods";
                }
            } else {
                push @{$node[SUBORDINATES]}, [ @exception_list ];
            }
            pushsub($symbols, [ @node ], $in_valuetype);

        } else {                          # Data
            unshift @arg, $kw;   # put type back into @arg
            if ($#typestack < 0) {
                error "unexpected declaration";
                next;
            }
            if ($typestack[-1] == UNION) {
                # a union case may be followed by only one declaration,
                # i.e. each declaration must come after CASE or DEFAULT
                my $i = $#struct;
                while ($i > 0) {
                    last unless $struct[$i]->[TYPE] == REMARK;
                    --$i;
                }
                if ($i < 0 || $struct[$i]->[TYPE] != CASE && $struct[$i]->[TYPE] != DEFAULT) {
                    error "unexpected declaration, case missing?";
                    next;
                }
            }
            if (parse_members($symbols, \@arg, \@struct, $cmnt) == 1) {
                # end of type declaration was encountered
                my $type = pop @typestack;
                my $name = pop @namestack;
                if ($type == ANNOTATION) {
                    push @annoDefs, [ $name, @struct ];
                } else {
                   my $anno = pop @annostack;
                   my $initial_cmnt = pop @cmntstack;
                   if ($initial_cmnt) {
                       if ($cmnt && $cmnt != $initial_cmnt) {
                           push @{$initial_cmnt->[1]}, @{$cmnt->[1]};
                       }
                       $cmnt = $initial_cmnt;
                   }
                   my @node = ($type, $name, [ @struct ], $anno, $cmnt, curr_scope);
                   push @$symbols, [ @node ];
                }
                @struct = ();
            }
        }
    }
    info("IDLtree: done with parsing $file\n");
    if ($file) {
        close $in;
        pop @infilename;
        pop @line_number;
        $currfile--;
    }
    if ($n_errors) {
        return 0;
    }
    bless($symbols, "CORBA::IDLtree") unless $symb;
    return $symbols;
}

# If @{$argref} ends with ';' right off the bat then pop @{$argref} and
# return success.
# Otherwise read items from file and push them onto @{$argref} until ';'
# is seen.
# If end of file is encountered before seeing a ';' then return error,
# else pop the ';' off end of @{$argref} and return success.
sub require_end_of_stmt {
    my $argref = shift;
    my $file = shift;
    my $stmt_terminator = ';';
    if (@_) {
        $stmt_terminator = shift;
    }
    if ($argref->[$#$argref] eq $stmt_terminator) {
        pop @{$argref};
        return 1;
    }
    my @new_items;
    while ($argref->[$#$argref] ne $stmt_terminator) {
        last if (! (@new_items = get_items($file)));
        push @{$argref}, @new_items;
    }
    if ($argref->[$#$argref] eq $stmt_terminator) {
        pop @{$argref};
        return 1;
    }
    0;
}


sub isnode {
    my $node_ref = shift;

    ref($node_ref) or return 0;
    ref($node_ref) eq "ARRAY" && defined($node_ref->[TYPE]) or return 0;
    if ($node_ref->[TYPE] >= BOOLEAN
        && $node_ref->[TYPE] < NUMBER_OF_TYPES) {
        if (scalar(@$node_ref) == 5) {
            # We give a warning here because element count 5 could indicate
            # that isnode() is called on a structured member (may indicate
            # misuse or latent bug).
            info("isnode(" . $node_ref->[NAME] . ") : element count is 5\n"
                 . Carp::longmess());
        }
        return (scalar(@$node_ref) == 6);
    }
    # NB: The (@$node_ref == 6) means that component descriptors of
    # structs/unions/exceptions and parameter descriptors of methods
    # do not qualify as nodes.
    return 0;
}


sub is_scope {
    my $thing = shift;
    my $rv = 0;
    if (isnode $thing) {
        my $type = $$thing[TYPE];
        $rv = ($type == MODULE || $type == INTERFACE || $type == VALUETYPE ||
               $type == INCFILE);
    }
    $rv;
}


sub is_type {
    my $thing = shift;
    if (isnode($thing)) {
        my $type = $thing->[TYPE];
        return $type == FIXED
            || $type == BOUNDED_STRING
            || $type == BOUNDED_WSTRING
            || $type == SEQUENCE
            || $type == ENUM
            || $type == TYPEDEF
            || $type == NATIVE
            || $type == STRUCT
            || $type == UNION
            || $type == INTERFACE
            || $type == INTERFACE_FWD
            || $type == VALUETYPE
            || $type == VALUETYPE_FWD
            || $type == VALUETYPE_BOX;
    } else {
        return is_elementary_type($thing);
    }
}

# Return the names of the nodes in @scopestack as a list.
sub scope_names {
    my @names = ();
    foreach my $noderef (@scopestack) {
        unless ($$noderef[TYPE] == INCFILE) {
            push @names, $$noderef[NAME];
        }
    }
    @names;
}


# Only push those elements which are not already in targetlist.
sub push_uniq {
    my ($targetlistref, @elements) = @_;
    my $element;
    foreach $element (@elements) {
        unless (grep { $_ eq $element } @$targetlistref) {
            push @$targetlistref, $element;
        }
    }
}

# Auxiliary to find_node_i:
# Find symbol named by @parts in (or below) scope $root
# Return list of matching node refs (empty list if no match)
# Does not check enclosing scopes!
sub find_node_i_sc {
    my ($root, @parts) = @_;

    my ($decls, $start, $end);
    my $anc = undef;
    my $type = 0;
    $start = 0;
    if (isnode($root)) {
        $decls = $root->[SUBORDINATES];
        $type = $root->[TYPE];
        if ($type == INTERFACE) {
            $anc = $decls->[0];
            $start = 2;
        } elsif ($type == VALUETYPE) {
            $decls = $decls->[2];
        } elsif ($type == INTERFACE_FWD) {
            my $full_interface = $decls;
            unless (isnode($full_interface)) {
                # Return the INTERFACE_FWD node only if the full interface
                # is not known.
                my @r = ();
                my $first = $parts[0];
                if (defined($root->[NAME]) && $root->[NAME] eq $first) {
                    info("find_node_i_sc($first) : Unresolved INTERFACE_FWD");
                    @r = ($root);
                }
                return @r;
            }
            $decls = $full_interface->[SUBORDINATES];
            $anc = $decls->[0];
            $start = 2;
        }
    } else {
        $decls = $root;
    }
    $end = $#$decls;
    my $first = shift @parts;
    my @result = ();
    my $i;
    for ($i = $start; $i <= $end; $i++) {
        my $node = $decls->[$i];
        # !isnode($node) on the first 2 elements of INTERFACE subordinates
        next unless (isnode $node);
        if ($type == VALUETYPE) {
            next if $node->[0];  # ignore state members
            $node = $node->[1];
        }
        my $nt = $node->[TYPE];
        unless (defined $nt) {
          error("Undefined TYPE on node: " . join(',', @$node) . Carp::longmess());
          next;
        }
        next if ($nt == REMARK || $nt == METHOD || $nt == ATTRIBUTE);
        my @r;
        if ($nt == INCFILE) {
            @r = find_node_i_sc($node->[SUBORDINATES], $first, @parts);
        } elsif (defined($node->[NAME]) && $node->[NAME] eq $first) {
            if (@parts == 0) {
                @r = ($node);
                if ($nt == INTERFACE_FWD) {
                    # Return the full interface if it is already known.
                    my $full_interface = $node->[SUBORDINATES];
                    if (isnode($full_interface)) {
                        @r = ($full_interface);
                    }
                }
            } else {
                @r = find_node_i_sc($node, @parts);
            }
        }
        if (@r) {
            push_uniq(\@result, @r);
        }
    }

    # interfaces may inherit symbols from their ancestors
    if (defined($anc) && @parts == 0) {
        my @r;
        foreach (@$anc) {
            @r = find_node_i_sc($_, $first);
            if (@r) {
                push_uniq(\@result, @r);
            }
        }
    }
    return @result;
}

sub find_node_i {
    # Returns a reference to the defining node, or a type id value
    # if the name given is a CORBA predefined type name.
    # Returns 0 if the name could not be identified.
    my $name = shift;
    if ("$name" eq "") {
        Carp::cluck("IDLtree::find_node_i() called on empty name\n");
        return 0;
    }
    my $current_symtree_ref = shift;
    my $is_abs = 0;
    if ($name =~ /^::/) {
        $name =~ s/^:://;
        $is_abs = 1;
    }
    if ($name =~ /^CORBA::/ || $name !~ /::/) {
        my $n = $name;
        # this is not absolutely correct: according to the CORBA
        # specification IDL predefined names must not be scoped
        $n =~ s/^CORBA:://;
        my $predef_type_id = predef_type($n);
        if ($predef_type_id) {
            return $predef_type_id;
        }
    }

    if (in_annotation_def()) {
        if (exists $annoEnum{$name}) {
            return $name;
        }
        error("\@annotation " . $namestack[$#namestack] . ": unknown type $name");
        return 0;
    }

    my $res = undef;
    my @namecomponents = split(/::/, $name);

    unless ($is_abs) {
       # check "local" scope first
       my $scn = join("::", scope_names(), @namecomponents);
       $res = $findnode_cache->get($scn);
       return $res if defined $res;
       my @r = find_node_i_sc($current_symtree_ref, @namecomponents);
       if (@r == 1) {
           $res = $r[0];
           $findnode_cache->add($scn, $res);
           return $res;
       }
    }

    my @roots = ($current_symtree_ref);
    if (@prev_symroots && $prev_symroots[-1] != $current_symtree_ref) {
        push @roots, $prev_symroots[-1];
    }
    my $root;
    foreach $root (@roots) {
        unless ($is_abs) {
            my @scopes = scope_names;
            while (@scopes) {
                my $scn = join("::", @scopes);
                # try the node cache for the full name first
                my $n = join("::", $scn, $name);
                $res = $findnode_cache->get($n);
                if ($res) {
                    return $res;
                }
                # find the scope
                my @sc = find_node_i_sc($root, @scopes);
                last unless @sc;
                foreach (@sc) {
                    my $s = $_;
                    my @r = find_node_i_sc($s, @namecomponents);
                    if (@r) {
                        if (scalar(@r) > 1) {
                            # remove pragmas from node list for now
                            @r = grep(!is_pragma($_), @r);
                            if (@r > 1) {
                                warn("find_node_i: find_node_i_sc(" . typeof($s)
                                     . ", $name) returns multiple matches:\n");
                                foreach (@r) {
                                    warn "\t$_\n";
                                }
                                Carp::cluck();
                            } else {
                                warn("find_node_i($name): pragmas ignored\n");
                            }
                        }
                        
                        $res = $r[0];
                        $findnode_cache->add($n, $res);
                        return $res;
                    }
                }
                pop @scopes;
            }
        }
        # check global scope
        #info "find_node_i($name): checking global scope...\n";
        $res = $findnode_cache->get($name);
        last if defined  $res;
        my @r = find_node_i_sc($root, @namecomponents);
        if (@r) {
            if (scalar(@r) > 1) {
                # remove pragmas from node list for now
                @r = grep(!is_pragma($_), @r);
                if (@r > 1) {
                    warn("find_node_i: global find_node_i_sc("
                         . $name . ") returns multiple matches:\n");
                    foreach (@r) {
                        warn("\t" . typeof($_) . "\n");
                    }
                    Carp::cluck();
                } else {
                    warn("find_node_i($name): pragmas ignored\n");
                }
            }
            $res = $r[0];
            my $n = typeof($res, 1);
            $findnode_cache->add($n, $res);
            last;
        }
    }
    return $res;
}


sub info {
    $verbose or return;
    my $message = shift;
    if ($currfile >= 0 && $currfile < scalar(@infilename)) {
        print($infilename[$currfile]  . " line " . $line_number[$currfile]
                  . ": $message\n");
    } else {
        print($message . "\n");
    }
}

sub error {
    my $message = shift;
    if ($currfile >= 0 && $currfile < scalar(@infilename)) {
        warn($infilename[$currfile]  . " line " . $line_number[$currfile]
                  . ": $message\n");
    } else {
        warn($message . "\n");
    }
    $n_errors++;
}

sub abort {
    my $message = shift;
    my $f = "";
    if ($currfile >= 0) {
        $f = $infilename[$currfile]  . " line " . $line_number[$currfile]
          . ": ";
    }
    die ($f . $message . "\n");
}


# From here on, it's only Useful User Utilities
#  (not required for IDLtree internal purposes)

sub typeof {      # Returns the string of a "type descriptor" in IDL syntax
    my $type = shift;
    my $gen_scope = 0;       # generate scope-qualified name
    if (@_) {
        $gen_scope = shift;
    }
    my $rv = "";
    if (!ref($type) && ($type >= BOOLEAN && $type < NUMBER_OF_TYPES)) {
        $rv = $predef_types[$type];
        if ($type <= ANY) {
            $rv =~ s/_/ /g;
        }
        return $rv;
    } elsif (! isnode($type)) {
        Carp::cluck("CORBA::IDLtree::typeof error: parameter is not a node ($type)\n");
        return "";
    }
    my @node = @{$type};
    my $name = $node[NAME];
    my $prefix = "";
    if ($gen_scope) {
        my @tmpnode = @node;
        my @scope;
        while ((@scope = @{$tmpnode[SCOPEREF]})) {
            last if ($scope[TYPE] == INCFILE);
            my $new_prefix = $scope[NAME] . "::";
            unless ($prefix =~ /\b$new_prefix/) {
                $prefix = $new_prefix . $prefix;
            }
            @tmpnode = @scope;
        }
        if (ref $gen_scope) {
            # @gen_scope contains the scope strings.
            # Now we can decide whether the scope prefix is needed.
            my $curr_scope = join("::", @{$gen_scope});
            if ($prefix eq "${curr_scope}::") {
                $prefix = "";
            }
        }
    }
    $rv = "$prefix$name";
    if ($node[TYPE] == FIXED) {
        my @digits_and_scale = @{$node[SUBORDINATES]};
        my $digits = $digits_and_scale[0];
        my $scale = $digits_and_scale[1];
        $rv = "fixed<$digits,$scale>";
    } elsif ($node[TYPE] == BOUNDED_STRING ||
             $node[TYPE] == BOUNDED_WSTRING) {
        my $wide = "";
        if ($node[TYPE] == BOUNDED_WSTRING) {
            $wide = "w";
        }
        $rv = "${wide}string<" . $name . ">";
    } elsif ($node[TYPE] == SEQUENCE) {
        my $bound = $name;   # NAME holds the bound
        my $eltype = typeof($node[SUBORDINATES], $gen_scope);
        $rv = 'sequence<' . $eltype;
        if ($bound) {
            $rv .= ", $bound";
        }
        $rv .= '>';
    }
    $rv;
}


sub is_a {
    # Determines whether node is of given type. Recurses through TYPEDEFs.
    my ($type, $typeid) = @_;

    unless ($type) {
        Carp::cluck("CORBA::IDLtree::is_a: invalid input (comparing to "
             . typeof($typeid) . ")\n");
        return 0;
    }
    if (! isnode $type) {
        if ($typeid > 0) {
            return $type == $typeid;
        } else {
            return typeof($type) eq $typeid;
        }
    }

    # check the node
    if ($typeid > 0) {
        return 1 if $type->[TYPE] == $typeid;
    } else {
        return 1 if scoped_name($type) eq $typeid;
    }
    return 0 unless $type->[TYPE] == TYPEDEF;

    # we have a typedef

    my $origtype_and_dim = $type->[SUBORDINATES];

    # array ?
    my $dimref = $$origtype_and_dim[1];
    return 0 if $dimref && @{$dimref};

    # no, recursively check basetype
    return is_a($$origtype_and_dim[0], $typeid);
}

sub root_type {
    # Returns the original type of a TYPEDEF, i.e. recurses through
    # all non-array TYPEDEFs until the original type is reached.
    my $type = shift;
    if (isnode $type and $$type[TYPE] == TYPEDEF) {
        my($origtype, $dimref) = @{$$type[SUBORDINATES]};
        unless ($dimref && @{$dimref}) {
            return root_type($origtype);
        }
    }
    $type
}

sub root_elem_type {
    # Returns the original type of a TYPEDEF, i.e. recurses through
    # all TYPEDEFs until the original type is reached.
    # Also recurses through array types taking the element type of
    # an array type.
    my $type = shift;
    if (isnode $type and $$type[TYPE] == TYPEDEF) {
        return root_elem_type($type->[SUBORDINATES][0]);
    }
    return $type;
}


sub is_pragma {
    my $type = shift;
    if (isnode $type) {
        $type = $type->[TYPE];
    }
    return ($type == PRAGMA_PREFIX ||
            $type == PRAGMA_VERSION ||
            $type == PRAGMA_ID ||
            $type == PRAGMA);
}

sub files_included {
    return $includecache->symbols()
}

sub collect_includes {
   my($symroot, $dependency_hash_ref) = @_;
   my $myname = "CORBA::IDLtree::collect_includes";

   if (! $symroot) {
       warn "\n$myname: encountered empty elem (returning)\n";
       return;
   } elsif (not ref $symroot) {
       warn "\n$myname: incoming symroot is $symroot (returning)\n";
       return;
   } elsif (isnode $symroot) {
       warn "\n$myname: usage error: invoked on node (returning)\n";
       return;
   }
   foreach my $noderef (@{$symroot}) {
       my @node = @{$noderef};
       my $type = $node[TYPE];
       my $name = $node[NAME];
       if ($type == INCFILE) {
           $dependency_hash_ref->{$name} = 1;
           collect_includes($noderef->[SUBORDINATES], $dependency_hash_ref);
       }
   }
}

# For floating point notation, FORTRAN and C inspired languages support
# omitting the trailing dot-zero but Ada does not.
sub append_dot_zero {
    my $res = shift;
    my $epos = index($res, 'e');
    if ($epos < 0) {
        $epos = index($res, 'E');
    }
    if ($epos > 0) {
        $res = substr($res, 0, $epos) . ".0" . substr($res, $epos);
    } else {
        $res .= ".0";
    }
    return $res;
}

sub get_numeric {
    my $tree = shift;
    my ($value, $scoperef, $wantfloat) = @_;

    if ($value =~ /^[-+]?(?:0x)?[0-9a-f]*$/i) {
        # integer literal, convert to decimal
        if ($is64bit) {
            my $res = eval($value);
            if ($wantfloat) {
                $res = append_dot_zero($res);
            }
            return $res;
        } else {
            # use BigInt so that Perl won't switch to
            # floating point for large values
            my $v;
            if ($value =~ /^[-+]?0[0-7]/) {
                # Math::BigInt->new won't convert octal numbers
                # (and from_oct produces NaN for '0')...
                if (Math::BigInt->can('from_oct')) {
                    $v = Math::BigInt->from_oct($value);
                } else {
                    # older Math::BigInt versions don't have from_oct
                    my @dg = (split //, $value);
                    my $sg = '';
                    if ($dg[0] eq '-' || $dg[0] eq '+' || $dg[0] eq '0') {
                       my $c = shift @dg;
                       $sg = $c if $c eq '-';
                    }
                    $v = Math::BigInt->new(shift @dg);
                    while (@dg > 0) {
                       my $c = shift(@dg);
                       if ($c lt '0' || $c gt '7') {
                           $v->bnan();
                           last;
                       }
                       $v = $v * 8 + $c;
                    }
                    $v->bneg() if $sg eq '-';
                }
                if ($v->is_nan()) {
                    return undef;
                }
            } else {
                $v = Math::BigInt->new($value);
                if ($v->is_nan()) {
                    return undef;
                }
                if ($wantfloat && $v !~ /\./) {
                    $v = append_dot_zero($v);
                }
            }
            return $v;
        }
    }
    if ($value =~ /^[-+]?(?:\d+.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/) {
        # floating point literal
        my $res = eval($value);
        if ($wantfloat && $res !~ /\./) {
            $res = append_dot_zero($res);
        }
        return $res;
    }

    if (isnode($value)) {
        # only const node allowed here
        return undef unless $value->[TYPE] == CONST;
        # constants may contain an expression which
        # max contain other constants
        my $t = root_type($value->[SUBORDINATES][0]);
        $wantfloat = ($t >= FLOAT && $t <= LONGDOUBLE);
        my $rhs_ref = $value->[SUBORDINATES][1];

        my $expr = "";
        foreach my $token (@$rhs_ref) {
            if ($token =~ /^[a-z]/i) {
                # hex value or constant
                my $v = get_numeric($tree, $token, $value->[SCOPEREF], $wantfloat);
                if (defined $v) {
                    $expr .= $v;
                } else {
                    $expr .= " $token";
                }
            } else {
                $expr .= " $token";
            }
        }
        my $res = eval($expr);
        if ($wantfloat && $res !~ /\./) {
            $res = append_dot_zero($res);
        }
        return $res;
    }

    my @expr = idlsplit($value);
    if (@expr > 1) {
        # expression, construct a "pseudo const node" from it
        my $t = ($wantfloat ? &FLOAT : &LONG);
        # &LONG in the above is probably wrong - but we get away with it.
        # We just need to distinguish float from non float type here.
        return get_numeric($tree, [ CONST, "expr", [$t, [ @expr ] ], 0, "", $scoperef ], $wantfloat);
    } elsif ($expr[0] eq 'FALSE') {
        info "CORBA::IDLtree::get_numeric returns 'false' for boolean FALSE";
        return 'false';
    } elsif ($expr[0] eq 'TRUE') {
        info "CORBA::IDLtree::get_numeric returns 'true' for boolean TRUE";
        return 'true';
    }
    my $node = find_node($tree, $value, $scoperef);
    if (isnode($node)) {
        return get_numeric($tree, $node, $wantfloat);
    }
    Carp::cluck ("unknown symbol in expression: $value\n");
    return undef;
}


# Subs for finding stuff

sub find_in_current_scope {  # Auxiliary to find_scope() / find_node().
    my $name = shift;
    my $scoperef = shift;    # Expects node (of MODULE or INTERFACE)
    my $must_be_scope_node = 0;
    if (@_) {
        $must_be_scope_node = shift;
    }
    return undef unless defined $scoperef->[SUBORDINATES];

    my $decls = $scoperef->[SUBORDINATES];
    my $start = 0;
    my $scopetype = $scoperef->[TYPE];
    if ($scopetype == INTERFACE) {
        $start = 2;
    } elsif ($scopetype == VALUETYPE) {
        $decls = $decls->[2];
    }
    my $end = $#$decls;
    for (my $i = $start; $i <= $end; $i++) {
        my $node = $decls->[$i];
        if ($scopetype == VALUETYPE) {
            next if $node->[0];  # ignore state members
            $node = $node->[1];
        }
        if (@$node > 1 && $node->[NAME] eq $name) {
            if ($must_be_scope_node and not is_scope $node) {
                warn("warning: $name also used in " .
                     scoped_name($node) . "\n");
            } else {
                return $node;
            }
        }
    }
    undef;
}

sub find_scope_i;  # Auxiliary to find_scope().

sub find_scope_i {
    my ($scopelist_ref, $currscope, $global_symroot) = @_;
    my @scopes = @{$scopelist_ref};
    # $currscope sometimes is 0 instead of undef...

    $currscope = undef unless $currscope;
    unless (defined $currscope) {
        return undef unless defined $global_symroot;

        # Try find it somewhere in $global_symroot.
      GLOBAL_SCOPES:
        foreach my $node (@$global_symroot) {
            if ($node->[TYPE] == INCFILE) {
                my $subord = $node->[SUBORDINATES];
                $currscope = find_scope_i(\@scopes, undef, $subord);
                last GLOBAL_SCOPES if $currscope;
            } elsif (is_scope($node) && $scopes[0] eq $node->[NAME]) {
                # It's in this scope.
                $currscope = $node;
                if (scalar(@scopes) > 1) {
                    # See if the further scopes match, too.
                    my $subord = $node->[SUBORDINATES];
                    my @sc = @scopes;
                    shift @sc;
                    $currscope = find_scope_i(\@sc, undef, $subord);
                    if ($currscope) {
                        return $currscope;
                    }
                } else {
                    last;
                }
            }
        }
        return undef unless defined $currscope;
    }

    if ($scopes[0] eq $$currscope[NAME]) {
        # It's in the current scope.
        shift @scopes;
        while (@scopes) {
            my $sought_name = shift @scopes;
            $currscope = find_in_current_scope($sought_name, $currscope, 1);
            last unless $currscope;
        }
        return $currscope;
    }
    # Not a direct match with current scope.
    # Try the scopes nested in the current scope.
    my $scope = find_in_current_scope($scopes[0], $currscope, 1);
    if ($scope) {
        shift @scopes;
        while (@scopes) {
            my $sought_name = shift @scopes;
            $scope = find_in_current_scope($sought_name, $scope, 1);
            last unless $scope;
        }
        return $scope;
    }
    # Still no match. Step outside and try again.
    find_scope_i($scopelist_ref, $$currscope[SCOPEREF], $global_symroot);
}

sub find_scope {
    my $global_symroot = shift;
    my ($scopelist_ref, $currscope) = @_;

    my $scoperef = undef;
    $scoperef = find_scope_i($scopelist_ref, $currscope)
      if defined $currscope;

    # undef as the second arg to find_scope_i means
    # try to find it anywhere in $global_symroot.
    $scoperef = find_scope_i($scopelist_ref, undef, $global_symroot)
      unless defined $scoperef;

    $scoperef;
}

# Auxiliary to get_scope()
sub get_scope_1;

sub get_scope_1 {
    my ($scoperef) = @_;
    return () unless ref($scoperef);
    return () if ($scoperef->[TYPE] == INCFILE);
    return (get_scope_1($scoperef->[SCOPEREF]), $scoperef->[NAME]);
}

# return a list of scope names leading to the given scope
# (including the scope itself)
sub get_scope {
    my $scoperef = shift;
    my @scopes = get_scope_1($scoperef);
    # Remove multiple consecutive mentions of the same scope.
    # This happens for reopened modules (the SCOPEREF of a reopening
    # points to the previous opening of the same module.)
    my $i;
    for ($i = 1; $i < scalar(@scopes); $i++) {
        if ($scopes[$i] eq $scopes[$i - 1]) {
            splice(@scopes, $i, 1);
            $i--;
        }
    }
    return @scopes;
}

sub find_node {
    my $global_symroot = shift;
    my ($name, $scoperef, $recurse) = @_;
    
    #Carp::cluck("find_node: scoperef == 0") if $scoperef==0;
    
    # $scoperef is expected to be a MODULE or INTERFACE node reference

    my @components = split(/::/, $name);
    shift @components if $components[0] eq "";
    my $noderef = undef;
    if (scalar(@components) > 1) {
        $name = pop @components;
        $scoperef = $global_symroot->find_scope(\@components, $scoperef);
        if (defined $scoperef) {
            $noderef = find_in_current_scope($name, $scoperef);
        }
    } elsif (defined($scoperef) && $scoperef != 0) {
        my $scope = $scoperef;
        while ($scope) {
            $noderef = find_in_current_scope($name, $scope);
            last if $noderef;
            $scope = $$scope[SCOPEREF];
        }
        if ($recurse && !$noderef) {
            my $nodetype = $scoperef->[TYPE];
            my $innernodes = $scoperef->[SUBORDINATES];
            if ($nodetype == VALUETYPE) {
                $innernodes = $innernodes->[2];
            }
            foreach (@{$innernodes}) {
                my $n = $_;
                if ($nodetype == VALUETYPE) {
                    next if $n->[0];  # ignore state members
                    $n = $n->[1];
                }
                my $nt = $n->[TYPE];
                next unless ($nt == INCFILE || $nt == MODULE ||
                             $nt == INTERFACE || $nt == VALUETYPE);
                $noderef = $global_symroot->find_node($name, $n, 1);
                last if $noderef;
            }
        }
    } else {
        foreach (@$global_symroot) {
            next if $_->[TYPE] == REMARK;
            if ($_->[NAME] eq $name) {
                if ($_->[TYPE] == INTERFACE_FWD) {
                    my $full_interface = $_->[SUBORDINATES];
                    # Return the INTERFACE_FWD node only if the full interface
                    # is not known.
                    next if (defined($full_interface) && @{$full_interface});
                }
                return $_;
            }
        }
        # FIXME: This is not really correct:
        #  If no scope is given, search in all scopes, recursively
        foreach (@$global_symroot) {
            my $nt = $_->[TYPE];
            if ($nt == INCFILE || $nt == MODULE ||
                $nt == INTERFACE || $nt == VALUETYPE) {
                $noderef = $global_symroot->find_node($name, $_, 1);
                last if $noderef;
            }
        }
    }
    return $noderef;
}

sub scoped_name {
    my $node = shift;
    my $scope_sep = "::";
    if (@_) {
        $scope_sep = shift;
    }

    unless (isnode($node)) {
        return "";
    }
    my @scopes = get_scope($node->[SCOPEREF]);
    push @scopes, $node->[NAME];
    return join($scope_sep, @scopes);
}


# Dump_Symbols and auxiliary subroutines

# Meaning of $dsoptarg:
# undef   => print to stdout
# not ref => print to file
# ref     => print to $dstext
my $dsoptarg = undef;  # by default, print to stdout
my $dstext;
my $dsindentlevel = 0;

sub dsemit {
    my $str = shift;
    if (defined $dsoptarg) {
        if (ref $dsoptarg) {
            $dstext .= $str;
        } else {
            print DS $str;
        }
    } else {
        print $str;
    }
}

sub dsdent {
    dsemit(' ' x ($dsindentlevel * 3));
    if (@_) {
        dsemit shift;
    }
}

sub dump_comment {
    my $cmnt_ref = shift;
    $cmnt_ref or return;
    my @cmnt = @{$cmnt_ref->[1]};
    @cmnt or return;
    if (scalar(@cmnt) == 1) {
        my $comment = $cmnt[0];
        dsdent "// $comment\n";
        return;
    }
    # multi line comment
    dsdent "/*\n";
    foreach (@cmnt) {
        dsdent " $_\n";
     }
     dsdent " */\n";
}

my @dscopes;   # List of scope strings; auxiliary to sub dstypeof

sub dstypeof {
    typeof(shift, \@dscopes);
}

sub dump_symbols_internal {
    my $sym_array_ref = shift;
    if (! $sym_array_ref) {
        warn "dump_symbols_internal: empty elem (returning)\n";
        return 0;
    }
    my $status = 1;
    if (not isnode $sym_array_ref) {
        foreach (@{$sym_array_ref}) {
            unless (dump_symbols_internal $_) {
                $status = 0;
            }
        }
        return $status;
    }
    my @node = @{$sym_array_ref};
    my $type = $node[TYPE];
    my $name = $node[NAME];
    my $subord = $node[SUBORDINATES];
    my @arg = @{$subord};
    my $i;
    if ($type == INCFILE || $type == PRAGMA_PREFIX) {
        if ($type == INCFILE) {
            dsemit "\#include ";
            $name =~ s@^.*/@@;
        } else {
            dsemit "\#pragma prefix ";
        }
        dsemit "\"$name\"\n\n";
        return $status;
    }
    if ($type == ATTRIBUTE) {
        dsdent;
        dsemit("readonly ") if ($arg[0]);
        dsemit("attribute " . dstypeof($arg[1]) . " $name");
    } elsif ($type == METHOD) {
        my $t = shift @arg;
        my $rettype;
        if ($t == ONEWAY) {
            $rettype = 'oneway void';
        } elsif ($t == VOID) {
            $rettype = 'void';
        } else {
            $rettype = dstypeof($t);
        }
        my @exc_list;
        if (@arg) {
            my $lastarg = $arg[$#arg];
            unless (ref($lastarg) eq "ARRAY") {
                die("CORBA::IDLtree::dump_symbols_internal error at METHOD "
                    . $name . " last arg ($global_idlfile)\n");
            }
            my @last = @{$lastarg};
            if (scalar(@last) != 3 || ref($last[NAME])) {
                @exc_list = @{pop @arg};
            }
        }
        dsdent($rettype . " $name (");
        if (@arg) {
            unless ($#arg == 0) {
                dsemit "\n";
                $dsindentlevel += 5;
            }
            for ($i = 0; $i <= $#arg; $i++) {
                my $pnode = $arg[$i];
                my $ptype = dstypeof($$pnode[TYPE]);
                my $pname = $$pnode[NAME];
                my $m     = $$pnode[SUBORDINATES];
                my $pmode = ($m == &IN ? 'in' : $m == &OUT ? 'out' : 'inout');
                dsdent unless ($#arg == 0);
                dsemit "$pmode $ptype $pname";
                dsemit(",\n") if ($i < $#arg);
            }
            unless ($#arg == 0) {
                $dsindentlevel -= 5;
            }
        }
        dsemit ")";
        if (@exc_list) {
            dsemit "\n";
            $dsindentlevel++;
            dsdent " raises (";
            for ($i = 0; $i <= $#exc_list; $i++) {
                dsemit(${$exc_list[$i]}[NAME]);
                dsemit(", ") if ($i < $#exc_list);
            }
            dsemit ")";
            $dsindentlevel--;
        }
    } elsif ($type == VALUETYPE) {
        dsdent;
        if ($arg[0]) {          # `abstract' flag
            dsemit "abstract ";
        }
        dsemit "valuetype $name ";
        if ($arg[1]) {          # ancestor info
            my($truncatable, $ancestors_ref) = @{$arg[1]};
            if ($truncatable) {
                dsemit "truncatable ";
            }
            if (@{$ancestors_ref}) {
                dsemit ": ";
                my $first = 1;
                foreach (@{$ancestors_ref}) {
                    if ($first) {
                        $first = 0;
                    } else {
                        dsemit ", ";
                    }
                    dsemit(dstypeof $_);
                }
                dsemit ' ';
            }
        }
        dsemit "{\n";
        $dsindentlevel++;
        foreach (@{$arg[2]}) {
            my ($memberkind, $member) = @$_;
            if ($memberkind) {
                my $mtype = dstypeof($member->[TYPE]);
                my $mname = $member->[NAME];
                dump_comment $member->[COMMENT];
                dsdent($memberkind == &PUBLIC ? "public" : "private");
                dsemit " $mtype $mname;\n";
            } else {
                unless (dump_symbols_internal $member) {
                    $status = 0;
                }
            }
        }
        $dsindentlevel--;
        dsdent "}";
    } elsif ($type == MODULE || $type == INTERFACE) {
        push @dscopes, $name;
        dsdent;
        if ($type == INTERFACE) {
            if ($arg[1] == ABSTRACT) {
                dsemit "abstract ";
            } elsif ($arg[1] == LOCAL) {
                dsemit "local ";
            }
        }
        dsemit($predef_types[$type] . " ");
        dsemit "$name ";
        if ($type == INTERFACE) {
            my $ancref = shift @arg;
            my @ancestors = @{$ancref};
            shift @arg;  # discard the "abstract" flag
            if (@ancestors) {
                dsemit ": ";
                for ($i = 0; $i <= $#ancestors; $i++) {
                    my @ancnode = @{$ancestors[$i]};
                    dsemit $ancnode[NAME];
                    dsemit(", ") if ($i < $#ancestors);
                }
            }
        }
        dsemit " {\n\n";
        $dsindentlevel++;
        foreach (@arg) {
            unless (dump_symbols_internal $_) {
                $status = 0;
            }
        }
        $dsindentlevel--;
        dsdent "}";
        pop @dscopes;
    } elsif ($type == TYPEDEF) {
        my $origtype = $arg[0];
        my $dimref = $arg[1];
        dsdent("typedef " . dstypeof($origtype) . " $name");
        if ($dimref and @{$dimref}) {
            foreach (@{$dimref}) {
                dsemit "[$_]";
            }
        }
    } elsif ($type == CONST) {
        dsdent("const " . dstypeof($arg[0]) . " $name = ");
        dsemit join(' ', @{$arg[1]});
    } elsif ($type == ENUM) {
        dsdent "enum $name { ";
        @arg = enum_literals($subord);
        if ($#arg > 4) {
            $dsindentlevel += 5;
            dsemit "\n";
        }
        for ($i = 0; $i <= $#arg; $i++) {
            dsdent if ($#arg > 4);
            dsemit $arg[$i];
            if ($i < $#arg) {
                dsemit(", ");
                dsemit("\n") if ($#arg > 4);
            }
        }
        if ($#arg > 4) {
            $dsindentlevel -= 5;
            dsemit "\n";
            dsdent "}";
        } else {
            dsemit " }";
        }
    } elsif ($type == STRUCT || $type == UNION || $type == EXCEPTION) {
        dsdent($predef_types[$type] . " $name");
        if ($type == UNION) {
            dsemit(" switch (" . dstypeof(shift @arg) . ")");
        }
        dsemit " {\n";
        $dsindentlevel++;
        my $had_case = 0;
        while (@arg) {
            my $node = shift @arg;
            my $type = $$node[TYPE];
            my $name = $$node[NAME];
            my $suboref = $$node[SUBORDINATES];
            dump_comment $$node[COMMENT];
            if ($type == CASE || $type == DEFAULT) {
                if ($had_case) {
                    $dsindentlevel--;
                } else {
                    $had_case = 1;
                }
                if ($type == CASE) {
                    foreach (@{$suboref}) {
                       dsdent "case $_:\n";
                    }
                } else {
                    dsdent "default:\n";
                }
                $dsindentlevel++;
            } elsif ($type == REMARK) {
                dump_comment [ $name, $suboref ];
            } else {
                foreach (@{$suboref}) {
                    $name .= '[' . $_ . ']';
                }
                dsdent(dstypeof($type) . " $name;\n");
            }
        }
        $dsindentlevel -= $had_case + 1;
        dsdent "}";
    } elsif ($type == INTERFACE_FWD) {
        dsdent "interface $name";
    } elsif ($type == REMARK) {
        dump_comment [ $name, $subord ];
        return $status;
    } else {
        my $ttext;
        if (ref $type) {
            $ttext = dstypeof($type);
        } else {
            $ttext = $type;
        }
        warn("Dump_Symbols: unimplemented type $ttext\n");
        $status = 0;
    }
    if ($status) {
        dsemit ";\n\n";
    } else {
        dsemit "\n";  # just to get a clean line ending on error
    }
    $status
}


sub Dump_Symbols {
    my $sym_array_ref = shift;
    my $output_file_name;
    if (@_) {
        # Meaning of optional argument:
        # when string          => filename to open and write to
        # when array reference => dump into dereferenced array
        $dsoptarg = shift;
        unless (ref $dsoptarg) {
            $output_file_name = $dsoptarg;
            unless (open(DS, ">$output_file_name")) {
                warn "CORBA::IDLtree::Dump_Symbols: cannot create $output_file_name\n";
                $dsoptarg = undef;
                return undef;
            }
            my $hfence = $output_file_name;
            $hfence =~ s/\W+/_/g;
            $hfence = "_" . uc($hfence) . "_";
            dsemit "#ifndef $hfence\n";
            dsemit "#define $hfence\n\n";
        }
    } else {
        $dsoptarg = undef;
    }
    $dstext = "";
    my $res = dump_symbols_internal($sym_array_ref);
    if ($output_file_name) {
        dsemit "#endif\n";
        close DS;
    } elsif ($dsoptarg) {
        @{$dsoptarg} = split(/\n/, $dstext);
    }
    return $res;
}

# End of Dump_Symbols stuff.


# traverse_tree stuff.

my $user_sub_ref = 0;
my $traverse_includefiles = 0;

sub traverse;

sub traverse {
    my ($symroot, $scope, $inside_includefile) = @_;
    if (! $symroot) {
        warn "\nCORBA::IDLtree::traverse: encountered empty elem (returning)\n";
        return;
    } elsif (is_elementary_type $symroot) {
        &{$user_sub_ref}($symroot, $scope, $inside_includefile);
        return;
    } elsif (not isnode $symroot) {
        foreach (@{$symroot}) {
            traverse($_, $scope, $inside_includefile);
        }
        return;
    }
    &{$user_sub_ref}($symroot, $scope, $inside_includefile);
    my @node = @{$symroot};
    my $type = $node[TYPE];
    my $name = $node[NAME];
    my $subord = $node[SUBORDINATES];
    my @arg = @{$subord};
    if ($type == &INCFILE) {
        traverse($subord, $scope, 1) if ($traverse_includefiles);
    } elsif ($type == MODULE) {
        foreach (@arg) {
            traverse($_, scoped_name($symroot), $inside_includefile);
        }
    } elsif ($type == INTERFACE) {
        # my @ancestors = @{$arg[0]};
        # if (@ancestors) {
        #     foreach $elder (@ancestors) {
        #         &{$user_sub_ref}($elder, $scope, $inside_includefile);
        #     }
        # }
        shift @arg;   # discard ancestors
        shift @arg;   # discard abstract flag
        foreach (@arg) {
            traverse($_, scoped_name($symroot), $inside_includefile);
        }
    }
}

sub traverse_tree {
    my $sym_array_ref = shift;
    $user_sub_ref = shift;
    $traverse_includefiles = 0;
    if (@_) {
        $traverse_includefiles = shift;
    }
    traverse($sym_array_ref, "", 0);
}

# End of traverse_tree stuff.

sub get_scalar_default {
    my ($node, $scoped) =  @_;

    if (defined($comment_directives)) {
        return $comment_directives->get_default($node, $scoped);
    } else {
        my $t = root_type($node);
        if ($t == BOOLEAN) {
            return "FALSE";
        } elsif (is_elementary_type($t)) {
            return 0;
        } elsif ($t->[TYPE] == ENUM) {
            my @literals = enum_literals($t->[SUBORDINATES]);
            my $v = $literals[0];
            if ($scoped) {
                my @sc = get_scope($t);
                pop @sc;
                $v = join("::", @sc, $v);
            }
            return $v;
        } else {
            return undef;
        }
    }
}

sub is_integer {
    my ($type) = @_;
    my $e = is_elementary_type($type, 1);
    return $e == OCTET
        || $e == SHORT
        || $e == LONG
        || $e == LONGLONG
        || $e == USHORT
        || $e == ULONG
        || $e == ULONGLONG;
}

sub find_union_case {
    my ($tree, $node, $caseval) = @_;

    my $case = $caseval;
    if ($caseval =~ /::/) {
        $caseval =~ s/^.*:://;
    }
    return undef unless $node->[TYPE] == UNION;
    my $int = is_integer($node->[SUBORDINATES][0]);
    my $found = 0;
    my $thecase = undef;
    my $thecase_memb = undef;
    for (my $n = 1; $n <= $#{$node->[SUBORDINATES]}; ++$n) {
        my $memb = $node->[SUBORDINATES][$n];
        next if $memb->[TYPE] == REMARK;
        if ($memb->[TYPE] == CASE) {
            for my $c (@{$memb->[SUBORDINATES]}) {
                my $cv = $int ? $tree->get_numeric($c) : $c;
                if ($cv =~ /::/) { $cv =~ s/^.*:://; }
                if ($cv eq $caseval) {
                    $found = 1;
                    $thecase = $c;
                    last;
                }
            }
            $thecase_memb = $memb;
        } elsif ($memb->[TYPE] == DEFAULT) {
            # note: this assumes "default" is always the last branch
            $found = 1;
            $thecase = $case;
            $thecase_memb = $memb;
        } elsif ($found) {
            return ($thecase, $memb, $thecase_memb);
        }
    }
    return ($case, undef, undef);
}

sub get_union_default {
    my ($tree, $node) = @_;

    return undef unless $node->[TYPE] == UNION;

    my $switcht =  $node->[SUBORDINATES][0];

    # first try: default of discriminant type
    my $case = get_scalar_default($switcht, 1);

    my ($memb, $casememb);
    ($case, $memb, $casememb) = find_union_case($tree, $node, $case);
    if (defined($memb) || $union_default_null_allowed) {
        return ($case, $memb, $casememb);
    }
    # else...
    my $st = root_type($switcht);
    if (isnode($st) && $st->[TYPE] == ENUM) {
        # try each enum label until a match is found
        for my $e (enum_literals($st->[SUBORDINATES])) {
            my $el = ref($e) ? $e->[0] : $e;
            ($el, $memb, $casememb) = find_union_case($tree, $node, $el);
            if (defined $memb) {
                unless ($el =~ /::/) {
                    my @sc = CORBA::IDLtree::get_scope($st);
                    pop @sc;
                    $el = join("::", @sc, $el);
                }
                return ($el, $memb, $casememb);
            }
        }
    }
    # use the first case as fallback
    $case = undef;
    $casememb = undef;
    for (my $n = 1; $n <= $#{$node->[SUBORDINATES]}; ++$n) {
        my $memb = $node->[SUBORDINATES][$n];
        next if $memb->[TYPE] == REMARK;
        if ($memb->[TYPE] == CASE) {
            $case = $memb->[SUBORDINATES][0];
            $case = $tree->get_numeric($case) if is_integer($switcht);
            $casememb = $memb;
        } elsif ($memb->[TYPE] == DEFAULT) {
            $case = undef;
            $casememb = undef;
            next;
        } elsif (defined $case) {
            return ($case, $memb, $casememb);
        }
    }
    return undef;
}

=head1 AUTHOR

Oliver M. Kellogg, C<< <okellogg at users.sourceforge.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-corba-idltree at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CORBA-IDLtree>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CORBA::IDLtree


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CORBA-IDLtree>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CORBA-IDLtree>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CORBA-IDLtree>

=item * Search CPAN

L<http://search.cpan.org/dist/CORBA-IDLtree/>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to Heiko Schroeder for contributing.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 1998-2020, Oliver M. Kellogg

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# Local Variables:
# cperl-indent-level: 4
# indent-tabs-mode: nil
# End:
