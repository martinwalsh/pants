PANTS_REPO="git@github.com:martinwalsh/pants.git"
PANTS_BRANCH="master"

ok brew
ok brew bork
ok brew git
ok git ~/.pants $PANTS_REPO --branch=${PANTS_BRANCH}
