use v5.24.0;
use warnings;
package Synergy::Reactor::HelpSpot;

use Moose;
with 'Synergy::Role::Reactor';

use URI;
use URI::QueryParam;

use experimental qw(signatures);
use namespace::clean;

sub listener_specs {
  return;
}

has auth_token => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has api_uri => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

sub _http_get ($self, $param) {
  my $uri = URI->new($self->api_uri);

  $uri->query_form_hash($param);

  my $res = $self->hub->http_get(
    $uri,
    Authorization => 'Basic ' . $self->auth_token,
  );
}

sub helpspot_report ($self, $who) {
  return Future->done([ "not yet implemented" ]);
}

1;
