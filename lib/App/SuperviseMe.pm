package App::SuperviseMe;

# ABSTRACT: very simple command superviser

use strict;
use warnings;
use Carp 'croak';
use AnyEvent;

##############
# Constructors

sub new {
  my ($class, %args) = @_;

  my $cmds = delete($args{cmds}) || [];
  $cmds = [$cmds] unless ref($cmds) eq 'ARRAY';
  map { $_ = ref($_) ? $_ : {cmd => $_} } @$cmds;

  croak(q{Missing 'cmds',}) unless @$cmds;

  return bless {cmds => $cmds}, $class;
}

sub new_from_options {
  my ($class) = @_;

  _out('Enter commands to supervise, one per line');

  my @cmds;
  while (my $l = <STDIN>) {
    chomp $l;
    $l =~ s/^\s+|\s+$//g;
    next unless $l;
    next if $l =~ /^#/;

    push @cmds, {cmd => $l};
  }

  return $class->new(cmds => \@cmds);
}


################
# Start the show

sub run {
  my $self = shift;
  my $sv   = AE::cv;

  my $int_s =
    AE::signal 'INT' => sub { $self->_signal_all_cmds('INT'); $sv->send };
  my $term_s =
    AE::signal 'TERM' => sub { $self->_signal_all_cmds('TERM'); $sv->send };

  for my $cmd (@{$self->{cmds}}) {
    $self->_start_cmd($cmd);
  }

  $sv->recv;
}


##########
# Magic...

sub _start_cmd {
  my ($self, $cmd) = @_;
  _debug("Starting '$cmd->{cmd}'");

  my $pid = fork();
  if (!defined $pid) {
    _debug("fork() failed: $!");
    $self->_restart_cmd($cmd);
    return;
  }

  if ($pid == 0) {    ## Child
    $cmd = $cmd->{cmd};
    _debug("Exec'ing '$cmd'");
    exec($cmd);
    exit(1);
  }

  ## parent
  _debug("Watching pid $pid for '$cmd->{cmd}'");
  $cmd->{pid} = $pid;
  $cmd->{watcher} = AE::child $pid, sub { $self->_child_exited($cmd, @_) };

  return;
}

sub _child_exited {
  my ($self, $cmd, undef, $status) = @_;
  _debug("Child $cmd->{pid} exited, status $status: '$cmd->{cmd}'");

  delete $cmd->{watcher};
  delete $cmd->{pid};

  $cmd->{last_status} = $status >> 8;

  $self->_restart_cmd($cmd);
}

sub _restart_cmd {
  my ($self, $cmd) = @_;
  _debug("Restarting cmd '$cmd->{cmd}' in 1 second");

  my $t;
  $t = AE::timer 1, 0, sub { $self->_start_cmd($cmd); undef $t };
}

sub _signal_all_cmds {
  my ($self, $signal) = @_;
  _debug("Received signal $signal, exiting");
  for my $cmd (@{$self->{cmds}}) {
    next unless my $pid = $cmd->{pid};
    _debug("... sent signal $signal to $pid");
    kill($signal, $cmd->{pid}) if $pid;
  }
}


#########
# Loggers

sub _out {
  return unless -t \*STDOUT && -t \*STDIN;

  print @_, "\n";
}

sub _debug {
  return unless $ENV{SUPERVISE_ME_DEBUG};

  print STDERR "DEBUG [$$] ", @_, "\n";
}

sub _error {
  print "ERROR: ", @_, "\n";
  return;
}

1;
