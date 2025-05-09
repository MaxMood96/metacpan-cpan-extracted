#!/usr/bin/perl -*- coding: no-conversion -*-
#
# Regenerate (overwriting only if changed):
#
#    lib/Config.pm
#    lib/Config_heavy.pl
#    lib/Config.pod
#    ext/Config/Config_xs.in
#    ext/Config/Config_xs.out
#    ext/Config/Config.xs
#
# from the contents of the static files
#
#    ext/Config/Config_xs.in (the gperf template)
#
# and from the contents of the Configure-generated file
#
#    lib/Config_heavy.pl
#    lib/Config_git.pl
#

$VERSION = '6.29';
my $in_core;

BEGIN {
    if (-d 'ext/Config') {
        chdir 'ext/Config';
    }
    unless(-d 'regen') {
        unshift @INC, '../../lib', '../../lib/auto';
        $in_core = 1;
    }
    my $ptrsize = length(pack('P',""));
    my $ivsize =  length(pack('j',0));
    die "unknown pointer size" if $ptrsize != 4 && $ptrsize != 8; #POSIX.pm not available
    eval 'sub SPTR_MIN () { '.($ptrsize == 8 ? '-9223372036854775808' : '-2147483648').' } '.
    'sub SPTR_MAX () { '.($ptrsize == 8 ? '0x7FFFFFFFFFFFFFFF' : '0x7FFFFFFF').' } '.
    'sub IV_MIN () { '.($ivsize == 8 ? '-9223372036854775808' : '-2147483648').' } '.
    'sub IV_MAX () { '.($ivsize == 8 ? '0x7FFFFFFFFFFFFFFF' : '0x7FFFFFFF').' } '.
    'sub PTRSIZE () { '.$ptrsize.' } '.
    'sub INLSIZE () { '.($ptrsize == 8 ? 13 : 5).' } '.
    'sub BE () { '.((pack('N', 1) eq pack('L', 1))+0).'}';
}
use strict ;
use Config ;
if ($in_core) {
    require '../../regen/regen_lib.pl';
} else {
    require './regen/regen_lib.pl';
}

###########################################################################

my $force = @ARGV ? $ARGV[0] eq '--force' : 0;
shift if $force;
exit if $ARGV[0] eq '--tap';
my $regen = @ARGV ? $ARGV[0] eq '--regen' : 0;
shift if $regen;
my $no_gperf = @ARGV ? $ARGV[0] eq '--no-gperf' : 0;
shift if $no_gperf;
my $gperf = "gperf";
if (@ARGV>1 && $ARGV[0] eq '--gperf') {
  shift; $gperf = shift;
}
my $verbose = @ARGV ? $ARGV[0] eq '--verbose' : 0;
shift if $verbose;
my $pathsep = $^O =~ /^(MSWin32|dos|NetWare|OS2|symbian)$/ ? "\\" : '/';
$pathsep = '.' if $^O eq 'riscos'; # Acorn RISC OS
$pathsep = ':' if $^O eq 'MacOS';
my $heavy = ($in_core ? '../../lib' : $Config{archlib}) . $pathsep . 'Config_heavy.pl';
my $git   = ($in_core ? '../../lib' : $Config{archlib}) . $pathsep . 'Config_git.pl';
# the key-only gperf syntax template with empty values, this is where to fix XSUBs
my $xsin  = 'Config_xs.in';
# gperf expanded canned template with empty values, a generated file
my $xsout = 'Config_xs.out';
# gperf expanded build specific template with empty values, a generated file
my $xsincustm  = 'Config_xs_tmp.in';
my $xsoutcustm = 'Config_xs_tmp.out';
# patched with our values, a generated file
my $xstarg= 'Config.xs';

my ($in, $xs, %h, $gperf_ok);

