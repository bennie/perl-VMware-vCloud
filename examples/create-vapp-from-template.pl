#!/usr/bin/perl -I../lib
=head1 create-vapp-from-template.pl

This example script uses the API to compose a template to a vApp

=head2 Usage

  ./create-vapp-from-template.pl --username USER --password PASS --orgname ORG --hostname HOST
  
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

# Select an Org

my %orgs = $vcd->list_orgs();
my $orgid = &select_one("Select the Org you wish to create a vApp in:",\%orgs);

# Select a VDC

my %vdcs = $vcd->list_vdcs($orgid);
my $vdcid = &select_one("Select the Virtual Data Center you wish to create a vApp in:",\%vdcs);

# Select a template

my %templates = $vcd->list_templates();
my $templateid = &select_one("Select the Template you wish to put in your vApp:",\%templates);

# Select network

my %networks = $vcd->list_networks($vdcid);
my $networkid = &select_one("Select the Network you wish the template to use in:",\%networks);

print "$networks{$networkid}\n";

# Build the vApp

my $name = 'Example vApp';

my $ret = $vcd->create_vapp_from_template($name,$vdcid,$templateid,$networkid);

print Dumper($ret);

#### Subroutines

# This subroutine quickly handles user input to select items from a hash

sub select_one {
  my $message = shift @_;
  
  my %items = %{shift @_};
  my @items = sort { lc($items{$a}) cmp lc($items{$b}) } keys %items; # Put the names in alpha order

  my $line = '='x80;
  my $i = 1;

  print "$line\n\n$message\n";

  for my $item (@items) {
    print "   $i. \"$items{$item}\"\n";
    $i++;
  }

  print "\n$line\n";

  my $id = <STDIN>;
  chomp $id;
  $id -= 1;

  return $items[$id];
}