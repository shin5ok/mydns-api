use strict;
use warnings;

package MyDNS::API 0.03 {
  use Carp;
  use Data::Dumper;
  use Class::Accessor::Lite (
    rw => [qw( db auto_notify changed )],
  );
  use IPC::Cmd qw(run);
  use DBIx::Class;
  use Smart::Args;
  use DBIx::Class::Schema::Loader;
  use base qw(DBIx::Class::Schema::Loader);

  __PACKAGE__->loader_options(
       debug         => 0,
       naming        => 'v4',
       relationships => 1
  );

  sub new {
    args my $class,
         my $domain      => 'Str',
         my $dsn         => { isa => 'Str' },
         my $db_user     => { isa => 'Str',  optional => 1 },
         my $db_password => { isa => 'Str',  optional => 1 },
         my $auto_notify => { isa => 'Bool', optional => 1, default => 0 };

    my @args = ($dsn);
    push @args, $db_user     if defined $db_user;
    push @args, $db_password if defined $db_password;
         
    my $obj = bless {
                db          => $class->connect( @args ),
                changed     => 0,
                auto_notify => $auto_notify,
              }, $class;

    $obj->domain( $domain );

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

  sub domain {
     my $self   = shift;
     my $domain = shift;

    if (defined $domain) {
      $domain =~ /\.$/
        or $domain = $domain . q{.};
      $self->{domain} = $domain;

    }
    return $self->{domain};

  }


  sub get_domain_id {
    my $self = shift;

    my $soa_rs = $self->db->resultset('Soa');
    my ($zone) = $soa_rs->search({ origin => $self->domain });
    return $zone->id;

  }


  sub regist {
    my ($self, $args) = @_;

    my $domain = $self->domain;

    my $soa_rs = $self->db->resultset('Soa');

    if (exists $args->{soa}) {
      my $soa = $args->{soa};

      $soa->{origin} = $domain;

      $soa_rs->update_or_create($args->{soa}, { origin => $domain });

      $self->changed(1);

    }

    if (exists $args->{rr}) {
      my $rr = $args->{rr};

      if ($rr->{name} and $rr->{type}) {

        my $name  = $rr->{name};
        my $type  = $rr->{type};

        my $zone_id = $self->get_domain_id( domain => $domain );

        $args->{rr}->{zone} = $zone_id;

        my $rr_rs = $self->db->resultset('Rr');
        $rr_rs->update_or_create($args->{rr}, { name => $name, type => $type, zone => $zone_id });

        $self->changed(1);

      } else {
        croak "*** name or type in rr is not found";

      }

    }
    return 1;

  }


  sub send_notify {
    my $self   = shift;

    my $domain = $self->domain;

    # NSレコード を収集
    my $nameservers = qq{};

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

    my $r;
    if ($nameservers) {
      my $command = sprintf "zonenotify %s %s", $domain, $nameservers;
      $r = run(command => $command);

      $r or warn "*** $command is failure";

    }


  }


  sub DESTROY {
    my $self = shift;

    if ($self->auto_notify and $self->changed) {
      $self->send_notify;
    }

  }


}

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
