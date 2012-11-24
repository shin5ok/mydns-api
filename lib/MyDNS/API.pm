use strict;
use warnings;

package MyDNS::API 0.02 {
  use Carp;
  use Data::Dumper;
  use Class::Accessor::Lite (
    rw => [qw( db )],
  );
  use IPC::Cmd qw(run);
  use DBIx::Class;
  use DBIx::Class::Schema::Loader;
  use base qw(DBIx::Class::Schema::Loader);

  __PACKAGE__->loader_options(
       debug         => 0,
       naming        => 'v4',
       relationships => 1
  );

  sub new {
    my ($class, @args) = @_;

    my $db = $class->connect(@args);

    my $obj = bless {
                db     => $db,
              }, $class;

    return $obj;

  }

  # {
  #   soa => {
  #            origin  => $domain,
  #            ns      => $ns,
  #            mbox    => $mbox,
  #            serial  => $serial,
  #            refresh => $refresh,
  #            retry   => $retry,
  #            expire  => $expire,
  #            minimum => $minimum,
  #            ttl     => $ttl,
  #   },
  #   rr  => {
  #            zone => $zone,
  #            name => $name,
  #            data => $data,
  #            aux  => $aux || 0,
  #            ttl  => $ttl,
  #            type => $type,
  #   },
  # }

  sub get_domain_id {
    my ($self, $domain) = @_;

    my $soa_rs = $self->db->resultset('Soa');
    my ($zone) = $soa_rs->search({ origin => $domain });
    return $zone->id;

  }

  sub regist {
    my ($self, $domain, $args) = @_;
    warn $domain;
    warn Dumper $args;

    $domain =~ /\.$/
      or $domain = qq{${domain}.};

    $domain =~ /\.$/
      or $domain = $domain . q{.};

    my $soa_rs = $self->db->resultset('Soa');

    if (exists $args->{soa}) {
      my $soa = $args->{soa};

      $soa->{origin} = $domain;

      $soa_rs->update_or_create($args->{soa}, { origin => $domain });

    }

    if (exists $args->{rr}) {
      my $rr = $args->{rr};

      if ($rr->{name} and $rr->{type}) {

        my $name  = $rr->{name};
        my $type  = $rr->{type};

        my $zone_id = $self->get_domain_id( $domain );

        $args->{rr}->{zone} = $zone_id;

        my $rr_rs = $self->db->resultset('Rr');
        $rr_rs->update_or_create($args->{rr}, { name => $name, type => $type, zone => $zone_id });

      } else {
        croak "*** name or type in rr is not found";

      }

    }
    return 1;

  }


  sub send_notify {
    my $self   = shift;
    my $domain = shift;
    # NSレコード を収集

    my $nameservers = qq{}:

    my $rr_rs   = $self->db->resultset('Rr');
    my $zone_id = $self->get_domain_id( $domain );

    my @results = $rr_rs->search({ type => 'NS', zone => $zone_id });
    for my $result ( @results ) {
      my $ns = $result->data;
      $ns =~ /\.$domain$/
        or $ns .= ".${domain}";

      $nameservers
        and $nameservers .= " ";

      $nameservers .= $ns;

    }

    if ($nameservers) {
      my $command = sprintf "zonenotify %s %s", $domain, $nameservers;
      run(command => $command);
    }


  }


}

1;

1;
__END__

=head1 NAME

MyDNS::API -

=head1 SYNOPSIS

  use MyDNS::API;

=head1 DESCRIPTION

MyDNS::API is

=head1 AUTHOR

Author E<lt>shin5ok@55mp.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
