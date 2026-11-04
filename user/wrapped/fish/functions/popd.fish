
function popd --description "Pop directory from the stack and cd to it"
    if count $argv >/dev/null
        switch $argv[1]
            case -h --h --he --hel --help
                __fish_print_help popd
                return 0
        end
    end

    if set -q DIRSTACK[1]
        cd $DIRSTACK[1]
        set -e DIRSTACK[1]
    else
        printf (_ "%s: Directory stack is empty…\n") popd 1>&2
        return 1
    end
end
