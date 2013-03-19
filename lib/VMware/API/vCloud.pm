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

This module provides a bare interface to VMware's vCloud REST API.

VMware::vCloud is designed for high level usage with vCloud Director. This 
module, however, provides a more low-level access to the REST interface.

Responses received from vCloud are in XML. They are translated via XML::Simple
with ForceArray set for consistency in nesting. This is the object returned.

Aside from the translation of XML into a perl data structure, no further 
alteration is performed on the data.

HTTP errors are automatically parsed and die() is called. If you need to perform
a dangerous action, do so in an eval block and evaluate $@.

=head1 OBJECT METHODS

These methods are not API calls. They represent the methods that create
this module as a "wrapper" for the vCloud API.

=head2 new()

This method creates the vCloud object.

Arguments

=over 4

=item * hostname

=item * username

=item * password

=item * organization

=back

=cut

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

=head2 config()

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

# $self->{raw}->{version} - Full data on the API version from login (populated on api_version() call)
# $self->{raw}->{login}
# $self->{learned}->{version} - API version number (populated on api_version() call)
# $self->{learned}->{url}->{login} - Authentication URL (populated on api_version() call)
# $self->{learned}->{url}->{orglist}

sub DESTROY {
  my $self = shift @_;
  my @dump = split "\n", Dumper($self->{learned});
  pop @dump; shift @dump;
  #$self->_debug("Learned variables: \n" . join("\n",@dump));
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

  $self->{api_version} = $self->api_version();
  $self->_debug("API Version: $self->{api_version}");
  
  $self->{url_base} = URI->new('https://'. $self->{hostname} .'/api/v'. $self->{api_version} .'/');
  $self->_debug("API URL: $self->{url_base}");
}

sub _xml_response {
  my $self     = shift @_;
  my $response = shift @_;
  
  if ( $response->is_success ) {
    return undef unless $response->content;
    my $data = XMLin( $response->content, ForceArray => 1 );
    return $data;
  } else {
    $self->_fault($response);
  }
}

=head1 REST METHODS

These are direct access to the REST web methods.

=head2 delete($url)

Performs a DELETE action on the given URL, and returns the parsed XML response.

=cut 

sub delete {
  my $self = shift @_;
  my $url  = shift @_;
  $self->_debug("API: delete($url)\n") if $self->{debug};
  my $req = HTTP::Request->new( DELETE => $url );
  $req->header( Accept => $self->{learned}->{accept_header} );
  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 get($url)

Performs a GET action on the given URL, and returns the parsed XML response.

=cut 

sub get {
  my $self = shift @_;
  my $url  = shift @_;
  $self->_debug("API: get($url)\n") if $self->{debug};
  my $req = HTTP::Request->new( GET => $url );
  $req->header( Accept => $self->{learned}->{accept_header} );
  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
}

=head2 get_raw($url)

Performs a GET action on the given URL, and returns the unparsed HTTP::Request object.

=cut 

sub get_raw {
  my $self = shift @_;
  my $url  = shift @_;
  $self->_debug("API: get($url)\n") if $self->{debug};
  my $req = HTTP::Request->new( GET => $url );
  $req->header( Accept => $self->{learned}->{accept_header} );
  my $response = $self->{ua}->request($req);
  return $response->content;
}

=head2 post($url,$type,$content)

Performs a POST action on the given URL, and returns the parsed XML response.

The optional value for $type is set as the Content Type for the transaction. 

The optional value for $content is used as the content of the post.

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

=head1 API SHORTHAND METHODS

=head2 api_version 

* Relative URL: /api/versions

This call queries the server for the current version of the API supported. 
It is implicitly called when library is instanced.

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

* Relative URL: dynamic, but usually: /login/

This call takes the username and password provided in the config() and creates
an authentication  token from the server. If successful, it returns the login
data returned by the server.

In the 5.1 version of the API, this is a list of several access URLs.

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
    $self->{learned}->{url}->{admin}         = $link->{href} if $link->{type} eq 'application/vnd.vmware.admin.vcloud+xml';
    $self->{learned}->{url}->{entity}        = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.entity+xml';
    $self->{learned}->{url}->{extensibility} = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.apiextensibility+xml';
    $self->{learned}->{url}->{extension}     = $link->{href} if $link->{type} eq 'application/vnd.vmware.admin.vmwExtension+xml';
    $self->{learned}->{url}->{orglist}       = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.orgList+xml';
    $self->{learned}->{url}->{query}         = $link->{href} if $link->{type} eq 'application/vnd.vmware.vcloud.query.queryList+xml';
    #die Dumper($self->{raw}->{login}->{Link});
  }

  return $self->{raw}->{login};
}

