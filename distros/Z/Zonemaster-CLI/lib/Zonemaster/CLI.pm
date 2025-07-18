# Brief help module to define the exception we use for early exits.
package Zonemaster::Engine::Exception::NormalExit;
use v5.26;
use warnings;
use parent 'Zonemaster::Engine::Exception';

# The actual interesting module.
package Zonemaster::CLI;

use v5.26;

use warnings;

use version; our $VERSION = version->declare( "v8.0.0" );

use Locale::TextDomain 'Zonemaster-CLI';

use Encode;
use File::Slurp;
use Getopt::Long qw[GetOptionsFromArray :config gnu_compat bundling no_auto_abbrev];
use JSON::XS;
use List::Util qw[max uniq];
use Net::IP::XS;
use Pod::Usage;
use POSIX qw[setlocale LC_MESSAGES LC_CTYPE];
use Readonly;
use Scalar::Util qw[blessed];
use Time::HiRes;
use Try::Tiny;
use Zonemaster::CLI::TestCaseSet;
use Zonemaster::Engine::Exception;
use Zonemaster::Engine::Logger::Entry;
use Zonemaster::Engine::Normalization qw[normalize_name];
use Zonemaster::Engine::Translator;
use Zonemaster::Engine::Util       qw[parse_hints];
use Zonemaster::Engine::Validation qw[validate_ipv4 validate_ipv6];
use Zonemaster::Engine;
use Zonemaster::LDNS;

our %numeric = Zonemaster::Engine::Logger::Entry->levels;
our $JSON    = JSON::XS->new->allow_blessed->convert_blessed->canonical;
our $SCRIPT  = $0;

Readonly our $EXIT_SUCCESS       => 0;
Readonly our $EXIT_GENERIC_ERROR => 1;
Readonly our $EXIT_USAGE_ERROR   => 2;

Readonly our $DS_RE => qr/^(?:[[:digit:]]+,){3}[[:xdigit:]]+$/;

STDOUT->autoflush( 1 );

sub my_pod2usage {
    my ( %opts ) = @_;

    pod2usage(
        -input    => $SCRIPT,
        -output   => $opts{output},
        -verbose  => $opts{verbosity},
        -exitcode => 'NOEXIT',
    );

    return;
}

