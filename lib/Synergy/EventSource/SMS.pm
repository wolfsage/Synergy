use v5.24.0;
package Synergy::EventSource::Slack;

use Moose;
use experimental qw(signatures);
use JSON::MaybeXS qw(encode_json decode_json);
use Net::Async::HTTP::Server

use namespace::autoclean;

with 'Synergy::EventSource';

has http_server => (
  is => 'ro',
  isa => 'Net::Async::Server::HTTP',
  lazy => 1,
  default => sub ($self) {
    my $http_server = Net::Async::HTTP::Server->new(
      on_request => \&_handle_sms,
    );

    $http_server->listen($self->listener_args->%*)->get;

    $http_server;
  },
);

has listener_args => (
  is => 'ro',
  isa => 'HashRef',
  required => 1,
);

sub _params_from_req ($self, $req) {
  use HTTP::Body;
  my $body = HTTP::Body->new(
    scalar $request->header('Content-Type'),
    scalar $request->header('Content-Length'),
  );
  $body->add( $req->body );

  return $body->param;
}

sub _handle_sms ($http_server, $request, @) {
  my $param = $self->_params_from_req($request);

  my $from = $param->{From} // '';

  my $who = $self->username_for_phone($from);

  unless ($param->{AccountSid} eq $config->{twilio}{sid} and $who) {
    $response->code(400);
    $response->content("Bad request");
    $kernel->call( 'httpd', 'DONE', $response );
    $self->info(sprintf "Bad request for %s from phone %s from IP %s",
      $request->uri->path_query,
      $from,
      $response->connection->remote_ip,
    );
    return;
  }

  my $text = $param->{Body};

  my $reply = q{};
  my $result = $self->_dispatch({
    how   => 'sms',
    who   => $who->username,
    where => [ $from, $param->{To} ],
    what  => $text,
    reply_buffer => \$reply,
  });

  if ($result && $result eq -1) {
    $response->code(200);
    my $dnc = $self->_does_not_compute($who);
    $self->sms($from, $dnc, $param->{To});
    $response->content(q{});
  } else {
    $response->code(200);
    $self->sms($from, $reply, $param->{To});
    $response->content(q{});
  }

  $kernel->call( 'httpd', 'DONE', $response );

  $self->info("Request from " . $response->connection->remote_ip . " " . $request->uri->path_query);

  my $evt = Synergy::Event->new({
    type => 'message',
    text => $event->{text},
    from => $self->slack->users->{$event->{user}},
  });

  my $rch = Synergy::ReplyChannel::Slack->new(
    slack => $self->slack,
    channel => $event->{channel},
  );

  $self->eventhandler->handle_event($evt, $rch);
}

1;

event _http_sms => sub {
  my ($kernel, $self, $request, $response, $dirmatch)
    = @_[ KERNEL, OBJECT, ARG0 .. ARG2 ];

};


      {
        DIR => '^/sms$',
        SESSION => 'Synergy',
        EVENT => '_http_sms',
      },
      {
        DIR => '^/alert.json$',
        SESSION => 'Synergy',
        EVENT => '_http_alert',

