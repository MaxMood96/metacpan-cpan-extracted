#
# GENERATED WITH PDL::PP from func.pd! Don't modify!
#
package PDL::Fit::Levmar::Func;

our @EXPORT_OK = qw(levmar_func _callf _callj _callj1 );
our %EXPORT_TAGS = (Func=>\@EXPORT_OK);

use PDL::Core;
use PDL::Exporter;
use DynaLoader;


   our $VERSION = '0.0103';
   our @ISA = ( 'PDL::Exporter','DynaLoader' );
   push @PDL::Core::PP, __PACKAGE__;
   bootstrap PDL::Fit::Levmar::Func $VERSION;







#line 9 "func.pd"

=head1 NAME

PDL::Fit::Levmar::Func - Create model functions for Levenberg-Marquardt fit routines

=head1 DESCRIPTION

This module creates and manages functions for use with the
Levmar fitting module.  The functions are created with a
very simple description language (that is mostly C), or are
pure C, or are perl code. For many applications, the present
document is not necessary because levmar uses the
Levmar::Func module transparantly.  Therefore, before
reading the following, refer to L<PDL::Fit::Levmar>.

=head1 SYNOPSIS

    use PDL::Fit::Levmar::Func;

   $func = levmar_func(  FUNC =>  # define and link function

 '
  function gaussian
  loop
  x[i] = p[0] * exp(-(t[i] - p[1])*(t[i] - p[1])*p[2]);
  end function

  jacobian jacgaussian
  double arg, expf;
  loop
  arg = t[i] - p[1];
  expf = exp(-arg*arg*p[2]);
  d0 = expf;
  d1 = p[0]*2*arg*p[2]*expf;
  d2 = p[0]*(-arg*arg)*expf;
  end jacobian 
  ' 
  );

  $hout = PDL::Fit::Levmar::levmar($p,$x,$t,  # fit the data
               FUNCTION => $func,
 );

=head1 FUNCTIONS

=head2 levmar_func()

=for usage

 levmar_func( OPTIONS )

=for ref

This function creates and links a function, ie, takes a function definition
and returns a function (object instance) ready for use by levmar.
see PDL::Fit::Levmar::Func for more information.

OPTIONS:

=for options

 Some of the options are described in the PDL::Fit::Levmar documentation.

 MKOBJ  -- command to compile source into object code. This can be set.
        The default value is determined by the perl installation and can
        be determined by examining the Levmar::Func object returned by 
        new or the output hash of a call to levmar. A typical value is
        cc -c -O2 -fPIC -o %o %c

 MKSO   -- command to convert object code to dynamic library code. A typical
         default value is
         cc -shared -L/usr/local/lib -fstack-protector %o -o %s
 

 CTOP  --   The value of this string will be written at the top of the c code
  written by Levmar::Func. This can be used to include headers and so forth.
  This option is actually set in the Levmar::Func object.

=head2 call()

=for ref

Call (evaluate) the fit function in a Levmar::Func object.

=for usage

 use PDL::Fit::Levmar::Func;

 $Gh = levmar_func(FUNC=>$fcode);

 $x = $Gh->call($p,$t);

 Here $fcode is a function definition (say lpp code). (This does
 not currently work with perl subroutines, I think. Of course,
 you can call the subroutine directly. But it would be good
 to support it for consistency.)
 
 $p is a pdl or ref to array of parameters.
 $t is a pdl of co-ordinate values.
 $x is the fit function evaluated at $p and $t. $x has the
 same shape as $t.

