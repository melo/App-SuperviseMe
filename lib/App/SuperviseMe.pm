package App::SuperviseMe;
BEGIN {
  $App::SuperviseMe::VERSION = '0.001';
}

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

    push @cmds, $l;
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



=pod

=head1 NAME

App::SuperviseMe - very simple command superviser

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    my $superviser = App::SuperviseMe->new(
        cmds => [
          'plackup -p 3010 ./sites/x/app.psgi',
          'plackup -p 3011 ./sites/y/app.psgi',
        ],
    );
    $superviser->run;

=head1 DESCRIPTION

This module implements a multi-process supervisor.

It takes a list of commands to execute and starts each one, and then
monitors their execution. If one of the program dies, the supervisor
will restart it after a small 1 second pause.

=head1 METHODS

=head2 new

    my $supervisor = App::SuperviseMe->new( cmds => [...]);

Creates a supervisor instance with a list of commands to monitor.

It accepts a hash with the following options:

=over 4

=item cmds

A list reference with the commands to execute and monitor.

=back

=head2 new_from_options

    my $supervisor = App::SuperviseMe->new_from_options;

Reads the list of commands to start and monitor from C<STDIN>. It strips
white-space from the beggining and end of the line, and skips lines that
start with a C<#>.

Returns the superviser object.

=head2 run

    $supervisor->run;

Starts the supervisor, start all the child processes and monitors each
one.

This method returns when the supervisor is stopped with either a SIGINT
or a SIGTERM.

=encoding utf8

=head1 SEE ALSO

L<AnyEvent>

=head1 AUTHOR

Pedro Melo <melo@simplicidade.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by Pedro Melo.

This is free software, licensed under:

  The Artistic License 2.0

=cut


__END__

