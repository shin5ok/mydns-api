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

my $domain = shift;
defined $domain or croak "*** domain is empty";

opts my $force  => { isa => 'Bool' };

my $ttl = 300;

my $domain_api   = $ENV{DOMAIN_API};

my $db_user      = $ENV{MYSQLD_USER};
my $db_password  = $ENV{MYSQLD_PASSWORD};
my $debug        = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

my $script_name = basename $0;
my $pre_data_md5_file = sprintf qq[/var/tmp/%s-%s.json], $script_name, $domain;

my $fh;
if (! -f $pre_data_md5_file) {
  open my $tmp_fh, ">", $pre_data_md5_file;
  flock $tmp_fh, 2;
  print {$tmp_fh} "0";
}

open $fh, "+<", $pre_data_md5_file;
# non blocking
if (! flock $fh, LOCK_EX | LOCK_NB ) {
  croak "*** lock error";
}
seek $fh, 0, 0;
chomp ( my $pre_md5 = do { local $/; <$fh>; } );

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

my $failure;
my $ua = LWP::UserAgent->new;

my $response = $ua->get( $domain_api );

if (! $response->is_success) {
  croak "*** $domain_api cannot be available";
}

my $content = $response->content;

my $ref = decode_json $response->content;
my $current_md5 = md5_hex ( join "\n", sort @{$ref->{data}} );

if ($current_md5 eq $pre_md5) {
  logging (qq{nothing done});
  exit 0;
}
logging (qq{$current_md5 ne $pre_md5});

no strict 'refs';
for my $r ( @{$ref->{data}} ) {
  $r->{uuid} or next;
  my $name = sprintf "%s.%s.", $r->{uuid}, $domain;
  $api->regist(
     +{
        rr => +{
          data => $r->{domain_ip},
          name => $name,
          type => q{A},
          ttl  => $ttl,
        },
      }
  )
  or $failure++;

  logging ( "$name is register" );

}

if (! $failure) {
  seek $fh, 0, 0;
  truncate $fh, 0;
  print {$fh} $current_md5;
  exit 0;
}
exit 1;


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


