package VMware::vCloud;

use VMware::API::vCloud;
use strict;

our $VERSION = 'VERSIONTAG';

### External methods

sub new {
  my $class = shift @_;
  our $host = shift @_;
  our $user = shift @_;
  our $pass = shift @_;
  our $org  = shift @_;

  $org = 'System' unless $org; # Default to "System" org

  my $self  = {};
  bless($self);

  $self->{api} = new VMware::API::vCloud (our $host, our $user, our $pass, our $org);
  $self->{raw_login_data} = $self->{api}->login();

  return $self;
}

sub login {
  my $self = shift @_;
  return $self->list_orgs(@_);
}

# Returns a hasref of the org

sub get_org {

# Returns a hash of orgs the user can access

sub list_orgs {
  my $self = shift @_;

  my %orgs;
  for my $orgname ( keys %{$self->{raw_login_data}->{Org}} ) {
    my $href = $self->{raw_login_data}->{Org}->{$orgname}->{href};
    $href =~ /\/(.*?)$/;
    my $orgid = $1;
    $orgs{$orgname} = $orgid;
  }

  return wantarray ? %orgs : \%orgs;  
}

# Returns a hash of all the vapps the user can access in the given org

sub list_vapps {
  my $orgid = shift @_;
  my %orgs = $self->list_orgs();
  
}

1;

__END__

=head1 NAME

VMware::vCloud - The VMware vCloud API

=head1 SYNOPSIS

This module has been developed against VMware vCenter director.

  my $vcd = new VMware::vCloud (
    $hostname, $username, $password, $orgname
  );
  
  my $login = $vcd->login;

=head1 DESCRIPTION

This module provides a Perl interface to VMware's vCloud REST interface.

=head1 RETURNED VALUES

Many of the methods return hash references or arrays of hash references that
contain information about a specific "object" or concept on the vCloud Director
server. This is a rough analog to the Managed Object Reference structure of
the VIPERL SDK without the generic interface for retireval.

=head1 EXAMPLE SCRIPTS

Included in the distribution of this module are several example scripts. Hopefully
they provide an illustrative example of the vCloud API. All scripts have
their own POD and accept command line parameters in a similar way to the VIPERL
SDK utilities and vghetto scripts.

    login.pl - An example script that demonstrates logging in to the 
server.

=head1 WISH LIST

If someone from VMware is reading this, and has control of the API, I would
dearly love a few changes, that might help things:

=over 4

=item System - It would really help if in the API guide it mentions early on that the organization to connect as an administrator account, IE: the macro organization to which all other orgs descend from is called "System." That helps a lot.

=item External vs External - When you have the concept of a "fenced" network for a vApp, one of the most confusing points is the local network that is natted to the outside is referred to as "External" as is the outside IPs that the network is routed to. Walk a new user through some of the Org creation wizards and watch the confusion. Bad choice of names.

=back

=head1 VERSION

  Version: VERSIONTAG (DATETAG)

=head1 AUTHOR

  Phillip Pollard, <bennie@cpan.org>

=head1 CONTRIBUTIONS

  stu41j - http://communities.vmware.com/people/stu42j

=head1 DEPENDENCIES

  LWP
  XML::Simple

=head1 LICENSE AND COPYRIGHT

  Released under Perl Artistic License

=head1 SEE ALSO

 VMware vCloud Director
  http://www.vmware.com/products/vcloud/

 VMware vCloud API Specification v1.0
  http://communities.vmware.com/docs/DOC-12464

 VMware vCloud API Programming Guide v1.0
  http://communities.vmware.com/docs/DOC-12463
  
 vCloud API and Admin API v1.0 schema definition files
  http://communities.vmware.com/docs/DOC-13564
  
 VMware vCloud API Communities
  http://communities.vmware.com/community/vmtn/developer/forums/vcloudapi

=cut
