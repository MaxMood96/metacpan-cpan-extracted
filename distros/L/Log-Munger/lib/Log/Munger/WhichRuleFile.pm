package Log::Munger::WhichRuleFile;

use 5.006;
use strict;
use warnings;
use File::ShareDir ();

=head1 NAME

Log::Munger::WhichRuleFile - Resolves a Log::Munger rule file name to a path.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::WhichRuleFile;

    my $file_location = Log::Munger::WhichRuleFile->rule_file_location( 'file' => 'postfix' );
    if ( !defined($file_location) ) {
        print "Not found.\n";
    } else {
        print 'File Location: ' . $file_location . "\n";
    }

Rule files are looked for in a handful of places, and whichever is found first wins. That
ordering is what lets a local file shadow one shipped with the distribution: drop
your own C<sshd.yaml> in F</etc/log_munger/rules/> and every reference to C<sshd>
picks it up instead, with nothing else needing to change.

C<log_munger which_rule_file -f E<lt>nameE<gt>> is this method on the command line,
and C<log_munger list -p> shows what every discoverable name currently resolves to.

=head1 METHODS

=head2 rule_file_location

Returns the path a rule file name resolves to.

A name beginning with C</>, C<./>, or C<../> is treated as a path and used as
given. Anything else is searched for in the directories L</search_dirs> returns,
in that order.

Each location is tried twice, first for the name as given and then with C<.yaml>
appended, so C<sshd> and C<sshd.yaml> both find the same file.

    - file :: The name or path to locate. Required.
        Default :: undef

Returns the resolved path, or undef if the name turned up nothing anywhere. Dies
only if C<file> is undef.

    my $file_location = Log::Munger::WhichRuleFile->rule_file_location( 'file' => 'postfix' );

=cut

sub rule_file_location {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	}

	# a name that is already a path is used as given rather than searched for
	if ( $opts{'file'} =~ /^(\/|\.\/|\.\.\/)/ ) {
		return _existing_rule_file( $opts{'file'} );
	}

	foreach my $rules_dir ( Log::Munger::WhichRuleFile->search_dirs ) {
		next if ( !-d $rules_dir );
		my $found = _existing_rule_file( $rules_dir . '/' . $opts{'file'} );
		if ( defined($found) ) {
			return $found;
		}
	}

	return undef;
} ## end sub rule_file_location

# Checks whether a base path resolves to a rule file, first as given and then
# with .yaml appended, which is what lets "sshd" and "sshd.yaml" find the same
# file.
#
# Args:
#
#     - $base :: The path to try, such as "/etc/log_munger/rules/sshd" or
#         "./sshd".
#
# Returns the first of the two spellings that is a file, or undef when neither
# is.
#
#     my $found = _existing_rule_file( $rules_dir . '/' . $name );
sub _existing_rule_file {
	my ($base) = @_;

	if ( -f $base ) {
		return $base;
	} elsif ( -f $base . '.yaml' ) {
		return $base . '.yaml';
	}

	return undef;
} ## end sub _existing_rule_file

=head2 search_dirs

Returns the directories rule files are searched for in, highest precedence
first:

=over 4

=item 1. the directory named by the C<LOG_MUNGER_RULES_DIR> environment
variable, when set

=item 2. F</etc/log_munger/rules>

=item 3. F</usr/local/etc/log_munger/rules>

=item 4. the distribution share directory, C<< File::ShareDir::dist_dir('Log-Munger') >>
(skipped when the distribution is not installed, e.g. running out of a checkout)

=back

Takes no arguments. The directories are not checked for existence, so a caller
walking them needs to skip any that are missing.

    my @search_dirs = Log::Munger::WhichRuleFile->search_dirs;

=cut

sub search_dirs {
	my @rules_dirs = ( '/etc/log_munger/rules', '/usr/local/etc/log_munger/rules' );

	# LOG_MUNGER_RULES_DIR jumps the queue, which is what lets a checkout (or
	# a test run) resolve names against its own share dir instead of whatever
	# happens to be installed
	if ( defined( $ENV{'LOG_MUNGER_RULES_DIR'} ) && length( $ENV{'LOG_MUNGER_RULES_DIR'} ) ) {
		unshift( @rules_dirs, $ENV{'LOG_MUNGER_RULES_DIR'} );
	}

	# dist_dir dies when the distribution is not installed, which is normal
	# when running out of a checkout; treat that as one fewer place to look
	my $share_dir;
	eval { $share_dir = File::ShareDir::dist_dir('Log-Munger'); };
	if ( defined($share_dir) ) {
		push( @rules_dirs, $share_dir );
	}

	return @rules_dirs;
} ## end sub search_dirs

=head2 available_rule_files

Returns every rule file discoverable across the search path, as a hash ref of
name to resolved path. The name is the file name with the C<.yaml> suffix
stripped, so what comes back is what L</rule_file_location> takes.

A name found in more than one directory appears once, resolved to the copy in
the earliest directory, since that is the one L</rule_file_location> would
return for it.

Takes no arguments.

    my $available = Log::Munger::WhichRuleFile->available_rule_files;
    # $available = { 'base' => '/etc/log_munger/rules/base.yaml', ... }

=cut

sub available_rule_files {
	my %found;    # name => path (first, highest-precedence wins)
	foreach my $rules_dir ( Log::Munger::WhichRuleFile->search_dirs ) {
		next if ( !-d $rules_dir );
		foreach my $file ( sort( glob( $rules_dir . '/*.yaml' ) ) ) {
			my ($name) = $file =~ m{([^/]+)\.yaml\z};
			next if ( !defined($name) );
			if ( !exists( $found{$name} ) ) {
				$found{$name} = $file;
			}
		}
	} ## end foreach my $rules_dir ( Log::Munger::WhichRuleFile...)

	return \%found;
} ## end sub available_rule_files
