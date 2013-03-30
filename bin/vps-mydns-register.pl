#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use URI;
use Data::Dumper;
use JSON;
use Carp;
use MyDNS::API::Domain;

use lib qw( /usr/local/nagios/libexec/modules );
use HG::Escalation;

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

my $failure;
VLAN_ID: for my $vlan_id ( @vlan_ids ) {

  my $uri = URI->new( qq{$api_base_uri/ip_with_name/$vlan_id} );
  $uri->query_form(
    admin_key => $admin_key,
  );

  warn $uri if $debug;

  my $response = $ua->get( $uri );

  if (! $response->is_success) {
    exit 1;
  }
  warn $response->content if $debug;

  my $json = $response->content;
  my $hash_ref = decode_json $json;

  my $ip_data_ref = $hash_ref->{data};

  my @ip_datas = @$ip_data_ref

  if (@ip_datas == 0) {
    next VLAN_ID;
  }

  for my $r ( @$ip_datas ) {
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
    if ($@) {
      # HG::Escalation->send_my_nrpe({ target => 'SITUS_ERROR', log => '*** config reload miss', exit_status => 2 });
      HG::Escalation->send_my_nrpe({ target => 'MYDNS_ERROR', log => $@, exit_status => 2, });
      $failure = 1;
    }
  }

}

exit ( $failure ? 1 : 0 );
