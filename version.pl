#!/usr/bin/perl

# ./version.pl        : Prints the current tagged version number
# ./version.pl --bump : Increments the version number, retags, and pushes the tags

use strict;

my $version; my $build;

if ( $ARGV[0] eq '--bump' ) {
  my $version = &version();
  chomp($version);
  my $next_version = &next($version);
  print "Bumping version from $version to $next_version\n";
  system("git tag -a $next_version -m 'Version $next_version'");
  system("git push --tags origin master");
  system("git push --tags github master");
} elsif ( $ARGV[0] eq '--build' ) {
  print &build();
} else {
  print &version();
}

sub build {
  $build = `git describe --long | tr '-' ' ' | awk '{ print \$2 }'`
    unless defined $build and length $build;
  return $build;
}

sub next {
  my $old = shift @_;
  chomp($old);
  $old =~ /^(.+)\.(.+?)$/;
  my ($main,$sub) = ($1,$2);
  my $length = length($sub);
  $sub++;
  if ( length($sub) > $length ) {
    warn "WARNING: Version length now larger! (From $length digits to ",
         length($sub), ")\n";
    $length = length($sub);
  }
  return sprintf('%s.%0'.$length.'d',$main,$sub);
}

sub version {
  $version = `git describe --long | tr '-' ' ' | awk '{ print \$1 }'`
    unless defined $version and length $version;
  return $version;
}
