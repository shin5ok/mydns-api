#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use YAML;
use JSON;
use MyDNS::API;

our $yaml_file = exists $ENV{MYDNS_API_CONFIG}
               ? $ENV{MYDNS_API_CONFIG}
               : q{config.yaml};


helper mydns => sub {
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


app->renderer->default_format('json');

under sub {
  return 1;

};

get '/domain' => sub {
  my $self = shift;

};

post '/clone/(#src_domain)/to/(#domain)' => sub {
  my $self = shift;

  my $body   = $self->req->body;
  my $params = decode_json $body;
  my $mydns  = $self->mydns;

  my $src_domain = $self->param('src_domain');
  my $result     = $mydns->zone_clone( $src_domain, { ip => $params->{ip} } );

  my $response = +{ result => 0 };
  if ($result) {
    $response->{result} = 1;
  }

  $self->render_json( $response );

};

post '/send_notify/(#domain)' => sub {
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


__DATA__
@@ exception.json.ep
{"result":0,"message":"raise exception <%= $exception %>"}
