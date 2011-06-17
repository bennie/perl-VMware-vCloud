use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'VMware::API::LabManager',
    'VERSION_FROM' => 'lib/VMware/API/LabManager.pm',
    'PREREQ_PM'    => { 'SOAP::Lite' => '0', 'Crypt::SSLeay' => '0' },
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/VMware/API/LabManager.pm',
       AUTHOR     => 'Phillip Pollard <bennie@cpan.org>') : ()),
);
