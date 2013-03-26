#!/home/smc/bin/perl
use strict;
use warnings;
use Mojolicious::Lite;
use Carp;
use YAML;
use MojoX::Log::Log4perl;
use JSON;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use MyDNS::API;
use MyDNS::API::Domain;

our $yaml_file = exists $ENV{MYDNS_API_CONFIG}
               ? $ENV{MYDNS_API_CONFIG}
               : q{config.yaml};
my $config = YAML::LoadFile($yaml_file);
my $debug = exists $config->{debug} ? $config->{debug} : 0;

helper r => sub { Run->new };

helper mydns_domain => sub {
  my $self   = shift;
  my $domain = $self->param('domain');

  my $args = {
    domain      => $domain,
    dsn         => $config->{dsn},
    db_user     => $config->{db_user},
    db_password => $config->{db_password},
  };
  my $mydns_domain = MyDNS::API::Domain->new($args);
  return $mydns_domain;
};

helper mydns => sub {
  my $self   = shift;

  my $args = {
    dsn         => $config->{dsn},
    db_user     => $config->{db_user},
    db_password => $config->{db_password},
  };
  my $mydns = MyDNS::API->new($args);
  return $mydns;

};


app->renderer->default_format('json');
app->config({
              hypnotoad => {
                listen             => [ 'https://*:63001' ],
                workers            => 8,
                accepts            => 64,
                graceful_timeout   => 30,
                inactivity_timeout => 120,
              },
            });

if (not $debug) {
  app->log( MojoX::Log::Log4perl->new( $config->{log4perl_conf} ));
}

under sub {
  my ($self) = @_;

  if (exists $config->{allow_access}) {
    my $allow_ref = $config->{allow_access};
    my $address = $self->tx->remote_address;

    require Net::CIDR;
    if (Net::CIDR::cidrlookup($address, @$allow_ref)) {
      warn "$address is access ok" if $debug;
      $self->app->log->info("$address is access ok");
      return 1;
    } else {
      croak "*** disallow from $address";
    }

  }

  return 1;

};


# 条件に一致するドメインを探す
get '/domain' => sub {
  my $self = shift;

  my $key   = $self->param('key');
  my $value = $self->param('value');

  my $query;
  if ($key and $value) {
    $query = +{ type => uc $key, data => $value };
  }

  my $mydns   = $self->mydns;
  my @domains = $mydns->domain_search( $query );

  my $r = $self->r;
  $r->result(1);
  $r->data( \@domains );

  $self->render_json( $r->run );

};


get '/domain/(#domain)' => sub {
  my $self = shift;

  my $mydns_domain = $self->mydns_domain;
  my $domain       = $self->param('domain');
  my $no_zone_data = $self->param('no_zone_data');
  my $format       = $self->param('format') || qq{};

  my $r = $self->r;

  local $@;
  eval {

    if ($format ne 'bind') {
      my $info = $mydns_domain->zone_info;

      $r->result(1);
      if (! $no_zone_data) {
        $r->data( $info );
      }

    } else {
      my $zone_data = $mydns_domain->get_zone_bind_format;
      $r->result(1);
      $r->data( $zone_data );

    }

  };
  warn $@ if $@;

  $self->render_json( $r->run );

};


post '/clone/(#src_domain)/to/(#domain)' => sub {
  my $self = shift;

  my $body          = $self->req->body;
  my $params        = decode_json $body;
  my $mydns_domain  = $self->mydns_domain;
  my $r             = $self->r;

  my $src_domain = $self->param('src_domain');

  my $ip = exists $params->{ip}
         ? $params->{ip}
         : "";

  my $result = $mydns_domain->zone_clone(
                                           $src_domain, {
                                                          ip => $ip,
                                                        }
                                        );

  $r->result(1);

  $self->render_json( $r->run );

};

post '/domain/(#domain)' => sub {
  my $self = shift;

  my $body          = $self->req->body;
  my $params        = decode_json $body;

  no strict 'refs';
  my $result;
  if ($params->{mode} eq 'remove') {
    my $mydns_domain = $self->mydns_domain;
    $result = $mydns_domain->zone_remove;
  }

  my $r = $self->r;

  if ($result) {
    $r->result(1);
  }

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

app->start;


__DATA__
@@ exception.json.ep
% use Mojo::JSON;
% return Mojo::JSON->new->encode( { result => 0, message => $exception } );
