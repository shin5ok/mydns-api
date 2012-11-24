#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;

use MyDNS::API;

my $domain = shift || "example.com";

my $api_key      = $ENV{MURAKUMO_API_KEY};
my $api_base_uri = $ENV{MURAKUMO_API_URI};
my $db_user      = $ENV{MYSQLD_USER};
my $db_password  = $ENV{MYSQLD_PASSWORD};

my $uri = URI->new( qq{$api_base_uri/ip/list} );
$uri->query_form(
  key => $api_key,
);

my $ua = LWP::UserAgent->new;
my $response = $ua->get( $uri );

my $json = $response->content;
my $hash_ref = decode_json $json;

my $ip_data = $hash_ref->{data};

my $api = MyDNS::API->new('dbi:mysql:database=mydns', $db_user, $db_password);

for my $vlan_id ( 101..106 ) {
  for my $ip (@{$ip_data->{$vlan_id}}) {
    $ip->{used} or next;
    $ip eq '1' and next;

    my $data = _get_data ( $ip->{used} );

    $api->regist(
      $domain,
      {
        rr => {
          data => $ip->{ip},
          name => $data->{name},
          type => q{A},

        },
      }
    );

  }
}


sub _get_data {
  my $uuid = shift;

  my $uri = URI->new( qq{$api_base_uri/vps/define/info/$uuid} );
  $uri->query_form(
    key => $api_key,
  );

  warn $uri;

  my $ua = LWP::UserAgent->new;
  my $response = $ua->get( $uri );
  
  my $json = $response->content;
  my $hash_ref = decode_json $json;
  warn Dumper $hash_ref if exists $ENV{DEBUG};

  return $hash_ref->{data};

}


__END__
+-------+-----------------------------------------------------------------------------------+------+-----+---------+----------------+
| Field | Type                                                                              | Null | Key | Default | Extra          |
+-------+-----------------------------------------------------------------------------------+------+-----+---------+----------------+
| id    | int(10) unsigned                                                                  | NO   | PRI | NULL    | auto_increment |
| zone  | int(10) unsigned                                                                  | NO   | MUL | NULL    |                |
| name  | char(200)                                                                         | NO   |     | NULL    |                |
| data  | varbinary(128)                                                                    | NO   |     | NULL    |                |
| aux   | int(10) unsigned                                                                  | NO   |     | NULL    |                |
| ttl   | int(10) unsigned                                                                  | NO   |     | 86400   |                |
| type  | enum('A','AAAA','ALIAS','CNAME','HINFO','MX','NAPTR','NS','PTR','RP','SRV','TXT') | YES  |     | NULL    |                |
+-------+-----------------------------------------------------------------------------------+------+-----+---------+----------------+


