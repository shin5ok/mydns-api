use strict;
use warnings;

package MyDNS::Config 0.01 {
  use Carp;
  use Data::Dumper;
  use POSIX qw(strftime);

  sub config {
    {

      # +-------------+------------------+------+-----+---------+----------------+
      # | Field       | Type             | Null | Key | Default | Extra          |
      # +-------------+------------------+------+-----+---------+----------------+
      # | id          | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
      # | origin      | char(255)        | NO   | UNI | NULL    |                |
      # | ns          | char(255)        | NO   |     | NULL    |                |
      # | mbox        | char(255)        | NO   |     | NULL    |                |
      # | serial      | int(10) unsigned | NO   |     | 1       |                |
      # | refresh     | int(10) unsigned | NO   |     | 28800   |                |
      # | retry       | int(10) unsigned | NO   |     | 7200    |                |
      # | expire      | int(10) unsigned | NO   |     | 604800  |                |
      # | minimum     | int(10) unsigned | NO   |     | 86400   |                |
      # | ttl         | int(10) unsigned | NO   |     | 86400   |                |
      # | also_notify | char(255)        | YES  |     | NULL    |                |
      # +-------------+------------------+------+-----+---------+----------------+
      soa_default => +{
        serial  => (strftime "%Y%m%d00", localtime),
        refresh => 300,
        retry   => 300,
        expire  => 86400,
        ttl     => 300,
        minimum => 300,
      },
    }

  }

}


1;
__END__

=head1 NAME

MyDNS::Config - a mydns config module

=head1 SYNOPSIS

  use MyDNS::Config;

=head1 DESCRIPTION

MyDNS::API is a module for mydns config

=head1 AUTHOR

Author E<lt>shin5ok@55mp.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<>

=cut