# Returns an integer representing an OS exit status.
sub run {
    my ( $class, @argv ) = @_;

    my $opt_count        = 0;
    my @opt_ds           = ();
    my $opt_dump_profile = 0;
    my $opt_elapsed      = 0;
    my $opt_encoding     = undef;
    my $opt_help         = 0;
    my $opt_hints;
    my $opt_ipv4           = undef;
    my $opt_ipv6           = undef;
    my $opt_json           = undef;
    my $opt_json_stream    = 0;
    my $opt_json_translate = undef;
    my $opt_level          = 'NOTICE';
    my $opt_list_tests     = 0;
    my $opt_locale         = undef;
    my @opt_ns             = ();
    my $opt_nstimes        = 0;
    my $opt_profile;
    my $opt_progress = undef;
    my $opt_raw;
    my $opt_restore;
    my $opt_save;
    my $opt_show_level    = 1;
    my $opt_show_module   = 0;
    my $opt_show_testcase = 0;
    my $opt_sourceaddr4;
    my $opt_sourceaddr6;
    my $opt_stop_level = '';
    my @opt_test       = ();
    my $opt_time       = 1;
    my $opt_version    = 0;

    {
        local $SIG{__WARN__} = sub { print STDERR $_[0] };

        GetOptionsFromArray(
            \@argv,
            'count!'          => \$opt_count,
            'ds=s'            => \@opt_ds,
            'dump-profile!'   => \$opt_dump_profile,
            'dump_profile!'   => \$opt_dump_profile,
            'elapsed!'        => \$opt_elapsed,
            'encoding=s'      => \$opt_encoding,
            'hints=s'         => \$opt_hints,
            'help|h|usage|?!' => \$opt_help,
            'ipv4!'           => \$opt_ipv4,
            'ipv6!'           => \$opt_ipv6,
            'json!'           => \$opt_json,
            'json-stream!'    => \$opt_json_stream,
            'json_stream!'    => \$opt_json_stream,
            'json-translate!' => \$opt_json_translate,
            'json_translate!' => \$opt_json_translate,
            'level=s'         => \$opt_level,
            'list-tests!'     => \$opt_list_tests,
            'list_tests!'     => \$opt_list_tests,
            'locale=s'        => \$opt_locale,
            'ns=s'            => \@opt_ns,
            'nstimes!'        => \$opt_nstimes,
            'profile=s'       => \$opt_profile,
            'progress!'       => \$opt_progress,
            'raw!'            => \$opt_raw,
            'restore=s'       => \$opt_restore,
            'save=s'          => \$opt_save,
            'show-level!'     => \$opt_show_level,
            'show_level!'     => \$opt_show_level,
            'show-module!'    => \$opt_show_module,
            'show_module!'    => \$opt_show_module,
            'show-testcase!'  => \$opt_show_testcase,
            'show_testcase!'  => \$opt_show_testcase,
            'sourceaddr4=s'   => \$opt_sourceaddr4,
            'sourceaddr6=s'   => \$opt_sourceaddr6,
            'stop-level=s'    => \$opt_stop_level,
            'stop_level=s'    => \$opt_stop_level,
            'test=s'          => \@opt_test,
            'time!'           => \$opt_time,
            'version!'        => \$opt_version,
          )
          or do {
            my_pod2usage( verbosity => 0, output => \*STDERR );
            return 2;
          };
    }

    if ( $opt_help ) {
        my_pod2usage( verbosity => 1, output => \*STDOUT );
        say "Severity levels from highest to lowest:";
        say "  CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG, DEBUG2, DEBUG3";

        return 0;
    }

    $opt_level      = uc $opt_level;
    $opt_stop_level = uc $opt_stop_level;

    my @accumulator;
    my %counter;
    my $printed_something;

    if ( $opt_locale ) {
        undef $ENV{LANGUAGE};
        $ENV{LC_ALL} = $opt_locale;
    }

    # Set LC_MESSAGES and LC_CTYPE separately
    # (https://www.gnu.org/software/gettext/manual/html_node/Triggering.html#Triggering)
    if ( not defined setlocale( LC_MESSAGES, "" ) ) {
        my $locale = ( $ENV{LANGUAGE} || $ENV{LC_ALL} || $ENV{LC_MESSAGES} );
        say STDERR __x(
            "Warning: setting locale category LC_MESSAGES to {locale} failed -- is it installed on this system?",
            locale => $locale ) . "\n\n";
    }

    if ( not defined setlocale( LC_CTYPE, "" ) ) {
        my $locale = ( $ENV{LC_ALL} || $ENV{LC_CTYPE} );
        say STDERR __x(
            "Warning: setting locale category LC_CTYPE to {locale} failed -- is it installed on this system?",
            locale => $locale ) . "\n\n";
    }

    if ( $opt_version ) {
        print_versions();
        return $EXIT_SUCCESS;
    }

    if ( $opt_list_tests ) {
        print_test_list();
        return $EXIT_SUCCESS;
    }

    # errors and warnings
    if ( defined $opt_encoding ) {
        say STDERR __( "Warning: deprecated --encoding, simply remove it from your usage." );
    }

    if ( $opt_json_stream and defined $opt_json and not $opt_json ) {
        say STDERR __( "Error: --json-stream and --no-json cannot be used together." );
        return $EXIT_USAGE_ERROR;
    }

    if ( defined $opt_json_translate ) {
        unless ( $opt_json or $opt_json_stream ) {
            printf STDERR __( "Warning: --json-translate has no effect without either --json or --json-stream." )
              . "\n";
        }
        if ( $opt_json_translate ) {
            printf STDERR __( "Warning: deprecated --json-translate, use --no-raw instead." ) . "\n";
        }
        else {
            printf STDERR __( "Warning: deprecated --no-json-translate, use --raw instead." ) . "\n";
        }
    }

    # align values
    $opt_json = 1 if $opt_json_stream;
    $opt_raw //= defined $opt_json_translate ? !$opt_json_translate : 0;

    # Filehandle for diagnostics output
    my $fh_diag = ( $opt_json or $opt_raw or $opt_dump_profile )
      ? *STDERR     # Structured output mode (e.g. JSON)
      : *STDOUT;    # Human readable output mode

    my $show_progress = $opt_progress // !!-t STDOUT && !$opt_json && !$opt_raw;

    if ( $opt_profile ) {
        say $fh_diag __x( "Loading profile from {path}.", path => $opt_profile );
        my $json    = read_file( $opt_profile );
        my $foo     = Zonemaster::Engine::Profile->from_json( $json );
        my $profile = Zonemaster::Engine::Profile->default;
        $profile->merge( $foo );
        Zonemaster::Engine::Profile->effective->merge( $profile );
    }

    if ( defined $opt_sourceaddr4 ) {
        local $@;
        eval {
            Zonemaster::Engine::Profile->effective->set( q{resolver.source4}, $opt_sourceaddr4 );
            1;
        } or do {
            say STDERR __x( "Error: invalid value for --sourceaddr4: {reason}", reason => $@ );
            return $EXIT_USAGE_ERROR;
        };
    }

    if ( defined $opt_sourceaddr6 ) {
        local $@;
        eval {
            Zonemaster::Engine::Profile->effective->set( q{resolver.source6}, $opt_sourceaddr6 );
            1;
        } or do {
            say STDERR __x( "Error: invalid value for --sourceaddr6: {reason}", reason => $@ );
            return $EXIT_USAGE_ERROR;
        };
    }

    {
        my %all_methods = Zonemaster::Engine->all_methods;
        my $cases       = Zonemaster::CLI::TestCaseSet->new(    #
            Zonemaster::Engine::Profile->effective->get( q{test_cases} ),
            \%all_methods,
        );

        for my $test ( @opt_test ) {
            my @modifiers = Zonemaster::CLI::TestCaseSet->parse_modifier_expr( $test );
            while ( @modifiers ) {
                my $op   = shift @modifiers;
                my $term = shift @modifiers;

                if ( !$cases->apply_modifier( $op, $term ) ) {
                    say STDERR __x( "Error: unrecognized term '{term}' in --test.", term => $term ) . "\n";
                    return $EXIT_USAGE_ERROR;
                }
            }
        }

        Zonemaster::Engine::Profile->effective->set( q{test_cases}, [ $cases->to_list ] ),
    }

    # These two must come after any profile from command line has been loaded
    # to make any IPv4/IPv6 option override the profile setting.
    if ( defined( $opt_ipv4 ) ) {
        Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, $opt_ipv4 );
    }
    if ( defined( $opt_ipv6 ) ) {
        Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, $opt_ipv6 );
    }

    if ( $opt_dump_profile ) {
        do_dump_profile();
        return $EXIT_SUCCESS;
    }

    if ( $opt_stop_level and not defined( $numeric{$opt_stop_level} ) ) {
        say STDERR __x( "Failed to recognize stop level '{level}'.", level => $opt_stop_level );
        return $EXIT_USAGE_ERROR;
    }

    if ( not defined $numeric{$opt_level} ) {
        say STDERR __( "--level must be one of CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG, DEBUG2 or DEBUG3." );
        return $EXIT_USAGE_ERROR;
    }

    if ( $opt_restore ) {
        Zonemaster::Engine->preload_cache( $opt_restore );
    }

    my $level_width = 0;
    foreach ( keys %numeric ) {
        if ( $numeric{$opt_level} <= $numeric{$_} ) {
            my $width_l10n = length( decode_utf8( translate_severity( $_ ) ) );
            $level_width = $width_l10n if $width_l10n > $level_width;
        }
    }

    my $translator;
    my %field_width = (
        seconds  => 7,
        level    => $level_width,
        module   => 12,
        testcase => 14
    );
    my %header_names    = ();
    my %remaining_space = ();

    # Callback defined here so it closes over the setup above.
    # But we can’t use it right now because the translator isn’t initialized.
    my $message_printer = sub {
        my ( $entry ) = @_;

        print_spinner() if $show_progress;

        my $entry_level = $entry->level;

        $counter{ uc $entry_level } += 1;

        if ( $numeric{ uc $entry_level } >= $numeric{$opt_level} ) {
            $printed_something = 1;

            if ( $opt_json and $opt_json_stream ) {
                my %r;

                $r{timestamp} = $entry->timestamp if $opt_time;
                $r{module}    = $entry->module    if $opt_show_module;
                $r{testcase}  = $entry->testcase  if $opt_show_testcase;
                $r{tag}       = $entry->tag;
                $r{level}     = $entry_level if $opt_show_level;
                $r{args}      = $entry->args if $entry->args;
                $r{message}   = $translator->translate_tag( $entry ) unless $opt_raw;

                say $JSON->encode( \%r );
            }
            elsif ( $opt_json and not $opt_json_stream ) {
                # Don't do anything
            }
            else {
                my $prefix = q{};
                if ( $opt_time ) {
                    $prefix .= sprintf "%*.2f ", ${ field_width { seconds } }, $entry->timestamp;
                }

                if ( $opt_show_level ) {
                    $prefix .= $opt_raw ? $entry->level : translate_severity( $entry->level );
                    my $space_l10n =
                      ${ field_width { level } } - length( decode_utf8( translate_severity( $entry_level ) ) ) + 1;
                    $prefix .= ' ' x $space_l10n;
                }

                if ( $opt_show_module ) {
                    $prefix .= sprintf "%-*s ", ${ field_width { module } }, $entry->module;
                }

                if ( $opt_show_testcase ) {
                    $prefix .= sprintf "%-*s ", ${ field_width { testcase } }, $entry->testcase;
                }

                if ( $opt_raw ) {
                    $prefix .= $entry->tag;

                    my $message = $entry->argstr;
                    my @lines   = split /\n/, $message;

                    printf "%s%s %s\n", $prefix, ' ', @lines ? shift @lines : '';
                    for my $line ( @lines ) {
                        printf "%s%s %s\n", $prefix, '>', $line;
                    }
                }
                else {
                    if (    $entry_level eq q{DEBUG3}
                        and scalar( keys %{ $entry->args } ) == 1
                        and defined $entry->args->{packet} )
                    {
                        my $packet  = $entry->args->{packet};
                        my $padding = q{ } x length $prefix;
                        $entry->args->{packet} = q{};
                        printf "%s%s\n", $prefix, $translator->translate_tag( $entry );
                        foreach my $line ( split /\n/, $packet ) {
                            printf "%s%s\n", $padding, $line;
                        }
                    }
                    else {
                        printf "%s%s\n", $prefix, $translator->translate_tag( $entry );
                    }
                }
            } ## end else [ if ( $opt_json and $opt_json_stream)]
        } ## end if ( $numeric{ uc $entry_level...})
        if ( $opt_stop_level and $numeric{ uc $entry->level } >= $numeric{$opt_stop_level} ) {
            die(
                Zonemaster::Engine::Exception::NormalExit->new(
                    { message => "Saw message at level " . $entry->level }
                )
            );
        }
    };

    # Instead, hold early messages in a temporary queue and switch to the
    # actual callback when we are ready.
    my @held_messages;
    Zonemaster::Engine->logger->callback(
        sub {
            my ( $entry ) = @_;
            push @held_messages, @_;
        }
    );

    if ( @argv > 1 ) {
        say STDERR __(
            "Only one domain can be given for testing. Did you forget to prepend an option with '--<OPTION>'?" );
        return $EXIT_USAGE_ERROR;
    }
    elsif ( @argv < 1 ) {
        say STDERR __( "Must give the name of a domain to test." );
        return $EXIT_USAGE_ERROR;
    }

    my ( $domain ) = @argv;

    ( my $errors, $domain ) = normalize_name( decode( 'utf8', $domain ) );

    if ( @opt_ns ) {
        local $@;
        eval {
            check_fake_delegation( $domain, @opt_ns );
            1;
        } or do {
            print STDERR $@;
            return $EXIT_USAGE_ERROR;
        };
    }

    if ( @opt_ds ) {
        check_fake_ds( @opt_ds );
    }

    if ( scalar @$errors > 0 ) {
        my $error_message;
        foreach my $err ( @$errors ) {
            $error_message .= $err->string . "\n";
        }
        print STDERR $error_message;
        return $EXIT_USAGE_ERROR;
    }

    if ( defined $opt_hints ) {
        my $hints_data;
        my $error = undef;
        try {
            my $hints_text = read_file( $opt_hints ) // die "read_file failed\n";
            local $SIG{__WARN__} = \&die;
            $hints_data = parse_hints( $hints_text )
        }
        catch {
            $error = $_;
        };

        if ( defined $error ) {
            print STDERR __x( "Error loading hints file: {message}", message => $error );
            return $EXIT_USAGE_ERROR;
        }

        Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
        Zonemaster::Engine::Recursor->add_fake_addresses( '.', $hints_data );
    } ## end if ( defined $opt_hints)

    # This can generate early log messages.
    if ( @opt_ns ) {
        local $@;
        eval {
            add_fake_delegation( $domain, @opt_ns );
            1;
        } or do {
            print STDERR $@;
            return $EXIT_USAGE_ERROR;
        };
    }

    if ( @opt_ds ) {
        add_fake_ds( $domain, @opt_ds );
    }

    if ( not $opt_raw ) {
        $translator = Zonemaster::Engine::Translator->new;
        $translator->locale( $opt_locale )
          if $opt_locale;

        %header_names = (
            seconds  => __( 'Seconds' ),
            level    => __( 'Level' ),
            module   => __( 'Module' ),
            testcase => __( 'Testcase' ),
            message  => __( 'Message' )
        );
        foreach ( keys %header_names ) {
            $field_width{$_}     = _max( $field_width{$_}, length( decode_utf8( $header_names{$_} ) ) );
            $remaining_space{$_} = $field_width{$_} - length( decode_utf8( $header_names{$_} ) );
        }
    }

    if ( $opt_profile or @opt_test ) {
        # Separate initialization from main output in human readable output mode
        print "\n" if $fh_diag eq *STDOUT;
    }

    if ( not $opt_raw and not $opt_json ) {
        my $header = q{};

        if ( $opt_time ) {
            $header .= sprintf "%s%s ", $header_names{seconds}, " " x $remaining_space{seconds};
        }
        if ( $opt_show_level ) {
            $header .= sprintf "%s%s ", $header_names{level}, " " x $remaining_space{level};
        }
        if ( $opt_show_module ) {
            $header .= sprintf "%s%s ", $header_names{module}, " " x $remaining_space{module};
        }
        if ( $opt_show_testcase ) {
            $header .= sprintf "%s%s ", $header_names{testcase}, " " x $remaining_space{testcase};
        }
        $header .= sprintf "%s\n", $header_names{message};

        if ( $opt_time ) {
            $header .= sprintf "%s ", "=" x $field_width{seconds};
        }
        if ( $opt_show_level ) {
            $header .= sprintf "%s ", "=" x $field_width{level};
        }
        if ( $opt_show_module ) {
            $header .= sprintf "%s ", "=" x $field_width{module};
        }
        if ( $opt_show_testcase ) {
            $header .= sprintf "%s ", "=" x $field_width{testcase};
        }
        $header .= sprintf "%s\n", "=" x $field_width{message};

        print $header;
    } ## end if ( not $opt_raw and ...)

    # Now we are ready to actually print messages, including those that are
    # currently in the hold queue.
    while ( my $entry = pop @held_messages ) {
        $message_printer->( $entry );
    }
    Zonemaster::Engine->logger->callback( $message_printer );

    # Actually run tests!
    eval { Zonemaster::Engine->test_zone( $domain ); };

    if ( $@ ) {
        my $err = $@;
        if ( blessed $err and $err->isa( "Zonemaster::Engine::Exception::NormalExit" ) ) {
            say STDERR "Exited early: " . $err->message;
        }
        else {
            die $err;    # Don't know what it is, rethrow
        }
    }

    if ( not $opt_raw and not $opt_json ) {
        if ( not $printed_something ) {
            say __( "Looks OK." );
        }
    }

    my $json_output = {};

    if ( $opt_count ) {
        my %entries;
        foreach my $e ( @{ Zonemaster::Engine->logger->entries } ) {
            $entries{$e->level}{$e->tag} += 1;
        }

        if ( $opt_json ) {
            $json_output->{count} = {};
            foreach my $level ( sort { $numeric{$b} <=> $numeric{$a} } keys %counter ) {
                $json_output->{count}{by_level}{$level} = $counter{$level};
            }

            foreach my $level ( sort { $numeric{$b} <=> $numeric{$a} } keys %entries ) {
                foreach my $tag ( sort keys %{ $entries{$level} } ) {
                    $json_output->{count}{by_message_tag}{$level}{$tag} = $entries{$level}{$tag};
                }
            }
        }
        else {
            my $header1 = __( 'Level' );
            my $max1 = length $header1;
            my $header2 = __( 'Number of log entries' );
            my $max2 = length $header2;

            foreach my $level ( sort { $numeric{$b} <=> $numeric{$a} } keys %counter ) {
                my $len = length translate_severity( $level );
                $max1 = $len if $len > $max1;
            }

            printf "\n\n%${max1}s\t%${max2}s", $header1, $header2;
            printf "\n%s\t%s\n", '=' x $max1, '=' x $max2;

            foreach my $level ( sort { $numeric{$b} <=> $numeric{$a} } keys %counter ) {
                printf "%${max1}s\t%${max2}d\n", translate_severity( $level ), $counter{$level};
            }

            my $header3 = __( 'Message tag' );
            my $max3 = max map { length "$_" } ( ( map { keys %{ $_ } } ( values %entries ) ), $header3 );
            my $header4 = __( 'Count' );
            my $max4 = max map { length "$_" } ( ( map { values %{ $_ } } ( values %entries ) ), $header4 );

            printf "\n%${max1}s\t%${max3}s\t%${max4}s", $header1, $header3, $header4;
            printf "\n%${max1}s\t%${max3}s\t%${max4}s\n", '=' x $max1, '=' x $max3, '=' x $max4;
            foreach my $level ( sort { $numeric{$b} <=> $numeric{$a} } keys %entries ) {
                foreach my $tag ( sort keys %{ $entries{$level} } ) {
                    printf "%${max1}s\t%${max3}s\t%${max4}s\n", $level, $tag, $entries{$level}{$tag};
                }
            }
        }
    }

    if ( $opt_nstimes ) {
        my $zone = Zonemaster::Engine->zone( $domain );
        my %all_nss = %{ Zonemaster::Engine::Nameserver::object_cache };
        my @child_nss = @{ $zone->ns };
        my @parent_nss = @{ $zone->parent->ns };
        my @all_responded_nss;

        foreach my $ns_name ( keys %all_nss ) {
            foreach my $ns ( values %{ $all_nss{$ns_name} } ) {
                push @all_responded_nss, $ns if scalar @{ $ns->times } > 0;
            }
        }

        my %nss_filter = map { $_ => undef } ( @child_nss, @parent_nss );
        my @other_nss = grep { ! exists $nss_filter{$_} } @all_responded_nss;

        if ( $opt_json ) {
            my @times;

            my sub json_nstimes {
                my ( $ns ) = @_;
                return {
                    'ns'      => $ns->string,
                    'max'     => 1000 * $ns->max_time,
                    'min'     => 1000 * $ns->min_time,
                    'avg'     => 1000 * $ns->average_time,
                    'stddev'  => 1000 * $ns->stddev_time,
                    'median'  => 1000 * $ns->median_time,
                    'total'   => 1000 * $ns->sum_time,
                    'count'   => scalar @{ $ns->times }
                };
            }

            my %section_mapping = (
                'child' => \@child_nss,
                'parent' => \@parent_nss,
                'other' => \@other_nss
            );

            foreach my $section_name ( sort keys %section_mapping ) {
                my @entries = map { json_nstimes( $_ ) } sort @{ $section_mapping{$section_name} };
                push @times, { $section_name => \@entries };
            }

            $json_output->{nstimes} = \@times;
        }
        else {
            my $header = __( 'Name servers' );
            my $max = max map { length( "$_" ) } ( ( @child_nss, @parent_nss, @all_responded_nss ), $header );
            printf "\n%${max}s %s\n", $header, '        Max        Min        Avg     Stddev     Median       Total       Count';
            printf "%${max}s %s\n", '=' x $max, ' ========== ========== ========== ========== ========== =========== ===========';

            my $total_queries_count = 0;
            my $total_queries_times = 0;
            my %nss_already_processed;

            my sub print_nstimes {
                my ( $ns, $max, $total_queries_count, $total_queries_times, $nss_already_processed_ref ) = @_;
                my %nss_already_processed = %{ $nss_already_processed_ref };

                printf "%${max}s ",  $ns->string;
                printf "%11.2f ",    1000 * $ns->max_time;
                printf "%10.2f ",    1000 * $ns->min_time;
                printf "%10.2f ",    1000 * $ns->average_time;
                printf "%10.2f ",    1000 * $ns->stddev_time;
                printf "%10.2f ",    1000 * $ns->median_time;
                printf "%11.2f ",    1000 * $ns->sum_time;
                printf "%11d\n",     scalar @{ $ns->times };
                $total_queries_count += scalar @{ $ns->times } unless $nss_already_processed{$ns};
                $total_queries_times += ( 1000 * $ns->sum_time ) unless $nss_already_processed{$ns};

                return $total_queries_count, $total_queries_times;
            }

            my %section_mapping = (
                1 => { __( 'Child zone' ) => \@child_nss },
                2 => { __( 'Parent zone' ) => \@parent_nss },
                3 => { __( 'Other' ) => \@other_nss }
            );

            foreach my $section_order ( sort keys %section_mapping ) {
                foreach my $section_header ( keys % { $section_mapping{$section_order} } ) {
                    printf "%s %s\n", $section_header, '-' x ( ( $max - length $section_header ) - 1 );

                    foreach my $section_nss ( sort @{ $section_mapping{$section_order}{$section_header} } ) {
                        ( $total_queries_count, $total_queries_times ) =
                            print_nstimes( $section_nss, $max, $total_queries_count, $total_queries_times, \%nss_already_processed );
                        $nss_already_processed{$section_nss} = 1;
                    }
                }
            }

            printf "%${max}s %s\n", '=' x $max, ' ========== ========== ========== ========== ========== =========== ===========';
            printf "%${max}s %67.2f %11s\n", __( 'Grand total' ), $total_queries_times, $total_queries_count;
        }
    } ## end if ( $opt_nstimes )

    if ( $opt_elapsed ) {
        my $last = Zonemaster::Engine->logger->entries->[-1];

        if ( $opt_json ) {
            $json_output->{elapsed} = $last->timestamp;
        }
        else {
            printf "\nTotal test run time: %0.1f seconds.\n", $last->timestamp;
        }
    }

    if ( $opt_json and not $opt_json_stream ) {
        my $res = Zonemaster::Engine->logger->json( $opt_level );
        $res = $JSON->decode( $res );
        foreach ( @$res ) {
            unless ( $opt_raw ) {
                my %e     = %$_;
                my $entry = Zonemaster::Engine::Logger::Entry->new( \%e );
                $_->{message} = $translator->translate_tag( $entry );
            }
            delete $_->{timestamp} unless $opt_time;
            delete $_->{level}     unless $opt_show_level;
            delete $_->{module}    unless $opt_show_module;
            delete $_->{testcase}  unless $opt_show_testcase;
        }
        $json_output->{results} = $res;
    }

    if ( scalar keys %$json_output ) {
        say $JSON->encode( $json_output );
    }

    if ( $opt_save ) {
        Zonemaster::Engine->save_cache( $opt_save );
    }

    return $EXIT_SUCCESS;
} ## end sub run

