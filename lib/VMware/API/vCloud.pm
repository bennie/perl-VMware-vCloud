package VMware::API::vCloud;

use Data::Dumper;
use LWP;
use XML::Simple;
use strict;

our $VERSION = 'VERSIONTAG';

=head1 NAME

VMware::API::vCloud - The VMware vCloud API

=head1 SYNOPSIS


  my $api = new VMware::API::vCloud (
    $hostname, $username, $password, $orgname
  );
  
  my $raw_login_data = $vcd->login;

=head1 DESCRIPTION

This module provides a Perl interface to VMware's vCloud REST API.

In general, for most API calls, they are in the structure of the conecptual
name followed by an underscore and then the REST action. (IE: org_get() for
retrieveing an org, and org_post() for creating one.)

=head1 RETURNED VALUES

Responses received from vCloud are in XML. They are translated via XML::Simple
with ForceArray set for consistency in nesting. This is the object returned.

Aside from the translation of XML into a perl data structure, no further 
alteration is performed on the data.

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

=cut

#      $self->{raw}->{version} - Full data on the API version from login (populated on api_version() call)
#      $self->{raw}->{login}
#      $self->{learned}->{version} - API version number (populated on api_version() call)
#      $self->{learned}->{url}->{login} - Authentication URL (populated on api_version() call)
# $self->{learned}->{url}->{orglist}

sub new {
  my $class = shift @_;
  my $self  = {};

  $self->{hostname} = shift @_;
  $self->{username} = shift @_;
  $self->{password} = shift @_;
  $self->{orgname}  = shift @_;

  $self->{debug}        = 0; # Defaults to no debug info
  $self->{die_on_fault} = 1; # Defaults to dieing on an error
  $self->{ssl_timeout}  = 3600; # Defaults to 1h

  $self->{orgname} = 'System' unless $self->{orgname};

  $self->{conf} = shift @_ if defined $_[0] and ref $_[0];
  $self->{debug} = $self->{conf}->{debug} if defined $self->{conf}->{debug};

  bless($self,$class);

  $self->_regenerate();
  
  $self->_debug("Loaded VMware::vCloud v" . our $VERSION . "\n") if $self->{debug};
  return $self;
}

=head2 config

  $vcd->config( debug => 1 );

=over 4

=item debug - 1 to turn on debugging. 0 for none. Defaults to 0.

=item die_on_fault - 1 to cause the program to die verbosely on a soap fault. 0 for the fault object to be returned on the call and for die() to not be called. Defaults to 1. If you choose not to die_on_fault (for example, if you are writing a CGI) you will want to check all return objects to see if they are fault objects or not.

=item ssl_timeout - seconds to wait for timeout. Defaults to 3600. (1hr) This is how long a transaction response will be waited for once submitted. For slow storage systems and full clones, you may want to up this higher. If you find yourself setting this to more than 6 hours, your vCloud setup is probably not in the best shape.

=item hostname, orgname, username and password - All of these values can be changed from the original settings on new(). This is handing for performing multiple transactions across organizations.

=back

=cut

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

sub DESTROY {
  my $self = shift @_;
  my @dump = split "\n", Dumper($self->{learned});
  pop @dump; shift @dump;
  $self->_debug("Learned variables: \n" . join("\n",@dump));
}

sub _admin_urls {
  my $self = shift @_;
  my $req = HTTP::Request->new( GET =>  $self->{learned}->{url}->{admin} );
  $req->header( Accept => $self->{learned}->{accept_header} );

  return $self->{learned}->{url}->{admin_actions} if defined $self->{learned}->{url}->{admin_actions};

  my $response = $self->{ua}->request($req);
  my $parsed = $self->_xml_response($response);

  my $rightreference = $parsed->{RightReferences}->[0]->{RightReference};
  for my $name ( keys %$rightreference ) {
    $self->{learned}->{url}->{admin_actions}->{$name} = $rightreference->{$name}->{href};
  }

  return $self->{learned}->{url}->{admin_actions};
}

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
  my @error = @_;
  
  my $message = "\nERROR: ";
  
  if ( length(@error) and ref $error[0] eq 'HTTP::Response' ) {
    $message .= $error[0]->status_line;    
    $self->_debug( Dumper(\@error) );
    die $message;
  }
  
  while ( my $error = shift @error ) {
    if ( ref $error eq 'SCALAR' ) {
      chomp $error;
      $message .= $error;
    } else {
      $message .= Dumper($error);
    }
  }
}

