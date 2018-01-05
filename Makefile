# fpTools Makefile

PREFIX=/usr/lib64/tcl

install:
  install src/fpTools.tcl ${PREFIX}
  echo "pkg_mkIndex -verbose ${PREFIX}" | tclsh

test:
  cd test
  $(MAKE) test

