#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013-2024 -- leonerd@leonerd.org.uk

package Devel::MAT::Dumpfile 0.53;

use v5.14;
use warnings;

use Carp;
use IO::Handle;   # ->read
use IO::Seekable; # ->tell

use List::Util qw( pairmap );

use Devel::MAT::SV;
use Devel::MAT::Context;

use Struct::Dumb 0.07 qw( readonly_struct );
readonly_struct StructType => [qw( name fields )];
readonly_struct StructField => [qw( name type )];

use constant {
   PMAT_SVxMAGIC => 0x80,
};

=head1 NAME

C<Devel::MAT::Dumpfile> - load and analyse a heap dump file

=head1 SYNOPSIS

   use Devel::MAT::Dumpfile;

   my $df = Devel::MAT::Dumpfile->load( "path/to/the/file.pmat" );

=head1 DESCRIPTION

This module provides a class that loads a heap dump file previously written by
L<Devel::MAT::Dumper>. It provides accessor methods to obtain various
well-known root starting addresses, or to find arbitrary SVs by address. Each
SV is represented by an instance of L<Devel::MAT::SV>.

=cut

my @ROOTS;
my %ROOTDESC;
foreach (
   [ sv_undef        => "+the undef SV" ],
   [ sv_yes          => "+the true SV" ],
   [ sv_no           => "+the false SV" ],
   [ main_cv         => "+the main code" ],
   [ defstash        => "+the default stash" ],
   [ mainstack       => "+the main stack AV" ],
   [ beginav         => "+the BEGIN list" ],
   [ checkav         => "+the CHECK list" ],
   [ unitcheckav     => "+the UNITCHECK list" ],
   [ initav          => "+the INIT list" ],
   [ endav           => "+the END list" ],
   [ strtab          => "+the shared string table HV" ],
   [ envgv           => "-the ENV GV" ],
   [ incgv           => "+the INC GV" ],
   [ statgv          => "+the stat GV" ],
   [ statname        => "+the statname SV" ],
   [ tmpsv           => "-the temporary SV" ],
   [ defgv           => "+the default GV" ],
   [ argvgv          => "-the ARGV GV" ],
   [ argvoutgv       => "+the argvout GV" ],
   [ argvout_stack   => "+the argvout stack AV" ],
   [ errgv           => "+the *@ GV" ],
   [ fdpidav         => "+the FD-to-PID mapping AV" ],
   [ preambleav      => "+the compiler preamble AV" ],
   [ modglobalhv     => "+the module data globals HV" ],
   [ regex_padav     => "+the REGEXP pad AV" ],
   [ sortstash       => "+the sort stash" ],
   [ firstgv         => "-the *a GV" ],
   [ secondgv        => "-the *b GV" ],
   [ debstash        => "-the debugger stash" ],
   [ stashcache      => "+the stash cache" ],
   [ isarev          => "+the reverse map of \@ISA dependencies" ],
   [ registered_mros => "+the registered MROs HV" ],
   [ rs              => "+the IRS" ],
   [ last_in_gv      => "+the last input GV" ],
   [ ofsgv           => "+the OFS GV" ],
   [ defoutgv        => "+the default output GV" ],
   [ hintgv          => "-the hints (%^H) GV" ],
   [ patchlevel      => "+the patch level" ],
   [ apiversion      => "+the API version" ],
   [ e_script        => "+the '-e' script" ],
   [ mess_sv         => "+the message SV" ],
   [ ors_sv          => "+the ORS SV" ],
   [ encoding        => "+the encoding" ],
   [ blockhooks      => "+the block hooks" ],
   [ custom_ops      => "+the custom ops HV" ],
   [ custom_op_names => "+the custom op names HV" ],
   [ custom_op_descs => "+the custom op descriptions HV" ],
   map { [ $_ => "+the $_" ] } qw(
      Latin1 UpperLatin1 AboveLatin1 NonL1NonFinalFold HasMultiCharFold
      utf8_mark utf8_X_regular_begin utf8_X_extend utf8_toupper utf8_totitle
      utf8_tolower utf8_tofold utf8_charname_begin utf8_charname_continue
      utf8_idstart utf8_idcont utf8_xidstart utf8_perl_idstart utf8_perl_idcont
      utf8_xidcont utf8_foldclosures utf8_foldable ),
) {
   my ( $name, $desc ) = @$_;
   push @ROOTS, $name;
   $ROOTDESC{$name} = $desc;

   # Autogenerate the accessors
   my $code = sub {
      my $self = shift;
      $self->{roots}{$name} ? $self->sv_at( $self->{roots}{$name}[0] ) : undef;
   };
   no strict 'refs';
   *$name = $code;
}

