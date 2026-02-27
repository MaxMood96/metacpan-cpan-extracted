#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

BEGIN {
    eval "use Test::Spelling";
    if ($@) {
        plan skip_all => "Test::Spelling required for testing POD spelling";
    }
}

unless ($ENV{AUTHOR_TESTING}) {
    plan skip_all => "Spelling test only runs under AUTHOR_TESTING";
}

use Test::Spelling qw(
    set_spell_cmd
    add_stopwords
    all_pod_files_spelling_ok
    all_pod_files
);

set_spell_cmd('aspell list -d en_GB');

my @STOPWORDS = qw(
    Anwar
    CPAN
    DBIC
    DBIx
    API
    APIs
    ResultSet
    ResultSets
    ResultSource
    ResultSources
    async
    prefetch
    prefetched
    Prefetching
    deflate
    inflate
    inflators
    JOINs
    SQLite
    metadata
    resultset
    resultsets
    github
    manwar
    Mohammad
    Sajid
    cpan
    perldoc
    MetaCPAN
    MERCHANTABILITY
    ACKNOWLEDGEMENTS
    autodeploy
    deadlock
    deserialisation
    serialisation
    serialiisable
    Sanitisation
    customisation
    txn
    undef
    startup
    timestamp
    backend
    hashref
    hashrefs
    arrayref
    arrayrefs
    ENV
    PID
    readonly
    username
    workflow
    workflows
    deduplication
    deduplicated
    deduplicating
    stringification
    debugobj
    debugfh
    DBH
    dbh
    InactiveDestroy
    instantiation
    schemas
    Atomicity
    atomicity
    POPO
    Chainability
    Chainable
    backoff
    TTL
    IPC
    UI
    TOCTOU
    LIFECYCLE
    Lifecycle
    Signup
    KQueue
    Epoll
    Mojo
    Mojolicious
    MOJOLICIOUS
    mst
    licensable
    tradename
    un
    stdout
    stderr
    TODO
    DBI
    Recurse
    txn_do
    txn_batch
    MyDebugger
    sql
    filehandle
    multiprocess
    attrs
    foreach
    cond
    DateTime
    Gmail
    Namespace
    math
    accessor
    HashRefInflator
    Postgres
    UUID
    cache_ttl
    jdoe
    CURTIME
    signaling
    asyncawait
    alice
    anyevent
    cpanratings
    cpu
    dbd
    dbname
    dsn
    http
    https
    json
    msg
    myapp
    mysql
    perl
    perlfoundation
    www
    aren
    cartesian
    coderefs
    proxied
    serializer
    storable
    subclasses
    bool
    coderef
    destructor
    lookups
    pre
    authtoken
    curtime
    desc
    dev
    func
    gemini
    ilike
    iso
    memcached
    nullp
    pos
    resultclass
    userlog
    iter
    args
    behavior
    ithreads
    async_loop
    create_async_db
    filehandles
    txn_begin
    txn_commit
    txn_rollback
    serializer_class
    search_with_prefetch
    async_db
    ResultSetColumn
    accessors
    related_resultset
    _build_relationship_accessor
    _ensure_accessors
    _pos
    ASYNC_TRACE
    _async_db
    _attrs
    _is_prefetched
    _custom_inflators
    attr
    IO
    Future
    AsyncAwait
    Statistics
    Cursor
    Pager
    Schema
    Row
    Storage
    Function
    subselect
    subquery
    sprintf
    rethrow
    stacktrace
    elsif
    stringify
    stringifies
    opdate
    sigil
    cnt
    ident
);

add_stopwords(@STOPWORDS);

sub get_stopwords_list {
    no strict 'refs';
    # Try different possible variable names
    if (@Test::Spelling::Stopwords) {
        return @Test::Spelling::Stopwords;
    } elsif (@Test::Spelling::stopwords) {
        return @Test::Spelling::stopwords;
    } else {
        # Fallback to our list
        return @STOPWORDS;
    }
}

