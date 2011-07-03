use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'VMware::vCloud',
    'VERSION_FROM' => 'lib/VMware/vCloud.pm',
    'PREREQ_PM'    => { 'LWP' => '5', 'XML::Simple' => '2', Data::Dumper => '0' },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/VMware/vCloud.pm',
       AUTHOR     => 'Phillip Pollard <bennie@cpan.org>') : ()),
);
