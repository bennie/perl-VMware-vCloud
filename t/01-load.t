use strict;
use Test;

# Test a basic use statement

BEGIN { plan tests => 2 };
use VMware::vCloud;
ok(1);

# Check for connection info to run additonal tests

our %env;

my $skip_tests = 1;

if ( $ENV{VCLOUD_HOST} && $ENV{VCLOUD_USER} && $ENV{VCLOUD_PASS} ) {
  $skip_tests = 0;
}

my $host = $ENV{VCLOUD_HOST};
my $user = $ENV{VCLOUD_USER};
my $pass = $ENV{VCLOUD_PASS};
my $org  = $ENV{VCLOUD_ORG} || 'System';

unless ( $host ) {
  print STDERR "\n\nNo host connection info found. Skipping additional tests.\n\nSet environment variables VCLOUD_HOST, VCLOUD_USER, VCLOUD_PASS, VCLOUD_ORG\nto run full test suite.\n\n";
}

# Test loading the module

if ( $skip_tests ) {
  skip(1);
} else {
  my $vcd = new VMware::vCloud ( $host, $user, $pass, $org );
  ok(defined $vcd);
}
