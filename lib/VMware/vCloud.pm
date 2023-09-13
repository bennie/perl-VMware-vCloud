package VMware::vCloud;

use Cache::Bounded;
use Data::Dumper;
use VMware::API::vCloud;
use VMware::vCloud::vApp;

use warnings;
use strict;

$VMware::vCloud::VERSION = 'VERSIONTAG';

=head1 NAME

VMware::vCloud - VMware vCloud Director

=head1 SYNOPSIS

  my $vcd = new VMware::vCloud ( $hostname, $username, $password, $orgname, { debug => 1 } );  
  my %vapps = $vcd->list_vapps();

  my $vappid = $vapps{'My Personal vApp'};

  my $vapp = $vcd->get_vapp($vappid);
  my $ret = $vapp->power_on();

=head1 DESCRIPTION

This module provides a Perl interface to VMware's vCloud Director.

It's intention is to provide a high-level perl-style interface to vCloud 
Director actions.

If you are looking for a direct and low-level access to the vCloud API, you may 
want to look at VMware::API::vCloud, which is packaged and used by this module.

=head1 EXAMPLE SCRIPTS

Included in the distribution of this module are several example scripts. 
Hopefully they provide an illustrative example of the use of vCloud Director. 
All scripts have their own POD and accept command line parameters in a similar 
way to the VIPERL SDK utilities and vghetto scripts.

	login.pl - An example script that demonstrates logging in to the server.
	org_get.pl - Selects a random organization and prints a Data::Dumper dump of it's information.
	list-vapps.pl - Prints a list of all VMs the user has access to.

=head1 MODULE METHODS

=head2 new($host,$user,$pass,$org,$conf)

This method instances the VMware::vCloud object and verifies the user can log
onto the server.

$host, $user, and $pass are required. They should contain the login information
for the vCloud server.

$org and $conf are optional. 

$org is the vCloud Organization to connect to. If $org is not given, the 
default of 'System' is used.

$conf is an optional hasref containing tuneable parameters:

 * debug - set to a true value to turn on STDERR debugging statements.

=cut 

sub new {
  my $class = shift @_;
  our $host = shift @_;
  our $user = shift @_;
  our $pass = shift @_;
  our $org  = shift @_;
  our $conf = shift @_;

  $org = 'System' unless $org; # Default to "System" org

  my $self  = {};
  bless($self,$class);

  our $cache = new Cache::Bounded;

  $self->{api} = new VMware::API::vCloud ($host,$user,$pass,$org,$conf);
  $self->{raw_login_data} = $self->{api}->login();

  return $self;
}

sub DESTROY {
  my $self = shift @_;
  $self->{api}->logout() if defined $self->{api}->{have_session} and $self->{api}->{have_session} > 0;
}

=head2 debug(1|0)

This turns debugging on and off programatically. An argument of '1' for debugging, '0'
for no debugging.

=cut

sub debug {
  my $self = shift @_;
  my $val  = shift @_;
  $self->{api}->{debug} = $val;
}

=head2 login()

This method is deprecated and will be removed in later releases.

This method roughly emulates the default login action of the API: It returns
information on which organizations are accessible to the user.

It is a synonym for list_orgs() and all details on return values should be
take from that method's documentation.

=cut

sub login {
  my $self = shift @_;
  return $self->list_orgs(@_);
}

=head2 purge()

This method clears the in-module caching of API responses.

This module caches many API calls to reduce response times and load on the 
server. This cache is automatically cleared when a method that changes the 
status of the VCD server is called. However, there may be times when you have
a lon running process, or wish to manually clear the cache yourself.

=cut

sub purge {
  our $cache->purge();
}

### Standard methods

=head1 VAPP METHODS

=head2 create_vapp_from_template($name,$vdcid,$tmplid,$netid)

Given a name, VDC, template and network, instantiate the template with the given
settings and other defaults.

Details of the create task will be returned.

=cut

# bridged, isolated, or natRouted
# NONE, MANUAL, POOL, DHCP

