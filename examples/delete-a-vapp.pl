#!/usr/bin/perl -I../lib
=head1 delete-a-vapps.pl

This example script uses the API to list all vApps that the user has ability to 
access.

=head2 Usage

  ./list-vapps.pl --username USER --password PASS --orgname ORG --hostname HOST
  
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

my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 0 } );

my %vapps = $vcd->list_vapps();
my @href = keys %vapps;

print "\nSelect a vApp:\n\n";

my $c = 0;
for my $href (@href) {
  print $c++, ". $vapps{$href} ($href)\n";
}

my $num = <STDIN>;
chomp $num;

print "Deleting $vapps{$href[$num]}...\n";

my $ret = $vcd->delete_vapp($href[$num]);
my $task = $ret->{href};

my ($val,$ref) = $vcd->wait_on_task($task);
print "$val\n";

print Dumper($ref);