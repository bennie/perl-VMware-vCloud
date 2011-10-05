package VMware::vCloud::vApp;

use strict;

our $VERSION = 'VERSIONTAG';

sub new {
  my $class = shift @_;

  our $api  = shift @_;
  our $href = shift @_;
  our $data = shift @_;

  my $self = {};
  bless($self);
  return $self;
}

sub available_actions {
  my %actions;
  for my $action ( @{ our $data->{Link} } ) {
    next if $action->{rel} =~ /^(up|down|edit|controlAccess)$/;
    $actions{$action->{rel}} = $action->{href};
  }
  return \%actions;
}

sub dumper {
  return our $data;
}

sub power_on {
  my $self = shift @_;
  my %actions = $self->available_actions();
  
}

sub power_off {

}

1;

__END__

=head1 NAME

VMware::vCloud::vApp

=head1 DESCRIPTION

This is an internal module to VMware::vCloud and is not designed to be used
independantly.

=head1 VERSION

  Version: VERSIONTAG (DATETAG)

=head1 AUTHOR

  Phillip Pollard, <bennie@cpan.org>

=head1 LICENSE AND COPYRIGHT

  Released under Perl Artistic License

=cut
