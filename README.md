# Dotfiles

My personal dotfiles, now managed with Nix Home Manager.

## Quick Setup (Using Nix)

1. Clone the repository:
```bash
git clone git@github.com:tieoneease/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Install Nix (if not already installed):
```bash
curl -L https://nixos.org/nix/install | sh
# Restart your shell or source the nix profile
. ~/.nix-profile/etc/profile.d/nix.sh
```

3. Enable Flakes:
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

4. Install Home Manager:
```bash
nix run home-manager/master -- init --switch
```

5. Apply the configuration:
```bash
cd ~/dotfiles
nix --extra-experimental-features "nix-command flakes" run home-manager/master -- switch --flake ./nix#chungsam
```

That's it! Your dotfiles are now managed by Nix Home Manager.

## Manual Setup (Legacy Method)

If you prefer to use the traditional stow-based setup, follow these steps:

### Setup
```bash
git clone git@github.com:tieoneease/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --target ~/.config .
```

### Dependencies
1. [install zsh](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
2. install oh-my-zsh 
3. [install ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation)
4. install kitty 
```bash
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
``` 
5. install starship 
```bash
curl -sS https://starship.rs/install.sh | sh
```
6. [install tmux](https://github.com/tmux/tmux/wiki/Installing)
7. [install neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md)
8. install yabai 
```bash
brew install koekeishiya/formulae/yabai
``` 
9. install spacebar 
```bash
brew install cmacrae/formulae/spacebar
brew services start spacebar
```
10. install skhd 
```bash
  brew install koekeishiya/formulae/skhd
  skhd --start-service
```
11. [install nerdfonts](https://github.com/ryanoasis/nerd-fonts?tab=readme-ov-file#option-4-homebrew-fonts)
12. [install lazygit](https://github.com/jesseduffield/lazygit#installation)
13. [install nvm](https://github.com/nvm-sh/nvm)
14. install rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
15. install tmux-sessionizer
```bash
cargo install tmux-sessionizer
```
16. install nvm
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```
17. install waybar and hyprpaper
```bash
sudo pacman -S waybar
sudo pacman -S hyprpaper
```
18. MacOS Karabiner
brew install --cask karabiner-elements


### Initialization
Add these lines to your ~/.zshenv:
```bash
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
```

Add these lines to your ~/.zshrc:
```bash
eval "$(starship init zsh)"
```
Symlink tmux:
```bash
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
```
Setup sessionizer paths (use your own workspace paths):
```bash
tms config -p ~/Workspace ~/dotfiles
```
My personal workspace:
```bash
mkdir ~/Workspace
```

My Fonts (mac):
```bash
brew tap homebrew/cask-fonts         # You only need to do this once!
brew install font-inconsolata-go-nerd-font
```

Install all fonts if you want:
```bash
brew search '/font-.*-nerd-font/' | awk '{ print $1 }' | xargs -I{} brew install --cask {} || true
```

Arch:
```bash
sudo pacman -S ttf-inconsolata-go-nerd
```

Alternatively, run these commands (handles all the above for you):
```bash
echo "export XDG_CONFIG_HOME=\"\$HOME/.config\"" >> ~/.zshenv
echo "export ZDOTDIR=\"\$XDG_CONFIG_HOME/zsh\"" >> ~/.zshenv
echo "eval \"\$(starship init zsh)\"" >> ~/.zshrc
ln -s ~/.tmux/tmux.conf ~/.tmux.conf
mkdir ~/Workspace
tms config -p ~/Workspace ~/dotfiles
```

### Nice to haves (have not integrated here)
```bash
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
```bash
yay -S sddm-git sddm-sugar-candy-git python-pywal
yay -S warpd-git
```



### Ideas
### bluetooth on arch with pipewire: https://bbs.archlinux.org/viewtopic.php?id=288398 
For mac, maybe migrate to [sketchybar](https://github.com/felixkratz/sketchybar)

## Updating Configuration

To update your configuration after making changes:

```bash
cd ~/dotfiles
nix --extra-experimental-features "nix-command flakes" run home-manager/master -- switch --flake ./nix#chungsam
```

## Rolling Back

If something goes wrong, you can roll back to the previous generation:

```bash
home-manager generations
# Find the generation you want to roll back to
home-manager switch --flake /nix/store/xxx-home-manager-generation
```

## Configuration Structure

- `nix/` - Contains all Nix-related configurations
  - `flake.nix` - The main flake configuration
  - `home-manager/home.nix` - The home-manager configuration

## Additional Notes

- The configuration uses relative paths to maintain portability
- Some programs are managed by home-manager (zsh, starship)
- Other configurations are symlinked from the dotfiles repository
- All dependencies are automatically installed through Nix

### Environment Variables

These are now managed by home-manager in `home.nix`:
```nix
home.sessionVariables = {
  XDG_CONFIG_HOME = "$HOME/.config";
  ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
};
```

### My Personal Workspace
```bash
mkdir ~/Workspace