# collect all the values.
# and check if any keys had changed. need to update the gperf then.
if ($in_core && ! -e $heavy) { # help the Makefile deps to produce Config_heavy.pl
    system("$^X -Ilib configpm");
}
open $in, "<", $heavy or die "Error reading '$heavy': $!";
while (<$in>) {
    last if $_ eq "\$_ = <<'!END!';\n";
}
while (<$in>) { # as in config.sh
    chomp;
    last if $_ eq '!END!';
    next if $in_core && /^perl_(version|subversion|revision)=/;
    my ($k,$v) = split(/=/,$_,2);
    $v = substr($v, 1, length($v)-2); # strip start/end quotes, ' or "
    #$v =~ s/\\/\\\\/g;
    $h{$k} = $v;
}
while (<$in>) {
    last if $_ eq "our \$Config_SH_expanded = \"\\n\$_\" . << 'EOVIRTUAL';\n"
        || $_ eq #5.8.7 has unique attribute
            q|our $Config_SH_expanded : unique = "\n$_" . << 'EOVIRTUAL';|."\n";
}
while (<$in>) {
    chomp;
    last if $_ eq 'EOVIRTUAL';
    my ($k,$v) = split(/=/,$_,2);
    $v = substr($v, 1, length($v)-2); # strip start/end quotes, ' or "
    #$v =~ s/\\/\\\\/g;
    $h{$k} = $v;
}
close $in;
if ($in_core || -e $git) {
    open $in, "<", $git or die "Error reading '$git': $!";
    while (<$in>) {
        last if $_ eq "\$Config::Git_Data=<<'ENDOFGIT';\n";
    }
    while (<$in>) {
        chomp;
        last if $_ eq 'ENDOFGIT';
        # some Config_git.pl that were generated, probably without a git binary
        # available but with a .git dir in perl source tree
        # contain a blank line before ENDOFGIT line
        next unless length $_;
        my ($k,$v) = split(/=/,$_,2);
        $v = substr($v, 1, length($v)-2); # strip start/end quotes, ' or "
        $h{$k} = $v;
    }
    close $in;
}

# Test if gperf works. if not patch canned xsout instead.
unless ($no_gperf) {
    local $!;
    $gperf_ok = !(system("$gperf --output-file=${xsout}_tmp gperftest.in") >> 8);
    if ($gperf_ok and -z $xsout."_tmp") {
        $gperf_ok = 0;
    }
    unlink $xsout."_tmp";
    print STDERR "$gperf ",$gperf_ok ? "works ok\n" : "does not work. $!\n";
    unless ($gperf_ok) {
        if ($in_core) {
            print STDERR "Please install gperf for higher efficiency.\n";
        } else { # print the banner
            local $/;
            my $msg = <DATA>;
            eval $msg;
        }
    }
}

