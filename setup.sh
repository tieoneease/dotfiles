# install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash 

# install zsh on ubuntu
sudo apt-get update && sudo apt-get -y install zsh

# install zsh on mac
brew install zsh

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# symlink zshrc
ln -s /home/$(whoami)/.config/dotfiles/zshrc ~/.zshrc
