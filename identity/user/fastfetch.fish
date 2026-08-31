function fastfetch --wraps fastfetch --description 'Fastfetch with the wallpaper-themed KaleidashOS logo'
    if set -q XDG_DATA_HOME
        set -l kaleidash_data_home "$XDG_DATA_HOME"
    else
        set -l kaleidash_data_home "$HOME/.local/share"
    end

    set -l kaleidash_logo "$kaleidash_data_home/kaleidash-os/kaleidash-mark.png"

    if not test -f "$kaleidash_logo"
        command fastfetch $argv
        return
    end

    if string match -q 'xterm-kitty*' -- "$TERM"
        command fastfetch \
            --logo "$kaleidash_logo" \
            --logo-type kitty-direct \
            --logo-width 28 \
            --logo-height 14 \
            --logo-padding-right 3 \
            $argv
    else
        command fastfetch \
            --logo "$kaleidash_logo" \
            --logo-type kitty \
            --logo-width 28 \
            --logo-height 14 \
            --logo-padding-right 3 \
            $argv
    end
end
