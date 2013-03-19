use strict;
use warnings;

package MyDNS::API::Domain 0.01 {
  use Carp;
  use Data::Dumper;
  use IPC::Cmd qw(run);
  use POSIX q(strftime);
  use Smart::Args;

  use base qw( MyDNS::API );

  sub new {
    my ($class, $params) = @_;

    my $domain = delete $params->{domain};

    defined $domain
      or croak "*** domain name is not found";

    my $obj = $class->SUPER::new( $params );

    $obj->domain( $domain );

    if ($params->{auto_notify}) {
      $obj->{auto_notify} = $params->{auto_notify};

    }

    return $obj;

  }

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
    my $zone = $soa_rs->find({ origin => $self->domain });

    $zone or return q{};
    return $zone->id;

  }

  sub zone_clone {
    my ($self, $src_domain, $args) = @_;

    if (! $src_domain) {
      croak "*** clone src domain is empty";

    }

    $src_domain =~ /\.$/
      or $src_domain = $src_domain . ".";

    my $error = 0;

    my $dst_domain = $self->domain;

    my $txn       = $self->db->txn_scope_guard;
    my $soa_rs    = $self->db->resultset('Soa');


    my $dst_rs = $soa_rs->search( { origin => $dst_domain } );
    if ($dst_rs->count) {
      croak "*** error already $dst_domain is exist";

    }

    my ($src_soa) = $soa_rs->search( { origin => $src_domain } );

    if (not defined $src_soa) {
      croak "*** $src_domain for source is not found";
    }

    #*************************** 4. row ***************************
    #         id: 4
    #     origin: cloud.sq.mcnet.jp.
    #         ns: cloud.sq.mcnet.jp.
    #       mbox: postmaster.cloud.sq.mcnet.jp.
    #     serial: 488
    #    refresh: 300
    #      retry: 7200
    #     expire: 604800
    #    minimum: 86400
    #        ttl: 86400

    my %soa_param = (
       origin => $dst_domain,
       ns     => $src_soa->ns,
       mbox   => $src_soa->mbox,
       serial => (strftime "%Y%m%d00", localtime),
      refresh => $src_soa->refresh,
        retry => $src_soa->retry,
       expire => $src_soa->expire,
      minimum => $src_soa->minimum,
          ttl => $src_soa->ttl,
    );

    if (my $also_notify = $src_soa->can("also_notify")) {
      $soa_param{"also_notify"} = $src_soa->$also_notify;

    }

    $self->regist({ soa => \%soa_param })
      or $error = 1;

    my ($dst_soa) = $soa_rs->search({ origin => $dst_domain });

    #*************************** 62. row ***************************
    #  id: 208
    #zone: 4
    #name: managed-apache-test001
    #data: 203.211.191.2
    # aux: 0
    # ttl: 86400
    #type: A

    my $rr_rs = $self->db->resultset('Rr');

    my (@src_rres) = $rr_rs->search({ zone => $src_soa->id });

    no strict 'refs';
    for my $src_rr ( @src_rres ) {
      my $data = $src_rr->type eq 'A'
               ? $args->{ip}
               : $src_rr->data;

      $data =~ s/(\.?)${src_domain}(\.?)$/${1}${dst_domain}${2}/;

      my $name = $src_rr->name eq $src_domain
               ? $dst_domain
               : $src_rr->name;

      my %rr_param = (
        zone => $dst_soa->id,
        name => $name,
        data => $data || $src_rr->data,
        aux  => $src_rr->aux,
        type => $src_rr->type,

      );

      $self->regist({ rr => \%rr_param })
        or $error = 1;

    }

    if (! $error) {
      $txn->commit;
      return 1;

    } else {
      return 0;

    }

  }


  sub zone_info {
    my ($self) = @_;

    my $rr_rs  = $self->db->resultset('Rr');
    my $soa_rs = $self->db->resultset('Soa');

    my $id = $self->get_domain_id;

    if (! $id) {
      croak "*** domain not found";

    }

    my @infos = $rr_rs->search({ zone => $id });

    my $domain = $self->domain;

    my @zone_infos;
    for my $info ( @infos ) {
      my $zone_info = +{ $info->get_columns };

      if (! $zone_info->{name}) {
        $zone_info->{name} = $domain;
      }
      elsif ($zone_info->{name} !~ /\.$/) {
        $zone_info->{name} .= "." . $domain;
      }
      push @zone_infos, $zone_info;
    }

    return undef if @zone_infos == 0;
    return \@zone_infos;

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
  
      if ($rr->{type}) {

        my $name  = $rr->{name};
        my $type  = $rr->{type};

        my $zone_id = $self->get_domain_id;

        $args->{rr}->{zone} = $zone_id;

        my $rr_rs = $self->db->resultset('Rr');
        $rr_rs->update_or_create($args->{rr}, { name => $name, type => $type, zone => $zone_id });

        $self->changed(1);

      } else {
        croak "*** type for rr is not found";

      }

    }

    $self->changed and $self->serial_up;

  }


  sub zone_remove {
    my ($self) = @_;

    my $txn  = $self->db->txn_scope_guard;

    my $domain_id = $self->get_domain_id;

    my $rr_rs  = $self->db->resultset('Rr');
    my $soa_rs = $self->db->resultset('Soa');

    $rr_rs->search ({ zone => $domain_id })->delete;
    $soa_rs->search({ id   => $domain_id })->delete;

    if ($self->get_domain_id) {
      croak "*** domain remove failure";
    }

    $txn->commit;

  }

  sub serial_up {
    my $self = shift;

    my $sql = sprintf "update soa set serial = serial + 1 where origin = '%s'", $self->domain;
    my $dbh = $self->db->storage->dbh;
    $dbh->do($sql)
      or croak "*** error serial up";

  }


  sub send_notify {
    my $self   = shift;

    my $domain = $self->domain;

    # NS�쥳���� �����
    my $nameservers = qq{};

    my $rr_rs   = $self->db->resultset('Rr');
    my $zone_id = $self->get_domain_id;

    my @results = $rr_rs->search({ type => 'NS', zone => $zone_id });
    for my $result ( @results ) {
      my $ns = $result->data;
      if ($ns !~ /\.$domain$/ and $ns !~ /\.$/) {
        $ns .= ".${domain}";
      }

      $nameservers
        and $nameservers .= " ";

      $nameservers .= $ns;

    }

    my $r;
    if ($nameservers) {
      my $command = sprintf "zonenotify %s %s", $domain, $nameservers;
      $r = run(command => $command);

      exists $ENV{DEBUG} and warn $command;

      $r or warn "*** $command is failure";

    }


  }


  sub DESTROY {
    my $self = shift;

    if ($self->auto_notify and $self->changed) {
      exists $ENV{DEBUG}
        and warn "send notify auto";
      $self->send_notify;
    }

  }

}


1;
__END__

=head1 NAME

MyDNS::API::Domain -

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