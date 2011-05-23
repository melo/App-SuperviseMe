#!perl

use strict;
use warnings;
use Test::More;
use Test::Deep;
use Test::Fatal;
use App::SuperviseMe;
use IO::String;

subtest 'basic constructor' => sub {
  my $sm;
  is(exception { $sm = App::SuperviseMe->new(cmds => ['a']) },
    undef, 'new() lives');
  ok($sm, '... got something back');
  is(ref($sm), 'App::SuperviseMe', '... of the proper type');
  cmp_deeply(
    $sm->{cmds},
    [{cmd => 'a'}],
    '... with the expected command list'
  );

  like(
    exception { App::SuperviseMe->new(cmds => []) },
    qr{^Missing 'cmds',},
    'new() dies with empty cmds list'
  );
  like(
    exception { App::SuperviseMe->new },
    qr{^Missing 'cmds',},
    'new() dies with no cmds list'
  );
};

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
