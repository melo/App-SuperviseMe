package App::SuperviseMe;

# ABSTRACT: very simple command superviser

use strict;
use warnings;
use Carp 'croak';

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


sub _out {
  return unless -t \*STDOUT && -t \*STDIN;

  print @_, "\n";
}

1;