*ROOTS = sub { @ROOTS };

=head1 CONSTRUCTOR

=cut

=head2 load

   $df = Devel::MAT::Dumpfile->load( $path, %args );

Loads a heap dump file from the given path, and returns a new
C<Devel::MAT::Dumpfile> instance representing it.

Takes the following named arguments:

=over 8

=item progress => CODE

If given, should be a CODE reference to a function that will be called
regularly during the loading process, and given a status message to update the
user.

=back

=cut

sub load
{
   my $class = shift;
   my ( $path, %args ) = @_;

   my $progress = $args{progress};

   $progress->( "Loading file $path..." ) if $progress;

   open my $fh, "<", $path or croak "Cannot read $path - $!";
   my $self = bless { fh => $fh }, $class;

   my $filelen = -s $fh;

   # Header
   $self->_read(4) eq "PMAT" or croak "File magic signature not found";

   my $flags = $self->_read_u8;

   my $endian = ( $self->{big_endian} = $flags & 0x01 ) ? ">" : "<";

   my $u32_fmt = $self->{u32_fmt} = "L$endian";
   my $u64_fmt = $self->{u64_fmt} = "Q$endian";

   @{$self}{qw( uint_len uint_fmt )} =
      ( $flags & 0x02 ) ? ( 8, $u64_fmt ) : ( 4, $u32_fmt );

   @{$self}{qw( ptr_len ptr_fmt )} =
      ( $flags & 0x04 ) ? ( 8, $u64_fmt ) : ( 4, $u32_fmt );

   @{$self}{qw( nv_len nv_fmt )} =
      ( $flags & 0x08 ) ? ( 10, "D$endian" ) : ( 8, "d$endian" );

   $self->{ithreads} = !!( $flags & 0x10 );

   $flags &= ~0x1f;
   die sprintf "Cannot read %s - unrecognised flags %x\n", $path, $flags if $flags;

   $self->{minus_1} = unpack $self->{uint_fmt}, pack $self->{uint_fmt}, -1;

   $self->_read_u8 == 0 or die "Cannot read $path - 'zero' header field is not zero";

   $self->_read_u8 == 0 or die "Cannot read $path - format version major unrecognised";

   ( $self->{format_minor} = $self->_read_u8 ) <= 6 or
      die "Cannot read $path - format version minor unrecognised ($self->{format_minor})";

   if( $self->{format_minor} < 1 ) {
      warn "Loading an earlier format of dumpfile - SV MAGIC annotations may be incorrect\n";
   }

   $self->{perlver} = $self->_read_u32;

   my $n_types = $self->_read_u8;
   my @sv_sizes = unpack "(a3)*", my $tmp = $self->_read( $n_types * 3 );
   $self->{sv_sizes} = [ map [ unpack "C C C", $_ ], @sv_sizes ];

   if( $self->{format_minor} >= 4 ) {
      my $n_extns = $self->_read_u8;
      my @extn_sizes = unpack "(a3)*", my $tmp = $self->_read( $n_extns * 3 );
      $self->{svx_sizes} = [ map [ unpack "C C C", $_ ], @extn_sizes ];
   }
   else {
      # versions < 4 had just one, PMAT_SVxMAGIC
      $self->{svx_sizes} = [
         [ 2, 2, 0 ],  # PMAT_SVxMAGIC
      ];
   }

   if( $self->{format_minor} >= 2 ) {
      my $n_ctxs = $self->_read_u8;
      my @ctx_sizes = unpack "(a3)*", my $tmp = $self->_read( $n_ctxs * 3 );
      $self->{ctx_sizes} = [ map [ unpack "C C C", $_ ], @ctx_sizes ];
   }

   $self->{structtypes_by_id} = {};

   # Roots
   foreach (qw( undef yes no )) {
      my $addr = $self->{"${_}_at"} = $self->_read_ptr;
      my $class = "Devel::MAT::SV::\U$_";
      $self->{uc $_} = $class->new( $self, $addr );
   }

   $self->{roots} = \my %roots;
   # The three immortals
   $roots{"sv_$_"} = [ $self->{"\U$_"}->addr, $ROOTDESC{"sv_$_"} ] for qw( undef yes no );

   foreach ( 1 .. $self->_read_u32 ) {
      my $name = $self->_read_str;
      my $desc = $ROOTDESC{$name} // $name;
      $desc =~ m/^[+-]/ or $desc = "+$desc";
      $roots{$name} = [ $self->_read_ptr, $desc ];
   }

   # Stack
   my $stacksize = $self->_read_uint;
   $self->{stack_at} = [ map { $self->_read_ptr } 1 .. $stacksize ];

   # Heap
   $self->{heap} = \my %heap;
   $self->{protosubs_by_oproot} = \my %protosubs_by_oproot;
   while( my $sv = $self->_read_sv ) {
      $heap{$sv->addr} = $sv;

      # Also identify the protosub of every oproot
      if( $sv->type eq "CODE" and $sv->oproot and $sv->is_clone ) {
         $protosubs_by_oproot{$sv->oproot} = $sv;
      }

      my $pos = $fh->IO::Seekable::tell; # fully-qualified method for 5.010
      $progress->( sprintf "Loading file %d of %d bytes (%.2f%%)",
         $pos, $filelen, 100*$pos / $filelen ) if $progress and (keys(%heap) % 5000) == 0;
   }

   # Contexts
   $self->{contexts} = \my @contexts;
   while( my $ctx = $self->_read_ctx ) {
      push @contexts, $ctx;
   }

   # From here onwards newer files have mortals, older ones don't
   if( my $mortalcount = $self->_read_uint ) {
      $self->{mortals_at} = \my @mortals_at;
      push @mortals_at, $self->_read_ptr for 1 .. $mortalcount;
      foreach my $addr ( @mortals_at ) {
         my $sv = $self->sv_at( $addr );
         unless( $sv ) {
            warn sprintf "SV address 0x%x is marked mortal but there is no SV", $addr;
            next;
         }
         $sv->_set_is_mortal;
      }
      $self->{mortal_floor} = $self->_read_uint;
   }

   $self->_fixup( %args ) unless $args{no_fixup};

   return $self;
}

