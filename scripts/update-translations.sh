#!/bin/bash

# Pre-requisites:
# 1. transifex authentication in ~/.transifexrc
# 2. github authentication in ~/.ssh/pioneer-transifex.id_rsa
#    2.1 add to config
#    Host pioneer-transifex-github
#      Hostname github.com
#      User git
#      IdentityFile ~/.ssh/pioneer-transifex.id_rsa

set -x
set -e

cd $HOME/pioneer

if [ "$1" = "init" ]
then
    git clone --depth=1 git@pioneer-transifex-github:pioneerspacesim/pioneer
    cd pioneer
    git config user.name 'Pioneer Transifex'
    git config user.email 'pioneer-transifex@pioneerspacesim.net'
else
    cd pioneer
    git fetch
    git reset --hard origin/master

    # push only our en.json strings to transifex (-s source, -t translation)
    tx push -s

    # (force) pull translations from transifex to machine
    # tx pull -a
    tx pull -t -f

    # remove transifex's indentation:
    for i in $(find data/lang -name '*.json')
    do
        jq -S . < $i > /tmp/${i//\//_}
        mv /tmp/${i//\//_} $i ;
    done

    git add data/lang/
    git commit -m 'auto-commit: translation updates'
    git push
fi
exit 0
