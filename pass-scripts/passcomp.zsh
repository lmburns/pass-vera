#!/usr/bin/env zsh

# desc: adds call to _pass-vera completion from _pass completion
# for whatever reason I cannot get it to work without this, unless I call pass-vera, which is not a command

[ -f "$HOME/.zshrc" ] && . $HOME/.zshrc
[ -f "$HOME/.config/zsh/.zshrc" ] && . $HOME/.config/zsh/.zshrc

whichcomp() {
    for 1; do
        ( print -raC 2 -- $^fpath/${_comps[$1]:?unknown command}(NP*$1*) )
    done
}

passcomp=$(whichcomp pass | cut -d' ' -f3)
[ ! -e $passcomp ] && echo "_pass completion not found" && exit 1

case "$1" in
  install|i|update|u)
    present="$(rg -Uq '^.*vera\)\n.*_pass-vera$\n.*;;$\n.*open\)\n.*_pass-open$\n.*;;$\n.*close\)\n.*_pass-close$\n.*;;$')"
    if [[ $? -eq 0 ]]; then
      printf "%b\n" "$(tput setaf 1)vera completion is already present"
      exit 1
    fi
    sed -i -Ee '/git:Call/a\\t\t\t\"vera:Call pass vera\"' -Ee '/show\|\*/i\\t\t\tvera\)\n\t\t\t\t_pass-vera\n\t\t\t\t\;\;' $passcomp
    sed -i -Ee '/vera:Call pass vera/a\\t\t\t\"open:Call pass open to open vera\"' -Ee '/show\|\*/i\\t\t\topen\)\n\t\t\t\t_pass-open\n\t\t\t\t\;\;' $passcomp
    sed -i -Ee '/open:Call pass open/a\\t\t\t\"close:Call pass close to close vera\"' -Ee '/show\|\*/i\\t\t\tclose\)\n\t\t\t\t_pass-close\n\t\t\t\t\;\;' $passcomp

    printf "%b\n" "$(tput setaf 2)Finished updating _pass completion with vera"
    ;;
  uninstall|remove|rm|r)
    sed -i -E '/vera:Call pass vera/d; /open:Call pass open to open vera/d; /close:Call pass close to close vera/d' $passcomp
    sed -i '/vera)$/{N;N;d}; /open)$/{N;N;d}; /close)$/{N;N;d}' $passcomp

    printf "%b\n" "$(tput setaf 5)Finished removing vera from _pass completion"
    ;;
esac
