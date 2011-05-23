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


1;
