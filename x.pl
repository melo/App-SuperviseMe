use IO::String;

  my $io = IO::String->new(<<"  EOF");
 x1
   
     # asdasdasd 
      x2 

  EOF

local *STDIN = $io;
while (<>) {
  print "!!!!! $_";
}

