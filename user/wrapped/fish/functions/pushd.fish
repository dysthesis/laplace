# Exposes DIRSTACK for Starship.
function pushd --description 'Push directory to stack'
    set -l rot_r
    set -l rot_l

    if count $argv >/dev/null
        switch $argv[1]
            case -h --h --he --hel --help
                __fish_print_help pd
                return 0
        end

        if string match -qr '^-[0-9]+$' -- $argv[1]
            set rot_r (string sub -s 2 -- $argv[1])
        else if string match -qr '^\+[0-9]+$' -- $argv[1]
            set rot_l (string sub -s 2 -- $argv[1])
        end
    end

    set -q DIRSTACK
    or set -g -x DIRSTACK

    if not set -q argv[1]
        if not set -q DIRSTACK[1]
            echo "pd: no other directory"
            return 1
        end

        set -l top_dir $PWD
        set -l next_dir $DIRSTACK[1]

        set -g -x DIRSTACK[1] $top_dir
        cd $next_dir
        return
    end

    if test -n "$rot_l" -o -n "$rot_r"
        set -l stack $PWD $DIRSTACK

        if test -n "$rot_r"
            if test $rot_r -ge (count $stack)
                echo "pd: -$rot_r: directory stack index out of range"
                return 1
            end

            set rot_l (math (count $stack) - 1 - $rot_r)
        end

        if test $rot_l -ge (count $stack)
            echo "pd: +$rot_l: directory stack index out of range"
            return 1
        else
            if test $rot_l -gt 0
                set stack $stack[(math $rot_l + 1)..(count $stack)] $stack[1..$rot_l]
            end

            set -g -x DIRSTACK $stack[2..(count $stack)]
            cd $stack[1]
        end

        dirs
        return
    end

    set -l old_pwd $PWD
    cd $argv[1]; and set -g -x -p DIRSTACK $old_pwd
end
