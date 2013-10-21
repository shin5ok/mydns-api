use strict;
use warnings;
use Test::More;
use POSIX qw(strftime);
use Data::Dumper;
use YAML;

our $yaml_file = qq{$ENV{HOME}/mydns-api-config.yaml};

BEGIN {
  use_ok("MyDNS::API::Domain");
};

my $config = YAML::LoadFile($yaml_file);
my $domain = q{example01.com};

is(ref $config, 'HASH');

my $args = {
  domain      => $domain,
  dsn         => $config->{dsn},
  db_user     => $config->{db_user},
  db_password => $config->{db_password},
};

# my $mydns_domain = MyDNS::API::Domain->new($args);
#
# isa_ok($mydns_domain, qq{MyDNS::API::Domain});
#
done_testing;
