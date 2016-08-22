ACTION=$1
FRAGMENT=$2
TARGET=$3
shift 3

case "$ACTION" in
    desc)
        echo 'assert a fragment of text, read from a file,'
        echo 'can be found in another file in its entirety.'
        echo '> ok fragment fragment/nvm.profile ~/.profile'
        ;;

    status)
      bake IS_SUBSET=$(awk 'FNR == NR {a[$0]; next} $0 in a {delete a[$0]} END {if (length(a) == 0) {print "is_subset"}}' $FRAGMENT $TARGET)
      if [ "Xis_subsetX" == "X$(bake echo $IS_SUBSET)X" ]; then
        return $STATUS_OK
      else
        return $STATUS_MISSING
      fi
    ;;

    install|upgrade)
      bake cat $FRAGMENT >> $TARGET
      source $FRAGMENT
    ;;

    *) return 1 ;;
esac
