use warnings;
use strict;
use MyDNS::API;

my $domain = shift;
my $src    = shift;
my $ip     = shift;

my $v = MyDNS::API->new( {
                           domain      => $domain,
                           dsn         => "dbi:mysql:mydns", 
                           db_user     => "root", 
                           db_password => $ENV{MYSQLD_PASSWORD},
                          });
$v->zone_clone($src, { ip => $ip });