sub structtype
{
   my $self = shift;
   my ( $id ) = @_;

   return $self->{structtypes_by_id}{$id} //
      croak "Dumpfile does not define a struct type of ID=$id\n";
}

sub _fixup
{
   my $self = shift;
   my %args = @_;

   my $progress = $args{progress};

   my $heap = $self->{heap};

   my $heap_total = scalar keys %$heap;

   # Annotate each root SV
   foreach my $name ( keys %{ $self->{roots} } ) {
      my $sv = $self->root( $name ) or next;
      $sv->{rootname} = $name;
   }

   my $count = 0;
   while( my ( $addr ) = each %$heap ) {
      my $sv = $heap->{$addr} or next;

      # While dumping we weren't able to determine what ARRAYs were really
      # PADLISTs. Now we can fix them up
      $sv->_fixup if $sv->can( "_fixup" );

      $count++;
      $progress->( sprintf "Fixing %d of %d (%.2f%%)",
         $count, $heap_total, 100*$count / $heap_total ) if $progress and ($count % 20000) == 0;
   }

   # Walk the SUB contexts setting their true depth
   if( $self->{format_minor} >= 2 ) {
      my %prev_depth_by_cvaddr;

      foreach my $ctx ( @{ $self->{contexts} } ) {
         next unless $ctx->type eq "SUB";

         my $cvaddr = $ctx->{cv_at};
         $ctx->_set_depth( $prev_depth_by_cvaddr{$cvaddr} // $ctx->cv->depth );

         $prev_depth_by_cvaddr{$cvaddr} = $ctx->olddepth;
      }
   }

   return $self;
}

# Nicer interface to IO::Handle
sub _read
{
   my $self = shift;
   my ( $len ) = @_;
   return "" if $len == 0;
   defined( $self->{fh}->read( my $buf, $len ) ) or croak "Cannot read - $!";
   return $buf;
}

sub _read_u8
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, 1 ) ) or croak "Cannot read - $!";
   return unpack "C", $buf;
}

