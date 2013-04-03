#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use URI;
use Data::Dumper;
use JSON;
use Fcntl qw(:flock);
use Cache::Memcached::Fast;
use File::Basename;
use Carp;
use MyDNS::API::Domain;

use lib qw( /usr/local/nagios/libexec/modules );
use HG::Escalation;

my $domain   = shift;
my @vlan_ids = @ARGV;
$domain       or croak "*** domain is empty";
@vlan_ids > 0 or croak "*** no vlan id";

my $managed_tag  = q{MANAGED};
my $ttl          = 300;

my $admin_key    = $ENV{MURAKUMO_ADMIN_KEY};
my $api_base_uri = $ENV{MURAKUMO_API_URI};
my $db_user      = $ENV{MYSQLD_USER};
my $db_password  = $ENV{MYSQLD_PASSWORD};
my $debug        = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

my $pre_data_md5_file = q{/var/tmp/mydns-register.json};

my $fh;
if (! -f $pre_data_md5_file) {
  open my $tmp_fh, ">", $pre_data_md5_file;
  flock $tmp_fh, 2;
  print {$tmp_fh} "{}\n";
}

open $fh, "+<", $pre_data_md5_file;
# non blocking
if (! flock $fh, LOCK_EX | LOCK_NB ) {
  croak "*** lock error";
}
seek $fh, 0, 0;
my $pre = do { local $/; <$fh>; };
my $md5_ref = decode_json $pre;

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

  my $current_md5 = md5_hex $json;

  if (exists $md5_ref->{$vlan_id}) {
    $md5_ref->{$vlan_id} eq $current_md5
      and next VLAN_ID;
  }

  $md5_ref->{$vlan_id} = $current_md5;

  my $hash_ref = decode_json $json;

  my $ip_data_ref = $hash_ref->{data};

  my @ip_datas = @$ip_data_ref;

  if (@ip_datas == 0) {
    next VLAN_ID;
  }

  for my $r ( @ip_datas ) {
    $r->{tag} //= qq{};

    $r->{secondary}           and next;
    $r->{tag} eq $managed_tag or  next;

    local $@;
    eval {
      $api->regist(
        +{
          rr => +{
            data => $r->{ip},
            name => $r->{name},
            type => q{A},
            ttl  => $ttl,
          },
        }
      );
    };
    if ($@) {
      HG::Escalation->send_my_nrpe({ target => 'MYDNS_ERROR', log => $@, exit_status => 2, });
      $failure = 1;
    }
  }

}

seek $fh, 0, 0;
truncate $fh, 0;
print {$fh} encode_json $md5_ref, "\n";

exit ( $failure ? 1 : 0 );

