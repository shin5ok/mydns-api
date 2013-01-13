#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use YAML;
use JSON;
use MyDNS::API;
use MyDNS::API::Domain;

our $yaml_file = exists $ENV{MYDNS_API_CONFIG}
               ? $ENV{MYDNS_API_CONFIG}
               : q{config.yaml};

helper r => sub { Run->new };

helper mydns_domain => sub {
  my $self   = shift;
  my $domain = $self->param('domain');

  my $yaml = YAML::LoadFile($yaml_file);
  my $args = {
    domain      => $domain, 
    dsn         => $yaml->{dsn},
    db_user     => $yaml->{db_user},
    db_password => $yaml->{db_password},
  };
  my $mydns_domain = MyDNS::API::Domain->new($args);
  return $mydns_domain;
};

helper mydns => sub {
  my $self   = shift;

  my $yaml = YAML::LoadFile($yaml_file);
  my $args = {
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

  my $key   = $self->param('key');
  my $value = $self->param('value');

  my $query;
  if ($key and $value) {
    $query = +{ type => uc $key, data => $value };
  }

  my $mydns_domain   = $self->mydns;
  my @domains = $mydns_domain->search( $query );

  my $response = { result => 1, domain => \@domains };
  $self->render_json( $response );

};


get '/domain/(#domain)' => sub {
  my $self = shift;

  my $mydns_domain  = $self->mydns;
  my $domain = $self->param('domain');
  my $info   = $mydns_domain->zone_info( $domain );

  my $response = { result => 1, info => $info };
  $self->render_json( $response );

};

post '/clone/(#src_domain)/to/(#domain)' => sub {
  my $self = shift;

  my $body   = $self->req->body;
  my $params = decode_json $body;
  my $mydns_domain  = $self->mydns;
  my $r      = $self->r;

  my $src_domain = $self->param('src_domain');
  my $result     = $mydns_domain->zone_clone( $src_domain, { ip => $params->{ip} } );

  $r->result(1);

  $self->render_json( $r->run );

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



package Run 0.01 {
  use strict;
  use warnings;
  use Data::Dumper;

  use Class::Accessor::Lite ( rw => [ qw( result message data ) ] );

  sub new {
    my ($class, $app) = @_;
    bless {
       result  => 0,
       message => '',
       data    => '',
       app     => $app,
     
     };
   }

  sub run {
    my ($self, $hash_ref) = @_;

    my $result_hash_ref = +{};

    $result_hash_ref->{result}  = $self->result;
    $result_hash_ref->{message} = $self->message;
  
    $hash_ref and $self->data( $hash_ref );
    $result_hash_ref->{data} = $self->data || qq{},

    return $result_hash_ref;
  
  }
};


__DATA__
@@ exception.json.ep
{"result":0,"message":"raise exception <%= $exception %>"}
