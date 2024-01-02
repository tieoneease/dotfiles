## Setup
```
stow --target ~/.config .
```
or
```
git clone https://github.com/tieoneease/dotfiles.git ~/.config
```


### Dependencies
1. [install zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
2. install oh-my-zsh ```sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"```
3. [install ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
4. install kitty ```curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin``` 
5. install starship ```curl -sS https://starship.rs/install.sh | sh```
6. [install tmux](https://github.com/tmux/tmux/wiki/Installing)
7. [install neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md)
8. install yabai ```brew install koekeishiya/formulae/yabai``` 
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

### Initialization
Add these lines to your .zshenv:
```
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
```
