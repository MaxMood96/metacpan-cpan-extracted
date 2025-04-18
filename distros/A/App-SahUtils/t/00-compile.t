use 5.006;
use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile 2.058

use Test::More;

plan tests => 33 + ($ENV{AUTHOR_TESTING} ? 1 : 0);

my @module_files = (
    'App/SahUtils.pm'
);

my @scripts = (
    'script/coerce-with-sah',
    'script/filter-with-sah',
    'script/format-with-sah',
    'script/get-sah-type',
    'script/get-value-with-sah',
    'script/is-sah-builtin-type',
    'script/is-sah-collection-builtin-type',
    'script/is-sah-collection-type',
    'script/is-sah-numeric-builtin-type',
    'script/is-sah-numeric-type',
    'script/is-sah-ref-builtin-type',
    'script/is-sah-ref-type',
    'script/is-sah-simple-builtin-type',
    'script/is-sah-simple-type',
    'script/is-sah-type',
    'script/list-sah-clauses',
    'script/list-sah-coerce-rule-modules',
    'script/list-sah-filter-rule-modules',
    'script/list-sah-pschema-modules',
    'script/list-sah-pschemabundle-modules',
    'script/list-sah-schema-modules',
    'script/list-sah-schemabundle-modules',
    'script/list-sah-type-modules',
    'script/list-sah-value-rule-modules',
    'script/normalize-sah-schema',
    'script/resolve-sah-schema',
    'script/sah-to-human',
    'script/show-sah-coerce-rule-module',
    'script/show-sah-filter-rule-module',
    'script/show-sah-schema-module',
    'script/show-sah-value-rule-modules',
    'script/validate-with-sah'
);

# no fake home requested

my @switches = (
    -d 'blib' ? '-Mblib' : '-Ilib',
);

use File::Spec;
use IPC::Open3;
use IO::Handle;

open my $stdin, '<', File::Spec->devnull or die "can't open devnull: $!";

my @warnings;
for my $lib (@module_files)
{
    # see L<perlfaq8/How can I capture STDERR from an external command?>
    my $stderr = IO::Handle->new;

    diag('Running: ', join(', ', map { my $str = $_; $str =~ s/'/\\'/g; q{'} . $str . q{'} }
            $^X, @switches, '-e', "require q[$lib]"))
        if $ENV{PERL_COMPILE_TEST_DEBUG};

    my $pid = open3($stdin, '>&STDERR', $stderr, $^X, @switches, '-e', "require q[$lib]");
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';
    my @_warnings = <$stderr>;
    waitpid($pid, 0);
    is($?, 0, "$lib loaded ok");

    shift @_warnings if @_warnings and $_warnings[0] =~ /^Using .*\bblib/
        and not eval { +require blib; blib->VERSION('1.01') };

    if (@_warnings)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}

foreach my $file (@scripts)
{ SKIP: {
    open my $fh, '<', $file or warn("Unable to open $file: $!"), next;
    my $line = <$fh>;

    close $fh and skip("$file isn't perl", 1) unless $line =~ /^#!\s*(?:\S*perl\S*)((?:\s+-\w*)*)(?:\s*#.*)?$/;
    @switches = (@switches, split(' ', $1)) if $1;

    close $fh and skip("$file uses -T; not testable with PERL5LIB", 1)
        if grep { $_ eq '-T' } @switches and $ENV{PERL5LIB};

    my $stderr = IO::Handle->new;

    diag('Running: ', join(', ', map { my $str = $_; $str =~ s/'/\\'/g; q{'} . $str . q{'} }
            $^X, @switches, '-c', $file))
        if $ENV{PERL_COMPILE_TEST_DEBUG};

    my $pid = open3($stdin, '>&STDERR', $stderr, $^X, @switches, '-c', $file);
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';
    my @_warnings = <$stderr>;
    waitpid($pid, 0);
    is($?, 0, "$file compiled ok");

    shift @_warnings if @_warnings and $_warnings[0] =~ /^Using .*\bblib/
        and not eval { +require blib; blib->VERSION('1.01') };

    # in older perls, -c output is simply the file portion of the path being tested
    if (@_warnings = grep { !/\bsyntax OK$/ }
        grep { chomp; $_ ne (File::Spec->splitpath($file))[2] } @_warnings)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
} }



is(scalar(@warnings), 0, 'no warnings found')
    or diag 'got warnings: ', ( Test::More->can('explain') ? Test::More::explain(\@warnings) : join("\n", '', @warnings) ) if $ENV{AUTHOR_TESTING};


