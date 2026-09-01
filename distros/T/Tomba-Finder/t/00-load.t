#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

my @modules = qw(
    Tomba::Client
    Tomba::Finder
    Tomba::Account
    Tomba::Domain
    Tomba::Verifier
    Tomba::Phone
    Tomba::Count
    Tomba::Status
    Tomba::Sources
    Tomba::Format
    Tomba::Similar
    Tomba::Technology
    Tomba::Location
    Tomba::Enrichment
    Tomba::Reveal
    Tomba::Keys
    Tomba::Usage
    Tomba::Logs
    Tomba::Flag
    Tomba::Leads
    Tomba::LeadsList
    Tomba::LeadsAttributes
    Tomba::Bulk
);

for my $module (@modules) {
    use_ok($module) || BAIL_OUT("Cannot load $module");
}

diag("Testing Tomba::Finder $Tomba::Finder::VERSION");
ok(defined $Tomba::Finder::VERSION, 'Tomba::Finder VERSION is defined');

diag("Testing Tomba::Client $Tomba::Client::VERSION");
ok(defined $Tomba::Client::VERSION, 'Tomba::Client VERSION is defined');

# Verify service modules inherit from Tomba::Client
for my $module (@modules[2..$#modules]) {
    ok($module->isa('Tomba::Client'), "$module inherits from Tomba::Client");
}

# Verify Tomba::Finder inherits from Tomba::Client
ok(Tomba::Finder->isa('Tomba::Client'), 'Tomba::Finder inherits from Tomba::Client');

done_testing();
