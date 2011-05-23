package App::SuperviseMe;
BEGIN {
  $App::SuperviseMe::VERSION = '0.001';
}

# ABSTRACT: very simple command superviser

use strict;
use warnings;
use Carp 'croak';

sub new {
  my ($class, %args) = @_;

  my $cmds = delete($args->{cmds}) || [];
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

__END__
=pod

=head1 NAME

App::SuperviseMe - very simple command superviser

=head1 VERSION

version 0.001

=head1 AUTHOR

Pedro Melo <melo@simplicidade.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2011 by Pedro Melo.

This is free software, licensed under:

  The Artistic License 2.0

=cut

