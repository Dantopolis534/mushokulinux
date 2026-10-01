# =============================================================================
#  cyberArch-Dotfiles :: Mushoku Tensei
#  .config/fish/config.fish
# =============================================================================

fish_add_path $HOME/.local/bin $HOME/bin

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx XC_THEME mushoku-tensei
set -gx MT_PERSONAJE rudeus

# --- Prompt -------------------------------------------------------------------
set -g __mt_prompt_color '#5BC8FF'

function __mt_personaje
    if test -r ~/.config/shell/mushoku-personaje
        cat ~/.config/shell/mushoku-personaje | string trim
    else
        echo $MT_PERSONAJE
    end
end

function __mt_rune
    switch (__mt_personaje)
        case roxy      echo -e '\033[38;2;91;200;255m◈'
        case eris      echo -e '\033[38;2;255;95;86m✦'
        case sylphie   echo -e '\033[38;2;95;217;138m❈'
        case hitogami  echo -e '\033[38;2;155;123;212m✧'
        case lara      echo -e '\033[38;2;180;123;212m❖'
        case '*'       echo -e '\033[38;2;224;179;84m✧'
    end
end

function __mt_git
    if not type -q git
        return
    end
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        return
    end
    set -l branch (git symbolic-ref --short HEAD 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
    if test -z "$branch"
        return
    end
    set -l st (git status --porcelain --untracked-files=no 2>/dev/null)
    set -l a (count (string match -r '^\s*A' -- $st))
    set -l m (count (string match -r '^\s*M' -- $st))
    set -l d (count (string match -r '^\s*D' -- $st))
    set -l out "git:$branch"
    test $a -gt 0; and set out "$out \033[38;2;95;217;138m+$a"
    test $m -gt 0; and set out "$out \033[38;2;224;179;84m~$m"
    test $d -gt 0; and set out "$out \033[38;2;255;95;86m-$d"
    echo $out
end

function fish_prompt
    set -l cwd (prompt_pwd -d)
    echo
    echo -n (__mt_rune)' '
    echo -n '\033[38;2;91;200;255m'$USER
    echo -n '\033[38;2;142;154;184m@'
    echo -n '\033[38;2;91;200;255m'(hostname -s)
    echo -n '  \033[38;2;224;179;84m'"$cwd"
    set -l g (__mt_git)
    if test -n "$g"
        echo -n '  '"$g"
    end
    echo
    echo -n '\033[38;2;91;200;255m╭▊'
end
