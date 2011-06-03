# Pragmas.
use strict;
use warnings;

# Modules.
use Test::More 'tests' => 2;

BEGIN {

	# Test.
	use_ok('CVS::Metrics::Parser');
}

# Test.
require_ok('CVS::Metrics::Parser');