if ($gperf_ok) {
    # make a customized .xs, not git tracked, smaller Config shared lib since
    # we dont need a "universal" set of keys for all build configs of perl
    gen_gperf_Config($xsin, $xsoutcustm, \%h);
    # postprocess the values a bit to generate a canned Config for CI/no gperf
    # reserve up to 39 config_args
    for (0..39) {
        my $k = "config_arg".$_;
        $h{$k} = '' unless exists $h{$k};
    } # needed for cperl and CPAN
    #these qw blocks are created with genkeys.PL in the cpan repo
    my @cannedkeys = qw(

bin_ELF bootstrap_charset   canned_gperf    ccstdflags  ccwarnflags charsize
config_argc config_args d_attribute_always_inline   d_attribute_used
d_builtin_clz   d_builtin_ctz   d_builtin_prefetch  d_get_current_dir_name
d_llabs d_re_comp   d_realpath  d_regcmp    d_setenv    dlltool dtraceobject
fake_signatures getcwdnull  git_ancestor    git_commit_date git_remote_branch
git_unpushed    hostgenerate    hostosname  hostperl    i_netinet_in_systm
i_netinet_ip    i_netinet_ip6   incpth  installhtmldir  installhtmlhelpdir
ld_can_script   libdb_needs_pthread mad malloc_cflags   sanitize_address
sysincpth   syslibpth   sysroot targetdir   targetenv   targethost  targetmkdir
targetport  useversionedarchname

      );
    unless ($in_core) { # cperl doesn't need these, CPAN does
        push @cannedkeys , qw(

ARCH    BuiltWithPatchPerl  Mcc PATH    PERL_PATCHLEVEL ansi2knr    arflags
ccflags_nolargefiles    cf_epoch    charbits    compiler_warning
config_heavy    d_accept4   d_acosh d_asctime64 d_asinh d_atanh d_attribut
d_attribute_deprecated  d_attribute_format  d_attribute_malloc
d_attribute_nonnull d_attribute_noreturn    d_attribute_pure
d_attribute_unused  d_attribute_visibility  d_attribute_warn_unused_result
d_backtrace d_bcmp  d_bcopy d_builtin_add_overflow  d_builtin_arith_overflow
d_builtin_choose_expr   d_builtin_expect    d_builtin_mul_overflow
d_builtin_sub_overflow  d_bzero d_c99_variadic_macros   d_cbrt  d_charvspr
d_clearenv  d_copysign  d_cplusplus d_ctermid   d_ctime64   d_difftime64
d_dir_dd_fd d_dladdr    d_double_has_inf    d_double_has_nan
d_double_has_negative_zero  d_double_has_subnormals d_double_style_cray
d_double_style_ibm  d_double_style_ieee d_double_style_vax  d_dup3  d_duplocale
d_erf   d_erfc  d_exp2  d_expm1 d_fchmodat  d_fdclose   d_fdim  d_fegetround
d_ffs   d_ffsl  d_fma   d_fmax  d_fmin  d_fp_classify   d_fp_classl
d_fpgetround    d_freelocale    d_fs_data_s d_fstatfs   d_fstatvfs  d_futimes
d_gai_strerror  d_gdbm_ndbm_h_uses_prototypes   d_gdbmndbm_h_uses_prototypes
d_getaddrinfo   d_getenv_preserves_other_thread d_getfsstat d_getmnt
d_getmntent d_getnameinfo   d_gmtime64  d_has_C_UTF8    d_hasmntopt d_hypot
d_ilogb d_inc_version_list  d_inetntop  d_inetpton  d_ip_mreq
d_ip_mreq_source    d_ipv6_mreq d_ipv6_mreq_source  d_isblank   d_isfinitel
d_isinfl    d_isless    d_isnormal  d_j0    d_j0l   d_lc_monetary_2008
d_ldexpl    d_lgamma    d_lgamma_r  d_libname_unique    d_linkat    d_llrint
d_llrintl   d_llround   d_llroundl  d_localeconv_l  d_localtime64
d_localtime_r_needs_tzset   d_log1p d_log2  d_logb  d_long_double_style_ieee
d_long_double_style_ieee_doubledouble   d_long_double_style_ieee_extended
d_long_double_style_ieee_std    d_long_double_style_vax d_lrint d_lrintl
d_lround    d_lroundl   d_malloc_good_size  d_malloc_size
d_malloc_usable_size    d_mbrlen    d_mbrtowc   d_memchr    d_memcmp
d_memcpy    d_memmem    d_memmove   d_memrchr   d_memset    d_mkostemp
d_mktime64  d_modfl_pow32_bug   d_modflproto    d_nan   d_nanosleep d_ndbm
d_ndbm_h_uses_prototypes    d_nearbyint d_newlocale d_nextafter d_nexttoward
d_nl_langinfo_l d_non_int_bitfields d_nv_zero_is_allbits_zero   d_openat
d_perl_lc_all_category_positions_init   d_perl_lc_all_separator
d_perl_lc_all_uses_name_value_pairs d_pipe2 d_prctl d_prctl_set_name
d_printf_format_null    d_pseudofork    d_ptrdiff_t d_querylocale   d_regcomp
d_remainder d_remquo    d_renameat  d_rint  d_round d_safebcpy  d_safemcpy
d_sanemcmp  d_scalbn    d_setenv    d_setlocale_accepts_any_locale_name d_sfio
d_siginfo_si_addr   d_siginfo_si_band   d_siginfo_si_errno  d_siginfo_si_fd
d_siginfo_si_pid    d_siginfo_si_status d_siginfo_si_uid    d_siginfo_si_value
d_signbit   d_sin6_scope_id d_sitearch  d_snprintf  d_sockaddr_in6
d_sockaddr_sa_len   d_sockaddr_storage  d_sprintf_returns_strlen    d_stat
d_statfs_f_flags    d_statfs_s  d_static_inline d_statvfs   d_strchr
d_strctcpy  d_strerrm   d_strerror  d_strerror_l    d_strlcat   d_strlcpy
d_strnlen   d_strtod_l  d_strtold_l d_strxfrm_l d_tgamma    d_thread_local
d_thread_safe_nl_langinfo_l d_timegm    d_towlower  d_towupper  d_trunc
d_truncl    d_unlinkat  d_unsetenv  d_uselocale d_ustat d_vendorscript
d_vms_case_sensitive_symbols    d_volatile  d_vprintf   d_vsnprintf d_wcrtomb
d_wcscmp    d_wcsxfrm   default_inc_excludes_dot    defvoidused dl_so_eq_ext
doop_cflags doubleinfbytes  doublekind  doublemantbits  doublenanbytes  dtrace
dtracexnolibs   extern_C    found_libucb    from    gccansipedantic git_branch
git_commit_id   git_commit_id_title git_describe    git_snapshot_date
git_uncommitted_changes gnulibc_version hash_func   html1dir    html1direxp
html3dir    html3direxp i32dformat  i_assert    i_bfd   i_dld   i_execinfo
i_fenv  i_float i_gdbm_ndbm i_gdbmndbm  i_mallocmalloc  i_math  i_memory
i_mntent    i_quadmath  i_sfio  i_stdarg    i_stdbool   i_stddef    i_stdint
i_sysmount  i_syspoll   i_sysstatfs i_sysstatvfs    i_syssyscall    i_sysvfs
i_ustat i_values    i_varargs   i_varhdr    i_wchar i_xlocale   ieeefp_h
initialinstalllocation  installhtml1dir installhtml3dir installsitehtml1dir
installsitehtml3dir installsiteman1dir  installsiteman3dir  installsitescript
installvendorhtml1dir   installvendorhtml3dir   installvendorman1dir
installvendorman3dir    installvendorscript ldflags_nolargefiles
libs_nolargefiles   libswanted_nolargefiles longdblinfbytes longdblkind
longdblmantbits longdblnanbytes madlyh  madlyobj    madlysrc    mistrustnm
nv_overflows_integers_at    nvmantbits  op_cflags   perl_patchlevel
perl_revision   perl_static_inline  perl_subversion perl_thread_local
perl_version    ppmarch pthread_h_first regexec_cflags  rm_try  run sGMTIME_max
sGMTIME_min sLOCALTIME_max  sLOCALTIME_min  sitehtml1dir    sitehtml1direxp
sitehtml3dir    sitehtml3direxp siteman1dir siteman1direxp  siteman3dir
siteman3direxp  sitescript  sitescriptexp   st_dev_sign st_dev_size st_ino_sign
st_ino_size taint_disabled  taint_support   targetsh    to  toke_cflags
u32XUformat u32oformat  u32uformat  u32xformat  usecbacktrace   usecperl
usedefaultstrict    usedevel    usedtrace   usekernprocpathname uselanginfo
usensgetexecutablepath  usequadmath userelocatableinc   usesfio vaproto
vendorhtml1dir  vendorhtml1direxp   vendorhtml3dir  vendorhtml3direxp
vendorman1dir   vendorman1direxp    vendorman3dir   vendorman3direxp
vendorscript    vendorscriptexp voidflags   xlocale_needed  yacc    yaccflags

        );
    }

    for my $k (@cannedkeys) {
        if (!exists $h{$k}) {
            warn "add $k to $xsout\n" if $verbose;
            $h{$k} = '';
        }
    }
    #dont regen the git tracked canned hash inside cperl unless requested
    gen_gperf_Config($xsin, $xsout, \%h) if $regen || ! $in_core;
    $xsout = $xsoutcustm; # use smaller build specific .xs
}
#add marker key so we know for testing the larger canned gperf hash was used
else {
    $h{canned_gperf} = '';
}

