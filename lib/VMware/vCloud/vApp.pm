package VMware::vCloud::vApp;

use Data::Dumper;
use strict;

our $VERSION = 'VERSIONTAG';

=head1 NAME

VMware::vCloud::vApp

=head1 DESCRIPTION

This module is instanciated to represent a vApp on vCloud Director. As such,
it contains methods that interact with the specific vApp this object represents.

This is an internal module to VMware::vCloud and is not designed to be used
independantly. You obtain a vApp object by using the get_vapp() method availble
in VMware::vCloud.

=head1 METHODS

=cut

sub new {
  my $class = shift @_;
  our $api  = shift @_;
  our $href = shift @_;

  my $self = {};
  bless($self,$class);
  
  our $data = $api->vapp_get($href);
  
  return $self;
}

=head2 available_actions()

This method returns a hash or hashref of available actions that can be performed
on the VM. (Eg: Powering on, deploying, etc.)

Each key represents and action and each value is the corresponding href for
said action to be executed.

=cut

sub available_actions {
  my %actions;
  for my $action ( @{ our $data->{Link} } ) {
    next if $action->{rel} =~ /^(up|down|edit|controlAccess)$/;
    $actions{$action->{rel}} = $action->{href};
  }
  return wantarray ? %actions : \%actions;
}

=head2 dumper()

This debugging method returns the internal data structure representing all
known information on the vApp.

=cut

sub dumper {
  return our $data;
}

=head2 power_on($vappid)

If it is an available action, it creates the task to power on a vApp.

It returns an array or arraref with three items: returned message, returned
numeric code, and a hashref of the full XML data returned.

The "Power On" action will deploy the vApp if it is currently undeployed.

A text error message is returned if the app is currently not able to be powered 
on. (IE: It is already on, or is busy with another task.)

=cut

sub power_on {
  my $self = shift @_;
  my %actions = $self->available_actions();
  return "Error: Unable to Power On the vApp at this time.\n" . Dumper(\%actions) unless defined $actions{'power:powerOn'};

  return our $api->post($actions{'power:powerOn'});  
}

sub power_off {

}

sub recompose {
  
}

1;

__END__

=head1 VERSION

  Version: VERSIONTAG (DATETAG)

=head1 AUTHOR

  Phillip Pollard, <bennie@cpan.org>

=head1 LICENSE AND COPYRIGHT

  Released under Perl Artistic License

=cut
