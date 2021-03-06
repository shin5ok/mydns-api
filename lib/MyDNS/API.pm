use strict;
use warnings;

package MyDNS::API 0.05 {
  use Carp;
  use Data::Dumper;
  use Class::Accessor::Lite (
    rw => [qw( db auto_notify changed db_user db_password dsn db_name )],
  );
  use IPC::Cmd qw(run);
  use POSIX q(strftime);
  use DBIx::Class;
  use Smart::Args;
  use DBIx::Class::Schema::Loader;
  use base qw(DBIx::Class::Schema::Loader);

  __PACKAGE__->loader_options(
       debug         => exists $ENV{DEBUG} ? $ENV{DEBUG} : 0,
       naming        => 'v4',
       relationships => 1
  );

  sub new {
    args my $class,
         my $dsn         => { isa => 'Str' },
         my $db_user     => { isa => 'Str',  optional => 1 },
         my $db_password => { isa => 'Str',  optional => 1 };

    my @args = ($dsn);
    push @args, $db_user     if defined $db_user;
    push @args, $db_password if defined $db_password;

    my $obj = bless {
                db      => $class->connect( @args ),
                changed => 0,
              }, $class;

    if ($dsn =~ /^dbi:mysql:([^;:]+)/) {
      $obj->db_name( $1 );
    }

    $obj->db_user    ( $db_user     || q{} );
    $obj->db_password( $db_password || q{} );
    $obj->dsn( $dsn );

    return $obj;

  }


  sub domain_search {
    my $self     = shift;
    my $rr_query = shift || qq{};

    my $rr_rs     = $self->db->resultset('Rr');
    my $soa_rs    = $self->db->resultset('Soa');
    my %id2domain = map { $_->id => $_->origin }
                    $soa_rs->search;

    my %domain;
    for my $rr ( $rr_rs->search( $rr_query ) ) {
      if (defined $rr) {
        my $zone = $rr->zone;
        exists $id2domain{$zone} or next;
        $domain{$id2domain{$zone}} = 1;
      }
    }

    my @domains = grep { $_ } keys %domain;

    return [@domains];

  }

}


1;
__END__

=head1 NAME

MyDNS::API - a mydns config module

=head1 SYNOPSIS

  use MyDNS::API;

=head1 DESCRIPTION

MyDNS::API is a module for mydns config

=head1 AUTHOR

Author E<lt>shin5ok@55mp.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