# code in Config_heavy.pl to compute byteorder is customized/interpolated
# for each build permutation of perl by configpm. The byteorder in the
# Config_heavy.pl database is ignored. Just use Config_heavy.pl to get byteorder
# instead of copying the complicated code in configpm to here
$h{byteorder} = $Config{byteorder};

#these values are dynamically generated in ActivePerl::Config, freeze them
if(defined &ActivePerl::PRODUCT && ! $ENV{ACTIVEPERL_CONFIG_DISABLE}){
    foreach (qw (
        _a
        _o
        ar
        cc
        cccdlflags
        ccflags
        ccname
        ccversion
        cpp
        cppminus
        cpprun
        cppstdin
        dlltool
        gccversion
        i64type
        ld
        lddlflags
        ldflags
        lib_ext
        libc
        libs
        make
        obj_ext
        optimize
        perllibs
        quadtype
        u64type
        uquadtype
    )) {
        $h{$_} = $Config{$_} if exists $Config{$_};
    }
}

#Strawberry Perl's Portable.pm in Config.pm means parsing Config_heavy.pl
#gave bad paths in everything like
#   Failed test 'cmp PP to XS hashes'
#   at t/XSConfig.t line 158.
#     Structures begin differing at:
#          $got->{installsitebin} = 'C:\sperl\526\perl\site\bin'
#     $expected->{installsitebin} = 'C:\strawberry\perl\site\bin'
#fetch runtime computed ones, but this portable perl wont be portable any
#further after XSConfig is installed
if($INC{'Portable.pm'}) {
    foreach(qw (
archlib archlibexp  bin binexp  incpath installarchlib  installbin
installprefix   installprefixexp    installprivlib  installscript
installsitearch installsitebin  installsitelib  installsitescript
installstyle    installvendorarch   installvendorbin    installvendorlib
installvendorscript ld  lddlflags   ldflags ldflags_nolargefiles    libpth
perlpath    prefix  prefixexp   privlib privlibexp  scriptdir   scriptdirexp
sitearch    sitearchexp sitebin sitebinexp  sitelib sitelibexp  siteprefix
siteprefixexp   sitescript  sitescriptexp   usrinc  vendorarch  vendorarchexp
vendorbin   vendorbinexp    vendorhtml1dir  vendorhtml3dir  vendorlib
vendorlibexp    vendorman1dir   vendorman3dir   vendorprefix    vendorprefixexp
vendorscript    vendorscriptexp
    )) {
        $h{$_} = $Config{$_} if exists $Config{$_};
    }
}

