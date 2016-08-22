# This type is inspired by thoughtbot's append_to_zsh
# in https://github.com/thoughtbot/laptop/blob/master/mac
ACTION=$1
LINE=$2
TARGET=$3
SKIP_NEWLINE=${4:-0}
shift 4

case "$ACTION" in
    desc)
        echo 'assert a line of text appears in a file, and append it if not.'
        echo "> ok lineinfile 'if which rbenv > /dev/null; then eval \"$(rbenv init -)\"; fi' ~/.profile"
        ;;

    status)
      if bake 'grep -Fqs "$LINE" "$TARGET"'; then
        return $STATUS_OK
      else
        return $STATUS_MISSING
      fi
    ;;

    install|upgrade)
      if [ "$SKIP_NEWLINE" -eq 1 ]; then
        bake 'printf "%s\n" "$LINE" >> "$TARGET"'
      else
        bake 'printf "\n%s\n" "$LINE" >> "$TARGET"'
      fi
    ;;

    *) return 1 ;;
esac