sub clean_word {
    my ($word) = @_;

    # Remove common punctuation from start and end
    $word =~ s/^["'\(\[]+//;
    $word =~ s/["'\),\].!?:;]+$//;

    # REJECT if it contains ANY special characters (module separators, etc)
    return undef if $word =~ /[:\/\\&@#\$%^*=+<>|{}\[\]`~]/;

    # REJECT if it contains numbers
    return undef if $word =~ /\d/;

    # REJECT if it's all uppercase (acronyms) and longer than 2 chars
    return undef if $word =~ /^[A-Z]+$/ && length($word) > 2;

    # REJECT if it contains an apostrophe (like ResultSet's) - these are possessives
    return undef if $word =~ /'/;

    # REJECT if it looks like a method call or code
    return undef if $word =~ /\(/ || $word =~ /\)/;

    # REJECT if it's too short
    return undef if length($word) < 3;

    # REJECT if it contains underscores (Perl variables)
    return undef if $word =~ /_/;

    # REJECT if it contains hyphens (unless it's a common compound word)
    # But for now, reject them to be safe
    return undef if $word =~ /-/;

    # REJECT if it's mixed case with capitals inside (like camelCase)
    return undef if $word =~ /[a-z][A-Z]/;

    # Accept only if it's a simple word with lowercase letters (or first letter capital)
    return undef unless $word =~ /^[A-Z]?[a-z]+$/;

    return $word;
}

no warnings 'redefine';

sub Test::Spelling::pod_file_spelling_ok {
    my ($file, $verbose) = @_;

    # Extract POD as text using pod2text directly
    my $text = `pod2text "$file" 2>/dev/null`;
    my @words = split(/\s+/, $text);

    # Create a mapping of words to their line numbers by parsing the source file
    my %word_lines;
    my $line_num = 0;
    my $in_pod = 0;

    open my $fh, '<', $file or die "Cannot open $file: $!";
    while (<$fh>) {
        $line_num++;
        chomp;

        # Track POD sections
        if (/^\=cut/) {
            $in_pod = 0;
            next;
        }
        if (/^\=head/ || /^\=item/ || /^\=over/ || /^\=back/ || /^\=for/ || /^\=begin/ || /^\=end/) {
            $in_pod = 1;
        }

        # Always check lines that start with POD commands
        if (/^\=/) {
            $in_pod = 1;
        }

        # Check lines in POD sections
        if ($in_pod) {
            my $line = $_;

            # Remove POD commands themselves
            $line =~ s/^\=\w+\s*//;

            # Remove POD formatting
            $line =~ s/[A-Z]+<([^>]+)>/$1/g;  # Remove all X<> formatting
            $line =~ s/[=:]//g;               # Remove remaining POD markers
            $line =~ s/[{}]//g;               # Remove braces

            # Extract simple words (letters only, no apostrophes)
            while ($line =~ /\b([A-Za-z][A-Za-z][A-Za-z]+)\b/g) {
                my $word = lc $1;
                push @{$word_lines{$word}}, $line_num;
            }
        }
    }
    close $fh;

    # Get stopwords
    my @stopwords_list = get_stopwords_list();
    my %stopwords = map { lc($_) => 1 } @stopwords_list;

    # Check each unique word
    my %seen;
    my @errors;

    foreach my $word (@words) {
        my $clean_word = clean_word($word);
        next unless defined $clean_word;

        my $lcword = lc $clean_word;
        next if $stopwords{$lcword};
        next if $seen{$lcword}++;

        # Check with aspell
        my $temp_file = "/tmp/spell_check_$$.txt";
        open my $out, '>', $temp_file or next;
        print $out $clean_word;
        close $out;

        my $result = `cat "$temp_file" | aspell list -d en_GB 2>/dev/null`;
        unlink $temp_file;

        chomp $result;

        if ($result) {
            my $line_ref = $word_lines{$lcword};
            if ($line_ref && @$line_ref) {
                my $line_nums = join(',', @$line_ref);
                my $plural = @$line_ref > 1 ? "s" : "";
                push @errors, "$clean_word (line$plural $line_nums)";
            } else {
                push @errors, "$clean_word (line unknown)";
            }
        }
    }

    if (@errors) {
        my $error_list = join("\n#     ", @errors);
        fail("POD spelling for $file");
        diag("Misspelled words:\n#     $error_list");
        return 0;
    } else {
        pass("POD spelling for $file");
        return 1;
    }
}

all_pod_files_spelling_ok();
