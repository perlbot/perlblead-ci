#!/bin/bash

# Make sure we have perlbrew env vars
source ~/perl5/perlbrew/etc/bashrc

# Don't let me use uninit vars, and any error is a problem
set -u
set -e


FREE=`df -k / | tail -n 1 | awk '{print $4}'`
IDENT="perlbot-blead-`date --iso-8601`"
MINSPACE=$(( 1024*1024 ))

export IDENT
echo Building blead as \'$IDENT\'

if [ $FREE -lt $MINSPACE ]; then
  echo "FAILED:  not enough free space. $FREE < $MINSPACE"
  exit 1
fi

timeout -k 1.1h 1h ./build_blead.sh
timeout -k 31m 30m ./install_cpan.sh
rm -f $PERLBREW_ROOT/perls/perlbot-blead-intest
ln -s $PERLBREW_ROOT/perls/$IDENT PERLBREW_ROOT/perls/perlbot-blead-intest
timeout -k 45m 40m prove
touch $PERLBREW_ROOT/perls/$IDENT/.perlbot_known_good
rm -f $PERLBREW_ROOT/perls/perlbot-evalperl
ln -s $PERLBREW_ROOT/perls/$IDENT PERLBREW_ROOT/perls/perlbot-evalperl
# systemctl restart perlbot-evalserver # restart the eval server
