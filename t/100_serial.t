use strict;
use warnings;
use Test::More;
use POSIX qw(strftime);
use File::Temp qw(tempfile);
use Data::Dumper;
use IPC::Open2;

BEGIN {
  use_ok("MyDNS::API::Domain::Serial");
};

my $datetime = strftime "%Y%m%d01", localtime;
my $domain   = q{example01.com};
my ($dbfh, $db_path) = tempfile();

my $arg = +{ domain => $domain, db_path => $db_path };
{
  local $Data::Dumper::Terse = 1;
  diag( Dumper $arg );
}

ok( _create_test_db($db_path), "$db_path is create");


my $obj = MyDNS::API::Domain::Serial->new( $arg );

isa_ok( $obj, "MyDNS::API::Domain::Serial");
isa_ok( $obj, "DBIx::Class::Schema::Loader");

ok(! $obj->serial);

ok( $obj->serial($datetime), "set $datetime" );

is( $obj->serial, $datetime, "validate $datetime to set serial" );

$datetime++;

ok( $obj->serial($datetime), "set $datetime(update)" );
is( $obj->serial, $datetime, "validate $datetime to set serial(update)" );

done_testing;

sub _db_dumper {
"
CREATE TABLE zone_serial (
  origin char(255) NOT NULL,
  serial int(10) NOT NULL,
  PRIMARY KEY (origin)
);
"
}

sub _create_test_db {
  my $pid = open2 my $r, my $w, "sqlite3", $db_path;

  diag(_db_dumper());
  if ($pid > 0) {
    print {$w} _db_dumper();
    print {$w} ".quit\n";
    close $r;
    waitpid $pid, 0;
    return ($? >> 8) == 0;
  }
}

END {
  if (-f $db_path) {
    diag "$db_path is cleanup";
    unlink $db_path;
  }
}

