#!/bin/bash

set -u
set -e
# HACK UNTIL Net::DNS 1.06 is out.  Until then a broken test is in there
perlbrew exec --with $IDENT cpanm --verbose --notest Net::DNS
perlbrew exec --with $IDENT cpanm --verbose --installdeps /home/ryan/bots/perlbuut
