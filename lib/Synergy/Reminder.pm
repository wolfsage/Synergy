use v5.16.0;
package Synergy::Reminder;
use Moose;
use namespace::autoclean;
use Data::GUID;

has action => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

has 'time' => (
  is => 'ro',
  required => 1,
);

has reply_arg => (
  is => 'ro',
  isa => 'HashRef',
  required => 1,
);

has requested_time => (
  is => 'ro',
  isa => 'DateTime',
  required => 1,
);

has message => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

has guid => (
  is => 'ro',
  isa => 'Str',
  default => sub { Data::GUID->new->as_string },
);

1;
