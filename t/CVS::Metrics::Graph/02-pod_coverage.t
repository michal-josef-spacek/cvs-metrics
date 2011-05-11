# Pragmas.
use strict;
use warnings;

# Modules.
use Test::Pod::Coverage 'tests' => 1;

# Test.
pod_coverage_ok('CVS::Metrics::Graph', 'CVS::Metrics::Graph is covered.');
