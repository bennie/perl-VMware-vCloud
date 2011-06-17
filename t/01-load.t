use strict;
use Test;

# Test a basic use statement

BEGIN { plan tests => 2 };
use VMware::vCloud;
ok(1);

# Test loading the module

my $vcd = new VMware::vCloud (
  qw/localhost username password orgname/
);

ok(defined $vcd);
