#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# Test loading the main modules
use_ok('IO::K8s');
use_ok('IO::K8s::Resource');
use_ok('IO::K8s::Types');

# Test loading some representative classes
use_ok('IO::K8s::Api::Core::V1::Pod');
use_ok('IO::K8s::Api::Core::V1::Service');
use_ok('IO::K8s::Api::Core::V1::Container');
use_ok('IO::K8s::Api::Apps::V1::Deployment');
use_ok('IO::K8s::Api::Apps::V1::ReplicaSet');
use_ok('IO::K8s::Api::Batch::V1::Job');
use_ok('IO::K8s::Apimachinery::Pkg::Apis::Meta::V1::ObjectMeta');

done_testing;