sub _regenerate {
  my $self = shift @_;
  
  $self->{ua} = LWP::UserAgent->new;
  #$self->{ua}->cookie_jar({});

  $self->{api_version} = $self->api_version();
  $self->_debug("API Version: $self->{api_version}");
  
  $self->{url_base} = URI->new('https://'. $self->{hostname} .'/api/v'. $self->{api_version} .'/');
  $self->_debug("API URL: $self->{url_base}");
}

sub _xml_response {
  my $self     = shift @_;
  my $response = shift @_;
  
  if ( $response->is_success ) {
    my $data = XMLin( $response->content, ForceArray => 1 );
    return $data;
  } else {
    $self->_fault($response);
  }
}

### Public methods

=head1 PUBLIC API METHODS

=head2 api_version

This call queries the server for the current version of the API supported. It is implicitly called when library is instanced.

=cut

sub api_version {
  my $self = shift @_;
  my $url = URI->new('https://'. $self->{hostname} .'/api/versions'); # Check API version first!

  $self->_debug("Checking $url for supported API versions");

  my $req = HTTP::Request->new( GET =>  $url ); 
  my $response = $self->{ua}->request($req);
  if ( $response->status_line eq '200 OK' ) {
    my $info = XMLin( $response->content );

    #die Dumper($info);

    $self->{learned}->{version} = 0;
    for my $verblock ( @{$info->{VersionInfo}} ) {
      if ( $verblock->{Version} > $self->{learned}->{version} ) {
        $self->{raw}->{version}          = $verblock;
        $self->{learned}->{version}      = $verblock->{Version};
        $self->{learned}->{url}->{login} = $verblock->{LoginUrl};
      }
    }

    return $self->{learned}->{version};
  } else {
    $self->_fault($response);
  }
}

=head2 login

This call takes the username and password provided and creates an authentication token from the server. If successful, it returns the list of organizations the authenticated user may access.

=cut

sub login {
  my $self = shift @_;

  $self->_debug('Login URL: '.$self->{learned}->{url}->{login});
  my $req = HTTP::Request->new( POST => $self->{learned}->{url}->{login} ); 

  $req->authorization_basic( $self->{username} .'@'. $self->{orgname}, $self->{password} );
  $self->_debug("Attempting to login: " . $self->{username} .'@'. $self->{orgname} .' '. $self->{password} );

  $self->{learned}->{accept_header} = 'application/*+xml;version='.$self->{learned}->{version};
  $self->_debug('Accept header: '.$self->{learned}->{accept_header});
  $req->header( Accept => $self->{learned}->{accept_header} );
 
  my $response = $self->{ua}->request($req);

  my $token = $response->header('x-vcloud-authorization');
  $self->{ua}->default_header('x-vcloud-authorization', $token);

  $self->_debug( "Authentication status: " . $response->status_line );
  $self->_debug( "Authentication token: " . $token );

  $self->{raw}->{login} = $self->_xml_response($response);

  for my $link ( @{$self->{raw}->{login}->{Link}} ) {
    $self->{learned}->{url}->{admin}     = $link->{href} if $link->{type} eq 'application/vnd.vmware.admin.vcloud+xml';
    $self->{learned}->{url}->{entity}    = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.entity+xml';
    $self->{learned}->{url}->{extension} = $link->{href} if $link->{type} eq 'application/vnd.vmware.admin.vmwExtension+xml';
    $self->{learned}->{url}->{orglist}   = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.orgList+xml';
    $self->{learned}->{url}->{querylist} = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.query.queryList+xml';
    #die Dumper($self->{raw}->{login}->{Link});
  }

  return $self->{raw}->{login};
}

### API methods

=head2 catalog_get($catid or $caturl)

As a parameter, this method thakes the raw numeric id of the catalog or the full URL detailed for the catalog from the login catalog.

It returns the requested catalog.

=cut

