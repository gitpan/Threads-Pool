#!/usr/bin/perl

use strict;

use ExtUtils::MakeMaker;

  WriteMakefile(
      NAME              => "Threads::Pool",
      VERSION_FROM      => "lib/Threads/Pool.pm",
  );

