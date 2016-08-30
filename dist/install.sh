#!/usr/bin/env bash
getDir () {
  fname=$1
  while [ -h "$fname" ]; do
    dir=$(cd -P "$(dirname "$fname")" && pwd)
    fname=$(readlink $fname)
    [[ $fname != /* ]] && fname="$dir/$fname"
  done
  echo "$(cd "$(dirname $fname)" && pwd -P)"
}
# used by loader to find core/ and stdlib/
BORK_SOURCE_DIR="$(cd $(getDir ${BASH_SOURCE[0]})/.. && pwd -P)"
BORK_SCRIPT_DIR=$PWD
BORK_WORKING_DIR=$PWD
operation="satisfy"
case "$1" in
  status) operation="$1"
esac
is_compiled () { return 0; }
arguments () {
  op=$1
  shift
  case $op in
    get)
      key=$1
      shift
      value=
      while [ -n "$1" ] && [ -z "$value" ]; do
        this=$1
        shift
        if [ ${this:0:2} = '--' ]; then
          tmp=${this:2}       # strip off leading --
          echo "$tmp" | grep -E '=' > /dev/null
          if [ "$?" -eq 0 ]; then
            param=${tmp%%=*}    # everything before =
            val=${tmp##*=}      # everything after =
          else
            param=$tmp
            val="true"
          fi
        if [ "$param" = $key ]; then value=$val; fi
        fi
      done
      [ -n $value ] && echo "$value"
      ;;
    *) return 1 ;;
  esac
}
bag () {
  action=$1
  varname=$2
  shift 2
  if [ "$action" != "init" ]; then
    length=$(eval "echo \${#$varname[*]}")
    last=$(( length - 1 ))
  fi
  case "$action" in
    init) eval "$varname=( )" ;;
    push) eval "$varname[$length]=\"$1\"" ;;
    pop) eval "unset $varname[$last]=" ;;
    read)
      [ "$length" -gt 0 ] && echo $(eval "echo \${$varname[$last]}") ;;
    size) echo $length ;;
    filter)
      index=0
      (( limit=$2 ))
      [ "$limit" -eq 0 ] && limit=-1
      while [ "$index" -lt $length ]; do
        line=$(eval "echo \${$varname[$index]}")
        if str_matches "$line" "$1"; then
          [ -n "$3" ] && echo $index || echo $line
          [ "$limit" -ge $index ] && return
        fi
        (( index++ ))
      done ;;
    find) echo $(bag filter $varname $1 1) ;;
    index) echo $(bag filter $varname $1 1 1) ;;
    set)
      idx=$(bag index $varname "^$1=")
      [ -z "$idx" ] && idx=$length
      eval "$varname[$idx]=\"$1=$2\""
      ;;
    get)
      line=$(bag filter $varname "^$1=" 1)
      echo "${line##*=}" ;;
    print)
      index=0
      while [ "$index" -lt $length ]; do
        eval "echo \"\${$varname[$index]}\""
        (( index++ ))
      done
      ;;
    *) return 1 ;;
  esac
}
bake () { eval "$*"; }
has_curl () {
    needs_exec "curl"
}
http_head_cmd () {
    url=$1
    shift 1
    has_curl
    if [ "$?" -eq 0 ]; then
        echo "curl -sI \"$url\""
    else
        echo "curl not found; wget support not implemented yet"
        return 1
    fi
}
http_header () {
    header=$1
    headers=$2
    echo "$headers" | grep "$header" | tr -s ' ' | cut -d' ' -f2
}
http_get_cmd () {
    url=$1
    target=$2
    has_curl
    if [ "$?" -eq 0 ]; then
        echo "curl -so \"$target\" \"$url\" &> /dev/null"
    else
        echo "curl not found; wget support not implemented yet"
        return 1
    fi
}
md5cmd () {
  case $1 in
    Darwin)
      [ -z "$2" ] && echo "md5" || echo "md5 -q $2"
      ;;
    Linux)
      [ -z "$2" ] && arg="" || arg="$2 "
      echo "md5sum $arg| awk '{print \$1}'"
      ;;
    *) return 1 ;;
  esac
}
satisfying () { [ "$operation" == "satisfy" ]; }
permission_cmd () {
  case $1 in
    Linux) echo "stat --printf '%a'" ;;
    Darwin) echo "stat -f '%Lp'" ;;
    *) return 1 ;;
  esac
}
STATUS_OK=0
STATUS_FAILED=1
STATUS_MISSING=10
STATUS_OUTDATED=11
STATUS_PARTIAL=12
STATUS_MISMATCH_UPGRADE=13
STATUS_MISMATCH_CLOBBER=14
STATUS_CONFLICT_UPGRADE=20
STATUS_CONFLICT_CLOBBER=21
STATUS_CONFLICT_HALT=25
STATUS_BAD_ARGUMENTS=30
STATUS_FAILED_ARGUMENTS=31
STATUS_FAILED_ARGUMENT_PRECONDITION=32
STATUS_FAILED_PRECONDITION=33
STATUS_UNSUPPORTED_PLATFORM=34
_status_for () {
  case "$1" in
    $STATUS_OK) echo "ok" ;;
    $STATUS_FAILED) echo "failed" ;;
    $STATUS_MISSING) echo "missing" ;;
    $STATUS_OUTDATED) echo "outdated" ;;
    $STATUS_PARTIAL) echo "partial" ;;
    $STATUS_MISMATCH_UPGRADE) echo "mismatch (upgradable)" ;;
    $STATUS_MISMATCH_CLOBBER) echo "mismatch (clobber required)" ;;
    $STATUS_CONFLICT_UPGRADE) echo "conflict (upgradable)" ;;
    $STATUS_CONFLICT_CLOBBER) echo "conflict (clobber required)" ;;
    $STATUS_CONFLICT_HALT) echo "conflict (unresolvable)" ;;
    $STATUS_BAD_ARGUMENT) echo "error (bad arguments)" ;;
    $STATUS_FAILED_ARGUMENTS) echo "error (failed arguments)" ;;
    $STATUS_FAILED_ARGUMENT_PRECONDITION) echo "error (failed argument precondition)" ;;
    $STATUS_FAILED_PRECONDITION) echo "error (failed precondition)" ;;
    $STATUS_UNSUPPORTED_PLATFORM) echo "error (unsupported platform)" ;;
    *)    echo "unknown status: $1" ;;
  esac
}
needs_exec () {
  [ -z "$1" ] && return 1
  [ -z "$2" ] && running_status=0 || running_status=$2
  path=$(bake "which $1")
  if [ "$?" -gt 0 ]; then
    echo "missing required exec: $1"
    retval=$((running_status+1))
    return $retval
  else return $running_status
  fi
}
platform=$(uname -s)
is_platform () {
  [ "$platform" = $1 ]
  return $?
}
platform_is () {
  [ "$platform" = $1 ]
  return $?
}
baking_platform=
baking_platform_is () {
  [ -z "$baking_platform" ] && baking_platform=$(bake uname -s)
  [ "$baking_platform" = $1 ]
  return $?
}
str_contains () {
  str_matches "$1" "^$2\$"
}
str_get_field () {
  echo $(echo "$1" | awk '{print $'"$2"'}')
}
str_item_count () {
  accum=0
  for item in $1; do
    ((accum++))
  done
  echo $accum
}
str_matches () {
  $(echo "$1" | grep -E "$2" > /dev/null)
  return $?
}
str_replace () {
  echo $(echo "$1" | sed -E 's|'"$2"'|'"$3"'|g')
}
bork_performed_install=0
bork_performed_upgrade=0
bork_performed_error=0
bork_any_updated=0
did_install () { [ "$bork_performed_install" -eq 1 ] && return 0 || return 1; }
did_upgrade () { [ "$bork_performed_upgrade" -eq 1 ] && return 0 || return 1; }
did_update () {
  if did_install; then return 0
  elif did_upgrade; then return 0
  else return 1
  fi
}
did_error () { [ "$bork_performed_error" -gt 0 ] && return 0 || return 1; }
any_updated () { [ "$bork_any_updated" -gt 0 ] && return 0 || return 1; }
_changes_reset () {
  bork_performed_install=0
  bork_performed_upgrade=0
  bork_performed_error=0
  last_change_type=
}
_changes_complete () {
  status=$1
  action=$2
  if [ "$status" -gt 0 ]; then bork_performed_error=1
  elif [ "$action" = "install" ]; then bork_performed_install=1
  elif [ "$action" = "upgrade" ]; then bork_performed_upgrade=1
  fi
  if did_update; then bork_any_updated=1 ;fi
  [ "$status" -gt 0 ] && echo "* failure"
}
destination () {
  echo "deprecation warning: 'destination' utility will be removed in a future version - use 'cd' instead" 1>&2
  cd $1
}
bag init include_directories
bag push include_directories "$BORK_SCRIPT_DIR"
include () {
    incl_script="$(bag read include_directories)/$1"
    if [ -e $incl_script ]; then
        target_dir=$(dirname $incl_script)
        bag push include_directories "$target_dir"
        case $operation in
            compile) compile_file "$incl_script" ;;
            *) . $incl_script ;;
        esac
        bag pop include_directories
    else
        echo "include: $incl_script: No such file" 1>&2
        exit 1
    fi
    return 0
}
_source_runner () {
  if is_compiled; then echo "$1"
  else echo ". $1"
  fi
}
_bork_check_failed=0
check_failed () { [ "$_bork_check_failed" -gt 0 ] && return 0 || return 1; }
_checked_len=0
_checking () {
  type=$1
  shift
  check_str="$type: $*"
  _checked_len=${#check_str}
  echo -n "$check_str"$'\r'
}
_checked () {
  report="$*"
  (( pad=$_checked_len - ${#report} ))
  i=1
  while [ "$i" -le $pad ]; do
    report+=" "
    (( i++ ))
  done
  echo "$report"
}
_conflict_approve () {
  if [ -n "$BORK_CONFLICT_RESOLVE" ]; then
    return $BORK_CONFLICT_RESOLVE
  fi
  echo
  echo "== Warning! Assertion: $*"
  echo "Attempting to satisfy has resulted in a conflict.  Satisfying this may overwrite data."
  _yesno "Do you want to continue?"
  return $?
}
_yesno () {
  answered=0
  answer=
  while [ "$answered" -eq 0 ]; do
    read -p "$* (yes/no) " answer
    if [[ "$answer" == 'y' || "$answer" == "yes" || "$answer" == "n" || "$answer" == "no" ]]; then
      answered=1
    else
      echo "Valid answers are: yes y no n" >&2
    fi
  done
  [[ "$answer" == 'y' || "$answer" == 'yes' ]]
}
ok () {
  assertion=$1
  shift
  _bork_check_failed=0
  _changes_reset
  fn=$(_lookup_type $assertion)
  if [ -z "$fn" ]; then
    echo "not found: $assertion" 1>&2
    return 1
  fi
  argstr=$*
  quoted_argstr=
  while [ -n "$1" ]; do
    quoted_argstr=$(echo "$quoted_argstr \"$1\"")
    shift
  done
  case $operation in
    echo) echo "$fn $argstr" ;;
    status)
      _checking "checking" $assertion $argstr
      output=$(eval "$(_source_runner $fn) status $quoted_argstr")
      status=$?
      _checked "$(_status_for $status): $assertion $argstr"
      [ "$status" -eq 1 ] && _bork_check_failed=1
      [ "$status" -ne 0 ] && [ -n "$output" ] && echo "$output"
      return $status ;;
    satisfy)
      _checking "checking" $assertion $argstr
      status_output=$(eval "$(_source_runner $fn) status $quoted_argstr")
      status=$?
      _checked "$(_status_for $status): $assertion $argstr"
      case $status in
        0) : ;;
        1)
          _bork_check_failed=1
          echo "$status_output"
          ;;
        10)
          eval "$(_source_runner $fn) install $quoted_argstr"
          _changes_complete $? 'install'
          ;;
        11|12|13)
          echo "$status_output"
          eval "$(_source_runner $fn) upgrade $quoted_argstr"
          _changes_complete $? 'upgrade'
          ;;
        20)
          echo "$status_output"
          _conflict_approve $assertion $argstr
          if [ "$?" -eq 0 ]; then
            echo "Resolving conflict..."
            eval "$(_source_runner $fn) upgrade $quoted_argstr"
            _changes_complete $? 'upgrade'
          else
            echo "Conflict unresolved."
          fi
          ;;
        *)
          echo "-- sorry, bork doesn't handle this response yet"
          echo "$status_output"
          ;;
      esac
      if did_update; then
        echo "verifying $last_change_type: $assertion $argstr"
        output=$(eval "$(_source_runner $fn) status $quoted_argstr")
        status=$?
        if [ "$status" -gt 0 ]; then
          echo "* $last_change_type failed"
          _checked "$(_status_for $status)"
          echo "$output"
        else
          echo "* success"
        fi
        return 1
      fi
      ;;
  esac
}
bag init bork_assertion_types
register () {
  file=$1
  type=$(basename $file '.sh')
  if [ -e "$BORK_SCRIPT_DIR/$file" ]; then
    file="$BORK_SCRIPT_DIR/$file"
  else
    exit 1
  fi
  bag set bork_assertion_types $type $file
}
_lookup_type () {
  assertion=$1
  if is_compiled; then
    echo "type_$assertion"
    return
  fi
  fn=$(bag get bork_assertion_types $assertion)
  if [ -n "$fn" ]; then
    echo "$fn"
    return
  fi
  bork_official="$BORK_SOURCE_DIR/types/$(echo $assertion).sh"
  if [ -e "$bork_official" ]; then
    echo "$bork_official"
    return
  fi
  local_script="$BORK_SCRIPT_DIR/$assertion"
  if [ -e "$local_script" ]; then
    echo "$local_script"
    return
  fi
  return 1
}
PANTSDIR="${HOME}/.pants"

## BORK! BORK! BORK!
type_brew () {
  action=$1
  name=$2
  shift 2
  from=$(arguments get from $*)
  if [ -z "$name" ]; then
    case $action in
      desc)
        echo "asserts presence of packages installed via homebrew on mac os x"
        echo "* brew                  (installs homebrew)"
        echo "* brew package-name     (instals package)"
        echo "--from=caskroom/cask    (source repository)"
        ;;
      status)
        baking_platform_is "Darwin" || return $STATUS_UNSUPPORTED_PLATFORM
        needs_exec "ruby" || return $STATUS_FAILED_PRECONDITION
        path=$(bake which brew)
        [ "$?" -gt 0 ] && return $STATUS_MISSING
        changes=$(cd /usr/local; git fetch --quiet; git log master..origin/master)
        [ "$(echo $changes | sed '/^\s*$/d' | wc -l | awk '{print $1}')" -gt 0 ] && return $STATUS_OUTDATED
        return $STATUS_OK
        ;;
      install)
        bake 'ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"'
        ;;
      upgrade)
        bake brew update
        ;;
      *) return 1 ;;
    esac
  else
    case $action in
      status)
        baking_platform_is "Darwin" || return $STATUS_UNSUPPORTED_PLATFORM
        needs_exec "brew" || return $STATUS_FAILED_PRECONDITION
        bake brew list | grep -E "^$name$" > /dev/null
        [ "$?" -gt 0 ] && return $STATUS_MISSING
        bake brew outdated | awk '{print $1}' | grep -E "^$name$" > /dev/null
        [ "$?" -eq 0 ] && return $STATUS_OUTDATED
        return 0 ;;
      install)
        if [ -z "$from" ]; then
          bake brew install $name
        else
          bake brew install $from/$name
        fi
        ;;
      upgrade) bake brew upgrade $name ;;
      *) return 1 ;;
    esac
  fi
}
ok brew
ok brew bork

# The user-specific opt-in bork config file
type_directory () {
  action=$1
  dir=$2
  shift 2
  case "$action" in
    desc)
      echo "asserts presence of a directory"
      echo "* directories ~/.ssh"
      ;;
    status)
      [ ! -e "$dir" ] && return $STATUS_MISSING
      [ -d "$dir" ] && return $STATUS_OK
      echo "target exists as non-directory"
      return $STATUS_CONFLICT_CLOBBER
      ;;
    install) bake mkdir -p $dir ;;
    *) return 1 ;;
  esac
}
ok directory $PANTSDIR
type_file () {
  action=$1
  targetfile=$2
  sourcefile=$3
  shift 3
  perms=$(arguments get permissions $*)
  owner=$(arguments get owner $*)
  _bake () {
    if [ -n "$owner" ]; then
      bake sudo $*
    else bake $*
    fi
  }
  file_varname="borkfiles__$(echo "$sourcefile" | base64 | sed -E 's|\+|_|' | sed -E 's|\?|__|' | sed -E 's|=+||')"
  case $action in
    desc)
      echo "asserts the presence, checksum, owner and permissions of a file"
      echo "* file target-path source-path [arguments]"
      echo "--permissions=755       permissions for the file"
      echo "--owner=owner-name      owner name of the file"
      ;;
    status)
      if ! is_compiled && [ ! -f $sourcefile ]; then
        echo "source file doesn't exist: $sourcefile"
        return $STATUS_FAILED_ARGUMENTS
      fi
      if [ -n "$owner" ]; then
        owner_id=$(bake id -u $owner)
        if [ "$?" -gt 0 ]; then
          echo "unknown owner: $owner"
          return $STATUS_FAILED_ARGUMENT_PRECONDITION
        fi
      fi
      bake [ -f $targetfile ] || return $STATUS_MISSING
      if is_compiled; then
        md5c=$(md5cmd $platform)
        sourcesum=$(echo "${!file_varname}" | base64 --decode | eval $md5c)
      else
        sourcesum=$(eval $(md5cmd $platform $sourcefile))
      fi
      targetsum=$(_bake $(md5cmd $platform $targetfile))
      if [ "$targetsum" != $sourcesum ]; then
        echo "expected sum: $sourcesum"
        echo "received sum: $targetsum"
        return $STATUS_CONFLICT_UPGRADE
      fi
      mismatch=
      if [ -n "$perms" ]; then
        existing_perms=$(_bake $(permission_cmd $platform) $targetfile)
        if [ "$existing_perms" != $perms ]; then
          echo "expected permissions: $perms"
          echo "received permissions: $existing_perms"
          mismatch=1
        fi
      fi
      if [ -n "$owner" ]; then
        existing_user=$(_bake ls -l $targetfile | awk '{print $3}')
        if [ "$existing_user" != $owner ]; then
          echo "expected owner: $owner"
          echo "received owner: $existing_user"
          mismatch=1
        fi
      fi
      [ -n "$mismatch" ] && return $STATUS_MISMATCH_UPGRADE
      return 0
      ;;
    install|upgrade)
      dirn=$(dirname $targetfile)
      [ "$dirn" != . ] && _bake mkdir -p $dirn
      [ -n "$owner" ] && _bake chown $owner $dirn
      if is_compiled; then
        _bake "echo \"${!file_varname}\" | base64 --decode > $targetfile"
      else
        _bake cp $sourcefile $targetfile
      fi
      [ -n "$owner" ] && _bake chown $owner $targetfile
      [ -n "$perms" ] && _bake chmod $perms $targetfile
      return 0
      ;;
    compile)
      if [ ! -f "$sourcefile" ]; then
        echo "fatal: file '$sourcefile' does not exist!" 1>&2
        exit 1
      fi
      if [ ! -r "$sourcefile" ]; then
        echo "fatal: you do not have read permission for file '$sourcefile'"
        exit 1
      fi
      echo "# source: $sourcefile"
      echo "# md5 sum: $(eval $(md5cmd $platform $sourcefile))"
      echo "$file_varname=\"$(cat $sourcefile | base64)\""
      ;;
    *) return 1 ;;
  esac
}
# source: files/config
# md5 sum: 5f8d157d5614996452c825bfa37c9959
borkfiles__ZmlsZXMvY29uZmlnCg="IyMgWW91IG5lZWQgdGhlc2UgYXBwcwpvayBicmV3IGdpdApvayBicmV3IGF3c2NsaQpvayBicmV3IGdudS10YXIKb2sgYnJldyB0cmVlCm9rIGJyZXcgcGFja2VyCm9rIGJyZXcgdGVycmFmb3JtCgpvayBjYXNrIGRvY2tlci10b29sYm94ICAjIGluY2x1ZGVzIHZpcnR1YWxib3gsIGRvY2tlciwgZG9ja2VyLW1hY2hpbmUsIGV0Yy4Kb2sgY2FzayB2YWdyYW50CgojIyBTb21lZGF5IHRoZXNlIG1heSBiZSByZXF1aXJlZCwgdW5jb21tZW50IHRvIGluc3RhbGwgdG9kYXkuCiMgb2sgY2FzayBqYXZhCiMgb2sgY2FzayBhcGFjaGUtZGlyZWN0b3J5LXN0dWRpbwoKIyMgWW91J2xsIHByb2JhYmx5IHdhbnQgdGhlc2UgYXBwcywgdW5jb21tZW50IHRvIGluc3RhbGwuCiMgb2sgYnJldyB2aW0KIyBvayBicmV3IHA3emlwCiMgb2sgYnJldyBubWFwCiMgb2sgYnJldyBiYXNoLWNvbXBsZXRpb24KIyBvayBicmV3IGJhc2gtZ2l0LXByb21wdAojIG9rIGJyZXcgZ251cGcKIyBvayBicmV3IGdwZy1hZ2VudAojIG9rIGJyZXcgc3FsaXRlCiMgb2sgYnJldyB3YXRjaAojIG9rIGJyZXcgZ2F3awojIG9rIGJyZXcgZ251LXNlZAojIG9rIGJyZXcgaHRvcAojIG9rIGJyZXcganEKCiMjIE1vcmUgYXBwcyB5b3UgbWF5IHdhbnQsIHVuY29tbWVudCB0byBpbnN0YWxsLgojIG9rIGNhc2sgZ29vZ2xlLWNocm9tZQojIG9rIGNhc2sgYXRvbQojIG9rIGNhc2sgaXRlcm0yCiMgb2sgY2FzayBkcm9wYm94CiMgb2sgY2FzayAxcGFzc3dvcmQKCiMjIE1hbmFnZSBBcHBTdG9yZSBhcHBzIHdpdGggaG9tZWJyZXcKIyBvayBtYXMKIyBvayBtYXMgPGFwcHN0b3JlIGlkPiAxcGFzc3dvcmQKCiMjIE5vZGUsIFB5dGhvbiBvciBSdWJ5IHZpcnR1YWwgZW52aXJvbm1lbnQsIHZlcnNpb24gbWFuYWdlcnMKCiMgUEFOVFNfTk9ERV9WRVJTSU9OUz0idjUuMTIuMCB2Ni41LjAiCiMgaW5jbHVkZSBpbmNsdWRlcy9udm0KClBBTlRTX1JVQllfVkVSU0lPTlM9IjIuMi4yIgppbmNsdWRlIGluY2x1ZGVzL3JiZW52CgojIFBBTlRTX1BZVEhPTl9WRVJTSU9OUz0iMi43LjUiCiMgaW5jbHVkZSBpbmNsdWRlcy9weWVudgo="
ok file ${PANTSDIR}/config files/config --permissions=755

## Files to be sourced
ok directory ${PANTSDIR}/profile
# source: files/profile/nvm.profile
# md5 sum: aa8b0a9b8030364e3ad469dc9d92b0a9
borkfiles__ZmlsZXMvcHJvZmlsZS9udm0ucHJvZmlsZQo="ZXhwb3J0IE5WTV9ESVI9IiRIT01FLy5udm0iCi4gIiQoYnJldyAtLXByZWZpeCBudm0pL252bS5zaCIK"
ok file ${PANTSDIR}/profile/nvm.profile files/profile/nvm.profile
# source: files/profile/rbenv.profile
# md5 sum: 2706a852806175b3f84e8ec721103d58
borkfiles__ZmlsZXMvcHJvZmlsZS9yYmVudi5wcm9maWxlCg="aWYgd2hpY2ggcmJlbnYgPiAvZGV2L251bGw7IHRoZW4gZXZhbCAiJChyYmVudiBpbml0IC0pIjsgZmkK"
ok file ${PANTSDIR}/profile/rbenv.profile files/profile/rbenv.profile
# source: files/profile/pyenv.profile
# md5 sum: 8f19aea13b19d1509f44f8b5e743e269
borkfiles__ZmlsZXMvcHJvZmlsZS9weWVudi5wcm9maWxlCg="aWYgd2hpY2ggcHllbnYgPiAvZGV2L251bGw7IHRoZW4gZXZhbCAiJChweWVudiBpbml0IC0pIjsgZmkK"
ok file ${PANTSDIR}/profile/pyenv.profile files/profile/pyenv.profile

## Complex bork recipes
ok directory ${PANTSDIR}/includes
# source: files/includes/nvm
# md5 sum: a2a7864eb0865e116e814c7d99040c98
borkfiles__ZmlsZXMvaW5jbHVkZXMvbnZtCg="IyEvYmluL2Jhc2gKUEFOVFNfTk9ERV9WRVJTSU9OUz0ke1BBTlRTX05PREVfVkVSU0lPTlM6LXY1LjEyLjAgdjYuNS4wfQoKb2sgYnJldyBudm0KaWYgZGlkX3VwZGF0ZTsgdGhlbgogIG9rIGRpcmVjdG9yeSAke0hPTUV9Ly5udm0KCiAgUFJPRklMRT0iJHtIT01FfS8ucGFudHMvcHJvZmlsZS9udm0ucHJvZmlsZSIKICBpZiAhIGdyZXAgLUZxcyAic291cmNlICRQUk9GSUxFIiAke0hPTUV9Ly5wcm9maWxlOyB0aGVuCiAgICBlY2hvICJzb3VyY2UgJFBST0ZJTEUiID4+ICR7SE9NRX0vLnByb2ZpbGUKICBmaQoKICBzb3VyY2UgJFBST0ZJTEUKICBmb3IgUEFOVFNfTk9ERV9WRVJTSU9OIGluICRQQU5UU19OT0RFX1ZFUlNJT05TOyBkbwogICAgbnZtIGluc3RhbGwgJFBBTlRTX05PREVfVkVSU0lPTgogIGRvbmUKZmkKCiMgdmltOiBzZXQgZnQ9c2gK"
ok file ${PANTSDIR}/includes/nvm files/includes/nvm
# source: files/includes/rbenv
# md5 sum: 750bfb1713952401ce7966b169a009b6
borkfiles__ZmlsZXMvaW5jbHVkZXMvcmJlbnYK="IyEvYmluL2Jhc2gKUEFOVFNfUlVCWV9WRVJTSU9OUz0ke1BBTlRTX1JVQllfVkVSU0lPTlM6LTIuMi4yIDIuMy4xfQoKb2sgYnJldyByYmVudiAgIyBydWJ5LWJ1aWxkIGlzIGluc3RhbGxlZCB3aXRoIHJiZW52PwppZiBkaWRfdXBkYXRlOyB0aGVuCiAgUFJPRklMRT0iJHtIT01FfS8ucGFudHMvcHJvZmlsZS9yYmVudi5wcm9maWxlIgogIGlmICEgZ3JlcCAtRnFzICJzb3VyY2UgJFBST0ZJTEUiICR7SE9NRX0vLnByb2ZpbGU7IHRoZW4KICAgIGVjaG8gInNvdXJjZSAkUFJPRklMRSIgPj4gJHtIT01FfS8ucHJvZmlsZQogIGZpCgogIHNvdXJjZSAkUFJPRklMRQogIGZvciBQQU5UU19SVUJZX1ZFUlNJT04gaW4gJFBBTlRTX1JVQllfVkVSU0lPTlM7IGRvCiAgICByYmVudiBpbnN0YWxsIC0tc2tpcC1leGlzdGluZyAkUEFOVFNfUlVCWV9WRVJTSU9OCiAgZG9uZQpmaQoKIyB2aW06IHNldCBmdD1zaAo="
ok file ${PANTSDIR}/includes/rbenv files/includes/rbenv
# source: files/includes/pyenv
# md5 sum: 0319b7c5760c336e32fe2fa00dc2ba93
borkfiles__ZmlsZXMvaW5jbHVkZXMvcHllbnYK="IyEvYmluL2Jhc2gKUEFOVFNfUFlUSE9OX1ZFUlNJT05TPSR7UEFOVFNfUFlUSE9OX1ZFUlNJT05TOi0yLjcuNX0KCm9rIGJyZXcgbnZtCmlmIGRpZF91cGRhdGU7IHRoZW4KICBvayBkaXJlY3RvcnkgJHtIT01FfS8ubnZtCgogIFBST0ZJTEU9IiR7SE9NRX0vLnBhbnRzL3Byb2ZpbGUvbnZtLnByb2ZpbGUiCiAgaWYgISBncmVwIC1GcXMgInNvdXJjZSAkUFJPRklMRSIgJHtIT01FfS8ucHJvZmlsZTsgdGhlbgogICAgZWNobyAic291cmNlICRQUk9GSUxFIiA+PiAke0hPTUV9Ly5wcm9maWxlCiAgZmkKCiAgc291cmNlICRQUk9GSUxFCiAgZm9yIFBBTlRTX1BZVEhPTl9WRVJTSU9OIGluICRQQU5UU19QWVRIT05fVkVSU0lPTlM7IGRvCiAgICBudm0gaW5zdGFsbCAkUEFOVFNfUFlUSE9OX1ZFUlNJT04KICBkb25lCmZpCgojIHZpbTogc2V0IGZ0PXNoCg=="
ok file ${PANTSDIR}/includes/pyenv files/includes/pyenv

## A helper executable script for later updates
ok directory ${HOME}/bin
# source: files/pants
# md5 sum: 09c7d02cccaafb5070b0c1ed1b479922
borkfiles__ZmlsZXMvcGFudHMK="IyEvYmluL2Jhc2gKIyB2aW06IGZ0PXNoCnNldCAtZW8gcGlwZWZhaWwKCkNPTkZJRz0iJHtIT01FfS8ucGFudHMvY29uZmlnIgoKY2FzZSAkezE6LXN0YXR1c30gaW4KICBpbnN0YWxsfHN0YXRpc2Z5fHVwZGF0ZXx1cGdyYWRlKQogICAgYm9yayBzYXRpc2Z5ICRDT05GSUcKICAgIDs7CiAgY2hlY2t8c3RhdHVzKQogICAgYm9yayBzdGF0dXMgJENPTkZJRwogICAgOzsKICAqKQogICAgZWNobyAiVXNhZ2U6ICQwIFtpbnN0YWxsfHN0YXR1c10iCiAgICBleGl0IDEKICAgIDs7CmVzYWMKCmV4aXQgMAo="
ok file ${HOME}/bin/pants files/pants --permissions=755
