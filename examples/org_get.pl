#!/usr/bin/perl

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.1 $' )[1];

my ( $username, $password, $hostname);
my $orgname = 'System';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $orgname and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname );
$vcd->config( debug => 1 ); # Turn debug text on.

my $login_info = $vcd->login; # Login

my $random_org = ( keys %$login_info )[0];
my $org_url = $login_info->{$random_org}->{href};
print "Selected random ORG of: $random_org\n";
print "Selected ORG's URL: $org_url\n";

my $org_info = $vcd->org_get($org_url);

print Dumper($org_info);