#!/bin/bash

echo ident: $IDENT

# Remove old blead tarball.  full clean might lose data we want to keep for now
rm -f /home/ryan/perl5/perlbrew/dists/blead.tar.gz
perlbrew uninstall $IDENT
#ls ~/perl5/perlbrew/dists

perlbrew install blead --as $IDENT
