use strict;
use warnings;
use Test::More;
use POSIX qw(strftime);

BEGIN {
  use_ok("MyDNS::API::Domain::Serial");
};

my $domain = q{example01.com};

my $arg = +{ domain => $domain, };
my $obj = MyDNS::API::Domain::Serial->new( $arg );

isa_ok( $obj, "MyDNS::API::Domain::Serial");
isa_ok( $obj, "DBIx::Class::Schema::Loader");

ok(! $obj->serial);

my $datetime = strftime "%Y%m%d01", localtime;
ok( $obj->serial($datetime), "set $datetime" );

is( $obj->serial, $datetime, "validate $datetime to set serial" );

$datetime++;

ok( $obj->serial($datetime), "set $datetime(update)" );
is( $obj->serial, $datetime, "validate $datetime to set serial(update)" );

done_testing;

