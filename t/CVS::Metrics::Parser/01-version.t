# Pragmas.
use strict;
use warnings;

# Modules.
use CVS::Metrics::Parser;
use Test::More 'tests' => 1;

# Test.
is($CVS::Metrics::Parser::VERSION, 0.19, 'Version.');
