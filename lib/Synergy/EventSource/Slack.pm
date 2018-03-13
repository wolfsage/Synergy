use v5.24.0;
package Synergy::EventSource::Slack;

use Moose;
use experimental qw(signatures);
use JSON::MaybeXS qw(encode_json decode_json);

use namespace::autoclean;

with 'Synergy::EventSource';

has slack => (
  is => 'ro',
  isa => 'Synergy::External::Slack',
  required => 1,
);

sub BUILD ($self, @) {
  $self->slack->client->{on_frame} = sub ($client, $frame) {
    return unless $frame;

    my $event;
    unless (eval { $event = decode_json($frame) }) {
      warn "ERROR DECODING <$frame> <$@>\n";
      return;
    }

    if ($event->{type} eq 'hello') {
      $self->slack->setup if $event->{type} eq 'hello';
      return;
    }

    # XXX dispatch these better
    return unless $event->{type} eq 'message';

    # This should go in the event handler, probably
    return if $event->{bot_id};
    return if $self->slack->username($event->{user}) eq 'synergy';

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
  };

  $self->slack->connect;
}

1;
