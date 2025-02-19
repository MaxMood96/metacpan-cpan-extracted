#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use Metrics::Any::Adapter;

# Basic parsing
{
   is(
      [ Metrics::Any::Adapter->split_type_string( "Type" ) ],
      [ "Type" ],
      'Type string with no args' );

   is(
      [ Metrics::Any::Adapter->split_type_string( "List:1,2" ) ],
      [ "List", "1", "2" ],
      'Type string with list args' );

   is(
      [ Metrics::Any::Adapter->split_type_string( "Map:one=1,two=2" ) ],
      [ "Map", one => "1", two => "2" ],
      'Type string with name=value args' );
}

# Nesting-aware parsing
{
   is(
      [ Metrics::Any::Adapter->split_type_string( "Type:[value:goes,here]" ) ],
      [ "Type", "value:goes,here" ],
      'Type string with [nested part]' );
}

done_testing;
