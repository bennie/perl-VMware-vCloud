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
  my $self = shift @_;
  my $id = shift @_;

  my $raw_org_data = $self->{api}->org_get($id);

  my %org;
  $org{description} = $raw_org_data->{Description}->[0];
  $org{name}        = $raw_org_data->{name};

  $raw_org_data->{href} =~ /([^\/]+)$/;
  $org{id} = $1;

  $org{contains} = {};
  
  for my $link ( @{$raw_org_data->{Link}} ) {
    $link->{type} =~ /^application\/vnd.vmware.vcloud.(\w+)\+xml$/;
    my $type = $1;
    $link->{href} =~ /([^\/]+)$/;
    my $id = $1;
    
    next if $type eq 'controlAccess';
    
    $org{contains}{$type}{$id} = $link->{name};
  }

  return %org;
}

# Returns a hasref of the vdc

sub get_vdc {
  my $self = shift @_;
  my $id = shift @_;

  my $raw_vdc_data = $self->{api}->vdc_get($id);

  my %vdc;
  $vdc{description} = $raw_vdc_data->{Description}->[0];
  $vdc{name}        = $raw_vdc_data->{name};

  $raw_vdc_data->{href} =~ /([^\/]+)$/;
  $vdc{id} = $1;

  $vdc{contains} = {};
  
  for my $link ( @{$raw_vdc_data->{Link}} ) {
    $link->{type} =~ /^application\/vnd.vmware.vcloud.(\w+)\+xml$/;
    my $type = $1;
    $link->{href} =~ /([^\/]+)$/;
    my $id = $1;
    
    next if $type eq 'controlAccess';
    
    $vdc{contains}{$type}{$id} = $link->{name};
  }

  return %$raw_vdc_data;
}
# Returns a hash of orgs the user can access

sub list_orgs {
  my $self = shift @_;

  my %orgs;
  for my $orgname ( keys %{$self->{raw_login_data}->{Org}} ) {
    my $href = $self->{raw_login_data}->{Org}->{$orgname}->{href};
    $href =~ /([^\/]+)$/;
    my $orgid = $1;
    $orgs{$orgid} = $orgname;
  }

  return wantarray ? %orgs : \%orgs;  
}

# Returns a hash of all the vapps the user can access in the given org

sub list_vapps {
  my $self  = shift @_;
  my $orgid = shift @_;
  my %orgs = $self->list_orgs();

  my %vdcs;
  
  for my $orgid ( keys %orgs ) {
    my %org = $self->get_org($orgid);
    for my $vdcid ( keys %{$org{contains}{vdc}} ) {
      $vdcs{$vdcid}++;
    }
  }

  my %vapps;
  
  for my $vdcid ( keys %vdcs ) {
    my %vdc = $self->get_vdc($vdcid);
    return %vdc;
  }
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
