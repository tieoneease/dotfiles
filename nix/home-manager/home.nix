{config, pkgs, ...}: {
  home.username = "chungsam";
  home.homeDirectory = "/home/chungsam";
  home.stateVersion = "23.11";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Packages to install
  home.packages = with pkgs; [
    # Basic tools
    ripgrep
    starship
    tmux
    neovim
    lazygit
    nodejs
    rustup

    # Window manager and related
    waybar
    hyprpaper

    # Fonts
    nerd-fonts.inconsolata
  ];

  # Program-specific configurations
  programs = {
    zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = ["git" "extract"];
      };
      initExtra = ''
        eval "$(starship init zsh)"
      '';
    };

    starship = {
      enable = true;
    };
  };

  # Keep your existing dotfiles using relative paths
  home.file = {
    ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink ../../../hypr;
    ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink ../../../waybar;
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink ../../../nvim;
    ".config/kitty".source = config.lib.file.mkOutOfStoreSymlink ../../../kitty;
    ".config/tmux".source = config.lib.file.mkOutOfStoreSymlink ../../../tmux;
    ".config/starship/starship.toml".source = config.lib.file.mkOutOfStoreSymlink ../../../starship/starship.toml;
  };

  # Set environment variables
  home.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
  };
}
