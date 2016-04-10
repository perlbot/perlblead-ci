#!/bin/bash

FREE=`df -k / | tail -n 1 | awk '{print $4}'`
IDENT="perlbot-blead-`date --iso-8601`"

echo freespace: $FREE k
echo ident: $IDENT

if [[ $FREE ]]

# Remove old blead tarball.  full clean might lose data we want to keep for now
rm -f ~/perl/perlbrew/dists/blead.tgz
perlbrew uninstall $IDENT
#ls ~/perl5/perlbrew/dists

perlbrew install blead --as $IDENT
