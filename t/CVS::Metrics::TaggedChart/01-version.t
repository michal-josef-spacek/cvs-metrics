# Pragmas.
use strict;
use warnings;

# Modules.
use CVS::Metrics::TaggedChart;
use Test::More 'tests' => 1;

# Test.
is($CVS::Metrics::TaggedChart::VERSION, '0.18', 'Version.');