sub create_vapp_from_template {
  my $self = shift @_;
  my $name = shift @_;

  my $vdcid  = shift @_;  
  my $tmplid = shift @_;
  my $netid  = shift @_;
  
  my %template = $self->get_template($tmplid);
  my %vdc = $self->get_vdc($vdcid);

  my @links = @{$vdc{Link}};
  my $url;

  for my $ref (@links) {
    #$url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.composeVAppParams+xml';
    $url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml';
  }

  my $fencemode = 'bridged'; # bridged, isolated, or natRouted
  my $IpAddressAllocationMode = 'POOL'; # NONE, MANUAL, POOL, DHCP

  return $self->{api}->vapp_create_from_template($url,$name,$netid,'bridged',$template{href},'POOL',$vdcid,$tmplid);
}

=head2 create_vapp_from_sources(...)

Create a vApp from varied sources

Details of the create task will be returned.

=cut

# bridged, isolated, or natRouted
# NONE, MANUAL, POOL, DHCP

sub create_vapp_from_sources {
  my $self = shift @_;
  my $name = shift @_;

  my $vdcid  = shift @_;  
  my $tmplid = shift @_;
  my $netid  = shift @_;
  
  my %template = $self->get_template($tmplid);
  my %vdc = $self->get_vdc($vdcid);

  my @links = @{$vdc{Link}};
  my $url;

  for my $ref (@links) {
    #$url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.composeVAppParams+xml';
    $url = $ref->{href} if $ref->{type} eq 'application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml';
  }

  my $fencemode = 'bridged'; # bridged, isolated, or natRouted
  my $IpAddressAllocationMode = 'POOL'; # NONE, MANUAL, POOL, DHCP

  return $self->{api}->vapp_create_from_sources($url,$name,$netid,'bridged',$template{href},'POOL',$vdcid,$tmplid);
}
=head2 delete_vapp($vapp_href)

Given the org HREF, call a delete on it.

=cut

sub delete_vapp {
  my $self = shift @_;
  my $href = shift @_;
  $self->purge(); # Clear cache when deleting
  return $self->{api}->delete($href);
}


=head2 get_vapp($vappid)

Given an vApp id, it returns a vApp object for that vApp.

See the documentation on VMware::vCloud::vApp for full details on this object
type.

=cut

sub get_vapp {
  my $self = shift @_;
  my $href = shift @_;

  my $vapp = our $cache->get('get_vapp:'.$href);
  return $vapp if defined $vapp;

  $vapp = new VMware::vCloud::vApp ( $self->{api}, $href );
  
  $cache->set('get_vapp:'.$href,$vapp);
  return $vapp;
}

=head2 list_vapps()

This method returns a hash or hashref of Template names and IDs the user has
access too.

=cut

sub list_vapps {
  my $self  = shift @_;
  my $vapps = our $cache->get('list_vapps:');
  
  unless ( defined $vapps ) {
    my %vdcs = $self->list_vdcs($self->{'api'}{'orgname'});
    
    for my $vdcid ( keys %vdcs ) {
      my %vdc = $self->get_vdc($vdcid);
      for my $entity ( @{$vdc{ResourceEntities}} ) {
        for my $name ( keys %{$entity->{ResourceEntity}} ) {
          next unless $entity->{ResourceEntity}->{$name}->{type} eq 'application/vnd.vmware.vcloud.vApp+xml';
          my $href = $entity->{ResourceEntity}->{$name}->{href};
          $vapps->{$href} = $name;
        }
      }
    }
  }
  
  $cache->set('list_vapps:',$vapps);
  return wantarray ? %$vapps : $vapps if defined $vapps;
}

=head1 TEMPLATE METHODS

=head2 get_template($templateid)

Given an organization id, it returns a hash of data for that organization.

=cut