sub check_fake_delegation {
    my ( $domain, @ns ) = @_;

    foreach my $pair ( @ns ) {
        my ( $name, $ip ) = split( '/', $pair, 2 );

        if ( $pair =~ tr/\/// > 1 or not $name ) {
            die __( "--ns must be a name or a name/ip pair." ) . "\n";
        }

        ( my $errors, $name ) = normalize_name( decode( 'utf8', $name ) );

        if ( scalar @$errors > 0 ) {
            my $error_message = "Invalid name in --ns argument:\n";
            foreach my $err ( @$errors ) {
                $error_message .= "\t" . $err->string . "\n";
            }
            die $error_message;
        }

        if ( $ip ) {
            my $net_ip = Net::IP::XS->new( $ip );
            unless ( validate_ipv4( $ip ) or validate_ipv6( $ip ) ) {
                die Net::IP::XS::Error()
                  ? "Invalid IP address in --ns argument:\n\t" . Net::IP::XS::Error() . "\n"
                  : "Invalid IP address in --ns argument.\n";
            }
        }
    } ## end foreach my $pair ( @ns )

    return;
} ## end sub check_fake_delegation

sub check_fake_ds {
    my ( @ds ) = @_;

    foreach my $str ( @ds ) {
        unless ( $str =~ /$DS_RE/ ) {
            say STDERR __(
"--ds ds data must be in the form \"keytag,algorithm,type,digest\". E.g. space is not permitted anywhere in the string."
            );
            exit( 1 );
        }
    }

    return;
}

