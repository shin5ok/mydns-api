use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'MyDNS::API',
    'VERSION_FROM' => 'lib/MyDNS/API.pm', # finds $VERSION
    'PREREQ_PM' => {
       Test::More => 0.32,
       Class::Accessor::Lite => 0.05,
       DBD::mysql => 4.022,
       DBIx::Class => 0.08204,
       DBIx::Class::Schema::Loader => 0.07033,
       JSON => 2.53,
       LWP::UserAgent => 6.04,
       Mojolicious => 3.64,
       Smart::Args => 0.10,
       URI => 1.60,
       Starman => 0.3001,
       YAML => 0.81,
       IO::Socket::SSL => 1.84,
       Net::CIDR => 0.17,
       Log::Dispatch::Syslog => 2.35,
       MojoX::Log::Log4perl => 0.06,
    },
);