sub _read_u32
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, 4 ) ) or croak "Cannot read - $!";
   return unpack $self->{u32_fmt}, $buf;
}

sub _read_u64
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, 8 ) ) or croak "Cannot read - $!";
   return unpack $self->{u64_fmt}, $buf;
}

sub _read_uint
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, $self->{uint_len} ) ) or croak "Cannot read - $!";
   return unpack $self->{uint_fmt}, $buf;
}

sub _read_ptr
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, $self->{ptr_len} ) ) or croak "Cannot read - $!";
   return unpack $self->{ptr_fmt}, $buf;
}

sub _read_ptrs
{
   my $self = shift;
   my ( $n ) = @_;
   defined( $self->{fh}->read( my $buf, $self->{ptr_len} * $n ) ) or croak "Cannot read - $!";
   return unpack "$self->{ptr_fmt}$n", $buf;
}

sub _read_nv
{
   my $self = shift;
   defined( $self->{fh}->read( my $buf, $self->{nv_len} ) ) or croak "Cannot read - $!";
   return unpack $self->{nv_fmt}, $buf;
}

sub _read_str
{
   my $self = shift;
   my $len = $self->_read_uint;
   return undef if $len == $self->{minus_1};
   return $self->_read($len);
}

sub _read_bytesptrsstrs
{
   my $self = shift;
   my ( $nbytes, $nptrs, $nstrs ) = @_;

   return
      ( $nbytes ? $self->_read( $nbytes ) : "" ),
      ( $nptrs  ? [ $self->_read_ptrs( $nptrs ) ] : undef ),
      ( $nstrs  ? [ map { $self->_read_str } 1 .. $nstrs ] : undef );
}

sub _read_sv
{
   my $self = shift;

   while(1) {
      my $type = $self->_read_u8;
      return if !$type;

      if( $type >= 0xF1 ) {
         die sprintf "Unrecognised META tag %02X\n", $type;
      }
      elsif( $type == 0xF0 ) {
         # META_STRUCT
         my $id = $self->_read_uint;
         my $nfields = $self->_read_uint;
         my $name = $self->_read_str;

         my @fields;
         push @fields, StructField(
            $self->_read_str,
            $self->_read_u8,
         ) for 1 .. $nfields;

         $self->{structtypes_by_id}{$id} = StructType(
            $name, \@fields,
         );

         next;
      }
      elsif( $type >= 0x80 ) {
         my $sizes = $self->{svx_sizes}[$type - 0x80];

         if( $self->{format_minor} == 0 and $type == PMAT_SVxMAGIC ) {
            # legacy magic support
            my ( $sv_addr, $obj ) = $self->_read_ptrs(2);
            my $type              = chr $self->_read_u8;

            my $sv = $self->sv_at( $sv_addr );

            # Legacy format didn't have flags, and didn't distinguish obj from ptr
            # However, the only objs it ever saved were refcounted ones. Lets just
            # pretend all of them are refcounted objects.
            $sv->more_magic( $type => 0x01, $obj, 0, 0 );
         }
         elsif( !$sizes ) {
            die sprintf "Unrecognised SV extension type %02x\n", $type;
         }
         else {
            my $sv_addr = $self->_read_ptr;
            my @args = $self->_read_bytesptrsstrs( @$sizes );

            my $sv = $self->sv_at( $sv_addr ) or
               warn( sprintf "Skipping SVx 0x%02X on missing SV at addr 0x%X\n", $type, $sv_addr ), next;

            my $code = $self->can( sprintf "_read_svx_%02X", $type ) or
               warn( sprintf "Skipping unrecognised SVx 0x%02X\n", $type ), next;

            $self->$code( $sv, @args );
         }

         next;
      }

      # First read the "common" header
      my $sv = Devel::MAT::SV->new( $type, $self,
         $self->_read_bytesptrsstrs( @{ $self->{sv_sizes}[0] } )
      );

      if( $type == 0x7F ) {
         my $structtype = $self->structtype( $sv->structid );
         $sv->load( $structtype->fields );
      }
      else {
         # Values 16=OBJECT and 17=CLASS should warn.
         # Technically a padname with the field CODEx extension on it should
         # also warn but in practice we shouldn't see one of those outside of
         # a class that would have warned first anyway.
         $type >= 16 and !$self->{warned_experimental_class}++ and
            warnings::warnif experimental => "Support for class features in PMAT file is experimental";

         my ( $bytes, $nptrs, $nstrs ) = @{ $self->{sv_sizes}[$type] };
         $sv->load(
            $self->_read_bytesptrsstrs( $bytes, $nptrs, $nstrs )
         );
      }

      return $sv;
   }
}