sub add_fake_delegation {
    my ( $domain, @ns ) = @_;
    my @ns_with_no_ip;
    my %data;

    foreach my $pair ( @ns ) {
        my ( $name, $ip ) = split( '/', $pair, 2 );

        ( my $errors, $name ) = normalize_name( decode( 'utf8', $name ) );

        if ( $ip ) {
            push @{ $data{$name} }, $ip;
        }
        else {
            push @ns_with_no_ip, $name;
        }
    }

    foreach my $ns ( @ns_with_no_ip ) {
        if ( not exists $data{$ns} ) {
            $data{$ns} = undef;
        }
    }

    return Zonemaster::Engine->add_fake_delegation( $domain => \%data );

} ## end sub add_fake_delegation

sub add_fake_ds {
    my ( $domain, @ds ) = @_;
    my @data;

    foreach my $str ( @ds ) {
        my ( $tag, $algo, $type, $digest ) = split( /,/, $str );
        push @data, { keytag => $tag, algorithm => $algo, type => $type, digest => $digest };
    }

    Zonemaster::Engine->add_fake_ds( $domain => \@data );

    return;
}

sub print_versions {
    say 'Zonemaster-CLI version ' . __PACKAGE__->VERSION;
    say 'Zonemaster-Engine version ' . $Zonemaster::Engine::VERSION;
    say 'Zonemaster-LDNS version ' . $Zonemaster::LDNS::VERSION;
    say 'NL NetLabs LDNS version ' . Zonemaster::LDNS::lib_version();

    return;
}

