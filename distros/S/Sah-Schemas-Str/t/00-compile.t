use 5.006;
use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile 2.058

use Test::More;

plan tests => 26 + ($ENV{AUTHOR_TESTING} ? 1 : 0);

my @module_files = (
    'Data/Sah/Filter/perl/Str/maybe_convert_to_re.pm',
    'Data/Sah/Filter/perl/Str/maybe_eval.pm',
    'Sah/Schema/hexstr.pm',
    'Sah/Schema/latin_alpha.pm',
    'Sah/Schema/latin_alphanum.pm',
    'Sah/Schema/latin_letter.pm',
    'Sah/Schema/latin_lowercase_alpha.pm',
    'Sah/Schema/latin_lowercase_letter.pm',
    'Sah/Schema/latin_uppercase_alpha.pm',
    'Sah/Schema/latin_uppercase_letter.pm',
    'Sah/Schema/lowercase_str.pm',
    'Sah/Schema/matcher/str.pm',
    'Sah/Schema/multi_line_str.pm',
    'Sah/Schema/non_empty_str.pm',
    'Sah/Schema/percent_str.pm',
    'Sah/Schema/single_line_str.pm',
    'Sah/Schema/str1.pm',
    'Sah/Schema/str_or_aos.pm',
    'Sah/Schema/str_or_aos/arrayified.pm',
    'Sah/Schema/str_or_aos1.pm',
    'Sah/Schema/str_or_aos1/arrayified.pm',
    'Sah/Schema/str_or_code.pm',
    'Sah/Schema/str_or_re.pm',
    'Sah/Schema/str_or_re_or_code.pm',
    'Sah/Schema/uppercase_str.pm',
    'Sah/Schemas/Str.pm'
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



is(scalar(@warnings), 0, 'no warnings found')
    or diag 'got warnings: ', ( Test::More->can('explain') ? Test::More::explain(\@warnings) : join("\n", '', @warnings) ) if $ENV{AUTHOR_TESTING};


