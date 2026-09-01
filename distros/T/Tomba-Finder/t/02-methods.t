#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Tomba::Client;
use Tomba::Finder;
use Tomba::Account;
use Tomba::Domain;
use Tomba::Verifier;
use Tomba::Phone;
use Tomba::Count;
use Tomba::Status;
use Tomba::Sources;
use Tomba::Format;
use Tomba::Similar;
use Tomba::Technology;
use Tomba::Location;
use Tomba::Enrichment;
use Tomba::Reveal;
use Tomba::Keys;
use Tomba::Usage;
use Tomba::Logs;
use Tomba::Flag;
use Tomba::Leads;
use Tomba::LeadsList;
use Tomba::LeadsAttributes;
use Tomba::Bulk;

# Verify Tomba::Client HTTP methods
my @client_methods = qw(new call post put delete_request _request);
for my $method (@client_methods) {
    ok(Tomba::Client->can($method), "Tomba::Client method $method exists");
}

# Verify individual service module methods
my %module_methods = (
    'Tomba::Account'          => [qw(Account)],
    'Tomba::Domain'           => [qw(DomainSearch)],
    'Tomba::Verifier'         => [qw(EmailVerifier)],
    'Tomba::Phone'            => [qw(PhoneFinder PhoneValidator)],
    'Tomba::Count'            => [qw(Count)],
    'Tomba::Status'           => [qw(Status Autocomplete)],
    'Tomba::Sources'          => [qw(EmailSources)],
    'Tomba::Format'           => [qw(EmailFormat)],
    'Tomba::Similar'          => [qw(Similar)],
    'Tomba::Technology'       => [qw(Technology)],
    'Tomba::Location'         => [qw(GetLocation)],
    'Tomba::Enrichment'       => [qw(PersonFind CompanyFind CombinedFind)],
    'Tomba::Reveal'           => [qw(CompaniesSearch)],
    'Tomba::Keys'             => [qw(ListKeys GetKey CreateKey ResetKey DeleteKey)],
    'Tomba::Usage'            => [qw(Usage)],
    'Tomba::Logs'             => [qw(Logs)],
    'Tomba::Flag'             => [qw(ListFlags CreateFlag)],
    'Tomba::Leads'            => [qw(ListLeads GetLead CreateLead UpdateLead DeleteLead)],
    'Tomba::LeadsList'        => [qw(ListLeadsLists GetLeadsList CreateLeadsList UpdateLeadsList DeleteLeadsList)],
    'Tomba::LeadsAttributes'  => [qw(ListAttributes GetAttribute CreateAttribute UpdateAttribute DeleteAttribute)],
    'Tomba::Bulk'             => [qw(ListBulks GetBulk LaunchBulk DeleteBulk ArchiveBulk RenameBulk BulkProgress BulkDownload)],
);

for my $module (sort keys %module_methods) {
    for my $method (@{$module_methods{$module}}) {
        ok($module->can($method), "$module method $method exists");
    }
}

# Verify backward compatibility: all methods still accessible on Tomba::Finder
my @finder_methods = qw(
    new call post put delete_request
    Account DomainSearch Count Status Autocomplete
    EmailFinder Enrichment AuthorFinder LinkedinFinder
    EmailVerifier EmailSources
    PhoneFinder PhoneValidator
    EmailFormat GetLocation Similar Technology
    PersonFind CompanyFind CombinedFind CompaniesSearch
    Usage Logs
    ListKeys GetKey CreateKey ResetKey DeleteKey
    ListFlags CreateFlag
    ListLeads GetLead CreateLead UpdateLead DeleteLead
    ListLeadsLists GetLeadsList CreateLeadsList UpdateLeadsList DeleteLeadsList
    ListAttributes GetAttribute CreateAttribute UpdateAttribute DeleteAttribute
    ListBulks GetBulk LaunchBulk DeleteBulk ArchiveBulk RenameBulk BulkProgress BulkDownload
);

for my $method (@finder_methods) {
    ok(Tomba::Finder->can($method), "Tomba::Finder backward-compat method $method exists");
}

done_testing();