sub get_template {
  my $self = shift @_;
  my $id   = shift @_;

  my $tmpl = our $cache->get('get_template:'.$id);
  return %$tmpl if defined $tmpl;
  
  my $raw_tmpl_data = $self->{api}->template_get($id);

  my %tmpl = %$raw_tmpl_data;

  #$tmpl{description} = $raw_org_data->{Description}->[0];
  #$tmpl{name}        = $raw_org_data->{name};

  #$raw_org_data->{href} =~ /([^\/]+)$/;
  #$org{id} = $1;

  #$org{contains} = {};
  
  #for my $link ( @{$raw_org_data->{Link}} ) {
    #$link->{type} =~ /^application\/vnd.vmware.vcloud.(\w+)\+xml$/;
    #my $type = $1;
    #$link->{href} =~ /([^\/]+)$/;
    #my $id = $1;
    
    #next if $type eq 'controlAccess';
    
    #$org{contains}{$type}{$id} = $link->{name};
  #}

  $cache->set('get_template:'.$id,\%tmpl);
  return ( wantarray ? %tmpl : \%tmpl );
}

=head2 list_templates()

This method returns a hash or hashref of Template names and IDs the user has
access too.

=cut

sub list_templates {
  my $self  = shift @_;
  
  my $templates = our $cache->get('list_templates:');
  return %$templates if defined $templates;

  my %orgs = $self->list_orgs();
  my %vdcs = $self->list_vdcs($self->{'api'}{'orgname'});
  
  my %templates;
  
  for my $vdcid ( keys %vdcs ) {
    my %vdc = $self->get_vdc($vdcid);
    for my $entity ( @{$vdc{ResourceEntities}} ) {
      for my $name ( keys %{$entity->{ResourceEntity}} ) {
        next unless $entity->{ResourceEntity}->{$name}->{type} eq 'application/vnd.vmware.vcloud.vAppTemplate+xml';
        my $href = $entity->{ResourceEntity}->{$name}->{href};
        $templates{$href} = $name;
      }
    }
  }

  $cache->set('list_templates:',\%templates);
  return %templates;
}

=head1 CATALOG METHODS

=head2 create_catalog($org_href,$conf)

This method creates a new, empty catalog in the given organization.

$conf is a hashref that can contain:

=over 4

=item * name

=item * description

=item * is_published

=back

Org HREF example: http://example.vcd.server/api/admin/org/{id}

=cut

sub create_catalog {
  my $self = shift @_;
  return $self->{api}->catalog_create(@_);
}

=head2 delete_catalog($catalog_href)

Given the org HREF, call a delete on it.

=cut

# http://pubs.vmware.com/vcd-51/index.jsp?topic=%2Fcom.vmware.vcloud.api.reference.doc_51%2Fdoc%2Foperations%2FDELETE-Catalog.html

sub delete_catalog {
  my $self = shift @_;
  my $href = shift @_;
  $self->purge(); # Clear cache when deleting  
  return $self->{api}->delete($href);
}

=head1 ORG METHODS

=head2 create_org(\%conf)

=cut

sub create_org {
  my $self = shift @_;
  my $conf = shift @_;
  return $self->{api}->org_create($conf);
}

=head2 delete_org($org_href)

Given the org HREF, call a delete on it.

=cut

sub delete_org {
  my $self = shift @_;
  my $href = shift @_;
  $self->purge(); # Clear cache when deleting  
  return $self->{api}->delete($href);
}

=head2 delete_org_network($org_network_href)

Given the org network HREF, call a delete on it.

=cut

sub delete_org_network {
  my $self = shift @_;
  my $href = shift @_;
  $self->purge(); # Clear cache when deleting  
  return $self->{api}->delete($href);
}

=head2 disable_org($org_href)

Given a Org href, call the disable action on it.

=cut

sub disable_org {
  my $self = shift @_;
  my $href = shift @_;
  $href .= '/action/disable' unless $href =~ /\/action\/disable$/;
  return $self->{api}->post($href,undef,'');   
}

=head2 enable_org($org_href)

Given a Org href, call the enable action on it.

=cut

sub enable_org {
  my $self = shift @_;
  my $href = shift @_;
  $href .= '/action/enable' unless $href =~ /\/action\/enable$/;
  return $self->{api}->post($href,undef,'');   
}

=head2 get_org($org_href)

Given an organization id, it returns a hash or hashref of data for that 
organization. Returned data:

  name - Name of the organization
  description - Description field of the organization
  href - anchor HREF for the organization in the API 
  id - UUID identified in the href.

  contains - A hashref of contained objects

  catalogs = references to the catalogs within the org
  vdcs - references to the org VDCs within the org

  raw - The raw returned XML structure for the organization from the API
  