### API methods

=head2 admin()

* Relative URL: dynamic admin URL, usually /api/admin/

Parses the admin API URL to build and return a hash reference of key URLs for
the API.

=cut

sub admin {
  my $self = shift @_;
  my $req = HTTP::Request->new( GET =>  $self->{learned}->{url}->{admin} );
  $req->header( Accept => $self->{learned}->{accept_header} );

  $self->_debug("API: admin()\n") if $self->{debug};
  return $self->{learned}->{admin} if defined $self->{learned}->{admin};

  my $response = $self->{ua}->request($req);
  my $parsed = $self->_xml_response($response);

  $self->{learned}->{admin}->{networks} = $parsed->{Networks}->[0]->{Network};
  $self->{learned}->{admin}->{rights}   = $parsed->{RightReferences}->[0]->{RightReference};
  $self->{learned}->{admin}->{roles}    = $parsed->{RoleReferences}->[0]->{RoleReference};
  $self->{learned}->{admin}->{orgs}     = $parsed->{OrganizationReferences}->[0]->{OrganizationReference};
  $self->{learned}->{admin}->{pvdcs}    = $parsed->{ProviderVdcReferences}->[0]->{ProviderVdcReference};

  return $self->{learned}->{admin};
}

=head2 admin_extension_get()

* Relative URL: dynamic admin URL followed by "/extension"

=cut

sub admin_extension_get {
  my $self = shift @_;
  $self->_debug("API: admin_extension_get()\n") if $self->{debug};

  my $req = HTTP::Request->new( GET => $self->{learned}->{url}->{admin} . 'extension' );
  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);  
}

=head2 admin_extension_vimServer_get()

=cut

sub admin_extension_vimServer_get {
  my $self = shift @_;
  my $url  = shift @_;
  
  $self->_debug("API: admin_extension_vimServer_get()\n") if $self->{debug};

  my $req = HTTP::Request->new( GET => $url );
  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);  
}


=head2 admin_extension_vimServerReferences_get()

=cut

sub admin_extension_vimServerReferences_get {
  my $self = shift @_;
  $self->_debug("API: admin_extension_vimServerReferences_get()\n") if $self->{debug};

  my $req = HTTP::Request->new( GET => $self->{learned}->{url}->{admin} . 'extension/vimServerReferences' );
  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);  
}


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
  my $conf = shift @_;

  $self->_debug("API: org_create()\n") if $self->{debug};
  my $url = $self->{learned}->{url}->{admin} . 'orgs';
  
  my $vdcs;  
  if ( defined $conf->{vdc} and ref $conf->{vdc} ) {
    for my $vdc (@{$conf->{vdc}}) {
      $vdcs .= '<Vdc href="'.$vdc.'"/> ';
    }
  } elsif ( defined $conf->{vdc} ) {
      $vdcs = '<Vdc href="'.$conf->{vdc}.'"/> ';
  }
  $vdcs .= "\n";
  
  my $xml = '
<AdminOrg xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$conf->{name}.'">
  <Description>'.$conf->{desc}.'</Description>
  <FullName>'.$conf->{fullname}.'</FullName>
  <IsEnabled>'.$conf->{is_enabled}.'</IsEnabled>  
    <Settings>
        <OrgGeneralSettings>
            <CanPublishCatalogs>'.$conf->{can_publish}.'</CanPublishCatalogs>
            <DeployedVMQuota>'.$conf->{deployed}.'</DeployedVMQuota>
            <StoredVmQuota>'.$conf->{stored}.'</StoredVmQuota>
            <UseServerBootSequence>false</UseServerBootSequence>
            <DelayAfterPowerOnSeconds>1</DelayAfterPowerOnSeconds>
        </OrgGeneralSettings>
    </Settings>
    <Vdcs>
      '.$vdcs.'
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

