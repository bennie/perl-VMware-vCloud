#!/usr/bin/perl -I../lib
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

my $version = ( split ' ', '$Revision: 1.6 $' )[1];
my ( $username, $password, $hostname, $orgname);

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $hostname;

my $vcd = new VMware::vCloud( $hostname, $username, $password, $orgname, { debug => 1 } );

my $login_info = $vcd->login; # Login

print "\n", Dumper($login_info);
