#!/usr/bin/env perl
# xt/c-compat.t - Validate C89/C99/C23 compatibility patterns
#
# This test checks for common C compatibility issues across all XS modules:
# - C23: bool/true/false are keywords (can't typedef/define over them)
# - C89: no inline, no // comments, no mixed declarations
# - Ensures compat headers are properly included

use strict;
use warnings;
use Test::More;
use File::Find;

# Read file without File::Slurp dependency
sub read_file {
    my $file = shift;
    open my $fh, '<', $file or return;
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

# Skip if not author testing
unless ($ENV{AUTHOR_TESTING} || $ENV{RELEASE_TESTING}) {
    plan skip_all => 'Author testing only (set AUTHOR_TESTING=1)';
}

my @xs_dirs = qw(
    xs/slot
    xs/util
    xs/noop
    xs/const
    xs/doubly
    xs/object
    xs/lru
    xs/heap
    xs/file
    xs/nvec
);

my @issues;

# Pattern checks
my %checks = (
    # === C23 ISSUES ===
    
    # C23 issues - typedef bool outside of proper guards will fail
    'typedef_bool_unguarded' => {
        pattern => qr/^\s*typedef\s+\w+\s+bool\s*;/m,
        severity => 'error',
        message => 'Direct typedef of bool will fail on C23 (use #ifndef bool guard)',
        # Must be inside proper C23 guard AND #ifndef bool
        required_guards => [qr/__STDC_VERSION__.*202311L/s, qr/#\s*ifndef\s+bool/],
    },
    
    # Unguarded #define true/false
    'unguarded_true_false' => {
        pattern => qr/^#\s*define\s+(true|false)\s+\d+\s*$/m,
        severity => 'warning',
        message => 'Unguarded #define true/false may conflict with C23 keywords',
        required_guards => [qr/__STDC_VERSION__.*202311L/s, qr/#\s*ifndef\s+(true|false)/],
    },
    
    # Using lowercase true/false in actual code (not comments)
    'lowercase_bool_usage' => {
        pattern => qr/^\s*(?:if|return|while|for)\s*\(.*\b(true|false)\b/m,
        severity => 'info',
        message => 'Uses lowercase true/false - ensure compat header is included',
        requires_compat => 1,
    },
    
    # C23: nullptr keyword (not available before C23)
    'nullptr_usage' => {
        pattern => qr/\bnullptr\b/,
        severity => 'warning',
        message => 'nullptr is C23 only - use NULL for compatibility',
        skip_in_compat => 1,
    },
    
    # === C89 ISSUES ===
    
    # C89: inline keyword without guard
    'unguarded_inline' => {
        pattern => qr/^\s*(?<!static\s)(?<!OBJECT_)inline\s+\w/m,
        severity => 'warning', 
        message => 'Bare inline keyword may fail on C89 (use OBJECT_INLINE or static inline)',
    },
    
    # C89: // comments (C++ style) - may fail on strict C89
    'cpp_style_comments' => {
        pattern => qr{^\s*//(?![/*])}m,  # // at start of line (not in string)
        severity => 'info',
        message => 'C++ style // comments may fail on strict C89 compilers',
        only_in_c_files => 1,
    },
    
    # C89: Variable declarations after statements (mixed declarations)
    # This is tricky to detect reliably, so we look for common patterns
    'mixed_declarations' => {
        pattern => qr/;\s*\n\s*(int|char|bool|SV|AV|HV|CV|GV|STRLEN|I32|U32|IV|UV|NV|Size_t)\s+\w+\s*[=;]/,
        severity => 'info',
        message => 'Variable declaration after statement may fail on C89',
        only_in_c_files => 1,
        skip_functions => 1,  # Too many false positives
    },
    
    # C99: restrict keyword
    'restrict_keyword' => {
        pattern => qr/\brestrict\b/,
        severity => 'info',
        message => 'restrict keyword is C99+ only',
    },
    
    # C99: Variable-length arrays (disabled - too many false positives with array indexing)
    # 'variable_length_array' => {
    #     pattern => qr/\[\s*[a-z_][a-z0-9_]*\s*\]\s*[;=]/i,
    #     severity => 'info',
    #     message => 'Variable-length arrays are C99+ only',
    #     only_in_c_files => 1,
    # },
    
    # === COMPILER-SPECIFIC ISSUES ===
    
    # GCC/Clang __attribute__ without guard
    'unguarded_attribute' => {
        pattern => qr/__attribute__\s*\(\(/,
        severity => 'info',
        message => '__attribute__ is GCC/Clang specific - use PERL_UNUSED_DECL or guard',
        skip_in_ppport => 1,
    },
    
    # GCC __builtin_ functions
    'builtin_functions' => {
        pattern => qr/__builtin_(?!expect)/,  # __builtin_expect is commonly used
        severity => 'info',
        message => '__builtin_* functions are GCC specific',
    },
    
    # === PERL XS ISSUES ===
    
    # NOTE: PERL_NO_GET_CONTEXT is a micro-optimization for threaded perls.
    # Most XS code works fine without it. Only flag if explicitly requested.
    # Disabled by default as it's too noisy.
    
    # NOTE: PL_sv_undef, PL_sv_yes, PL_sv_no, etc. are standard Perl globals
    # that are perfectly safe to use in XS code. They're thread-safe constants.
    # Disabled as it creates too much noise for legitimate XS patterns.
    
    # === MEMORY/SAFETY ISSUES ===
    
    # sprintf without size limit (buffer overflow risk)
    'unsafe_sprintf' => {
        pattern => qr/\bsprintf\s*\(/,
        severity => 'warning',
        message => 'sprintf is unsafe - use snprintf or sv_catpvf for safety',
        only_in_c_files => 1,
    },
    
    # strcpy without size limit
    'unsafe_strcpy' => {
        pattern => qr/\bstrcpy\s*\(/,
        severity => 'warning',
        message => 'strcpy is unsafe - use strncpy or Copy/Move macros',
        only_in_c_files => 1,
    },
    
    # strcat without size limit
    'unsafe_strcat' => {
        pattern => qr/\bstrcat\s*\(/,
        severity => 'warning',
        message => 'strcat is unsafe - use strncat or sv_catpv',
        only_in_c_files => 1,
    },
    
    # gets() - extremely unsafe
    'unsafe_gets' => {
        pattern => qr/\bgets\s*\(/,
        severity => 'error',
        message => 'gets() is extremely unsafe and removed in C11 - use fgets',
        only_in_c_files => 1,
    },
    
    # === PORTABILITY ISSUES ===
    
    # Assuming sizeof(int) or sizeof(pointer)
    'hardcoded_sizes' => {
        pattern => qr/\b(sizeof\s*\(\s*(int|long|void\s*\*)\s*\)\s*==\s*[48]|[48]\s*==\s*sizeof)/,
        severity => 'warning',
        message => 'Hardcoded type sizes are not portable across platforms',
    },
    
    # Platform-specific headers without guards
    'unistd_without_guard' => {
        pattern => qr/^#\s*include\s+<unistd\.h>/m,
        severity => 'info',
        message => '<unistd.h> is Unix-only - may need HAS_UNISTD guard',
        negative_pattern => qr/#\s*if.*HAS_UNISTD|#\s*ifdef.*WIN32|#\s*ifndef.*_WIN32/,
    },
    
    # Windows-specific headers without guards  
    'windows_header_without_guard' => {
        pattern => qr/^#\s*include\s+<windows\.h>/mi,
        severity => 'info',
        message => '<windows.h> is Windows-only - ensure proper guards',
        negative_pattern => qr/#\s*if.*WIN32|#\s*ifdef.*_WIN32/,
    },
);

# Check each XS directory
for my $dir (@xs_dirs) {
    my $full_dir = $dir;
    next unless -d $full_dir;
    
    my $module = $dir;
    $module =~ s|^xs/||;
    
    # Find .c and .h files
    my @files;
    find(sub {
        push @files, $File::Find::name if /\.[ch]$/ && !/ppport\.h$/;
    }, $full_dir);
    
    for my $file (@files) {
        my $content = eval { read_file($file) };
        next unless defined $content;
        
        my $rel_file = $file;
        my $is_compat = $file =~ /_compat\.h$/;
        my $is_c_file = $file =~ /\.c$/;
        
        # Check if this file includes a compat header
        my $has_compat = $content =~ /#include\s+["<]\w+_compat\.h[">]/;
        
        for my $check_name (sort keys %checks) {
            my $check = $checks{$check_name};
            
            # Skip compat-specific checks for compat headers themselves
            next if $is_compat && $check->{skip_in_compat};
            
            # Skip checks that only apply to .c files
            next if $check->{only_in_c_files} && !$is_c_file;
            
            # Skip checks marked to skip
            next if $check->{skip_functions};
            
            if ($content =~ $check->{pattern}) {
                # For negative patterns, skip if the negative pattern matches
                if ($check->{negative_pattern}) {
                    next if $content =~ $check->{negative_pattern};
                }
                
                # For patterns with required_guards, verify all guards are present
                if ($check->{required_guards}) {
                    my $all_guards_present = 1;
                    for my $guard (@{$check->{required_guards}}) {
                        unless ($content =~ $guard) {
                            $all_guards_present = 0;
                            last;
                        }
                    }
                    next if $all_guards_present;  # Properly guarded, skip
                }
                
                # For files using true/false, verify compat header
                if ($check->{requires_compat} && !$is_compat) {
                    next if $has_compat;
                    # Also check if it's in a compat-included header chain
                    next if $file =~ /\.h$/ && $content =~ /_compat\.h/;
                }
                
                push @issues, {
                    file => $rel_file,
                    check => $check_name,
                    severity => $check->{severity},
                    message => $check->{message},
                };
            }
        }
        
        # Additional check: .c files using bool/true/false should include compat header
        if ($file =~ /\.c$/ && !$is_compat) {
            if ($content =~ /\b(true|false)\b/ && $content !~ /TRUE|FALSE/) {
                unless ($has_compat || $content =~ /stdbool\.h/) {
                    push @issues, {
                        file => $rel_file,
                        check => 'missing_compat_header',
                        severity => 'warning',
                        message => 'Uses true/false but may not include compat header',
                    };
                }
            }
        }
    }
}

# Check that all compat headers have the fixed pattern
my @compat_headers = glob("xs/*/*.h");
@compat_headers = grep { /_compat\.h$/ } @compat_headers;

for my $compat (@compat_headers) {
    my $content = eval { read_file($compat) };
    next unless defined $content;
    
    # Get the corresponding .c file to check if bool is used
    my $c_file = $compat;
    $c_file =~ s/_compat\.h$/.c/;
    my $c_content = eval { read_file($c_file) } // '';
    my $uses_bool = $c_content =~ /\b(bool|true|false)\b/;
    
    # Check for the old broken pattern
    if ($content =~ /defined\(__bool_true_false_are_defined\)\s*\|\|\s*defined\(bool\)/) {
        if ($content !~ /#\s*ifndef\s+true/) {
            push @issues, {
                file => $compat,
                check => 'old_bool_compat_pattern',
                severity => 'error',
                message => 'Old bool compat pattern - perl.h defines bool but not true/false',
            };
        }
    }
    
    # Verify the proper pattern exists if the module uses bool
    unless ($content =~ /__STDC_VERSION__.*202311L/s) {
        if ($uses_bool) {
            push @issues, {
                file => $compat,
                check => 'missing_c23_check',
                severity => 'warning',
                message => 'Missing C23 (__STDC_VERSION__ >= 202311L) check and module uses bool',
            };
        } else {
            push @issues, {
                file => $compat,
                check => 'missing_c23_check',
                severity => 'info',
                message => 'Missing C23 check (module does not currently use bool)',
            };
        }
    }
}

# Report results
if (@issues) {
    my %by_severity;
    for my $issue (@issues) {
        push @{$by_severity{$issue->{severity}}}, $issue;
    }
    
    # Errors fail the test
    my @errors = @{$by_severity{error} || []};
    my @warnings = @{$by_severity{warning} || []};
    my @infos = @{$by_severity{info} || []};
    
    if (@errors) {
        diag "\n=== ERRORS (must fix) ===";
        for my $e (@errors) {
            diag sprintf "  %s: %s\n    %s", $e->{file}, $e->{check}, $e->{message};
        }
    }
    
    if (@warnings) {
        diag "\n=== WARNINGS (should review) ===";
        for my $w (@warnings) {
            diag sprintf "  %s: %s\n    %s", $w->{file}, $w->{check}, $w->{message};
        }
    }
    
    if (@infos && $ENV{VERBOSE}) {
        diag "\n=== INFO ===";
        for my $i (@infos) {
            diag sprintf "  %s: %s", $i->{file}, $i->{message};
        }
    }
    
    is(scalar @errors, 0, 'No C compatibility errors');
    
    # Warnings don't fail but are noted
    ok(1, sprintf("Found %d warnings, %d info items", scalar @warnings, scalar @infos));
} else {
    pass('No C compatibility issues found');
}

done_testing();