=head2 org_network_create($url,$conf)

Create an org network

The conf hash reference can contain:

=over 4

=item * name

=item * desc

=item * gateway

=item * netmask

=item * dns1

=item * dns2

=item * dnssuffix

=item * is_enabled

=item * start_ip

=item * end_ip

=back

=cut

sub org_network_create {
  my $self = shift @_;
  my $url  = shift @_;
  my $conf = shift @_;

  $conf->{is_shared} = 0 unless defined $conf->{is_shared};  

  $self->_debug("API: org_network_create()\n") if $self->{debug};
  
#  my $xml = '
#<OrgNetwork xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$name.'">
#  <Description>'.$desc.'</Description>
#   <Configuration>
#      <IpScopes>
#         <IpScope>
#            <IsInherited>false</IsInherited>
#            <Gateway>'.$gateway .'</Gateway>
#            <Netmask>'.$netmask.'</Netmask>
#            <Dns1>'.$dns1.'</Dns1>
#            <Dns2>'.$dns2.'</Dns2>
#            <DnsSuffix>'.$dnssuffix.'</DnsSuffix>
#            <IpRanges>
#               <IpRange>
#                  <StartAddress>'.$start_ip.'</StartAddress>
#                  <EndAddress>'.$end_ip.'</EndAddress>
#               </IpRange>
#            </IpRanges>
#         </IpScope>
#      </IpScopes>
#      <FenceMode>natRouted</FenceMode>
#   </Configuration>
#   <EdgeGateway
#      href="https://vcloud.example.com/api/admin/gateway/2000" />
#   <IsShared>true</IsShared>
#</OrgVdcNetwork>
#  ';

  my $xml = '<OrgVdcNetwork
   name="'.$conf->{name}.'"
   xmlns="http://www.vmware.com/vcloud/v1.5">
   <Description>'.$conf->{desc}.'</Description>
   <Configuration>
      <ParentNetwork
         href="'.$conf->{parent_net_href}.'" />
      <FenceMode>bridged</FenceMode>
   </Configuration>
  <IsShared>'.$conf->{is_shared}.'</IsShared>
</OrgVdcNetwork>';

  $url .= '/networks';

  my $ret = $self->post($url,'application/vnd.vmware.vcloud.orgVdcNetwork+xml',$xml);

  return $ret->[2]->{href} if $ret->[1] == 201;
  return $ret;
}

=head2 org_vdc_create($url,$conf)

Create an org VDC

The conf hash reference can contain:

=over 4

=item * name

=item * desc

=item * np_href

=item * sp_enabled

=item * sp_units

=item * sp_limit

=item * sp_default

=item * sp_href

=item * allocation_model

=item * cpu_unit

=item * cpu_alloc

=item * cpu_limit

=item * mem_unit

=item * mem_alloc

=item * mem_limit

=item * nic_quota

=item * net_quota

=item * ResourceGuaranteedMemory

=item * ResourceGuaranteedCpu

=item * VCpuInMhz

=item * is_thin_provision

=item * pvdc_name

=item * pvdc_href

=item * use_fast_provisioning

=back

=cut

