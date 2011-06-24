#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.2 $' )[1];

my ( $username, $password, $hostname);
my $orgname = 'System';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $orgname and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname );

$vcd->config( debug => 1 ); # Turn debug text on.

my $login = $vcd->login; # Login