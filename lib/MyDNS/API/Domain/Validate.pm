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
    my $domain = shift;
    $domain =~ s/\.$//;
    return
      is_domain( $domain, { domain_private_tld => qr/./ } );
  }

  sub srv_valid_domain {
    my $domain = shift;
    $domain =~ s/\.$//;
    return
      is_domain( $domain, {
                          domain_private_tld => qr/./,
                          domain_allow_underscore => 1,
                        },
                );

  }

  sub a {
    args my $self;

    if (valid_domain($self->name) and is_ipv4($self->data)) {
      return 1;
    }
    return 0;

  }

  sub mx {
    args my $self;

    if (valid_domain($self->name) and valid_domain($self->data)) {
      return 1;
    }
    return 0;

  }

  sub aaaa {
    args my $self;

    if (valid_domain($self->name) and is_ipv6($self->data)) {
      return 1;
    }
    return 0;

  }

  sub ns {
    args my $self;

    if (valid_domain($self->name) and valid_domain($self->data)) {
      return 1;
    }
    return 0;

  }

  sub cname {
    args my $self;

    if (valid_domain($self->name) and valid_domain($self->data)) {
      return 1;
    }
    return 0;

  }

  sub srv {
    args my $self;

    if (srv_valid_domain($self->name)) {
      return 1;
    }
    return 0;

  }

  sub txt {
    args my $self;

    if (valid_domain($self->name)) {
      return 1;
    }
    return 0;

  }

}

1;
