#!/usr/bin/perl -I../lib
=head1 compose-vapp.pl

This example script uses the API to compose a template to a vApp

=head2 Usage

  ./poweron-vapp.pl --username USER --password PASS --orgname ORG --hostname HOST
  
Orgname is optional. It will default to "System" if not given. 

=cut

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.2 $' )[1];

my ( $username, $password, $hostname, $orgname );

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 1 } );

# Select a template

my %templates = $vcd->list_templates();
my @templates = sort { lc($templates{$a}) cmp lc($templates{$b}) } keys %templates; # Put the names in alpha order

my $line = '='x80;
my $i = 1;

print "$line\n\nSelect a Template to compose:\n";

for my $template (@templates) {
  print "   $i. \"$templates{$template}\"\n";
  $i++;
}

print "\n$line\n";

my $id = <STDIN>;
chomp $id;
$id -= 1;

my $templateid = $templates[$id];
print "\nGoing to try compose $templates{$templateid}.\n";
print "\n$line\n";

# Select a VDC

my %vdcs = $vcd->list_vdcs();
my @vdcs = sort { lc($vdcs{$a}) cmp lc($vdcs{$b}) } keys %vdcs; # Put the names in alpha order

$i = 1;

print "$line\n\nSelect a VDC to compose it too:\n";

for my $vdc (@vdcs) {
  print "   $i. \"$vdcs{$vdc}\"\n";
  $i++;
}

print "\n$line\n";

$id = <STDIN>;
chomp $id;
$id -= 1;

my $vdcid = $vdcs[$id];
print "\nGoing to try compsing $vdcs{$vdcid}.\n";
print "\n$line\n";

# Get the relevant info

my %template = $vcd->get_template($templateid);
my %vdc = $vcd->get_vdc($vdcid);

my @links = @{$vdc{Link}};
my $url;

for my $ref (@links) {
  $url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.composeVAppParams+xml';
}

# XML to build

my $xml = '<ComposeVAppParams name="Example Corps CRM Appliance" xmlns="http://www.vmware.com/vcloud/v1" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1">
  <InstantiationParams>
    <NetworkConfigSection>
      <ovf:Info>Configuration parameters for logical networks</ovf:Info>
      <NetworkConfig networkName="CRMApplianceNetwork">
        <Configuration>
          <ParentNetwork href="http://vcloud.example.com/api/v1.0/network/54"/> 
          <FenceMode>bridged</FenceMode>
        </Configuration>
      </NetworkConfig>
    </NetworkConfigSection>
  </InstantiationParams>
  <Item>
    <Source href="http://vcloud.example.com/api/v1.0/vApp/vm-4"/>
    <InstantiationParams>
      <NetworkConnectionSection
        type="application/vnd.vmware.vcloud.networkConnectionSection+xml"
        href="http://vcloud.example.com/api/v1.0/vApp/vm-4/
        networkConnectionSection/" ovf:required="false">
        <ovf:Info/>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="CRMApplianceNetwork">
          <NetworkConnectionIndex>0</NetworkConnectionIndex>
          <IsConnected>true</IsConnected>
          <IpAddressAllocationMode>DHCP</IpAddressAllocationMode>
        </NetworkConnection>
      </NetworkConnectionSection>
    </InstantiationParams>
  </Item>
  <Item>
    <Source href="http://vcloud.example.com/api/v1.0/vAppTemplate/vappTemplate-114"/>
  </Item>
  <Item>
    <Source href="http://vcloud.example.com/api/v1.0/vAppTemplate/vappTemplate-190"/>
  </Item>
  <AllEULAsAccepted>true</AllEULAsAccepted>
</ComposeVAppParams>';

$xml = '<ComposeVAppParams name="Example Corps CRM Appliance" xmlns="http://www.vmware.com/vcloud/v1" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1">
</ComposeVAppParams>';

my $ret = $vcd->{api}->post($url,$xml);

print Dumper($ret);