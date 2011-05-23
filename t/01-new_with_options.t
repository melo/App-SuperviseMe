#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use App::SuperviseMe;
use IO::String;

my $sm = do {
  my $io = IO::String->new(<<"  EOF");
 x1
   
     # asdasdasd 
      x2 

  EOF
  local *STDIN = $io;
  App::SuperviseMe->new_from_options;
};

ok($sm, 'Got a SuperviseMe...');
is(ref($sm), 'App::SuperviseMe', '... of the proper type');
cmp_deeply(
  $sm->{cmds},
  [{cmd => 'x1',}, {cmd => 'x2',}],
  '... with the expected cmds list'
);

done_testing();
