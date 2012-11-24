use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'MyDNS::API',
    'VERSION_FROM' => 'lib/MyDNS/API.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
    },
);
