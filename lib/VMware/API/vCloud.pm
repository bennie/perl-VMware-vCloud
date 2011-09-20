package VMware::API::vCloud;

use Data::Dumper;
use LWP;
use XML::Simple;
use strict;

our $VERSION = 'VERSIONTAG';

### External methods

sub new {
  my $class = shift @_;
  my $self  = {};

  $self->{hostname} = shift @_;
  $self->{username} = shift @_;
  $self->{password} = shift @_;
  $self->{orgname}  = shift @_;

  $self->{orgname} = 'System' unless $self->{orgname};

  $self->{debug}        = 0; # Defaults to no debug info
  $self->{die_on_fault} = 1; # Defaults to dieing on an error
  $self->{ssl_timeout}  = 3600; # Defaults to 1h

  bless($self,$class);

  $self->_regenerate();
  
  $self->_debug("Loaded VMware::vCloud v" . our $VERSION . "\n") if $self->{debug};
  return $self;
}

sub config {
  my $self = shift @_;

  my %input = @_;
  my @config_vals = qw/debug die_on_fault hostname orgname password ssl_timeout username/;
  my %config_vals = map { $_,1; } @config_vals;

  for my $key ( keys %input ) {
    if ( $config_vals{$key} ) {
      $self->{$key} = $input{$key};
    } else {
      warn 'Config key "$key" is being ignored. Only the following options may be configured: '
         . join(", ", @config_vals ) . "\n";
    }
  }

  $self->_regenerate();

  my %out;
  map { $out{$_} = $self->{$_} } @config_vals;

  return wantarray ? %out : \%out;
}

### Internal methods

sub _debug {
  my $self = shift @_;
  return undef unless $self->{debug};
  while ( my $debug = shift @_ ) {
    chomp $debug;
    print STDERR "DEBUG: $debug\n";
  }
}

sub _fault {
  my $self = shift @_;
  die Dumper(@_);
}

sub _regenerate {
  my $self = shift @_;
  
  $self->{ua} = LWP::UserAgent->new;
  $self->{ua}->cookie_jar({});

  $self->{api_version} = $self->api_version();
  $self->_debug("API version: $self->{api_version}");
  
  $self->{url_base} = URI->new('https://'. $self->{hostname} .'/api/v'. $self->{api_version} .'/');
  $self->_debug("API URL: $self->{url_base}");
}

sub _xml_response {
  my $self     = shift @_;
  my $response = shift @_;
  
  if ( $response->status_line eq '200 OK' ) {
    my $data = XMLin( $response->content, ForceArray => 1 );
    return $data;
  } else {
    $self->_fault($response);
  }
}

### Public methods

sub api_version {
  my $self = shift @_;
  my $url = URI->new('https://'. $self->{hostname} .'/api/versions'); # Check API version first!
  my $req = HTTP::Request->new( GET =>  $url ); 
  my $response = $self->{ua}->request($req);
  if ( $response->status_line eq '200 OK' ) {
    my $info = XMLin( $response->content );
    
    my $version = 1.0;
    for my $verblock ( @{$info->{VersionInfo}} ) { 
      $version = $verblock->{Version} if $verblock->{Version} > $version;
    }
    
    return "1.0"; # Temporary overide of V1
  } else {
    $self->_fault($response);
  }
}

sub login {
  my $self = shift @_;
  my $req = HTTP::Request->new( POST =>  $self->{url_base} . 'login' ); 

  $req->authorization_basic( $self->{username} .'@'. $self->{orgname}, $self->{password} ); 
  my $response = $self->{ua}->request($req);

  $self->_debug( "Authentication status: " . $response->status_line );
  $self->_debug( "Response WWW-Authenticate Header: " . $response->header("WWW-Authenticate") );

  return $self->_xml_response($response);
}

### API methods

sub catalog_get {
  my $self = shift @_;
  my $cat  = shift @_;
  my $req;
  
  if ( $cat =~ /^\d+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'catalog/' . $cat );
  } else {
    $req = HTTP::Request->new( GET =>  $cat );
  }

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

sub org_get {
  my $self = shift @_;
  my $org  = shift @_;
  my $req;
  
  if ( $org =~ /^\d+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'org/' . $org );
  } else {
    $req = HTTP::Request->new( GET =>  $org );
  }

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

sub vdc_get {
  my $self = shift @_;
  my $vdc  = shift @_;
  my $req;
  
  if ( $vdc =~ /^\d+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'org/' . $vdc );
  } else {
    $req = HTTP::Request->new( GET =>  $vdc );
  }

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

sub vapp_get {
  my $self = shift @_;
  my $vapp = shift @_;
  my $req;
  
  if ( $vapp =~ /^\d+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'vApp/vapp-' . $vapp );
  } else {
    $req = HTTP::Request->new( GET =>  $vapp );
  }

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
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

=head1 PERL MODULE METHODS

These methods are not API calls. They represent the methods that create
this module as a "wrapper" for the vCloud API.

=head2 new

This method creates the vCloud object.

U<Arguments>

=over

=item * hostname

=item * username

=item * password

=item * organization

=back

=head2 config

  $vcd->config( debug => 1 );

=over 4

=item debug - 1 to turn on debugging. 0 for none. Defaults to 0.

=item die_on_fault - 1 to cause the program to die verbosely on a soap fault. 0 for the fault object to be returned on the call and for die() to not be called. Defaults to 1. If you choose not to die_on_fault (for example, if you are writing a CGI) you will want to check all return objects to see if they are fault objects or not.

=item ssl_timeout - seconds to wait for timeout. Defaults to 3600. (1hr) This is how long a transaction response will be waited for once submitted. For slow storage systems and full clones, you may want to up this higher. If you find yourself setting this to more than 6 hours, your vCloud setup is probably not in the best shape.

=item hostname, orgname, username and password - All of these values can be changed from the original settings on new(). This is handing for performing multiple transactions across organizations.

=back

=head1 PUBLIC API METHODS

=head2 api_version

This call queries the server for the current version of the API supported. It is implicitly called when library is instanced.

=head2 login

This call takes the username and password provided and creates an authentication token from the server. If successful, it returns the list of organizations the authenticated user may access..

=head2 catalog_get($catid or $caturl)

As a parameter, this method thakes the raw numeric id of the catalog or the full URL detailed for the catalog from the login catalog.

It returns the requested catalog.

=head2 org_get($orgid or $orgurl)

As a parameter, this method thakes the raw numeric id of the organization or the full URL detailed for the organization from the login catalog.

It returns the requested organization.

=head2 vdc_get($vdcid or $vdcurl)

As a parameter, this method thakes the raw numeric id of the virtual data center or the full URL detailed a catalog.

It returns the requested VDC.

=head2 vapp_get($vappid or $vappurl)

As a parameter, this method thakes the raw numeric id of the vApp or the full URL.

It returns the requested vApp.

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
