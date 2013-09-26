use strict;
use warnings;

package MyDNS::API::Domain::Serial 0.01 {
  use Carp;
  use Data::Dumper;
  use DBIx::Class;
  use Smart::Args;
  use Class::Accessor::Lite ( rw => [qw( domain db ) ] );
  use DBIx::Class::Schema::Loader;
  use base qw(DBIx::Class::Schema::Loader);

  __PACKAGE__->loader_options(
       debug         => 0,
       naming        => 'v4',
       relationships => 1
  );

  my $default_path = q{/root/.mydns-zone-serial.sqlite};

  sub new {
    args my $class,
         my $domain  => { isa => 'Str' },
         my $db_path => { isa => 'Str', optional => 1, default => $default_path };

    my $dsn = sprintf "dbi:SQLite:%s", $db_path;

    my $obj = bless {
                      domain => $domain,
                    }, $class;

    $obj->db( $class->connect( $dsn, q{}, q{} ) );

    return $obj;

  }

  sub serial {
    my $self  = shift;
    my $value = shift;

    my $removed_rs = $self->db->resultset('ZoneSerial');

    if (defined $value) {
      $removed_rs->update_or_create({
                                      origin => $self->domain,
                                      serial => $value,
                                    });
      return 1;

    } else {
      my $result = $removed_rs->find( $self->domain );
      return undef if not defined $result;
      return $result->serial;
    }

  }
}

1;
