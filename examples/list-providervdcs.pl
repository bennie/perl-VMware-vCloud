#!/usr/bin/perl -I../lib
=head1 list-templates.pl

This example script uses the API to list all Templates that the user has 
ability to access.

=head2 Usage

  ./list-templates.pl --username USER --password PASS --orgname ORG --hostname HOST
  
Orgname is optional. It will default to "System" if not given. 

=cut

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.1 $' )[1];

my ( $username, $password, $hostname, $orgname );

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 1 } );

my $pvdcs = $vcd->{api}->pvdcs_list();

print "\n", Dumper($pvdcs);
