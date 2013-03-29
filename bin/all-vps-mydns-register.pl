#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;
use Carp;
use MyDNS::API::Domain;

my $domain   = shift;
my @vlan_ids = @ARGV;
$domain       or croak "*** domain is empty";
@vlan_ids > 0 or croak "*** no vlan id";

my $admin_key    = $ENV{MURAKUMO_ADMIN_KEY};
my $api_base_uri = $ENV{MURAKUMO_API_URI};
my $db_user      = $ENV{MYSQLD_USER};
my $db_password  = $ENV{MYSQLD_PASSWORD};
my $debug        = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

my $api = MyDNS::API::Domain->new({
                            domain      => $domain,
                            dsn         => 'dbi:mysql:database=mydns',
                            db_user     => $db_user,
                            db_password => $db_password,
                          });

my $ua = LWP::UserAgent->new;

  for my $vlan_id ( @vlan_ids ) {

    my $uri = URI->new( qq{$api_base_uri/ip_with_name/$vlan_id} );
    $uri->query_form(
      admin_key => $admin_key,
    );

  #   "data" : [
  #      {
  #         "gw" : "124.241.196.1",
  #         "vps_uuid" : "e52e6422-71a1-11e2-b3cb-ddb847ae2665",
  #         "ip" : "124.241.196.2",
  #         "name" : "fedora18-kawano001",
  #         "mask" : "255.255.254.0",
  #         "project_id" : "kawano"
  #      },
  #      {
  #         "gw" : "124.241.196.1",
  #         "vps_uuid" : "3eb1c026-71a6-11e2-8989-45bb47ae2665",
  #         "ip" : "124.241.196.3",
  #         "name" : "centos6-kawano001",
  #         "mask" : "255.255.254.0",
  #         "project_id" : "kawano"
  #      },

    warn $uri if $debug;
  
    my $response = $ua->get( $uri );
    warn $response->content if $debug;
  
    my $json = $response->content;
    my $hash_ref = decode_json $json;
  
    my $ip_data = $hash_ref->{data};
  
    for my $r ( @$ip_data ) {
      local $@;
      eval {
        $api->regist(
          +{
            rr => +{
              data => $r->{ip},
              name => $r->{name},
              type => q{A},
            },
          }
        );
      };
      warn $@ if $@;
    }
}