sub _read_svx_80
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   my ( $type, $flags ) = unpack "A1 C", $bytes;

   $sv->more_magic( $type => $flags, @$ptrs );
}

sub _read_svx_81
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   $sv->_more_saved( SCALAR => $ptrs->[0] );
}

sub _read_svx_82
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   $sv->_more_saved( ARRAY => $ptrs->[0] );
}

sub _read_svx_83
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   $sv->_more_saved( HASH => $ptrs->[0] );
}

sub _read_svx_84
{
   my $self = shift;
   my ( $av, $bytes, $ptrs, $strs ) = @_;

   my $index = unpack $self->{uint_fmt}, $bytes;

   $av->isa( "Devel::MAT::SV::ARRAY" ) and
      $av->_more_saved( $index, $ptrs->[0] );
}

sub _read_svx_85
{
   my $self = shift;
   my ( $hv, $bytes, $ptrs, $strs ) = @_;

   $hv->isa( "Devel::MAT::SV::HASH" ) and
      $hv->_more_saved( $ptrs->[0], $ptrs->[1] );
}

sub _read_svx_86
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   $sv->_more_saved( CODE => $ptrs->[0] );
}

sub _read_svx_87
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   $sv->_more_annotations( $ptrs->[0], $strs->[0] );
}

sub _read_svx_88
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   my ( $serial, $line ) = unpack "($self->{uint_fmt})2", $bytes;
   my $file = $strs->[0];

   $sv->_debugdata( $serial, $line, $file );
}

sub _read_svx_89
{
   my $self = shift;
   my ( $sv, $bytes, $ptrs, $strs ) = @_;

   my ( $shared_hek ) = unpack "$self->{ptr_fmt}", $bytes;

   if( $sv->type eq "SCALAR" ) {
      $sv->_set_shared_hek_at( $shared_hek );
   }
   else {
      warn sprintf "Ignoring SVxSHARED_HEK on non-SCALAR SV addr=%#x\n", $sv->addr;
   }
}

sub _read_ctx
{
   my $self = shift;

   my $type = $self->_read_u8;
   return if !$type;

   if( $self->{format_minor} >= 2 ) {
      my $ctx = Devel::MAT::Context->new( $type, $self,
         $self->_read_bytesptrsstrs( @{ $self->{ctx_sizes}[0] } )
      );

      $ctx->load(
         $self->_read_bytesptrsstrs( @{ $self->{ctx_sizes}[$type] } )
      );

      return $ctx;
   }
   else {
      return Devel::MAT::Context->load_v0_1( $type, $self );
   }
}

=head1 METHODS

=cut

=head2 perlversion

   $version = $df->perlversion;

Returns the version of perl that the heap dump file was created by, as a
string in the form C<5.14.2>.

=cut

sub perlversion
{
   my $self = shift;
   my $v = $self->{perlver};
   return join ".", $v>>24, ($v>>16) & 0xff, $v&0xffff;
}

=head2 endian

   $endian = $df->endian;

Returns the endian direction of the perl that the heap dump was created by, as
either C<big> or C<little>.

=cut

sub endian
{
   my $self = shift;
   return $self->{big_endian} ? "big" : "little";
}

=head2 uint_len

   $len = $df->uint_len;

Returns the length in bytes of a uint field of the perl that the heap dump was
created by.

=cut

sub uint_len
{
   my $self = shift;
   return $self->{uint_len};
}

=head2 ptr_len

   $len = $df->ptr_len;

Returns the length in bytes of a pointer field of the perl that the heap dump
was created by.

=cut

sub ptr_len
{
   my $self = shift;
   return $self->{ptr_len};
}

