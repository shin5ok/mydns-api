#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Array::Diff;
use Array::Utils qw(unique);
use URI;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Fcntl qw(:flock);
use File::Basename;
use Carp;
use MyDNS::API::Domain;
use Sys::Syslog qw(:DEFAULT setlogsock);
use opts;

use lib qw( /usr/local/nagios/libexec/modules );
use HG::Escalation;

my $domain   = shift;
my @vlan_ids = @ARGV; # 同じ名前が後ろにあると上書きする
$domain       or croak "*** domain is empty";
@vlan_ids > 0 or croak "*** no vlan id";

opts my $cleanup => { isa => 'Bool' },
     my $force   => { isa => 'Bool' };

my $select_tag = exists $ENV{SELECT_TAG}
               ? $ENV{SELECT_TAG}
               : undef;

my $ttl = 300;

my $admin_key    = $ENV{MURAKUMO_ADMIN_KEY};
my $api_base_uri = $ENV{MURAKUMO_API_URI};
my $db_user      = $ENV{MYSQLD_USER};
my $db_password  = $ENV{MYSQLD_PASSWORD};
my $debug        = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

my $pre_data_md5_file = qq{/var/tmp/mydns-register.$domain.json};

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

my $api = MyDNS::API::Domain->new(
                                    {
                                      domain      => $domain,
                                      dsn         => 'dbi:mysql:database=mydns',
                                      db_user     => $db_user,
                                      db_password => $db_password,
                                    },
                                    {
                                      no_validate_domainname => 1,
                                    },
                                  );

my $ua = LWP::UserAgent->new;

my @dns_hostnames;
my $failure;
my $regist_total = 0;
my $regist_ok    = 0;
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
  logging( $response->content );

  my $json = $response->content;

  my $hash_ref    = decode_json $json;
  if (! $hash_ref->{result}) {
    warn $uri . " is api error";
    next;
  }

  my $ip_data_ref = $hash_ref->{data};
  my @ip_datas    = @$ip_data_ref;

  my $current_md5 = md5_hex $json;

  if (defined $select_tag) {
    @ip_datas = grep { $_->{tag} and $_->{tag} eq $select_tag }
                     @ip_datas;
  }

  push @dns_hostnames,
       (
         unique
         map  { $_->{name} }
         grep { ! $_->{secondary} }
         grep { defined $_->{name} }
         @ip_datas
       );

  if (exists $md5_ref->{vlan}->{$vlan_id}) {
    logging( "$md5_ref->{vlan}->{$vlan_id} eq $current_md5" );
    if (! $force) {
      $md5_ref->{vlan}->{$vlan_id} eq $current_md5
        and next VLAN_ID;
    }
  }

  $md5_ref->{vlan}->{$vlan_id} = $current_md5;

  if (@ip_datas == 0) {
    next VLAN_ID;
  }

  IP_DATA:
  for my $r ( @ip_datas ) {
    $r->{tag} //= qq{};

    $regist_total++;

    local $@;
    eval {
      logging( "try register $r->{name} at $domain" );
      $api->regist(
        +{
           rr => +{
             data => $r->{ip},
             name => $r->{name},
             type => q{A},
             ttl  => $ttl,
           },
        }
      )
      and $regist_ok++;
    };
    if ($@) {
      HG::Escalation->send_my_nrpe({ target => 'MYDNS_ERROR', log => $@, exit_status => 2, });
      $failure = 1;
      # エラーが出たら、データを初期化し、次回に更新を強制的に実行させる
      $md5_ref = {};
    }
  }

}


@dns_hostnames = sort unique @dns_hostnames;

# お掃除
if ($cleanup) {

  if (exists $md5_ref->{hostname}) {
    my @pre_dns_hostnames = sort unique @{$md5_ref->{hostname}};
    if (ref $md5_ref->{hostname} eq 'ARRAY') {
      my $diff = Array::Diff->diff( \@pre_dns_hostnames, \@dns_hostnames );

      for my $host ( unique sort @{$diff->deleted} ) {
        logging( "try remove $host at $domain" );
        $api->record_remove({ name => $host });

      }

    }
  }
}

# エラーがなく、mydnsの変更がされていたら
if (! $failure and $regist_total == $regist_ok) {

  seek $fh, 0, 0;
  truncate $fh, 0;
  $md5_ref->{hostname} = \@dns_hostnames;
  print {$fh} encode_json $md5_ref, "\n";

}

exit ( $failure ? 1 : 0 );


sub logging {
  my $string = shift;
  my $ident  = basename __FILE__;
  openlog $ident, 'ndelay,pid', 'local0';
  syslog 'info', $string;
  closelog;
  if ($debug) {
    warn "DEBUG: ", $string;
  }
}


