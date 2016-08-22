PANTS_RUBY_VERSIONS=${PANTS_RUBY_VERSIONS:-2.2.2}
PANTS_NODE_VERSIONS=${PANTS_NODE_VERSIONS:-v5.12.0}
PANTS_PYTHON_VERSIONS=${PANTS_PYTHON_VERSIONS:=2.7.5}

PANTS=${PANTS_REPO:-git@github.com:martinwalsh/pants.git}
PANTS_BRANCH=${PANTS_BRANCH:-master}

register 'types/fragment.sh'

## BORK! BORK! BORK!
ok brew
ok brew bork
ok brew git
ok git ${HOME}/.pants ${PANTS} --branch=${PANTS_BRANCH}
ok directory ${HOME}/bin
ok file ${HOME}/bin/pants files/pants --permissions=755

## NODE ENVIRONMENT
ok brew nvm
if did_update; then
  ok directory ${HOME}/.nvm
  ok fragment fragments/nvm.profile ${HOME}/.profile
  source fragments/nvm.profilE
  for PANTS_NODE_VERSION in $PANTS_NODE_VERSIONS; do
    nvm install $PANTS_NODE_VERSION
  done
fi

## RUBY ENVIRONMENT
ok brew rbenv
if did_update; then
  ok brew ruby-build
  if did_update; then
    ok fragment fragments/rbenv.profile ${HOME}/.profile
    source fragments/rbenv.profile
    for PANTS_RUBY_VERSION in $PANTS_RUBY_VERSIONS; do
      rbenv install --skip-existing ${PANTS_RUBY_VERSION}
    done
  fi
fi

## PYTHON ENVIRONMENT
ok brew pyenv
if did_update; then
  ok fragment fragments/pyenv.profile ${HOME}/.profile
  source fragments/pyenv.profile
  for python_version in $PANTS_PYTHON_VERSIONS; do
    pyenv install --skip-existing $python_version
    pyenv shell $python_version
    ok pip ipython
  done
  pyenv shell --unset
fi
