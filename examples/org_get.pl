#!/usr/bin/perl
=head1 org_get.pl

This example script shows how to successfully retrieve data on a specific
organization from VCD via the API.

=head2 Usage

  ./org_get.pl --username USER --password PASS --orgname ORG --hostname HOST
  
Orgname is optional. It will default to "System" if not given. 

Information on a random organization that the user has access to will be 
returned.

=cut

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

my $login_info = $vcd->login; # Login

my $random_org = ( keys %$login_info )[0];
my $org_url = $login_info->{$random_org}->{href};
print "Selected random ORG of: $random_org\n";
print "Selected ORG's URL: $org_url\n";

my $org_info = $vcd->org_get($org_url);

print Dumper($org_info);