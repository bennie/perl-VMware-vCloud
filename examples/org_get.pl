#!/usr/bin/perl -I../lib
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

my $version = ( split ' ', '$Revision: 1.3 $' )[1];

my ( $username, $password, $hostname);
my $orgname = 'System';

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $orgname and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 1 });

my $login_info = $vcd->login;

my $random_orgid = ( keys %$login_info )[0];

print "\nSelected random ORG of: \"$login_info->{$random_orgid}\" ($random_orgid)\n\n";

my %org = $vcd->get_org($random_orgid);

print "\n", Dumper(\%org);