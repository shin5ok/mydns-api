use strict;
use warnings;

package MyDNS::API::Domain::Validate 0.01 {
  use Carp;
  use Data::Dumper;
  use DBIx::Class;
  use Smart::Args;

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

}

1;
