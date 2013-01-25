package App::SuperviseMe;

# ABSTRACT: very simple command superviser
# VERSION
# AUTHORITY

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
  for my $cmd (@$cmds) {
    $cmd = [$cmd] unless ref($cmd) eq 'ARRAY';
    $cmd = { cmd => $cmd };
  }

  croak(q{Missing 'cmds',}) unless @$cmds;

  return bless { cmds => $cmds }, $class;
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

    push @cmds, $l;
  }

  return $class->new(cmds => \@cmds);
}


################
# Start the show

sub run {
  my $self = shift;
  my $sv   = AE::cv;

  my $int_s = AE::signal 'INT' => sub { $self->_signal_all_cmds('INT', $sv); };
  my $term_s = AE::signal 'TERM' => sub { $self->_signal_all_cmds('TERM'); $sv->send };

  for my $cmd (@{ $self->{cmds} }) {
    $self->_start_cmd($cmd);
  }

  $sv->recv;
}


##########
# Magic...

sub _start_cmd {
  my ($self, $cmd) = @_;
  _debug("Starting '@{$cmd->{cmd}}'");

  my $pid = fork();
  if (!defined $pid) {
    _debug("fork() failed: $!");
    $self->_restart_cmd($cmd);
    return;
  }

  if ($pid == 0) {    ## Child
    $cmd = $cmd->{cmd};
    _debug("Exec'ing '@$cmd'");
    exec(@$cmd);
    exit(1);
  }

  ## parent
  _debug("Watching pid $pid for '@{$cmd->{cmd}}'");
  $cmd->{pid} = $pid;
  $cmd->{watcher} = AE::child $pid, sub { $self->_child_exited($cmd, @_) };

  return;
}

sub _child_exited {
  my ($self, $cmd, undef, $status) = @_;
  _debug("Child $cmd->{pid} exited, status $status: '@{$cmd->{cmd}}'");

  delete $cmd->{watcher};
  delete $cmd->{pid};

  $cmd->{last_status} = $status >> 8;

  $self->_restart_cmd($cmd);
}

sub _restart_cmd {
  my ($self, $cmd) = @_;
  _debug("Restarting cmd '@{$cmd->{cmd}}' in 1 second");

  my $t;
  $t = AE::timer 1, 0, sub { $self->_start_cmd($cmd); undef $t };
}

sub _signal_all_cmds {
  my ($self, $signal, $cv) = @_;
  _debug("Received signal $signal");
  my $is_any_alive = 0;
  for my $cmd (@{ $self->{cmds} }) {
    next unless my $pid = $cmd->{pid};
    _debug("... sent signal $signal to $pid");
    $is_any_alive++;
    kill($signal, $pid);
  }

  return if $cv and $is_any_alive;

  _debug('Exiting...');
  $cv->send if $cv;
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

__END__

=encoding utf8

=head1 SYNOPSIS

    my $superviser = App::SuperviseMe->new(
        cmds => [
          'plackup -p 3010 ./sites/x/app.psgi',
          'plackup -p 3011 ./sites/y/app.psgi',
          ['bash', '-c', '... bash script ...'],
        ],
    );
    $superviser->run;


=head1 DESCRIPTION

This module implements a multi-process supervisor.

It takes a list of commands to execute and starts each one, and then monitors
their execution. If one of the program dies, the supervisor will restart it
after a small 1 second pause.

You can send SIGTERM to the supervisor process to kill all childs and exit.

You can also send SIGINT (Ctrl-C on your terminal) to restart the processes. If
a second SIGINT is received and no child process is currently running, the
supervisor will exit. This allows you to tap Ctrl- C twice in quick succession
in a terminal window to terminate the supervisor and all child processes


=head1 METHODS

=head2 new

    my $supervisor = App::SuperviseMe->new( cmds => [...]);

Creates a supervisor instance with a list of commands to monitor.

It accepts a hash with the following options:

=over 4

=item cmds

A list reference with the commands to execute and monitor. Each command can be
a scalar, or a list reference.

=back


=head2 new_from_options

    my $supervisor = App::SuperviseMe->new_from_options;

Reads the list of commands to start and monitor from C<STDIN>. It strips
white-space from the beggining and end of the line, and skips lines that start
with a C<#>.

Returns the superviser object.


=head2 run

    $supervisor->run;

Starts the supervisor, start all the child processes and monitors each one.

This method returns when the supervisor is stopped with either a SIGINT or a
SIGTERM.


=head1 SEE ALSO

L<AnyEvent>


=cut
