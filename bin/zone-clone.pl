use warnings;
use strict;
use MyDNS::API::Domain;

my $domain = shift;
my $src    = shift;
my $ip     = shift;

my $v = MyDNS::API::Domain->new( {
                           domain      => $domain,
                           dsn         => "dbi:mysql:mydns", 
                           db_user     => $ENV{MYSQLD_USER}, 
                           db_password => $ENV{MYSQLD_PASSWORD},
                          });
$v->zone_clone($src, { ip => $ip });
