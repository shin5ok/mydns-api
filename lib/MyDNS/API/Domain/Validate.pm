use strict;
use warnings;

package MyDNS::API::Domain::Validate 0.01 {
  use Carp;
  use Data::Dumper;
  use DBIx::Class;
  use Smart::Args;
  use Carp;
  use Data::Validate::Domain qw( is_domain );
  use Data::Validate::IP qw( is_ipv4 is_ipv6 );
  use Class::Accessor::Lite ( rw => [qw( name data )] );

  sub new {
    args my $class,
         my $name => { isa => 'Str' },
         my $data => { isa => 'Str' };

    my $obj = bless {
                name => $name,
                data => $data,
              }, $class;

    return $obj;

  }

  sub valid_domain {
    return
      is_domain( shift, { domain_private_tld => qr/./ } );
  }

  sub srv_valid_domain {
    return
      is_domain( shift, {
                          domain_private_tld => qr/./,
                          domain_allow_underscore => 1,
                        },
                );

  }

  sub a {

  }

  sub mx {

  }

  sub aaaa {

  }

  sub ns {

  }

  sub cname {

  }

  sub srv {

  }

}

1;
