#!/usr/bin/perl
=head1 login.pl

This example script shows how to successfully log into VCD via the API.

=head2 Usage

  ./login.pl --username USER --password PASS --orgname ORG --hostname HOST
  
Orgname is optional. It will default to "System" if not given.

=cut

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.4 $' )[1];

my ( $username, $password, $hostname);
my $orgname = 'System';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $orgname and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname );

$vcd->config( debug => 1 ); # Turn debug text on.

my $login_info = $vcd->login; # Login

print Dumper($login_info);