=cut

sub get_org {
  my $self = shift @_;
  my $id   = shift @_;

  my $org = our $cache->get('get_org:'.$id);
  return ( wantarray ? %$org : $org ) if defined $org;
  
  my $raw_org_data = $self->{api}->org_get($id);

  my %org;
  $org{raw}         = $raw_org_data;

  $org{catalogs}    = $raw_org_data->{Catalogs}->[0]->{CatalogReference};
  $org{description} = $raw_org_data->{Description}->[0];
  $org{href}        = $raw_org_data->{href};
  $org{name}        = $raw_org_data->{name};
  $org{networks}    = $raw_org_data->{Networks}->[0]->{Network};
  $org{vdcs}        = $raw_org_data->{Vdcs}->[0]->{Vdc};

  $raw_org_data->{href} =~ /([^\/]+)$/;
  $org{id} = $1;

  $org{contains} = {};
  
  for my $link ( @{$raw_org_data->{Link}} ) {
    $link->{type} =~ /^application\/vnd.vmware.vcloud.(\w+)\+xml$/;
    my $type = $1;

    my $id = $link->{href};
    
    next if $type eq 'controlAccess';
    
    $org{contains}{$type}{$id} = $link->{name};
  }

  $cache->set('get_org:'.$id,\%org);
  return wantarray ? %org : \%org;
}

=head2 list_orgs()

This method returns a hash or hashref of Organization names and IDs.

=cut

sub list_orgs {
  my $self = shift @_;
  my $orgs = our $cache->get('list_orgs:');

  unless ( defined $orgs ) {
    $orgs = {};
    my $ret = $self->{api}->org_list();

    for my $orgname ( keys %{$ret->{Org}} ) {
      warn "Org type of $ret->{Org}->{$orgname}->{type} listed for $orgname\n" unless $ret->{Org}->{$orgname}->{type} eq 'application/vnd.vmware.vcloud.org+xml';
      my $href = $ret->{Org}->{$orgname}->{href};
      $orgs->{$orgname} = $href;
    }
    $cache->set('list_orgs:',$orgs); 
  }
  
  return wantarray ? %$orgs : $orgs if defined $orgs;
}

=head1 ORG VDC METHODS

=head2 create_vdc($org_url,$conf)

=cut

sub create_vdc {
  my $self = shift @_;
  my $href = shift @_;
  my $conf = shift @_;
  return $self->{api}->org_vdc_create($href,$conf);
}  

=head2 delete_vdc($vdc_href);

Given the org VDC HREF, call a delete on it.

=cut

sub delete_vdc {
  my $self = shift @_;
  my $href = shift @_;
  $self->purge(); # Clear cache when deleting
  return $self->{api}->delete($href);
}

=head2 disable_vdc($vdc_href)

Given a VDC href, call the disable action on it.

=cut

sub disable_vdc {
  my $self = shift @_;
  my $href = shift @_;
  $href .= '/action/disable' unless $href =~ /\/action\/disable$/;
  return $self->{api}->post($href,undef,'');   
}

=head2 enable_vdc($vdc_href)

Given a VDC href, call the enable action on it.

=cut

sub enable_vdc {
  my $self = shift @_;
  my $href = shift @_;
  $href .= '/action/enable' unless $href =~ /\/action\/enable$/;
  return $self->{api}->post($href,undef,'');   
}

=head2 get_vdc($vdc_href)

Given an VDC href, it returns a hash of data for that vDC.

=cut

sub get_vdc {
  my $self = shift @_;
  my $id = shift @_;

  my $vdc = our $cache->get('get_vdc:'.$id);
  return %$vdc if defined $vdc;

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
  
  $cache->set('get_vdc:'.$id,$raw_vdc_data);
  return wantarray ? %$raw_vdc_data : $raw_vdc_data;
}

=head2 list_vdcs() | list_vdcs($orgid)

This method returns a hash or hashref of VDC names and IDs the user has
access too.

The optional argument of an $orgname will limit the returned list of VDCs in 
that Organization.

