# Pragmas.
use strict;
use warnings;

# Modules.
use CVS::Metrics;
use Test::More 'tests' => 1;

# Test.
is($CVS::Metrics::VERSION, '0.19', 'Version.');
