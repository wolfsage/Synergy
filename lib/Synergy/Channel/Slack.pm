use v5.24.0;
package Synergy::Channel::Slack;

use Moose;
use experimental qw(signatures);
use JSON::MaybeXS;

use Synergy::Event;
use Synergy::ReplyChannel;

use namespace::autoclean;

my $JSON = JSON->new->canonical;

with 'Synergy::Role::Channel';

has api_key => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);

has slack => (
  is => 'ro',
  isa => 'Synergy::External::Slack',
  lazy => 1,
  default => sub ($self) {
    Synergy::External::Slack->new(
      loop    => $self->loop,
      api_key => $self->api_key,
    );
  }
);

sub start ($self) {
  $self->slack->connect;

  $self->slack->client->{on_frame} = sub ($client, $frame) {
    return unless $frame;

    my $event;
    unless (eval { $event = $JSON->decode($frame) }) {
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

    my $from_user = $self->hub->user_directory->user_by_channel_and_address(
      $self->name, $event->{user}
    );

    my $from_username = $from_user
                      ? $from_user->username
                      : $self->slack->username($event->{user});

    # decode text
    my $me = $self->slack->own_name;
    my $text = $self->decode_slack_usernames($event->{text});

    $text =~ s/\A \@?($me)(?=\W):?\s*//x;
    my $was_targeted = !! $1;

    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&amp;/&/g;

    my $is_public = $event->{channel} =~ /^C/;
    $was_targeted = 1 if not $is_public;   # private replies are always targeted

    my $evt = Synergy::Event->new({
      type => 'message',
      text => $text,
      was_targeted => $was_targeted,
      is_public => $is_public,
      from_channel => $self,
      from_address => $event->{user},
      ( $from_user ? ( from_user => $from_user ) : () ),
      transport_data => $event,
    });

    my $rch = Synergy::ReplyChannel->new(
      channel => $self,
      default_address => $event->{channel},
      private_address => $event->{user},
      ( $is_public ? ( prefix => "$from_username: " ) : () ),
    );

    $self->hub->handle_event($evt, $rch);
  };
}

# TODO: re-encode these on reply?
sub decode_slack_usernames ($self, $text) {
  return $text =~ s/<\@(U[A-Z0-9]+)>/"@" . $self->slack->username($1)/ger;
}

sub send_text ($self, $target, $text) {
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;

  $self->slack->api_call("chat.postMessage", {
    text    => $text,
    channel => $target,
    as_user => 1,
  });
  return;
}

sub describe_event ($self, $event) {
  my $who = $event->from_user ? $event->from_user->username
                              : $self->slack->users->{$event->from_address}{name};

  my $channel_id = $event->transport_data->{channel};

  my $slack = $self->name;

  if ($channel_id =~ /^C/) {
    my $channel = $self->slack->channels->{$channel_id}{name};

    return "a message on #$channel from $who on slack $slack";
  } elsif ($channel_id =~ /^D/) {
    return "a private message from $who on slack $slack";
  } else {
    return "an unknown slack communication from $who on slack $slack";
  }
}

1;
