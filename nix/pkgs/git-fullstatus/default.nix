{ perl
, git
, writeScriptBin
}:

# https://stackoverflow.com/a/53108053

writeScriptBin "git-fullstatus" ''
  #!${perl}/bin/perl

  use strict;

  # --ignored means something different to ls-files than to status
  my @ls_args = grep( ! m/^(-i|--ignored)/, @ARGV );

  my @files  = split( /\n/, `${git}/bin/git ls-files  @ls_args` );
  my @status = split( /\n/, `${git}/bin/git status -s @ARGV` );

  # merge the two sorted lists
  while (@files and @status) {
      $status[0] =~ m/^.. (.*)/;
      my $cmp = $1 cmp $files[0];
      if ($cmp <= 0) {
          print shift @status, "\n";
          if ($cmp == 0) {
              shift @files;
          }
      }
      else {
          print "   ", shift @files, "\n";
      }
  }
  # print remainder
  print map {"   $_\n"} @files;
  print map {"$_\n"} @status;
''
