#!/usr/bin/env perl

use Data::Dumper;
use File::Slurp;
use strict;

### Handle version tasks if asked

for my $arg (@ARGV) {
  version_bump() and last if $arg eq '--bump';
  if ( $arg eq '--retag'   ) { version_retag();  exit; }
  if ( $arg eq '--version' ) { print version_current(), "\n"; exit; }
}

### Validate we have what we need to build

# These will be necessary for Make Maker to make the module with proper files.
require CPAN::Meta;
require CPAN::Meta::Converter;
require CPAN::Meta::YAML;
require ExtUtils::MakeMaker;

print "Using ExtUtils::MakeMaker ($ExtUtils::MakeMaker::VERSION)\n";
print "Using CPAN::Meta ($CPAN::Meta::VERSION)\n";

die "You need a modern version of ExtUtils::MakeMaker." unless $ExtUtils::MakeMaker::VERSION > 6;

### Read the config.txt and try to process it

die "No config.txt present." unless -f 'config.txt';

my ($module, $author,  $license, $abstract, $description, $perl_ver, %requires);

my $text = read_file('config.txt') ;
1 while chomp $text;
die "No config data." unless length $text;

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

my $sourcefile = 'lib/' . $module . '.pm';
$sourcefile =~ s/::/\//g;

my $require_text = Dumper(\%requires);
$require_text =~ s/\$VAR1 = //;
$require_text =~ s/;$//;
1 while chomp($require_text);

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

### Figure out the provides

my %provides; my $provides;

for my $file ( `find lib -type f -name "*.pm"` ) {
  chomp $file;
  die "Can't figure out what is provided." unless $file =~ /^lib\/(.+).pm$/;
  my $name = $1;
  $name =~ s/\//::/g;
  $provides{$name} = { file => $file, version => $version };
}

$provides = Dumper(\%provides);
$provides =~ s/\$VAR1 = //;
$provides =~ s/;$//;
1 while chomp($provides);


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
                'meta-spec' => { version => 2 },
                no_index => {directory => [qw/t/]},
                provides => 

	$provides,

                release_status => 'stable',
                resources => {
                    repository => {
                        type => 'git',
                        url  => '$git',
                        web  => '$repo',
                    },
                    bugtracker => {
                        web => '$bug',
                    },

                },
            },
        )
    ),

  ( \$ExtUtils::MakeMaker::VERSION < 6.48
        ? ()
        : ( MIN_PERL_VERSION => '$perl_ver' )
  )

);";

close MAKEFILE;

### Build the distribution directory

print `perl Makefile.PL`;
print `make distmeta`;

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

system "gtar cvf $distdir.tar $distdir && gzip --best $distdir.tar";

### META.json check

warn "\nSomething is odd! We didn't build a META.json\n\n"
  unless -f $distdir.'/META.json';

### Cleanup

unlink('Makefile');
unlink('Makefile.old');
unlink('Makefile.PL');
unlink('MYMETA.json');
unlink('MYMETA.yml');

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
