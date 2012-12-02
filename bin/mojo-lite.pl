#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use YAML;
use MyDNS::API;

our $yaml_file = exists $ENV{MYDNS_API_CONFIG}
               ? $ENV{MYDNS_API_CONFIG}
               : q{config.yaml};


helper model => sub {
  my $self   = shift;
  my $domain = $self->param('domain');

  my $yaml = YAML::LoadFile($yaml_file);
  my $args = {
    domain      => $domain, 
    dsn         => $yaml->{dsn},
    db_user     => $yaml->{db_user},
    db_password => $yaml->{db_password},
  };
  my $mydns = MyDNS::API->new($args);
  return $mydns;
};


under sub {
  return 1;

};

get '/domain' => sub {
  my $self = shift;

};

post '/domain/(#domain)' => sub {
  my $self = shift;

};

put '/domain/(#domain)' => sub {
  my $self = shift;

};

del '/domain/(#domain)' => sub {
  my $self = shift;

};

any '*' => sub {
  my $self = shift;

};

app->start;