sub catalog_get {
  my $self = shift @_;
  my $cat  = shift @_;
  my $req;

  $self->_debug("API: catalog_get($cat)\n") if $self->{debug};
  
  if ( $cat =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'catalog/' . $cat );
  } else {
    $req = HTTP::Request->new( GET =>  $cat );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 org_create($name,$desc,$fullname,$is_enabled)

Create an organization?

=cut

sub org_create {
  my $self = shift @_;
  my $name = shift @_;
  my $desc = shift @_;
  my $fullname = shift @_;
  my $is_enabled = shift @_;
  my $vdc_url = shift @_;

  $self->_debug("API: org_create()\n") if $self->{debug};
  my $url = $self->{learned}->{url}->{admin} . 'orgs';

  my $xml = '
<AdminOrg xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$name.'">
  <Description>'.$desc.'</Description>
  <FullName>'.$fullname.'</FullName>
  <IsEnabled>'.$is_enabled.'</IsEnabled>  
    <Settings>
        <OrgGeneralSettings>
            <CanPublishCatalogs>true</CanPublishCatalogs>
            <DeployedVMQuota>10</DeployedVMQuota>
            <StoredVmQuota>15</StoredVmQuota>
            <UseServerBootSequence>false</UseServerBootSequence>
            <DelayAfterPowerOnSeconds>1</DelayAfterPowerOnSeconds>
        </OrgGeneralSettings>
    </Settings>
    <Vdcs>
        <Vdc href="'.$vdc_url.'"/>
    </Vdcs>  
</AdminOrg>
';

  my $ret = $self->post($url,'application/vnd.vmware.admin.organization+xml',$xml);

  return $ret->[2]->{href} if $ret->[1] == 201;
  return $ret;
}

=head2 org_get($orgid or $orgurl)

As a parameter, this method takes the raw numeric id of the organization or the full URL detailed for the organization from the login catalog.

It returns the requested organization.

=cut

sub org_get {
  my $self = shift @_;
  my $org  = shift @_;
  my $req;

  $self->_debug("API: org_get($org)\n") if $self->{debug};
  
  if ( $org =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'org/' . $org );
  } else {
    $req = HTTP::Request->new( GET =>  $org );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 org_list()

Returns the full list of available organizations.

=cut

sub org_list {
  my $self = shift @_;
  $self->_debug("API: org_list()\n") if $self->{debug};

  my $req = HTTP::Request->new( GET => $self->{learned}->{url}->{orglist} );
  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 org_network_create($name,$desc,$gateway,$netmask,$dns1,$dns2,$dnssuffix,$is_enabled,$start_ip,$end_ip)

Create an org network

=cut

sub org_network_create {
  my $self = shift @_;
  my $url  = shift @_;
  my $name = shift @_;
  my $desc = shift @_;

  my $gateway    = shift @_;
  my $netmask    = shift @_;
  my $dns1       = shift @_;
  my $dns2       = shift @_;
  my $dnssuffix  = shift @_;
  my $is_enabled = shift @_;

  my $start_ip = shift @_;
  my $end_ip   = shift @_;

  $self->_debug("API: org_network_create()\n") if $self->{debug};
  
  my $xml = '
<OrgNetwork xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$name.'">
  <Description>'.$desc.'</Description>
    <Settings>
      <IpScope>
        <Gateway>'.$gateway .'</Gateway>
        <Netmask>'.$netmask.'</Netmask>
        <Dns1>'.$dns1.'</Dns1>
        <Dns2>'.$dns2.'</Dns2>
        <DnsSuffix>'.$dnssuffix.'</DnsSuffix>
        <IsEnabled>'.$is_enabled.'</IsEnabled>
        <IpRanges>
           <IpRange>
             <EndAddress>'.$end_ip.'</EndAddress>
          </IpRange>
        </IpRanges>
      </IpScope>
    </Settings>
</OrgNetwork>
  ';
#             <StartAddress>'.$start_ip.'</StartAddress>

  $url .= '/networks';

  my $ret = $self->post($url,'application/vnd.vmware.admin.orgNetwork+xml',$xml);

  return $ret->[2]->{href} if $ret->[1] == 201;
  return $ret;
}

=head2 org_network_create($name,$desc,$gateway,$netmask,$dns1,$dns2,$dnssuffix,$is_enabled,$start_ip,$end_ip)

Create an org network

=cut

sub org_vdc_create {
  my $self = shift @_;
  my $url  = shift @_;
  my $name = shift @_;
  my $desc = shift @_;

  my $allocation_model = 'AllocationVApp';

  $self->_debug("API: org_vdc_create()\n") if $self->{debug};
  
  my $xml = '
<CreateVdcParams xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$name.'">
  <Description>'.$desc.'</Description>
  <AllocationModel>'.$allocation_model.'</AllocationModel>
  <ComputeCapacity>
    <Cpu>
      <Units> MB </Units>
      <Allocated> 500 </Allocated>
      <Limit> 1000 </Limit>
    </Cpu>
    <Memory>
      <Units> MB </Units>
      <Allocated> 1000 </Allocated>
      <Limit> 2000 </Limit>
    </Memory>
  </ComputeCapacity>
  <IsEnabled> 1 </IsEnabled>
  <VdcStorageProfile>
        <Units> MB </Units>
        <Limit> 100 </Limit>
        <Default> 1 </Default>
        <ProviderVdcStorageProfile href="" />
  </VdcStorageProfile>
  <NicQuota> 10 </NicQuota>
  <NetworkQuota> 10 </NetworkQuota> 
</CreateVdcParams>
  ';

  $url .= '/vdcsparams';

  my $ret = $self->post($url,'application/vnd.vmware.admin.createVdcParams+xml',$xml);

  return $ret->[2]->{href} if $ret->[1] == 201;
  return $ret;
}

=head2 post($url)

Performs the requested URL post to the server.

It returns an array or arraref with three items: returned message, returned
numeric code, and a hashref of the full XML data returned.

=cut

sub post {
  my $self = shift @_;
  my $href = shift @_;

  my $type = shift @_;
  my $content = shift @_;

  $self->_debug("API: post($href)\n") if $self->{debug};
  my $req = HTTP::Request->new( POST => $href );

  $req->content($content) if $content;
  $req->content_type($type) if $type;
  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  my $data = $self->_xml_response($response);

  my @ret = ( $response->message, $response->code, $data );

  return wantarray ? @ret : \@ret;
}

=head2 template_get($templateid or $templateurl)

As a parameter, this method thakes the raw numeric id of the template or the full URL.

It returns the requested template.

=cut

sub template_get {
  my $self = shift @_;
  my $tmpl = shift @_;
  my $req;

  $self->_debug("API: template_get($tmpl)\n") if $self->{debug};
  
  if ( $tmpl =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'tmpl/' . $tmpl );
  } else {
    $req = HTTP::Request->new( GET =>  $tmpl );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 vdc_get($vdcid or $vdcurl)

As a parameter, this method thakes the raw numeric id of the virtual data center or the full URL detailed a catalog.

It returns the requested VDC.

=cut

sub vdc_get {
  my $self = shift @_;
  my $vdc  = shift @_;
  my $req;
  
  $self->_debug("API: vdc_get($vdc)\n") if $self->{debug};

  if ( $vdc =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'vdc/' . $vdc );
  } else {
    $req = HTTP::Request->new( GET =>  $vdc );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 vapp_get($vappid or $vappurl)

As a parameter, this method thakes the raw numeric id of the vApp or the full URL.

It returns the requested vApp.

=cut

sub vapp_get {
  my $self = shift @_;
  my $vapp = shift @_;
  my $req;
  
  $self->_debug("API: vapp_get($vapp)\n") if $self->{debug};

  if ( $vapp =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'vApp/vapp-' . $vapp );
  } else {
    $req = HTTP::Request->new( GET =>  $vapp );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

1;

__END__

=head1 BUGS and LIMITATIONS

Template name validation.

  Most names in the GUI (for vApps, VMs, Templates, and Catalogs) are limited to
  128 characters, and are restricted to being composed of alpha numerics and 
  standard keyboard punctuations. Notably, spaces and tabs are NOT allowed to
  be entered in the GUI. However, you can upload a template in the API with a
  space in the name. It will only be visable or usable some of the time in the 
  GUI. Apparently there is a bug in name validation via the API.

=head1 WISH LIST

If someone from VMware is reading this, and has control of the API, I would
dearly love a few changes, that might help things:

=over 4

=item Statistics & Dogfooding - There is an implied contract in the API. That is, anything I can see and do in the GUI I should also be able to do via the API. There are no per-VM statistics available in the API. But the statistics are shown in the GUI. Please offer per-VM statistics in the API. Crosswalking the VM name and trying to find the data in the vSphere API to do this is a pain.

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
