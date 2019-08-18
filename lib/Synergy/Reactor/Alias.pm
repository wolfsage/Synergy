use v5.24.0;
use warnings;
package Synergy::Reactor::Alias;

use Moose;
use DateTime;
with 'Synergy::Role::Reactor::EasyListening';

use utf8;
use experimental qw(signatures);
use namespace::clean;
use List::Util qw(first);
use Synergy::Util qw(parse_time_hunk);
use Time::Duration::Parse;
use Time::Duration;

sub sort_id { 0 }

has aliases => (
  is => 'ro',
  isa     => 'HashRef',
  default => sub {  {}  },
  writer => '_set_aliases',
  traits  => [ 'Hash' ],
);

sub listener_specs ($reactor) {
  return (
    {
      name      => 'alias',
      method    => 'handle_alias',
      exclusive => 1,
      predicate => sub ($self, $e) {
        $e->was_targeted && $e->text =~ /^alias(\s+|\s*$)/i;
      },
    },
    {
      name      => 'unalias',
      method    => 'handle_unalias',
      exclusive => 1,
      predicate => sub ($self, $e) {
        $e->was_targeted && $e->text =~ /^unalias(\s+|\s*$)/i;
      },
    },
    {
      name      => 'process_alias',
      method    => sub { warn "Not possible\n" },
      predicate => \&process_alias,
    },
  );
}

sub process_alias ($self, $event) {
  return unless $event->from_user;

  my ($alias, $rest) = $event->text =~ /^([^\s]+)/;
  warn "checking $alias\n";
  return unless $alias;


  my $username = $event->from_user->username;
  return unless exists $self->reactor->aliases->{$username}->{$alias};
  warn "Got an alias\n";
  my $value = $self->reactor->aliases->{$username}->{$alias};
  warn "Value: $value\n";
  $event->mark_handled;

  $event->{text} = "$value" . ($rest ? " $rest" : "");

  warn "Processing $event->{text}\n";

  # Carry on
  return;
}

sub handle_unalias ($self, $event) {
  return unless $event->from_user;

  $event->mark_handled;

  my ($alias) = $event->text =~ /^unalias\s+(.*)$/i;
  return $event->reply("Usage: unalias <alias>") unless defined$alias;

  my $username = $event->from_user->username;
  my $value = delete $self->aliases->{$username}->{$alias};
  return $event->reply("No such alias '$alias'") unless defined $value;

  $self->save_state;
  return $event->reply("Alias '$alias' deleted");
}

sub handle_alias ($self, $event) {
  return unless $event->from_user;

  $event->mark_handled;

  return $self->list_aliases($event) if $event->text =~ /^alias\s*$/i;

  my ($alias, $set, $value) = $event->text =~ /^alias\s+([^\s=]+)(?:(=)?(.*?))?$/i;

  if ($set) {
    $self->set_alias($event, $alias => $value);
  } else {
    $self->describe_alias($event, $alias);
  }
}

sub list_aliases ($self, $event) {
  my $username = $event->from_user->username;

  my $replied;

  for my $alias (keys $self->{aliases}->{$username}->%*) {
    my $value = $self->{aliases}->{$username}->{$alias};
    $event->reply("$alias=$value");
    $replied++;
  }

  $event->reply("No aliases configured") unless $replied;

  return;
}

sub set_alias ($self, $event, $alias, $value) {
  my $username = $event->from_user->username;
  $self->aliases->{$username}->{$alias} = $value;
  $event->reply("Set $alias=$value");
  $self->save_state;
  return;
}

sub describe_alias ($self, $event, $alias) {
  my $username = $event->from_user->username;
  unless (exists $self->aliases->{$username}->{$alias}) {
    return $event->reply("No such alias '$alias'");
  }
  my $value = $self->aliases->{$username}->{$alias};
  $event->reply("$alias=$value");
  return;
}

sub state ($self) {
  return {
    aliases => $self->aliases,
  };
}

after register_with_hub => sub ($self, @) {
  if (my $state = $self->fetch_state) {
    if ($state->{aliases}) {
      $self->_set_aliases($state->{aliases});
    }
  }
};

1;