sub org_vdc_create {
  my $self = shift @_;
  my $url  = shift @_;
  my $conf = shift @_;

  $self->_debug("API: org_vdc_create()\n") if $self->{debug};
  
  my $networkpool = $conf->{np_href} ? '<NetworkPoolReference href="'.$conf->{np_href}.'"/>' : '';
  
  my $sp;
  if ( defined $conf->{sp} and ref $conf->{sp} ) {
    for my $ref ( @{$conf->{sp}} ) {
      $sp .= '<VdcStorageProfile>
      <Enabled>'.$ref->{sp_enabled}.'</Enabled>
      <Units>'.$ref->{sp_units}.'</Units>
      <Limit>'.$ref->{sp_limit}.'</Limit>
      <Default>'.$ref->{sp_default}.'</Default>
      <ProviderVdcStorageProfile href="'.$ref->{sp_href}.'" />
   </VdcStorageProfile>';
	}
  } elsif ( defined $conf->{sp_enabled} ) {
    $sp = '<VdcStorageProfile>
      <Enabled>'.$conf->{sp_enabled}.'</Enabled>
      <Units>'.$conf->{sp_units}.'</Units>
      <Limit>'.$conf->{sp_limit}.'</Limit>
      <Default>'.$conf->{sp_default}.'</Default>
      <ProviderVdcStorageProfile href="'.$conf->{sp_href}.'" />
   </VdcStorageProfile>';
  }
   
  my $xml = '
<CreateVdcParams xmlns="http://www.vmware.com/vcloud/v1.5" name="'.$conf->{name}.'">
  <Description>'.$conf->{desc}.'</Description>
  <AllocationModel>'.$conf->{allocation_model}.'</AllocationModel>
   <ComputeCapacity>
      <Cpu>
         <Units>'.$conf->{cpu_unit}.'</Units>
         <Allocated>'.$conf->{cpu_alloc}.'</Allocated>
         <Limit>'.$conf->{cpu_limit}.'</Limit>
      </Cpu>
      <Memory>
         <Units>'.$conf->{mem_unit}.'</Units>
         <Allocated>'.$conf->{mem_alloc}.'</Allocated>
         <Limit>'.$conf->{mem_limit}.'</Limit>
      </Memory>
   </ComputeCapacity>
   <NicQuota>'.$conf->{nic_quota}.'</NicQuota>
   <NetworkQuota>'.$conf->{net_quota}.'</NetworkQuota>
   '.$sp.'
   <ResourceGuaranteedMemory>'.$conf->{ResourceGuaranteedMemory}.'</ResourceGuaranteedMemory>
   <ResourceGuaranteedCpu>'.$conf->{ResourceGuaranteedCpu}.'</ResourceGuaranteedCpu>
   <VCpuInMhz>'.$conf->{VCpuInMhz}.'</VCpuInMhz>
   <IsThinProvision>'.$conf->{is_thin_provision}.'</IsThinProvision>
   '.$networkpool.'
   <ProviderVdcReference
      name="'.$conf->{pvdc_name}.'"
      href="'.$conf->{pvdc_href}.'" />
   <UsesFastProvisioning>'.$conf->{use_fast_provisioning}.'</UsesFastProvisioning>
</CreateVdcParams>
  ';

  $url .= '/vdcsparams';

  my $ret = $self->post($url,'application/vnd.vmware.admin.createVdcParams+xml',$xml);

  return $ret->[2]->{href} if $ret->[1] == 201;
  return $ret;
}

=head2 pdvc_get()

=cut

sub pvdc_get {
  my $self = shift @_;
  my $tmpl = shift @_;
  my $req;

  $self->_debug("API: pvdc_get($tmpl)\n") if $self->{debug};
  
  if ( $tmpl =~ /^[^\/]+$/ ) {
    $req = HTTP::Request->new( GET =>  $self->{url_base} . 'tmpl/' . $tmpl );
  } else {
    $req = HTTP::Request->new( GET =>  $tmpl );
  }

  $req->header( Accept => $self->{learned}->{accept_header} );

  my $response = $self->{ua}->request($req);
  return $self->_xml_response($response);
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

=head2 vdc_list()

Returns the full list of available VDCs.

=cut

sub vdc_list {
  my $self = shift @_;
  $self->_debug("API: vdc_list()\n") if $self->{debug};

  my $req = HTTP::Request->new( GET => $self->{learned}->{url}->{admin} . 'vdcs/query' );
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

 VMware vCloud Director Publications
  http://www.vmware.com/support/pubs/vcd_pubs.html
  http://pubs.vmware.com/vcd-51/index.jsp

 VMware vCloud API Programming Guide v5.1
  http://pubs.vmware.com/vcd-51/topic/com.vmware.vcloud.api.doc_51/GUID-86CA32C2-3753-49B2-A471-1CE460109ADB.html
  
 vCloud API and Admin API v5.1 schema definition files
  http://pubs.vmware.com/vcd-51/topic/com.vmware.vcloud.api.reference.doc_51/about.html
  
 VMware vCloud API Communities
  http://communities.vmware.com/community/vmtn/developer/forums/vcloudapi

 VMware vCloud API Specification v1.5
  http://www.vmware.com/support/vcd/doc/rest-api-doc-1.5-html/

=cut