my @spinner_strings = ( '  | ', '  / ', '  - ', '  \\ ' );

sub print_spinner {
    state $counter   = 0;
    state $last_spin = [ 0, 0 ];

    my $time = [ Time::HiRes::gettimeofday() ];
    if ( Time::HiRes::tv_interval( $last_spin, $time ) > 0.1 ) {
        $last_spin = $time;
        printf "%s\r", $spinner_strings[ $counter++ % 4 ];
    }
}

sub print_test_list {
    my %methods = Zonemaster::Engine->all_methods;
    my $maxlen  = max map {
        map { length( $_ ) }
          @$_
    } values %methods;

    foreach my $module ( sort keys %methods ) {
        say $module;
        foreach my $method ( sort @{ $methods{$module} } ) {
            printf "  %${maxlen}s\n", $method;
        }
        print "\n";
    }

    return;
}

sub do_dump_profile {
    my $json = JSON::XS->new->canonical->pretty;

    print $json->encode( Zonemaster::Engine::Profile->effective->{q{profile}} );

    return;
}

sub translate_severity {
    my $severity = shift;
    if ( $severity eq "DEBUG" ) {
        return __( "DEBUG" );
    }
    elsif ( $severity eq "INFO" ) {
        return __( "INFO" );
    }
    elsif ( $severity eq "NOTICE" ) {
        return __( "NOTICE" );
    }
    elsif ( $severity eq "WARNING" ) {
        return __( "WARNING" );
    }
    elsif ( $severity eq "ERROR" ) {
        return __( "ERROR" );
    }
    elsif ( $severity eq "CRITICAL" ) {
        return __( "CRITICAL" );
    }
    else {
        return $severity;
    }
} ## end sub translate_severity

sub _max {
    my ( $a, $b ) = @_;
    $a //= 0;
    $b //= 0;
    return ( $a > $b ? $a : $b );
}

1;

__END__
=pod

=encoding UTF-8

=head1 NAME

Zonemaster::CLI - run Zonemaster tests from the command line

=head1 AUTHORS

Vincent Levigneron <vincent.levigneron at nic.fr>
- Current maintainer

Calle Dybedahl <calle at init.se>
- Original author

=head1 LICENSE

This is free software under a 2-clause BSD license. The full text of the license can
be found in the F<LICENSE> file included with this distribution.

=cut
