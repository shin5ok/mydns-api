use strict;
use warnings;

package MyDNS::API 0.01 {
  use Carp;
  use Data::Dumper;
  use Class::Accessor::Lite (
    rw => [qw( db )],
  );
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

  sub regist {
    my ($self, $domain, $args) = @_;
    warn $domain;
    warn Dumper $args;

    $domain =~ /\.$/
      or $domain = qq{${domain}.};

    $domain =~ /\.$/
      or $domain = $domain . q{.};

    my $soa_rs = $self->db->resultset('Soa');
    warn Dumper $args;

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

        my ($zone) = $soa_rs->search({ origin => $domain });

        my $zone_id = $zone->id;
        $args->{rr}->{zone} = $zone_id;

        my $rr_rs = $self->db->resultset('Rr');
        $rr_rs->update_or_create($args->{rr}, { name => $name, type => $type, zone => $zone_id });

      } else {
        croak "*** name or type in rr is not found";

      }

    }
    return 1;

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
