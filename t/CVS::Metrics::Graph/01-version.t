# Pragmas.
use strict;
use warnings;

# Modules.
use CVS::Metrics::Graph;
use Test::More 'tests' => 1;

# Test.
is($CVS::Metrics::Graph::VERSION, 0.19, 'Version.');
