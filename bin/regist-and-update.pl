#!/usr/bin/env perl
use warnings;
use strict;
use MyDNS::API::Domain;

my $domain = shift;
my $name   = shift;
my $ip     = shift;

my $v = MyDNS::API::Domain->new( {
                           domain      => $domain,
                           dsn         => "dbi:mysql:mydns", 
                           db_user     => $ENV{MYSQLD_USER}, 
                           db_password => $ENV{MYSQLD_PASSWORD},
                           auto_notify => 1,
                          });

$v->regist( { rr => { name => $name, data => $ip, type => 'A' } } );