=cut

sub list_vdcs {
  my $self    = shift @_;
  my $orgname = shift @_;
  $orgname = '' if !defined $orgname || $orgname =~ /^[sS]ystem$/; # Show all if the org is System
  my $vdcs = our $cache->get("list_vdcs:$orgname:");

  unless ( defined $vdcs ) {
    $vdcs = {};
    my %orgs = $self->list_orgs();
    %orgs = ( $orgname => $orgs{$orgname} ) if defined $orgname; 
    
    for my $orgname ( keys %orgs ) {
      my %org = $self->get_org($orgs{$orgname});
      for my $vdcid ( keys %{$org{contains}{vdc}} ) {
        $vdcs->{$vdcid} = $org{contains}{vdc}{$vdcid};
      }
    }
  }

  $cache->set("list_vdcs:$orgname:",$vdcs);
  return wantarray ? %$vdcs : $vdcs;
}

=head1 PROVIDER VDC METHODS

=head2 get_pvdc($pvdc_href)

Returns a hashref of the information on the PVDC

=cut

sub get_pvdc {
  my $self = shift @_;
  my $href = shift @_;
  return $self->{api}->pvdc_get($href);
}

=head2 list_pvdcs()

Returns a hashref of the information on available PVDCs

=cut

sub list_pvdcs {
  my $self = shift @_;
  my $href = shift @_;

  my $admin_urls = $self->admin_urls();
  my $pvdcs = {};
  
  for my $name ( keys %{$admin_urls->{pvdcs}} ) {
    my $href = $admin_urls->{pvdcs}->{$name}->{href};
    $pvdcs->{$href} = $name;
  }
  
  return wantarray ? %$pvdcs : $pvdcs;
}

=head1 NETWORK METHODS

=head2 create_org_network 

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

=item * is_shared

=item * start_ip

=item * end_ip

=back

=cut

sub create_org_network {
  my $self = shift @_;
  my $href = shift @_;
  my $conf = shift @_;
  return $self->{api}->org_network_create($href,$conf);
}

=head2 list_networks() | list_networks($vdcid)

This method returns a hash or hashref of network names and IDs.

Given an optional VDCid it will return only the networks available in that VDC.

=cut

sub list_networks {
  my $self = shift @_;
  my $vdcid = shift @_;

  my $networks = our $cache->get("list_networks:$vdcid:");
  return %$networks if defined $networks;

  my %networks;
  my %vdcs = ( $vdcid ? ( $vdcid => 1 ) : $self->list_vdcs() );

  for my $vdcid ( keys %vdcs ) {
    my %vdc = $self->get_vdc($vdcid);
    my @networks = @{$vdc{AvailableNetworks}};
    for my $netblock (@networks) {
      for my $name ( keys %{$netblock->{Network}} ) {
        my $href = $netblock->{Network}->{$name}->{href};
        $networks{$name} = $href;
      }
    }
  }

  $cache->set("list_networks:$vdcid:",\%networks);
  return %networks;
}

=head1 TASKS

=head3 get_task($href)

Returns a hash or hashref of the given task.

