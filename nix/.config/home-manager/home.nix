{config, pkgs, ...}: 
let
  username = builtins.getEnv "USER";
  homeDirectory = builtins.getEnv "HOME";
in {
  home.username = if username != "" then username else "chungsam";
  home.homeDirectory = if homeDirectory != "" then homeDirectory else "/home/chungsam";
  home.stateVersion = "23.11";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Packages to install
  home.packages = with pkgs; [
    # Basic tools
    ripgrep
    lazygit
    nodejs
    rustup
    tmux

    # Window manager and related
    waybar
    hyprpaper

    # Fonts
    nerd-fonts.inconsolata
  ];

  # Program-specific configurations
  programs = {
    tmux = {
      enable = true;
      escapeTime = 10;
      keyMode = "vi";
      prefix = "C-a";
      terminal = "screen-256color";
      baseIndex = 1;
      sensibleOnTop = false;
      customPaneNavigationAndResize = true;
      extraConfig = ''
        set -g focus-events on

        # setup seamless navigation between tmux & vim
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" "send-keys C-h"  "select-pane -L"
        bind-key -n 'C-j' if-shell "$is_vim" "send-keys C-j"  "select-pane -D"
        bind-key -n 'C-k' if-shell "$is_vim" "send-keys C-k"  "select-pane -U"
        bind-key -n 'C-l' if-shell "$is_vim" "send-keys C-l"  "select-pane -R"
        bind-key -n 'C-\' if-shell "$is_vim" "send-keys C-\\" "select-pane -l"

        tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'

        if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
        if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
            "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

        bind-key -n 'C-Space' if-shell "$is_vim" 'send-keys C-Space' 'select-pane -t:.+'
        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
        bind-key -T copy-mode-vi 'C-\' select-pane -l

        # sessionizer
        bind C-o display-popup -E "tms"
        bind f display-popup -E "tms switch"
        bind w display-popup -E "tms windows"
        bind -r '(' switch-client -p\; refresh-client -S
        bind -r ')' switch-client -n\; refresh-client -S

        # splitting and layout bindings
        bind '\' split-window -h
        bind '-' split-window -v
        bind '=' next-layout
        bind 'o' resize-pane -Z
        bind 'u' resize-pane -Z

        # resize bindings
        bind l resize-pane -R 25
        bind j resize-pane -D 10
        bind k resize-pane -U 10
        bind h resize-pane -L 25

        # other bindings
        bind-key C-d detach
        bind r source-file ~/.tmux.conf

        # visual settings
        set-option -g visual-activity off
        set-option -g visual-bell off
        set-option -g visual-silence off
        set-window-option -g monitor-activity off
        set-option -g bell-action none

        set-option -g status-position top

        # Catppuccin theme settings
        set -g @catppuccin_flavour 'frappe'
        set -g @catppuccin_window_left_separator "█"
        set -g @catppuccin_window_right_separator "█ "
        set -g @catppuccin_window_number_position "right"
        set -g @catppuccin_window_middle_separator "  █"
        set -g @catppuccin_window_default_fill "number"
        set -g @catppuccin_window_default_text "#W"
        set -g @catppuccin_window_current_fill "number"
        set -g @catppuccin_window_current_text "#W"
        set -g @catppuccin_status_modules_right "directory session date_time"
        set -g @catppuccin_status_left_separator  ""
        set -g @catppuccin_status_right_separator " "
        set -g @catppuccin_status_right_separator_inverse "yes"
        set -g @catppuccin_status_fill "all"
        set -g @catppuccin_status_connect_separator "no"
        set -g @catppuccin_date_time_text "%Y-%m-%d %H:%M:%S"
        set -g @catppuccin_directory_text "#{pane_current_path}"
      '';
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = catppuccin;
          extraConfig = "";
        }
      ];
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;  # For plugins that need Node.js
      withPython3 = true;  # For plugins that need Python
    };

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
    ".config/starship/starship.toml".source = config.lib.file.mkOutOfStoreSymlink ../../../starship/starship.toml;
  };

  # Set environment variables
  home.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    ZDOTDIR = "$XDG_CONFIG_HOME/zsh";
    # Ensure neovim can find its config
    NVIM_APPNAME = "nvim";
  };
}
