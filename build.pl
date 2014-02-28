#!/usr/bin/env perl

require CPAN::Meta::YAML; # Do both YAML and JSON

use Data::Dumper;
use CPAN::Meta;
use strict;

### Config

my ($module, $author,  $license, $abstract, $description, $perl_ver, %requires);

open INFILE, '<', 'config.txt' or die "Can't open 'config.txt'";
my $text = join('',<INFILE>);
close INFILE;

eval $text;
die $@ if $@;

die "Bad config." unless $module && $author && $license && 
  $abstract && $description && $perl_ver && %requires;

### Post config

my $path_chunk = $module;
$path_chunk =~ s/::/-/g;

my $bug  = 'https://rt.cpan.org/Dist/Display.html?Name='.$path_chunk;
my $repo = 'http://github.com/bennie/perl-' . $path_chunk;
my $git  = 'git://github.com/bennie/perl-'.$path_chunk.'.git';

my $require_text = Dumper(\%requires);
$require_text =~ s/\$VAR1 = //;
$require_text =~ s/;$//;

### Bump the version if asked

for my $arg (@ARGV) {
  version_bump() and last if $arg eq '--bump';
  if ( $arg eq '--retag'   ) { version_retag();  exit; }
  if ( $arg eq '--version' ) { print version_current(), "\n"; exit; }
}

### External data

my $version = version_current();
my $date    = `date '+%Y/%m/%d'`;
my $year    = `date '+%Y'`;
my $distdir = $path_chunk .'-' . $version;

chomp $date;
chomp $year;
chomp $distdir;

print "
Version : $version
Date    : $date
Year    : $year
Dist    : $distdir

";

### Write Makefile.PL

open MAKEFILE, '>', 'Makefile.PL';

print MAKEFILE "use ExtUtils::MakeMaker;

WriteMakefile(
  ABSTRACT => \"$abstract\",
  AUTHOR   => '$author',
  LICENSE  => '$license',
  NAME     => '$module',
  VERSION  => '$version',

  PREREQ_PM => $require_text,

  ( \$ExtUtils::MakeMaker::VERSION < 6.46
        ? ()
        : ( META_MERGE => {
                requires  => {perl => '$perl_ver'},
                resources => {
                    # homepage => 'http://FIXME.org',
                    # license  => 'http://dev.perl.org/licenses/',
                    # MailingList => 'http://FIXME',
                    repository => {
                        type => 'git',
                        url  => '$git',
                        web  => '$repo',
                    },
                    bugtracker => {
                        # mailto => '...',
                        web => '$bug',
                    },

                },
                no_index => {directory => [qw/t/]},
            },
            META_ADD => {
                build_requires     => {},
                configure_requires => {}
            },
        )
    )

);";

close MAKEFILE;

### Build the distribution directory

print `perl Makefile.PL`;
print `make distmeta`;

### Build META.json

unless ( -f $distdir.'/META.json' ) {
  my $distmeta = {

    # Required
    abstract => $abstract,
    author   => [ $author ],
    license  => [ $license ],
    name     => $path_chunk,
    version  => $version,

    # optional
    dynamic_config => 1,
    'meta-spec' => { version => '2', url => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec' },
    generated_by => "CPAN::Meta version $CPAN::Meta::VERSION",

    # 2.0 only stuff
    description =>  $description,
    release_status => 'stable',

    prereqs => {
      runtime => {
        requires => \%requires,
        recommends => { },
      },
      build => {
        requires => \%requires,
      }
    },
    resources => {
      license    => [ 'http://dev.perl.org/licenses/' ],
      bugtracker => { web => $bug },
      repository => { web => $repo , type => 'git', url => $git },
    },
  };

  $distmeta->{prereqs}->{runtime}->{requires}->{perl} = $perl_ver;

  my $meta = CPAN::Meta->create($distmeta);
  print "Generating META.json on my own.\n";
  $meta->save($distdir.'/META.json');

  print "Adding META.json to the MANIFEST\n";
  open MANIFEST, '>>', $distdir.'/MANIFEST';
  print MANIFEST "META.json\nMakefile.PL";
  close MANIFEST;

}

### Updating the tags

print  "\nUpdating DATETAG -> $date\n";
system "find $distdir -type f | xargs perl -p -i -e 's|DATETAG|$date|g'";
print  "Updating VERSIONTAG -> $version\n";
system "find $distdir -type f | xargs perl -p -i -e 's|VERSIONTAG|$version|g'";
print  "Updating YEARTAG -> $year\n";
system "find $distdir -type f | xargs perl -p -i -e 's|YEARTAG|$year|g'";
print "\n";

### Build the tarball

unlink($distdir.'.tar')    if -f $distdir.'.tar';
unlink($distdir.'.tar.gz') if -f $distdir.'.tar.gz';

system "tar cvf $distdir.tar $distdir && gzip --best $distdir.tar";

### Cleanup

unlink('Makefile');
unlink('Makefile.old');
unlink('Makefile.PL');

print "\nDONE!\n";

### Subroutines

sub version_bump {
  my $version = version_current();
  my $next_version = version_next($version);
  print "Bumping version from $version to $next_version\n";
  system("git tag -a $next_version -m 'Version $next_version'");
  system("git push --tags origin master");
  system("git push --tags github master");
  our $version = $next_version;
}

sub version_current {
  our $version;
  return $version if defined $version and length $version;
  $version = `git describe --long | tr '-' ' ' | awk '{ print \$1 }'`;
  chomp $version;
  $version = '0.01' unless length $version;
  return $version;
}

sub version_next {
  my $old = shift @_;
  $old =~ /^(.+)\.(.+?)$/;
  my ($main,$sub) = ($1,$2);
  my $length = length($sub);
  $sub++;
  if ( length($sub) > $length ) {
    warn "WARNING: Version length now larger! (From $length digits to ", length($sub), ")\n";
    $length = length($sub);
  }
  return sprintf('%s.%0'.$length.'d',$main,$sub);
}

sub version_retag {
  my $tag = version_current();
  system("git tag -d $tag");
  system("git push origin :refs/tags/$tag");
  system("git push github :refs/tags/$tag");
  print "\nTagging current as $tag\n";
  system("git tag -a $tag -m 'Version $tag'");
  system("git push --tags origin master");
  system("git push --tags github master");
}