my $inside_stringpool;
# and now patch the values into Config.xs
open $in, '<', $xsout  or die "Error reading '$xsout': $!";
open $xs, '>', $xstarg or die "Error writing '$xstarg': $!";
while (<$in>) {
    if (!$gperf_ok
           && /    char stringpool_str\d+\[sizeof \("([^"]+)"\)\];\n/) {
        #"soft" remove stringpool keys from canned gperf if they are not in PP config
        #this saves some space but rerunning gperf is more space efficient to
        #have less holes in the hash
        if(! exists $h{$1}) {
            $_ = '';
        }
    }
    elsif (!$gperf_ok && /static const struct stringpool_t stringpool_contents =/){
        $inside_stringpool = 1;
    }
    elsif (!$gperf_ok && $inside_stringpool && /    "([^"]+)",/) {
        if(! exists $h{$1}) { #soft delete for canned hash
            $_ = '';
        }
    }
    elsif($inside_stringpool && $_ eq '  };') {
        $inside_stringpool = 0;
    }
    elsif (/0,ALN64I"@@(\w+)@@"/) {{
        my $k = $1;
        unless (exists $h{$k}){ #soft delete for canned hash
            $_ = "{XSCNO},\n";
            last;
        }
        my $v = $h{$k};
        my $type = t_type($v);
        my ($qv, $l);
        if ($type eq 'T_STR') {
            if ($v eq 'undef') {
                $l  = 0;
                $qv = 'ALN64I (char*)VUNDEF'
            } elsif ($v eq 'define') {
                $l  = 0;
                $qv = 'ALN64I (char*)VDEFINE'
          } elsif ($v eq '') {
              $l  = 0;
              $qv = 'ALN64I (char*)VEMPTY'
        } else { # a string in ASCII/characters
            my $lv = length($v);
            die "the value of Config key $k is over permitted length"
              unless $lv <= 1<<15;
            # an inline string stored directly in struct
            if ($lv <= INLSIZE) {
                my $h = unpack('H['.(INLSIZE*2).']', $v);
                $h .= '0' x ((INLSIZE*2)-length($h)); # null pad out to end of struct
                my @h = unpack("(A2)*", $h);
                $l = 'LENPACKINL('.$lv.', 0x'.$h[0].')';
                $qv = '(const char*)' if PTRSIZE == 4;
                if (BE) {
                    $qv = join('', $qv, '0x', @h[1,2,3,4]);
                    $qv = join('', $qv, ', (const char*)0x', @h[5..12])
                      if (PTRSIZE == 8);
                } else {
                    $qv = join('', $qv, '0x', @h[4,3,2,1]);
                    $qv = join('', $qv, ', (const char*)UINT64_C(0x', @h[12,11,10,9,8,7,6,5], ')')
                      if (PTRSIZE == 8);
                }
            } else { # a regular C string
                $v =~ s/"/\\"/g;
                # $v =~ s/\\!/!/;
                # $v =~ s/\\ / /g;
                $qv = $v;
                $qv =~ s/(\\[^nrftacx"' ])/\\$1/g; # windows paths: \\ => \\\\
                $qv =~ s/(\\[nrftacx ])/\\$1/g;    # \n => \\n, allowed escape chars
                $qv = '"'.$qv.'"';
                $l = $v =~ m/["'\\]/ ?
                  # don't calculate C-style length [cperl #61], let C do it for us
                  # and don't count the ending \0
                  'sizeof (' . $qv . ')-1'
                  : length($v)+0;
                $l = "($l) << 1" if ! BE;
                $qv = 'ALN64I '.$qv;
            }
      }
        } else { # $type eq 'T_INT'
            if ($v >= SPTR_MIN && $v <= SPTR_MAX) { # can fit in a ptr
                $l = 0;
                $qv = 'ALN64I (char *)'.$v;
            } else {# str in C, IV in perl, will be atoi-ed, 64b IV on 32b perl
                $l = length($v);
                $qv = '"'.$v.'"';
            }
        }
        my $new = $type.', '. $l . ', ' . $qv ;
        s/T_\w+,0,ALN64I"\@\@$k\@\@"/$new/; # we have one line per key only
        chomp;
        $_ .= " /* k=$k v=$v*/\n";
    }} #double } for last stmt
    print $xs $_;
}
close $in;
close $xs;
rename $xsout."_tmp", $xsout;

# creates a not-valid-C/XS template for gperf, then runs it through gperf, then
# fixes misc flaws in the C code gen of gperf in the C/XS file.
# The final C/XS file has all the Config keys, but no Config values.
sub gen_gperf_Config {
    my $in;
    my ($xsin, $xsout, $h) = @_;
    my $xs = open_new($xsincustm, '>');
    open $in, "<", $xsin or die "Error reading '$xsin': $!";

    # expand only keys within %%
    while (<$in>) {
        print $xs $_;
        last if /^%%$/;
    }

    foreach my $k (sort { $a cmp $b } keys %$h) {
        my $tabs = "\t" x (3-((2+length($k))/8));
        # generate gperf syntax section of Config_xs.in
        printf $xs "%s,\t%s%s,0,ALN64I\"@@%s@@\"\n", $k, $tabs, 'T_INV', $k;
    }
    print $xs "%%\n";

    while (<$in>) {
        last if /^%%$/;
    }
    # and the rest after the keys
    while (<$in>) {
        print $xs $_;
    }
    close $in;
    $xs->flush if $xs->can('flush');

    if (close_and_rename($xs) or $force or -M $xsin < -M $xsout or !(-f $xsout))
    {
        print STDERR "gperf $xsout\n";
        system("gperf -m 2 --output-file=$xsout $xsincustm");
        post_process_gperf($xsout);
    }
}

sub post_process_gperf {
    my $in = shift;
    my $tmp = $in.".tmp";
    open my $OUT, '>', $tmp or die "Can't write '$tmp': $!";
    binmode $OUT;
    local $/ = "\n\n";
    print $OUT <<'EOT';
/* ex: set ro ft=c: -*- buffer-read-only: t; mode: c; c-basic-offset: 4; -*-
  !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
  This file is built by ext/Config/Config_xs.PL and ext/Config/Config_xs.in. */
EOT
    my $lnr = 0;
    open my $IN, '<', $in or die "Can't read '$in': $!";

    while (<$IN>) {
        # overlong line, and don't bother bug-gnu-gperf\@gnu.org with crazy encodings
        # also c_indent.t
        # XXX add EBCDIC support, bypassing gperf (i.e. pperf)
        s/^#?error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gnu-gperf\@gnu.org>."/#  error "gperf generated tables don't work with this non ISO-646 based character set."/m;

        # C++ requires full struct initializers
        s/{-1},/{XSCNO},/g;

        # harmonize darwin with linux gperf
        s{(duplicates = \d+ \*/\n\n)$}{\1}m;

        # skip inline
        s/\Q#ifdef __GNUC__
__inline
#if defined __GNUC_STDC_INLINE__ || defined __GNUC_GNU_INLINE__
__attribute__ ((__gnu_inline__))
#endif
#endif\E//;
        s/\Q#ifdef __GNUC__
__inline
#else
#ifdef __cplusplus
inline
#endif
#endif\E//;
        s/\Q#if (defined (__STDC_VERSION__) && __STDC_VERSION__ >= 199901L) || defined(__cplusplus) || defined(__GNUC_STDC_INLINE__)
inline
#elif defined(__GNUC__)
__inline
#endif\E//;

        # There should be at least one space between a C keyword and any subsequent
        # open parenthesis
        s/sizeof\(/sizeof (/g;

        # fixup gperf 3.1 lookup signature. max U32 keys
        s{\QConfig_lookup (register const char *str, register size_t len)\E}
         {Config_lookup (register const char *str, register unsigned int len)};

        # fixup U16
        s/\(int\)\((long|size_t)\)\&/(U16)(Size_t)&/g;
        s/\Qregister int o = wordlist[key].name\E/register U16 o = wordlist[key].name/;
        s/\Qif (o >= 0)\E\n/if (o != XCNAME_MAX)\n/;

        # don't delete line numbers, pointing to Config_xs.in
        s/^#line \d+ .+$//gm; # do it to catch a bug
        # but insert a #line after the wordlist in Config_lookup
        $lnr += tr/\n/\n/;
        if (/if \(len <= MAX_WORD_LENGTH/) {
            print $OUT "#line $lnr \"Config.xs\"\n";
        }

        print $OUT $_;
    }
    close $IN;
    close $OUT;
    rename $tmp, $in;
}

sub t_type ($) {
    my $v = shift;
    return $v =~ /^-?\d+$/ && $v >= IV_MIN && $v <= IV_MAX ?  'T_INT' : 'T_STR';
}

__DATA__

# banner: "please install gperf for efficiency and rebuild"
# Generated with Font ANSI Shadow
# http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=please%0Ainstall%0Agperf%20for%0Aefficiency%0Aand%0Arebuild

my $utf8msg =
'██████╗ ██╗     ███████╗ █████╗ ███████╗███████╗
██╔══██╗██║     ██╔════╝██╔══██╗██╔════╝██╔════╝
██████╔╝██║     █████╗  ███████║███████╗█████╗
██╔═══╝ ██║     ██╔══╝  ██╔══██║╚════██║██╔══╝
██║     ███████╗███████╗██║  ██║███████║███████╗
╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝

██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗
██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║
██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║
██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║
██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝

 ██████╗ ██████╗ ███████╗██████╗ ███████╗    ███████╗ ██████╗ ██████╗
██╔════╝ ██╔══██╗██╔════╝██╔══██╗██╔════╝    ██╔════╝██╔═══██╗██╔══██╗
██║  ███╗██████╔╝█████╗  ██████╔╝█████╗      █████╗  ██║   ██║██████╔╝
██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██╔══╝      ██╔══╝  ██║   ██║██╔══██╗
╚██████╔╝██║     ███████╗██║  ██║██║         ██║     ╚██████╔╝██║  ██║
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝         ╚═╝      ╚═════╝ ╚═╝  ╚═╝

███████╗███████╗███████╗██╗ ██████╗██╗███████╗███╗   ██╗ ██████╗██╗   ██╗
██╔════╝██╔════╝██╔════╝██║██╔════╝██║██╔════╝████╗  ██║██╔════╝╚██╗ ██╔╝
█████╗  █████╗  █████╗  ██║██║     ██║█████╗  ██╔██╗ ██║██║      ╚████╔╝
██╔══╝  ██╔══╝  ██╔══╝  ██║██║     ██║██╔══╝  ██║╚██╗██║██║       ╚██╔╝
███████╗██║     ██║     ██║╚██████╗██║███████╗██║ ╚████║╚██████╗   ██║
╚══════╝╚═╝     ╚═╝     ╚═╝ ╚═════╝╚═╝╚══════╝╚═╝  ╚═══╝ ╚═════╝   ╚═╝

 █████╗ ███╗   ██╗██████╗
██╔══██╗████╗  ██║██╔══██╗
███████║██╔██╗ ██║██║  ██║
██╔══██║██║╚██╗██║██║  ██║
██║  ██║██║ ╚████║██████╔╝
╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝

██████╗ ███████╗██████╗ ██╗   ██╗██╗██╗     ██████╗
██╔══██╗██╔════╝██╔══██╗██║   ██║██║██║     ██╔══██╗
██████╔╝█████╗  ██████╔╝██║   ██║██║██║     ██║  ██║
██╔══██╗██╔══╝  ██╔══██╗██║   ██║██║██║     ██║  ██║
██║  ██║███████╗██████╔╝╚██████╔╝██║███████╗██████╔╝
╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝
';

my $cp437msg =
'�����ۻ �ۻ     ������ۻ ����ۻ ������ۻ������ۻ
������ۻ�ۺ     ������ͼ������ۻ������ͼ������ͼ
������ɼ�ۺ     ����ۻ  ������ۺ������ۻ����ۻ
�����ͼ �ۺ     ����ͼ  ������ۺ������ۺ����ͼ
�ۺ     ������ۻ������ۻ�ۺ  �ۺ������ۺ������ۻ
�ͼ     ������ͼ������ͼ�ͼ  �ͼ������ͼ������ͼ

�ۻ��ۻ   �ۻ������ۻ�������ۻ ����ۻ �ۻ     �ۻ
�ۺ���ۻ  �ۺ������ͼ�������ͼ������ۻ�ۺ     �ۺ
�ۺ����ۻ �ۺ������ۻ   �ۺ   ������ۺ�ۺ     �ۺ
�ۺ�ۺ��ۻ�ۺ������ۺ   �ۺ   ������ۺ�ۺ     �ۺ
�ۺ�ۺ ����ۺ������ۺ   �ۺ   �ۺ  �ۺ������ۻ������ۻ
�ͼ�ͼ  ���ͼ������ͼ   �ͼ   �ͼ  �ͼ������ͼ������ͼ

 �����ۻ �����ۻ ������ۻ�����ۻ ������ۻ    ������ۻ �����ۻ �����ۻ
������ͼ ������ۻ������ͼ������ۻ������ͼ    ������ͼ�������ۻ������ۻ
�ۺ  ��ۻ������ɼ����ۻ  ������ɼ����ۻ      ����ۻ  �ۺ   �ۺ������ɼ
�ۺ   �ۺ�����ͼ ����ͼ  ������ۻ����ͼ      ����ͼ  �ۺ   �ۺ������ۻ
�������ɼ�ۺ     ������ۻ�ۺ  �ۺ�ۺ         �ۺ     �������ɼ�ۺ  �ۺ
 �����ͼ �ͼ     ������ͼ�ͼ  �ͼ�ͼ         �ͼ      �����ͼ �ͼ  �ͼ

������ۻ������ۻ������ۻ�ۻ �����ۻ�ۻ������ۻ��ۻ   �ۻ �����ۻ�ۻ   �ۻ
������ͼ������ͼ������ͼ�ۺ������ͼ�ۺ������ͼ���ۻ  �ۺ������ͼ��ۻ ��ɼ
����ۻ  ����ۻ  ����ۻ  �ۺ�ۺ     �ۺ����ۻ  ����ۻ �ۺ�ۺ      �����ɼ
����ͼ  ����ͼ  ����ͼ  �ۺ�ۺ     �ۺ����ͼ  �ۺ��ۻ�ۺ�ۺ       ���ɼ
������ۻ�ۺ     �ۺ     �ۺ������ۻ�ۺ������ۻ�ۺ ����ۺ������ۻ   �ۺ
������ͼ�ͼ     �ͼ     �ͼ �����ͼ�ͼ������ͼ�ͼ  ���ͼ �����ͼ   �ͼ

 ����ۻ ��ۻ   �ۻ�����ۻ
������ۻ���ۻ  �ۺ������ۻ
������ۺ����ۻ �ۺ�ۺ  �ۺ
������ۺ�ۺ��ۻ�ۺ�ۺ  �ۺ
�ۺ  �ۺ�ۺ ����ۺ������ɼ
�ͼ  �ͼ�ͼ  ���ͼ�����ͼ

�����ۻ ������ۻ�����ۻ �ۻ   �ۻ�ۻ�ۻ     �����ۻ
������ۻ������ͼ������ۻ�ۺ   �ۺ�ۺ�ۺ     ������ۻ
������ɼ����ۻ  ������ɼ�ۺ   �ۺ�ۺ�ۺ     �ۺ  �ۺ
������ۻ����ͼ  ������ۻ�ۺ   �ۺ�ۺ�ۺ     �ۺ  �ۺ
�ۺ  �ۺ������ۻ������ɼ�������ɼ�ۺ������ۻ������ɼ
�ͼ  �ͼ������ͼ�����ͼ  �����ͼ �ͼ������ͼ�����ͼ
';
#appveyor's console->html converter assumes console output is utf8 even though
#console is set to CP 437
print $^O eq 'MSWin32' && ! $ENV{APPVEYOR} ? $cp437msg : $utf8msg;