=for example

 $Gf = levmar_func( FUNC => '
       function	   
       x = p0 * t * t;
     ');

 print $Gf->call([2],sequence(10))  , "\n";
 [0 2 8 18 32 50 72 98 128 162]

=cut 

use strict;
use Carp;
use Config;
use File::Path;
use File::Spec::Functions;

sub munlink;

#use PDL::NiceSlice;
use PDL::Core ':Internal'; # For topdl()

use vars ('$MKOBJ', '$MKSO', '$OBJ_EXT' , '$SO',
	  '$LEVFUNC', '$JLEVFUNC', '$LPPEXT' );

# These are pointers to the C functions that wrap the user's
# perl fit functions.
#$LEVFUNC = get_perl_func_wrap();
#$JLEVFUNC = get_perl_jac_wrap();

$OBJ_EXT = $Config{obj_ext};
$SO = $Config{so};
$LPPEXT = '.lpp';
# string  to compile .c to .o 
$MKOBJ = $Config{cc} . " -c " . $Config{optimize} . " " .
    $Config{cccdlflags} . " -o %o %c ";

# string  to compile .o to .so 
$MKSO = $Config{ld} . " " . $Config{lddlflags} ." %o -o %s ";

use File::Temp qw(tempdir);

#line 181 "func.pd"

=head2 new

=for usage

  my $fitfunc = new PDL::Fit::Levmar::Func(...);
  or
  my $fitfunc = levmar_func(...);

=for ref

Generic constructor. Use levmar_func rather than new.

=cut

$PDL::Fit::Levmar::Func::SRC_EXT = ".c";
#$PDL::Fit::Levmar::Func::SO_EXT = ".so";
#$PDL::Fit::Levmar::Func::OBJ_EXT = ".o";

sub deb { 
 #    print STDERR $_[0], "\n";
}

sub prwarn { print STDERR $_[0], "\n";}

##########################################
# Methods follow

# some kind of stack corruption is related to this function, maybe. no probably not.
# So, only shift opts if they are there
#use Data::Dumper;

sub new {
  my($class) = shift;
  my($opts) = shift;
#  print STDERR "In new class: $class, opts $opts\n";
  if(ref $opts ne 'HASH') { # change opts to hash of opts
    $opts = defined $opts ? {$opts,@_} : {} ;
  }
#  print Dumper($opts),"\n";
  my $self = { # following are defaults
      MKOBJ => $MKOBJ,
      MKSO => $MKSO,
      NOCLEAN => undef,
      FUNC => undef,
      JFUNC => undef,
#      TYPE => 'double',
      NOSO => undef,
      CSRC => undef,
      CTOP => undef,
      DIR => tempdir( CLEANUP => !$opts->{NOCLEAN} ), # where the .so is built
      TESTSYNTAX => undef,
      LIBHANDLE => undef,
      FVERBOSE => 0,
  };
  foreach ( keys %$opts ) { # replace defaults
      if ( exists $self->{$_} ) {
	  $self->{$_} = $opts->{$_};
      }	  
      else { die "Levmar::Func::new: Unrecognized option to Levmar::Func '$_'";}
  }
  return bless $self,$class;
}

# all these attempts at dying and croaking fail.
# program does not quit and error messages are not printed
# dont know why. It must be some bad bug in the xs code.
# If I just print the error message, its fine.
# I think it has to do with DESTROY. return does not work either
sub DESTROY {
    my $self = shift;
    my $cnt = 0;
    return if defined $self->{NOSO};
    if ( defined $self->{LIBHANDLE}) { 
	my ($ret, $err) = close_shared_object_file($self->{LIBHANDLE});
	if ( $err ne '' or $ret != 0) {
	    warn "Levmar::Func::DESTROY: Error closing function library:$ret '$err'";
	}
	warn "Error closing function library:$ret '$err'" if  $ret != 0;
	if ( defined $self->{JPOINTER} ) { # call close twice because we got two symbols
	    ($ret, $err) = close_shared_object_file($self->{LIBHANDLE});
	    warn "Error closing function library:$ret '$err'" if $ret !=0 ;
	    if ( $err ne '' or $ret != 0 ) {
		warn "Levmar::Func::DESTROY: Error closing function library:$ret '$err'";
	    }
	}
	if ( defined $self->{SJPOINTER} ) { # call close twice because we got two symbols
	    ($ret, $err) = close_shared_object_file($self->{LIBHANDLE});
	    warn "Error closing function library:$ret '$err'" if $ret !=0 ;
	    if ( $err ne '' or $ret != 0 ) {
		warn "Levmar::Func::DESTROY: Error closing function library:$ret '$err'";
	    }
	}
	if ( defined $self->{SFPOINTER} ) { # call close twice because we got two symbols
	    ($ret, $err) = close_shared_object_file($self->{LIBHANDLE});
	    warn "Error closing function library:$ret '$err'" if $ret !=0 ;
	    if ( $err ne '' or $ret != 0 ) {
		warn "Levmar::Func::DESTROY: Error closing function library:$ret '$err'";
	    }
	}
    }
    if (not defined $self->{NOCLEAN} and defined $self->{SONAME} ) {
	foreach my $k ( qw ( SONAME  )) { # clean so file
	    my $fn = $self->{$k};
	    if (-e $fn) {
		if ( not -f $fn ) {
		    warn "Levmar::Func::DESTROY: Refusing to remove non-file '$fn'";
		}
		else {
		    $cnt  = munlink $fn;
		    if ( $cnt < 1 ) {
			warn "Levmar::Func::DESTROY: failed removing '$fn' (lib probably open)";
		    }
		    else {
#			warn "Levmar::Func::DESTROY: SUCCESS removing '$fn'";
		    }
		}
	    }
	}
    }
}

sub levmar_func { my $self = new PDL::Fit::Levmar::Func(@_);
		  my @err;
		  if ( defined $self->{FUNC} and $self->{FUNC} =~ /CODE/ ) {
		      $self->{NOSO} = 1; # bad way to handle this
		      $self->{FPOINTER} = 0; # test for this in levmar
		  }
		  else {
		      if ( not defined $self->{FUNC}  and not defined $self->{CSRC} ) {
			  die "Levmar::Func::lemar_func: neither FUNC nor CSRC defined";
		      }
		      @err = $self->make_ccode();
		      return @err if $err[0] == -1;
		      $self->make_build_names();
		      $self->write_ccode();
		      if ( not $self->make_shared_object_file() ) {
			  die "Levmar::Func::levmar_func: Compilation failed.";
		      }
		      if ( not $self->load_fit_library() ) {
			  die "Levmar::Func::levmar_func: Loading dynamic library failed.";
		      }
		      $self->clean_files() unless defined $self->{NOCLEAN};
		  }
		  if ( defined $self->{JFUNC}  ) { # probably won't get called
		      if ( $self->{JFUNC} =~ /CODE/ ) {
			  $self->{NOSO} = 1;
		      }
		      else {
			  die "Levmar::Func::levmar_func option JFUNC must be a ref to a perl sub";
		      }
		  }
		  return $self;
}

sub make_build_names {
    my $self = shift;
    die "Levmar::Func::levmar_func:  no name for function"
	unless defined $self->{NAME};
    my $q = $self->{DIR};
    if ( not -d $q ) {
	die "Levmar::Func::levmar_func: Can't make directory (folder) '$q'"
	    unless File::Path::mkpath( $q );
    }
    $self->{FNAME} = $self->{NAME} unless exists $self->{FNAME}; # base file name
    my $n = $self->{FNAME};
    my $srcn = catfile( $q , $n . $PDL::Fit::Levmar::Func::SRC_EXT);
    my $son = catfile($q ,$n . "." .  $SO);
    my $objn = catfile($q , $n . $OBJ_EXT);
    $self->{SRCNAME} = $srcn;
    $self->{SONAME} = $son;
    $self->{OBJNAME} = $objn;
}

# change this to identity, can remove sometime
sub mfqp {
    my ($self,$key) = @_;
    return  $self->{$key};
}

# substitue string $new for $old when it
# occurs after 'void'.
sub subst_func_name {
    my ($sref,$old,$new) = @_;
    $$sref =~ s/(\W)void\s+$old/$1void $new/;
}

# Write c source file from function definition.
# Entire definition is given as a string, or the
# filename , ending in $LPPEXT is given
# Copying the source strings around, inefficient. should use
# refs
sub make_ccode {
    my $self = shift;
    my @err;

    if ( not defined $self->{CSRC} ) { # is FUNC really c code?
	if (not $self->{FUNC} =~ /$LPPEXT$/o        # is not a $LPPEXT file
                and ( $self->{FUNC} =~ /\.c$/ or # is a .c file
                                                 # doesnt have function def
 	 not $self->{FUNC} =~ /(^|\n)\s*function(\s+\w+|\s*)\n/) ) {
	    $self->{CSRC} = $self->{FUNC};
	}
    }
    if ( defined $self->{CSRC} ) {
	if ( $self->{CSRC} =~ /\.c$/ ) {
	    my $cf = $self->{CSRC};
	    local (*CHAND);
	    local $/; 
	    open CHAND, "<$cf" or die "Levmar::Func::make_code : Can't open C src file '$cf'";
	    $self->{CCODE} = <CHAND>;
	    close(CHAND);
	}
	else {  # inefficient, but it works
	    $self->{CCODE} = $self->{CSRC}; 
	}
	my ($funcname, $jacname) = $self->get_funcs_from_c();
	$jacname = '' unless defined $jacname;
	my ($sfuncname, $sjacname);
	$sfuncname = 's' . $funcname;
	$sjacname = 's' . $jacname if $jacname;
	my $doublecode = $self->{CCODE};
	my $floatcode = $doublecode;
	subst_func_name(\$floatcode, $funcname, $sfuncname);
	subst_func_name(\$floatcode, $jacname, $sjacname) if $jacname;
	if ($^O =~ /MSWin32/i) {
              my $export = ' __declspec (dllexport) ';
   	      subst_func_name(\$doublecode, $funcname,  $export . $funcname);
   	      subst_func_name(\$floatcode, $sfuncname,  $export . $sfuncname);
   	      subst_func_name(\$doublecode, $jacname,  $export . $jacname) if $jacname;
   	      subst_func_name(\$floatcode, $sjacname,  $export . $sjacname) if $jacname;
        }
#	if ( /^\s*void\s+([\w]+)/ )
	$self->{CCODE} = 
"
#define FLOAT double
" .  $doublecode .
"
#undef FLOAT
#define FLOAT float
" . $floatcode;
	$self->{NAME} = $funcname unless exists $self->{NAME};
	$self->{JACNAME} = $jacname unless exists $self->{JACNAME};
	return (1); # don't use FUNC even if its there.
    }
    elsif ( defined $self->{FUNC} ) {
	my $st = $self->{FUNC};
	if ($st =~ /$LPPEXT$/o) {  # file, not string
	    local (*FUNCHAND);
	    local $/; 
	    open FUNCHAND, "<$st" or die "Levmar::Func::make_ccode : Can't open def file '$st'";
	    $st = <FUNCHAND>;
	    close(FUNCHAND);
	}
	my ($funcname,$jacname,$ccode);
	my @ret = generate_C_source($self, $st);
	if ( $ret[0] eq '-1' ) { # stop warnings with ==
	    my $r;
#	    ($r, $funcname, $jacname, $code, @err) = @ret; 
	    return @ret;
	}
	else {
	    ($funcname,$jacname,$ccode) = @ret;
	}
	$self->{CCODE} = $ccode;
	$self->{NAME} = $funcname unless exists $self->{NAME};
	$self->{JACNAME} = $jacname unless exists $self->{JACNAME};
	return (1);
    }
    return (-1, "Can't make C code with no defintion or source file");
}

# jacobian function name **must** start with 'jac' if using pure c code
sub get_funcs_from_c {
    my $self = shift;
    my @lines = split ("\n",$self->{CCODE});
    my ($fname, $jacname) = (undef, undef);
    foreach (@lines ) {
	if ( /^\s*void\s+([\w]+)/ ) { # prototype begins with 'void' return type
	    my $fn = $1;
	    if ($fn =~ /^jac/ ) {
		$jacname = $fn;
	    }
	    else {
		$fname = $fn;
	    }
	}
    }
    if ( not defined $fname or $fname eq '' ) { # ok if jacname == undef
	die "Levmar::Func::get_funcs_from_c : Can't find function name from c code";
    }
    return ($fname, $jacname);
}

sub write_ccode {
    my $self = shift;
    local (*CCODEH);
    return unless exists $self->{CCODE};
    if ( not defined $self->{NAME} ) {
	die "Levmar::Func::write_ccode : Can't write C code for function with no name";
    }
    my $srcn = $self->{SRCNAME};
    open CCODEH, ">$srcn" or die "Levmar::Func::write_ccode : Can't open C source file '$srcn' for writing";
    print CCODEH $self->{CTOP}, "\n" if defined $self->{CTOP};
    print CCODEH $self->{CCODE};
    close CCODEH;
}

sub make_shared_object_file {
    my $self = shift;
    my $ret;
    my $srcn1 = $self->{SRCNAME};
    my $fname1 = $self->{FNAME};
    my $i = 0;
    my $max = 20; # allow $max renamed files
    while ( -f $self->{SONAME} ) { # this is important to avoid user side bugs
	$i++;
	my $so = $self->{SONAME};
	$self->{FNAME} = $fname1 . $i;
	$self->make_build_names();
#	warn "Levmar::Func::make_shared_object_file: $so exists. Trying " . $self->{SONAME};
	last if $i > $max;
    }
    my $srcn = $self->{SRCNAME};
    my $objn = $self->{OBJNAME};
    my $sobjn = $self->{SONAME};
    my $fname = $self->{FNAME};
    if ( $i > $max ){
	die 'Levmar::Func::make_shared_object_file: Too many renamed files in '. $self->{DIR} . ' try cleaning.';
    }
    elsif ($i > 0) {
	if ( rename($srcn1,$srcn) == 0 ) {
	    die "Levmar::Func::make_shared_object_file: Faile to rename $srcn1 to $srcn";
	}
    }
#    my $mkobjstr = $self->{MKOBJ} ." -o $objn  $srcn";
    my $mkobjstr = $self->{MKOBJ};
    $mkobjstr =~ s/\%c/$srcn/g;
    $mkobjstr =~ s/\%o/$objn/g;    
    $ret = do_system($mkobjstr, $self); # compile c to o
    deb "Levmar::Func::make_shared_object_file: compile returned '$ret'";
    if ( $ret != 0) { # zero is success
	warn "Levmar::Func::make_shared_object_file: Compiling '$srcn' failed.";
	return 0;
    }
    $self->{MKOBJSTR} = $mkobjstr;
    my $sostr = $self->{MKSO};
    $sostr =~ s/\%s/$sobjn/g;
    $sostr =~ s/\%o/$objn/g;
    $ret = do_system($sostr, $self); #  make so from o
    deb "Levmar::Func::make_shared_object_file: '$sostr'  make so from o returned '$ret'";   
    if ( 0 != $ret ) {
	warn "Levmar::Func::make_shared_object_file: Making shared library '$sobjn' failed.";
	return 0;
    }
    $self->{SOSTR} = $sostr;
}

#### Some methods to return information
# get compiler strings
sub get_cc_str {
    my $self = shift;
    return ($self->{MKOBJSTR}, $self->{SOSTR});
}

sub get_fpoint {
    my $self = shift;
    $self->{FPOINTER};
}

sub get_jacpoint {
    my $self = shift;
    $self->{JPOINTER};
}

sub get_fit_pointers {
    my $self = shift;
    ($self->{FPOINTER},
     $self->{SFPOINTER},
     $self->{JPOINTER},
     $self->{SJPOINTER});
}

sub get_file_names {
    my $self = shift;
    return ($self->mfqp('SRCNAME'),
	    $self->mfqp('OBJNAME'),
	    $self->mfqp('SONAME'));
}

# remove generated  o, and C files
# Well, don't remove so file.
sub clean_files {
    my $self = shift;
    my $cnt = 0;
    my $srcn = $self->mfqp('SRCNAME'); # fully qualified names
    my $objn = $self->mfqp('OBJNAME');
    foreach my $k ( qw ( OBJNAME  )) { # soname needs to be there
	my $fn = $self->mfqp($k);
	if (-e $fn) {
	    if ( not -f $fn ) {
		warn "Levmar::Func::clean_files : Object file '$fn' not a file. Not deleting";
	    }
	    else {
		$cnt  = munlink $fn;
		if ( $cnt < 1) {
		    warn "Levmar::Func::clean_files : cnt $cnt: Failed to delete object file '$fn'";
		}
	    }
	}
    }
    if ( -e $srcn ) {
	if ( not -f $srcn ) {
	    warn "Levmar::Func::clean_files: Source file '$srcn' not a file. Not deleting";
	}
	open my $srch , '<' , 
              $srcn or die "Levmar::Func::clean_files : Can't open C source file '$srcn' for reading";
        my $closed = 0;
   # weird stack bug present when using implicit $_ rather than $line.
   # A function that calls levmar_func sometimes has an item in arg stack
   # replaced by the first line read here.
	while (my $line = <$srch>) {
	    next if $line =~ /^\s*$/;
	    if ($line =~ /\/\* This file automatically/) {
 	        close($srch);
                $closed = 1;
		$cnt = 0;
		$cnt = munlink $srcn;
                warn "Levmar::Func::clean_files: cnt $cnt: Failed to delete source file '$srcn'"
                    if $cnt < 1;
		last;
	    }
	    last; # only check up to first non-blank line
	}
	close($srch) unless $closed == 1;
    }
}

# Improve effiency after this is well tested by getting all four
# symbols at once.

sub load_fit_library {
    my $self = shift;
    my $so = $self->mfqp('SONAME');
    my $fn = $self->{NAME};
    my $jn = $self->{JACNAME};
    die "Levmar::Func::load_fit_library : Can't find dynamic library file '$so'" unless -e $so;
    my ($func_pointer, $jac_pointer, $lib_handle, $error_message)=
	(0,0,0,0);
    my ($sfunc_pointer, $sjac_pointer) =    # single precision
	(0,0);
    ($func_pointer, $lib_handle, $error_message) =
	open_and_find($so,$fn);
    ($sfunc_pointer, $lib_handle, $error_message) =  # single precision
	open_and_find($so,'s'.$fn);
    if ( $error_message ne ''  ) { 
	warn "Levmar::Func::load_fit_library: Failed to load dynamic library '$so'\n".
          " and find fit func '$fn'.\n dlopen:'$error_message'";
	return 0;
    }
    if ( defined $jn and $jn ne '') {
	($jac_pointer, $lib_handle, $error_message) =
	    open_and_find($so,$jn);
	if ( $error_message ne ''  ) { 
	    warn "Levmar::Func::load_fit_library: Failed to load dynamic library '$so' and find jacobian '$jn'.\n".
		" dlopen:'$error_message' ";
	}
	else {
	    $self->{JPOINTER} = $jac_pointer;
	}
	($sjac_pointer, $lib_handle, $error_message) =
	    open_and_find($so, 's' . $jn);
	if ( $error_message ne ''  ) { 
	    warn "Levmar::Func::load_fit_library: Failed to load dynamic library '$so' and find jacobian '$jn'.\n".
		" dlopen:'$error_message' ";
	}
	else {
	    $self->{SJPOINTER} = $sjac_pointer;
	}

    }
    $self->{FPOINTER} = $func_pointer;
    $self->{SFPOINTER} = $sfunc_pointer;
    $self->{LIBHANDLE} = $lib_handle;
}

# End of methods
# (Actually there are some more methods near the bottom
#  that are close to the corresponding pp_defs)
########################################
# Non-methods below here

# should return 0 on success
sub do_system {
    my ($c,$f) = @_;
    print STDERR $c,"\n" if $f->{FVERBOSE};
    system $c;
}

sub munlink {
    my $f = shift;
    my $cnt;
    my $sf = "'$f'";
    if ( not -e $f ) {
	prwarn "munlink: $sf does not exist";
	return 0;
    }
    if ( not -f $f ) {
	prwarn "munlink: $sf is not a file. Not removing.";
	return 0;
    }
    $cnt = unlink $f;
    if (not $cnt > 0) {
	prwarn "munlink: Can't unlink exisiting file $sf";
    }
    return $cnt;
}

# Turn a function description into C source
# !care! I disabled NiceSlice, because it erroneously saw
# slicing in this piddle-less routine. But I was not using it
# anyway. (parser is rewritten, maybe not a problem anymore.)
sub generate_C_source {
    my ($self, $fdef) = @_;
    my $funcname = ''; # this one is returned
    my $jacname = ''; # this one is returned
    # Do this first now send t -> t[i], x -> x[i], p3 -> p[3]
    # Probably a better way than doing this in a loop
    # but overlapping matchin patterns do not work with global flag
    # t --> t[i]

    # I tried to substitutions on $fdef vs on each line. Not much difference.
    my $defs = {};
    my ($lines,$def, $loopf, $noloopf, $name);
    my (@flines) = split(/\n/, $fdef);
    $lines = [];
    my $prefunc = $lines;# lines before any func def
    foreach my $oneline (@flines) { #break code into functions
	next if $oneline =~ /^\s*end\s+(function|jacobian)\s*/;
	if ( $oneline =~ /^\s*(function|jacobian)\s*(\w*)\s*$/ ) { # func declaration
	    $name = $2;
	    $name = "func" unless $name ne '';
	    my $type = $1;
	    $name = "jac" . $name if $type eq 'jacobian' and not $name =~ /^jac/ ;
	    $def = $defs->{$name} = {};
	    $def->{type} = $type;
	    $lines = [];
	    $def->{loop} = $lines;
	    $noloopf = 0;
	    $loopf  = 0;
	    next;
	}
	if ( $oneline =~  /^\s*noloop/ ) {  # don't want any implicit loop
	    $def->{preloop} = $lines;
	    $def->{loop} = undef;
	    $noloopf = 1;
	    next;
	}
	elsif ( $oneline =~  /^\s*loop/ ) {  # start implicit loop
	    $def->{preloop} = $lines;
	    $lines = [];
	    $def->{loop} = $lines;
	    $loopf = 1;
	    next;
	}
	else {
	    push @$lines, "" .$oneline ."\n";
	}
    }

    
    if ( defined $self->{TESTSYNTAX} ) {
	my $st = '';
        if ( @$prefunc > 0) {
	    $st .= ":PREFUNC: lines:" . scalar(@{$prefunc}). "\n";
	    	 $st .= join("\n",@{$prefunc}). "\n";
	}	    
	foreach my $name ( keys %$defs ) {
	    my $d = $defs->{$name};
	    $st .=  "NAME: $name, TYPE: " . $d->{type};
	    if (defined $d->{preloop}) {
		$st .=  ":PRELOOP: lines:" . scalar(@{$d->{preloop}}). "\n";
		$st .=  join("\n",@{$d->{preloop}}). "\n";
	    } 
	    if (defined $d->{loop}) {
		$st .=  ":LOOP: lines:" . scalar(@{$d->{loop}}). "\n";
		$st .=  join("\n",@{$d->{loop}}). "\n";
	    }
	}
	$self->{SYNTAXRESULTS} = $st;
    }

    my $end_function = "\}\n\n";
    my $end_loop = "  \}\n";
    my $start_loop = { 'jacobian' =>  "  for(i=j=0; i<n; ++i){\n",
		       'function' =>  "  for(i=0; i<n; ++i){\n" };

#    my $dtype = $self->{TYPE};
    my $dtype = 'FLOAT';
    my $start_function = {
	'jacobian' =>  "void JACFUNNAME($dtype *p, $dtype *d, int m, int n, $dtype *t)\n\{\n".
	    "  int i,j;\n",
#	    "  $dtype *t = ($dtype *) data;\n",
       'function' =>  "void FITFUNNAME($dtype *p, $dtype *x, int m, int n, $dtype *t)\n\{\n".
                 "  int i;\n" };
#             "  $dtype *t = ($dtype *) data;\n" };
    my $kode = 
	"/* This file automatically created and deleted. Do not edit. */\n" .
	"#include<math.h>\n#include <stdio.h>\n\n" .
	join('',@$prefunc);

    my $kode1 = '';

    foreach my $name ( keys %$defs ) {
	my $d = $defs->{$name};
	my ($loop, $preloop, $loopcode);
	my $type = $d->{type};
	$funcname = $name if $type eq 'function';
	$jacname = $name if $type eq 'jacobian';
	if ( defined $d->{loop} ) {
	    $loopcode = join("", @{$d->{loop} });
	    if ( $loopcode =~ /^\s*$/ ) { # loop code is whitespace
		$loopcode = undef;    # so don't print it
	    }
	    else {
		$loop = $d->{loop};
	    }
	}
	$preloop = $d->{preloop} if defined $d->{preloop};

#	$kode1 .= sprintf($start_function->{$type},$name);
	$kode1 .= sprintf($start_function->{$type}, '');
	if (defined $preloop ) {
	    foreach (@$preloop) {
		# p5 --> p[5]
		while ($_ =~ s/([^\w]|^)p(\d+)([^\w\[])/$1p[$2]$3/g){}
		if ( $type eq 'function' ) {
		    # x7 -- > x[7]
		    while($_ =~ s/([^\w]|^)x(\d+)([^\w\[])/$1x[$2]$3/g){}
		}
		elsif ( $type eq 'jacobian' ) {
		    # d3[6] -> d[ 3+ (n-1)*6], no! [3+m*6] is correct
		    while($_ =~ /([^\w]|^)d(\d+)\[(\d+)\]/ ) {
			my $i = "$2+m*$3" ;
			$_ =~ s/([^\w]|^)d\d+\[\d+\]/$1d[$i]/;
		    }
		}
	    }
	    $kode1 .= join('',@$preloop);
	}
	if ( defined $loop ) {
	    $kode1 .= $start_loop->{$type};
	    foreach ( @$loop ) {
		# t -- > t[i]
		while($_ =~ s/([^\w]|^)t([^\w\[])/$1t[i]$2/g){}
		# p5 --> p[5]
		while ($_ =~ s/([^\w]|^)p(\d+)([^\w\[])/$1p[$2]$3/g){}
		if ( $type eq 'function' ) {
		    # x -> x[i]
		    while($_ =~ s/([^\w]|^)x([^\w\[])/$1x[i]$2/g){}
		}
		elsif ( $type eq 'jacobian' ) {
		    if ( /^\s*d\d+\[?i?\]?(.+)/ ) {
			my $line = $1;
			$line  =~ s/\s*//; # strip space
			$_ =   "   d[j++] $line\n";
		    }
		}
		else {
		    warn "Levmar::Func::generate_C_source: Function type neither 'function' nor 'jacobian'";
		}
	    }
	    $kode1 .= join('',@$loop) . $end_loop;
	}
	$kode1 .= $end_function;
    } #foreach my $name ..
    my $export = $^O =~ /MSWin32/i ? '__declspec (dllexport)' : '';
    $kode .= "
#define FLOAT double
#define JACFUNNAME $export $jacname
#define FITFUNNAME $export $funcname
" .  $kode1 .
"
#undef FLOAT
#undef JACFUNNAME
#undef FITFUNNAME
#define FLOAT float
#define JACFUNNAME $export s$jacname
#define FITFUNNAME $export s$funcname
" . $kode1;
    return ($funcname,$jacname,$kode);
}  # end sub generate_C_source {

# load shared library with fit function and find a symbol
# (pointer to fit function or jacobian in our case.)
# $lib_name : name of library file , eg "./func.so"
# $func_name : name of function, eg "square"
# $func_pointer : value of C level pointer to $func_name, cast to int
# $lib_handle : same, but for pointer to library
sub open_and_find {
    my ($lib_name, $func_name) = @_;
    my $lib_handle = 0;
    my $func_pointer = 0;
    my $nchar = 1000; # avoid buffer overun by sending this number to memccpy
    my $error_message = "." x $nchar;
    deb "call_open_and_find for lib $lib_name, func $func_name.";
#    print STDERR "Nargs 1 ", scalar(@_) , "\n";
    my @res = call_open_and_find($lib_name, $func_name, $lib_handle,
		       $func_pointer,  $error_message , $nchar);
#    print STDERR "Nargs 2 ", scalar(@_) , "\n";
#    print STDERR ("call_open_and_find returned ", scalar(@res), " items\n.");
#    print STDERR (@res),"\n";
    return ($func_pointer, $lib_handle, $error_message);
#    return ($func_pointer, $lib_handle, '');
}

sub close_shared_object_file {
    my ($lib_handle) = @_;
    my $nchar = 1000; # avoid buffer overun by sending this number to memccpy
    my $error_message = "." x $nchar;
    my $ret = 0;
    deb "Closing so file.";
#    print STDERR "Nargs 3 ", scalar(@_) , "\n";
    my @res = call_close_shared_object_file( $lib_handle, $ret, $error_message, $nchar);
#    print STDERR "Nargs 4 ", scalar(@_) , "\n";
#    print STDERR ("close shared returned ", scalar(@res), " items\n.");
#    print STDERR (@res),"\n";
    return ($ret, $error_message);
}

#-----------------------------------------
# Some methods to call the functions

# evaluate the function.
# Given parameters p and coordiante pdl t,
# return x(t;p) with x->dims == t->dims.
# The functions don't really have to have
# this form, but this is what we assume for
# this call.
sub call {
    my $self = shift;
    my ($p,$t) = @_; # pdls
    my $x = zeroes($t);
    if ($self->{FPOINTER} == 0) {
	warn "Levmar::Func::call : No function loaded.";
	return PDL->null;
    }
    _callf(topdl($p),$t,$x, $self->{FPOINTER});
    return($x);
}

# call jacobian and get back 2-d pdl
# return jac(m,n) = jacfunc(p(m),t(n))
sub jac_of_t {
    my $self = shift;
    my ($p,$t) = @_; # pdls
    if ($self->{JPOINTER} == 0) {
	warn "Levmar::Func::jac_of_t: No jacobian function loaded.";
	return PDL->null;
    }
    my @dims = dims($t);
    my $jac = zeroes($p->type, $p->nelem,@dims);
    return 0 unless ref($jac) =~ /PDL/;
    _callj($p,$t,$jac, $self->{JPOINTER});
    return($jac);
}

# treat array of derivatives as 1-d, just at the
# supplied c routines do. For debugging.
# return jac(m*n) = jacfunc(p(m),t(n))
sub jac_of_t1 {
    my $self = shift;
    my ($p,$t) = @_; # pdls
    if ($self->{JPOINTER} == 0) {
	warn "Levmar::Func::jac_of_t1: No jacobian function loaded.";
	return PDL->null;
    }
    my @dims = dims($t);
    foreach (@dims) { $_ *= $p->nelem}
    my $jac = zeroes($p->type, @dims);
    return 0 unless ref($jac) =~ /PDL/;
    _callj1($p,$t,$jac, $self->{JPOINTER});
    return($jac);
}
#line 957 "Func.pm"

*_callf = \&PDL::Fit::Levmar::Func::_callf;




*_callj = \&PDL::Fit::Levmar::Func::_callj;




*_callj1 = \&PDL::Fit::Levmar::Func::_callj1;







#line 158 "func.pd"

=head1 AUTHORS

Copyright (C) 2006 John Lapeyre.
All rights reserved. There is no warranty. You are allowed
to redistribute this software / documentation under certain
conditions. For details, see the file COPYING in the PDL
distribution. If this file is separated from the PDL distribution,
the copyright notice should be included in the file.

=cut
#line 989 "Func.pm"

# Exit with OK status

1;
