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
ok git ~/.pants ${PANTS} --branch=${PANTS_BRANCH}
ok directory ~/bin
ok file ~/bin/pants files/pants --permissions=755

## NODE ENVIRONMENT
ok brew nvm
ok directory ~/.nvm
ok fragment fragments/nvm.profile ~/.profile
source ~/.profile
for PANTS_NODE_VERSION in $PANTS_NODE_VERSIONS; do
  nvm install $PANTS_NODE_VERSION
done

## RUBY ENVIRONMENT
ok brew rbenv
ok brew ruby-build
ok fragment fragments/rbenv.profile ~/.profile
source ~/.profile
for PANTS_RUBY_VERSION in $PANTS_RUBY_VERSIONS; do
  rbenv install --skip-existing ${PANTS_RUBY_VERSION}
done

## PYTHON ENVIRONMENT
ok brew pyenv
ok fragment fragments/pyenv.profile ~/.profile
source ~/.profile
for python_version in $PANTS_PYTHON_VERSIONS; do
  pyenv install --skip-existing $python_version
  pyenv shell $python_version
  ok pip ipython
done
pyenv shell --unset
