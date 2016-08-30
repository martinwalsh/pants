PANTSDIR="${HOME}/.pants"

## BORK! BORK! BORK!
ok brew
ok brew bork

# The user-specific opt-in bork config file
ok directory $PANTSDIR
ok file ${PANTSDIR}/config files/config --permissions=755

## Files to be sourced
ok directory ${PANTSDIR}/profile
ok file ${PANTSDIR}/profile/nvm.profile files/profile/nvm.profile
ok file ${PANTSDIR}/profile/rbenv.profile files/profile/rbenv.profile
ok file ${PANTSDIR}/profile/pyenv.profile files/profile/pyenv.profile

## Complex bork recipes
ok directory ${PANTSDIR}/includes
ok file ${PANTSDIR}/includes/nvm files/includes/nvm
ok file ${PANTSDIR}/includes/rbenv files/includes/rbenv
ok file ${PANTSDIR}/includes/pyenv files/includes/pyenv

## A helper executable script for later updates
ok directory ${HOME}/bin
ok file ${HOME}/bin/pants files/pants --permissions=755
