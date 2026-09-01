#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Tomba::Finder;
use Tomba::Account;
use Tomba::Usage;
use Tomba::Domain;
use Tomba::Count;
use Tomba::Status;
use Tomba::Verifier;

SKIP: {
    skip 'No API credentials set (TOMBA_API_KEY / TOMBA_SECRET_KEY)', 8
        unless $ENV{TOMBA_API_KEY} && $ENV{TOMBA_SECRET_KEY};

    # Test via Tomba::Finder facade (backward compatibility)
    my $tomba = Tomba::Finder->new($ENV{TOMBA_API_KEY}, $ENV{TOMBA_SECRET_KEY});

    # Account
    my $account = $tomba->Account();
    ok(defined $account, 'Finder->Account() returns data');

    # Usage
    my $usage = $tomba->Usage();
    ok(defined $usage, 'Finder->Usage() returns data');

    # Domain Search
    my $search = $tomba->DomainSearch("tomba.io");
    ok(defined $search, 'Finder->DomainSearch() returns data');

    # Email Count
    my $count = $tomba->Count("tomba.io");
    ok(defined $count, 'Finder->Count() returns data');

    # Domain Status
    my $status = $tomba->Status("gmail.com");
    ok(defined $status, 'Finder->Status() returns data');

    # Autocomplete
    my $autocomplete = $tomba->Autocomplete("googl");
    ok(defined $autocomplete, 'Finder->Autocomplete() returns data');

    # Email Finder
    my $finder = $tomba->EmailFinder("asana.com", "Dustin", "Moskovitz");
    ok(defined $finder, 'Finder->EmailFinder() returns data');

    # Email Verifier
    my $verifier = $tomba->EmailVerifier("b.mohamed\@tomba.io");
    ok(defined $verifier, 'Finder->EmailVerifier() returns data');
}

SKIP: {
    skip 'No API credentials set (TOMBA_API_KEY / TOMBA_SECRET_KEY)', 4
        unless $ENV{TOMBA_API_KEY} && $ENV{TOMBA_SECRET_KEY};

    # Test via individual service modules
    my $acct_svc = Tomba::Account->new($ENV{TOMBA_API_KEY}, $ENV{TOMBA_SECRET_KEY});
    my $acct = $acct_svc->Account();
    ok(defined $acct, 'Account->Account() returns data');

    my $usage_svc = Tomba::Usage->new($ENV{TOMBA_API_KEY}, $ENV{TOMBA_SECRET_KEY});
    my $usg = $usage_svc->Usage();
    ok(defined $usg, 'Usage->Usage() returns data');

    my $domain_svc = Tomba::Domain->new($ENV{TOMBA_API_KEY}, $ENV{TOMBA_SECRET_KEY});
    my $dsearch = $domain_svc->DomainSearch("tomba.io");
    ok(defined $dsearch, 'Domain->DomainSearch() returns data');

    my $status_svc = Tomba::Status->new($ENV{TOMBA_API_KEY}, $ENV{TOMBA_SECRET_KEY});
    my $st = $status_svc->Status("gmail.com");
    ok(defined $st, 'Status->Status() returns data');
}

done_testing();
