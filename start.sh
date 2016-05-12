#!/bin/bash

# Make sure we have perlbrew env vars
source ~/perl5/perlbrew/etc/bashrc

# Don't let me use uninit vars, and any error is a problem
set -u
set -e


FREE=`df -k / | tail -n 1 | awk '{print $4}'`
IDENT=${IDENT:-"perlbot-blead-`date --iso-8601`"}
MINSPACE=$(( 1024*1024 ))
REALPERL=${REALPERL:-"perl-blead"}

export REALPERL
export IDENT
echo Building $REALPERL as \'$IDENT\'

if [ $FREE -lt $MINSPACE ]; then
  echo "FAILED:  not enough free space. $FREE < $MINSPACE"
  exit 1
fi

./build_blead.sh
./install_cpan.sh
rm -f $PERLBREW_ROOT/perls/perlbot-intest
ln -s $PERLBREW_ROOT/perls/$IDENT $PERLBREW_ROOT/perls/perlbot-intest
prove
touch $PERLBREW_ROOT/perls/$IDENT/.perlbot_known_good
rm -f $PERLBREW_ROOT/perls/perlbot-evalperl
ln -s $PERLBREW_ROOT/perls/$IDENT $PERLBREW_ROOT/perls/perlbot-evalperl
# systemctl restart perlbot-evalserver # restart the eval server