=head2 nv_len

   $len = $df->nv_len;

Returns the length in bytes of a double field of the perl that the heap dump
was created by.

=cut

sub nv_len
{
   my $self = shift;
   return $self->{nv_len};
}

=head2 ithreads

   $ithreads = $df->ithreads;

Returns a boolean indicating whether ithread support was enabled in the perl
that the heap dump was created by.

=cut

sub ithreads
{
   my $self = shift;
   return $self->{ithreads};
}

=head2 roots

   %roots = $df->roots;

Returns a key/value pair list giving the names and SVs at each of the roots.

=head2 roots_strong

   %roots = $df->roots_strong;

Returns a key/value pair list giving the names and SVs at each of the roots
that count as strong references.

=head2 roots_weak

   %roots = $df->roots_weak;

Returns a key/value pair list giving the names and SVs at each of the roots
that count as strong references.

=cut

sub _roots
{
   my $self = shift;
   return map {
      my ( $root_at, $desc ) = @$_;
      $desc => $self->sv_at( $root_at )
   } values %{ $self->{roots} };
}

sub roots
{
   my $self = shift;
   return pairmap { substr( $a, 1 ) => $b } $self->_roots;
}

sub roots_strong
{
   my $self = shift;
   return pairmap { $a =~ m/^\+(.*)/ ? ( $1 => $b ) : () } $self->_roots;
}

sub roots_weak
{
   my $self = shift;
   return pairmap { $a =~ m/^\-(.*)/ ? ( $1 => $b ) : () } $self->_roots;
}

=head2 ROOTS

   $sv = $df->ROOT;

For each of the root names given below, a method exists with that name which
returns the SV at that root:

   main_cv
   defstash
   mainstack
   beginav
   checkav
   unitcheckav
   initav
   endav
   strtabhv
   envgv
   incgv
   statgv
   statname
   tmpsv
   defgv
   argvgv
   argvoutgv
   argvout_stack
   fdpidav
   preambleav
   modglobalhv
   regex_padav
   sortstash
   firstgv
   secondgv
   debstash
   stashcache
   isarev
   registered_mros

=cut

=head2 root_descriptions

   %rootdescs = $df->root_descriptions;

Returns a key/value pair list giving the (method) name and description text of
each of the possible roots.

=cut

sub root_descriptions
{
   my $self = shift;
   my $roots = $self->{roots};
   return map {
      $_ => substr $roots->{$_}[1], 1
   } keys %$roots;
}

=head2 root_at

   $addr = $df->root_at( $name );

Returns the SV address of the given named root.

=cut

sub root_at
{
   my $self = shift;
   my ( $name ) = @_;

   return $self->{roots}{$name} ? $self->{roots}{$name}[0] : undef;
}

=head2 root

   $sv = $df->root( $name );

Returns the given root SV.

=cut

sub root
{
   my $self = shift;
   my $root_at = $self->root_at( @_ ) or return;
   return $self->sv_at( $root_at );
}

=head2 heap

   @svs = $df->heap;

Returns all of the heap-allocated SVs, in no particular order

=cut

sub heap
{
   my $self = shift;
   return values %{ $self->{heap} };
}

=head2 stack

   @svs = $df->stack;

Returns all the SVs on the stack

=cut

sub stack
{
   my $self = shift;

   return map { $self->sv_at( $_ ) } @{ $self->{stack_at} };
}

=head2 contexts

   @ctxs = $df->contexts;

Returns a list of L<Devel::MAT::Context> objects representing the call context
stack in the dumpfile.

=cut

sub contexts
{
   my $self = shift;
   return @{ $self->{contexts} };
}

=head2 sv_at

   $sv = $df->sv_at( $addr );

Returns the SV at the given address, or C<undef> if one does not exist.

(Note that this is unambiguous, as a Perl-level C<undef> is represented by the
immortal C<Devel::MAT::SV::UNDEF> SV).

=cut

sub sv_at
{
   my $self = shift;
   my ( $addr ) = @_;
   return undef if !$addr;

   return $self->{UNDEF} if $addr == $self->{undef_at};
   return $self->{YES}   if $addr == $self->{yes_at};
   return $self->{NO}    if $addr == $self->{no_at};

   return $self->{heap}{$addr};
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