Contents include: (but aren't limited to)

* href
* operation
* expiryTime
* startTime
* Progress
* operationName
* operation
* status

=cut

sub get_task {
  my $self = shift @_;
  my $href = shift @_;
  return $self->{api}->task_get($href);
}

=head3 progress_of_task($task_href)

  my ($percent,$status) = $vcd->progress_of_task($task_href)

Returns the approximate percentage of completion of the task as an integer
between 1 and 101.

The text status of the task is returned as well:

* queued - The task has been queued for execution.
* preRunning - The task is awaiting preprocessing or administrative action.
* running - The task is running.
* success - The task completed with a status of success.
* error - The task encountered an error while running.
* cancelled - The task was canceled by the owner or an administrator.
* aborted - The task was aborted by an administrative action.

=cut

sub progress_of_task {
  my $self = shift @_;
  my $href = shift @_;  

  my $task = $self->get_task($href);
  my $status = $task->{status};
 
  if ( $status eq 'queued' or $status eq 'preRunning' or $status eq 'running' or $status eq 'success' ) {
    return ( $task->{Progress}->[0], $status );
    die Dumper($task);
  }  

  return ( (defined $task->{Progress}->[0] ? $task->{Progress}->[0] : 101), $status );
}

=head3 wait_on_task($href)

Given a task href, this method will query the task every second, and only
return once the task is completed.

Specifically, this method will block and continue to query the task while it 
has any of the following statuses:

* queued - The task has been queued for execution.
* preRunning - The task is awaiting preprocessing or administrative action.
* running - The task is running.

Any of the following statuses will cause this method to return:

* success - The task completed with a status of success.
* error - The task encountered an error while running.
* cancelled - The task was canceled by the owner or an administrator.
* aborted - The task was aborted by an administrative action.

The return value will be and array or arrayref composed of two elements:

* The status code returned by the server
* A hashref comprising the most recently retrived for of the task object. IE:
the same output as get_task()

=cut

sub wait_on_task {
  my $self = shift @_;
  my $href = shift @_;  

  my $task = $self->get_task($href);
  my $status = $task->{status};
  
  while ( $status eq 'queued' or $status eq 'preRunning' or $status eq 'running' ) {
    sleep 1;
    $task = $self->get_task($href);
    $status = $task->{status};
  }  

  return wantarray ? ( $status, $task ) : [ $status, $task ];
}

=head1 ADMINISTRATIVE METHODS

=head3 admin_urls()

Returns the list of administrative action URLs available to the user.

=cut

sub admin_urls {
  my $self = shift @_;
  return $self->{api}->admin();
}

=head3 create_external_network($name,$gateway,$netmask,$dns1,$dns2,$suffix,$vimref,$moref,$objtype)

=cut

sub create_external_network {
  my $self = shift @_;
  my $conf = shift @_;

  my $xml = '
<vmext:VMWExternalNetwork
   xmlns:vmext="http://www.vmware.com/vcloud/extension/v1.5"
   xmlns:vcloud="http://www.vmware.com/vcloud/v1.5"
   name="'.$conf->{name}.'"
   type="application/vnd.vmware.admin.vmwexternalnet+xml">
   <vcloud:Description>ExternalNet</vcloud:Description>
   <vcloud:Configuration>
      <vcloud:IpScopes>
         <vcloud:IpScope>
            <vcloud:IsInherited>false</vcloud:IsInherited>
            <vcloud:Gateway>'.$conf->{gateway}.'</vcloud:Gateway>
            <vcloud:Netmask>'.$conf->{subnet}.'</vcloud:Netmask>
            <vcloud:Dns1>'.$conf->{dns1}.'</vcloud:Dns1>
            <vcloud:Dns2>'.$conf->{dns2}.'</vcloud:Dns2>
            <vcloud:DnsSuffix>'.$conf->{suffix}.'</vcloud:DnsSuffix>
            <vcloud:IpRanges>
               <vcloud:IpRange>
                  <vcloud:StartAddress>'.$conf->{ipstart}.'</vcloud:StartAddress>
                  <vcloud:EndAddress>'.$conf->{ipend}.'</vcloud:EndAddress>
               </vcloud:IpRange>
            </vcloud:IpRanges>
         </vcloud:IpScope>
      </vcloud:IpScopes>
      <vcloud:FenceMode>isolated</vcloud:FenceMode>
   </vcloud:Configuration>
   <vmext:VimPortGroupRef>
      <vmext:VimServerRef
         href="'.$conf->{vimserver}.'" />
      <vmext:MoRef>'.$conf->{mo_ref}.'</vmext:MoRef>
      <vmext:VimObjectType>'.$conf->{mo_type}.'</vmext:VimObjectType>
   </vmext:VimPortGroupRef>
</vmext:VMWExternalNetwork>';
  
  return $self->{api}->post($self->{api}->{learned}->{url}->{admin}.'extension/externalnets','application/vnd.vmware.admin.vmwexternalnet+xml',$xml); 
}

=head3 extensions()

Returns the data structure for the admin extensions available.

=cut

sub extensions {
  my $self = shift @_;
  return $self->{api}->admin_extension_get();
}

=head2 list_datastores()

Requires using a sysadmin account and attaching to the System org.

Returns a hash(ref) of datastore information.

=cut

sub list_datastores {
  my $self = shift @_;
  my $ret = $self->{api}->datastore_list();  
  return wantarray ? %{$ret->{DatastoreRecord}} : $ret->{DatastoreRecord};
}

=head3 list_external_networks()

Returns a hash or hasref of all available external networks.

=cut

sub list_external_networks {
  my $self = shift @_;  
  my $extensions = $self->extensions();

  my $extnet_url;
  for my $link ( @{$extensions->{'vcloud:Link'}} ) {
    $extnet_url = $link->{href} if $link->{type} eq 'application/vnd.vmware.admin.vmwExternalNetworkReferences+xml';
  }

  my $ret = $self->{api}->get($extnet_url);
  my $externals = $ret->{'vmext:ExternalNetworkReference'};
  
  return wantarray ? %$externals : $externals;
}

=head3 list_portgroups()

Returns a hash or hashref of available portgroups on the first associated 
vcenter server.

=cut

sub list_portgroups {
  my $self = shift @_;
  my $query = $self->{api}->get('https://'. our $host .'/api/query?type=portgroup&pageSize=250');
  my %portgroups = %{$query->{PortgroupRecord}};
  return wantarray ? %portgroups : \%portgroups;
}

=head3 vimserver()

Returns a reference to the first associated vcenter server.

=cut

sub vimserver {
  my $self = shift @_;
  my $ret = $self->{api}->admin_extension_vimServerReferences_get();
  my $vims = $ret->{'vmext:VimServerReference'};
  my $vim = ( keys %$vims )[0];
  my $vimserver_href = $vims->{$vim}->{href};
  return $self->{api}->admin_extension_vimServer_get($vimserver_href);
}

=head3 webclienturl($type,$moref)

Give the vimserver type and managed object reference, this method returns the 
URL for viewing the object via the vSphere Web client. This is handy for finding
further details on objects within vSphere.

=cut

sub webclienturl {
  my $self  = shift @_;
  my $type  = shift @_;
  my $moref = shift @_;

  my $ret = $self->{api}->admin_extension_vimServerReferences_get();
  my $vims = $ret->{'vmext:VimServerReference'};
  my $vim = ( keys %$vims )[0];
  my $vimserver_href = $vims->{$vim}->{href};
    
  my $urlrequest = $vimserver_href .'/'. $type .'/'. $moref .'/vSphereWebClientUrl';
  return $urlrequest;
}

1;

__END__

=head1 NOTES

=head2 ID VERSUS HREF

Tl;DR - Use HREFs and not IDs.

Internally, objects are identified in the vCloud Director API via either an
UUID or a HREF that references that object.

According to the API documentation, (as of 5.1) UUIDs are not guaranteed to 
always be consistent between connections, but HREFs are considered permanent.

Consequently, it is considered a best practice to use HREFs as the unique 
identifier of an object. This module implements this best practice.

=head1 DEPENDENCIES

  Cache::Bounded
  VMware::API::vCloud

=head1 BUGS AND SOURCE

	Bug tracking for this module: https://rt.cpan.org/Public/Dist/Display.html?Name=VMware-vCloud

	Source hosting: http://www.github.com/bennie/perl-VMware-vCloud

=head1 VERSION

	VMware::vCloud vVERSIONTAG (DATETAG)

=head1 COPYRIGHT

	(c) 2011-YEARTAG, Phillip Pollard <bennie@cpan.org>

=head1 LICENSE

This source code is released under the "Perl Artistic License 2.0," the text of
which is included in the LICENSE file of this distribution. It may also be
reviewed here: http://opensource.org/licenses/artistic-license-2.0

=head1 AUTHORSHIP

  Phillip Pollard, <bennie@cpan.org>

=head1 CONTRIBUTIONS

A strong thanks to all people who have helped me with direction, ideas, patches
and other such items.

  Dave Gress, <dgress@vmware.com> - Handling org admin issues and metadata
  Stuart Johnston, <sjohnston@cpan.org> - authentication and XML on API v1.0
