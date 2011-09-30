#!/usr/bin/perl -I../lib
=head1 list-vms.pl

This example script uses the API to list all vApps and their VMs that the 
user has ability to access.

=head2 Usage

  ./list-vms.pl --username USER --password PASS --orgname ORG --hostname HOST
  
Orgname is optional. It will default to "System" if not given. 

=cut

use Data::Dumper;
use Getopt::Long;
use VMware::vCloud;
use strict;

my $version = ( split ' ', '$Revision: 1.3 $' )[1];

my ( $username, $password, $hostname, $orgname );

my $ret = GetOptions ( 'username=s' => \$username, 'password=s' => \$password,
                       'orgname=s' => \$orgname, 'hostname=s' => \$hostname );

die "Check the POD. This script needs command line parameters." unless
 $username and $password and $hostname;

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 1 } );

my %vms = $vcd->list_vapps();

print "\n", Dumper(\%vms);

=head1

my $login = $vcd->login;

my %orgs;

for my $name ( keys %$login ) {
  my $href = $login->{$name}->{href};
  $href =~ /(\d+)$/;
  my $id = $1;
  print "Found ORG \"$name\"\n";
  $orgs{$id} = $name;
}

my %catalogs;
my %vdcs;

for my $orgid ( keys %orgs ) {
  my $org = $vcd->org_get($orgid);
  for my $entity ( @{ $org->{Link} } ) {
    my $type = $entity->{type};
    #if ( $type =~ /\.catalog\+xml$/ ) {
    #  $catalogs{$entity->{name}}{$entity->{href}}++;
	#  print "ORG \"$orgs{$orgid}\" has CATALOG \"$entity->{name}\"\n";
	#}
    if ( $type =~ /\.vdc\+xml$/ ) {
      $vdcs{$entity->{name}}{$entity->{href}}++;
	  print "Found VDC \"$entity->{name}\" in ORG \"$orgs{$orgid}\"\n";
	}
  }
}

my %vapps;

for my $vdc ( keys %vdcs ) {
  for my $href ( keys %{$vdcs{$vdc}} ) {
    my $res = $vcd->vdc_get($href);
	my %entities = %{$res->{ResourceEntities}->{ResourceEntity}};
	for my $entity ( keys %entities ) {
	  next if $entities{$entity}{type} =~ /media\+xml$/;
	  next if $entities{$entity}{type} =~ /vAppTemplate\+xml$/;
      my $vapp = $vcd->vapp_get($entities{$entity}{href});
	  $vapps{$entity} = $vapp;
	}
  }
}

print "\n";

for my $name ( sort keys %vapps ) {
  print "VAPP: $name \n";

  my %vms = ();
  if ( defined $vapps{$name}{Children}{Vm} ) {
    if ( defined $vapps{$name}{Children}{Vm}{name} ) { # Single VM in the vApp
	  %vms = ( $vapps{$name}{Children}{Vm}{name} => $vapps{$name}{Children}{Vm} );
	} else { # Multiple VMs in the vApp
      %vms = %{$vapps{$name}{Children}{Vm}};
	}
  } else { # NO VMs in the vApp
    $vms{"(No VMs in this vApp)"}++;
  }  

  for my $vmname ( sort keys %vms ) {
    print "  vm: $vmname\n";
  }
  print "\n"; 
}