# Pragmas.
use strict;
use warnings;

# Modules.
use CVS::Metrics::Parser;
use Test::More 'tests' => 2;

# Test.
my $obj = new_ok('CVS::Metrics::Parser');

# Test.
$obj = $obj->new;
isa_ok($obj, 'CVS::Metrics::Parser');
