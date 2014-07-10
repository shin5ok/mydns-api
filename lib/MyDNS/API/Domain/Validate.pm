use strict;
use warnings;

package MyDNS::API::Domain::Validate 0.01 {
  use Carp;
  use Data::Dumper;
  use DBIx::Class;
  use Smart::Args;
  use Carp;

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
