## Setup
```
stow --target ~/.config .
```
or
```
git clone git@github.com:tieoneease/dotfiles.git ~/.config
```


### Dependencies
1. [install zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
2. install oh-my-zsh 
```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
3. [install ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
4. install kitty 
```
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
``` 
5. install starship 
```
curl -sS https://starship.rs/install.sh | sh
```
6. [install tmux](https://github.com/tmux/tmux/wiki/Installing)
7. [install neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md)
8. install yabai 
```
brew install koekeishiya/formulae/yabai
``` 
9. install spacebar 
```
brew install cmacrae/formulae/spacebar
brew services start spacebar
```
10. install skhd 
```
  brew install koekeishiya/formulae/skhd
  skhd --start-service
```
11. [install nerdfonts](https://github.com/ryanoasis/nerd-fonts?tab=readme-ov-file#option-4-homebrew-fonts)
12. [install lazygit](https://github.com/jesseduffield/lazygit#installation)
13. [install nvm](https://github.com/nvm-sh/nvm)
14. install rust
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
15. install tmux-sessionizer
```
cargo install tmux-sessionizer
```
16. install nvm
```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```
17. install waybar and hyprpaper
```
sudo pacman -S waybar
sudo pacman -S hyprpaper
```

### Initialization
Add these lines to your ~/.zshenv:
```
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
```

Add these lines to your ~/.zshrc:
```
eval "$(starship init zsh)"
```
Symlink tmux:
```
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
```
Setup sessionizer paths (use your own workspace paths):
```
tms config -p ~/Workspace ~/.config
```
My personal workspace:
```
mkdir ~/Workspace
```

My Fonts (mac):
```
brew tap homebrew/cask-fonts         # You only need to do this once!
brew install font-inconsolata-go-nerd-font
```

Install all fonts if you want:
```
brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true
```

Arch:
```
sudo pacman -S ttf-inconsolata-go-nerd
```

Alternatively, run these commands (handles all the above for you):
```
echo "export XDG_CONFIG_HOME=\"\$HOME/.config\"" >> ~/.zshenv
echo "export ZDOTDIR=\"\$XDG_CONFIG_HOME/zsh\"" >> ~/.zshenv
echo "eval \"\$(starship init zsh)\"" >> ~/.zshrc
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
mkdir ~/Workspace
tms config -p ~/Workspace ~/.config ~/dotfiles
```

### Nice to haves (have not integrated here)
```
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# in .zshrc
plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    extract
)
```



# Arch/Hyprland
```
yay -S sddm-git sddm-sugar-candy-git python-pywal
yay -S warpd-git
```


### Ideas

For mac, maybe migrate to [sketchybar](https://github.com/felixkratz/sketchybar)
