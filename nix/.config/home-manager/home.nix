{config, pkgs, ...}: 
let
  username = builtins.getEnv "USER";
  homeDirectory = builtins.getEnv "HOME";
in {
  imports = [
    ./neovim.nix
  ];

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
    zsh
    starship
    zsh-autosuggestions
    zsh-syntax-highlighting
    oh-my-zsh

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

    zsh = {
      enable = true;
      dotDir = ".config/zsh";
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      
      initExtraFirst = ''
        # Load oh-my-zsh
        export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
        source $ZSH/oh-my-zsh.sh

        # Initialize Starship
        eval "$(starship init zsh)"
      '';

      shellAliases = {
        ws = "cd ~/Workspace/";
        pg = "cd ~/Workspace/Playground";
        dl = "cd ~/Downloads/";
        dotfiles = "cd ~/dotfiles/";
        config = "cd ~/.config/";
        zshconfig = "nvim ~/.zshrc";
        nvimconfig = "nvim ~/.config/nvim";
        tml = "tmux ls";
        tma = "tmux a -t";
        tmk = "tmux kill-session -t";
        tmn = "tmux new -s";
        todos = "nvim ~/todos.todo";

        gs = "git status";
        ga = "git add";
        gp = "git push";
        gpo = "git push origin";
        gtd = "git tag --delete";
        gtdr = "git tag --delete origin";
        gr = "git branch -r";
        gplo = "git pull origin";
        gb = "git branch";
        gc = "git commit";
        gcm = "git commit -m";
        gd = "git diff";
        gco = "git checkout";
        gl = "git log";
        grs = "git remote show";
        glo = "git log --pretty=\"oneline\"";
        glol = "git log --graph --oneline --decorate";
      };

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "z" ];
      };
    };

    lazygit = {
      enable = true;
      settings = {
        gui = {
          theme = {
            lightTheme = false;
            activeBorderColor = ["#85c1dc" "bold"];
            inactiveBorderColor = ["#a5adce"];
            optionsTextColor = ["#85c1dc"];
            selectedLineBgColor = ["#414559"];
            selectedRangeBgColor = ["#414559"];
            cherryPickedCommitBgColor = ["#51576d"];
            cherryPickedCommitFgColor = ["#85c1dc"];
            unstagedChangesColor = ["#e78284"];
            defaultFgColor = ["#c6d0f5"];
            searchingActiveBorderColor = ["#85c1dc"];
          };
          nerdFontsVersion = "3";
          border = "rounded";
          mouseEvents = true;
          showFileTree = true;
          showRandomTip = false;
          showBottomLine = true;
        };
        git = {
          paging = {
            colorArg = "always";
            useConfig = false;
          };
          commit = {
            signOff = false;
          };
          merging = {
            manualCommit = false;
            args = "";
          };
          skipHookPrefix = "WIP";
          autoFetch = true;
          branchLogCmd = "git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --";
          allBranchesLogCmd = "git log --graph --all --color=always --abbrev-commit --decorate --date=relative  --pretty=medium";
          overrideGpg = false;
          disableForcePushing = false;
          parseEmoji = false;
        };
        update = {
          method = "prompt";
          days = 14;
        };
        confirmOnQuit = false;
        quitOnTopLevelReturn = true;
        keybinding = {
          universal = {
            quit = "q";
            quit-alt1 = "<c-c>";
            return = "<esc>";
            quitWithoutChangingDirectory = "Q";
            togglePanel = "<tab>";
            prevItem = "<up>";
            nextItem = "<down>";
            prevPage = ",";
            nextPage = ".";
            gotoTop = "<";
            gotoBottom = ">";
            prevBlock = "<left>";
            nextBlock = "<right>";
            jumpToBlock = ["1" "2" "3" "4" "5"];
            nextMatch = "n";
            prevMatch = "N";
            startSearch = "/";
            optionMenu = "x";
            edit = "e";
            new = "n";
            scrollUpMain = "<pgup>";
            scrollDownMain = "<pgdown>";
            scrollUpSelected = "<up>";
            scrollDownSelected = "<down>";
            refresh = "R";
            optionMenu-alt1 = "?";
            undo = "u";
            redo = "<c-r>";
            filteringMenu = "<c-s>";
            diffingMenu = "<c-e>";
            copyToClipboard = "y";
            submitEditorText = "<enter>";
            extrasMenu = "@";
            toggleWhitespaceInDiffView = "<c-w>";
            increaseContextInDiffView = "]";
            decreaseContextInDiffView = "[";
          };
        };
        os = {
          editCommand = "nvim";
          editCommandTemplate = "{{editor}} +{{line}} -- {{filename}}";
          openCommand = "nvim";
        };
      };
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        palette = "catppuccin_frappe";
        
        character = {
          success_symbol = "[[❯](sapphire) ](sapphire)";
          error_symbol = "[[❯](red) ](red)";
          vimcmd_symbol = "[❮](green)";
        };

        directory = {
          truncation_length = 4;
          style = "bold lavender";
        };

        git_branch = {
          symbol = " ";
          style = "bold mauve";
        };

        git_status = {
          style = "bold red";
        };

        cmd_duration = {
          min_time = 500;
          format = "took [$duration](peach)";
        };

        palettes.catppuccin_frappe = {
          rosewater = "#f2d5cf";
          flamingo = "#eebebe";
          pink = "#f4b8e4";
          mauve = "#ca9ee6";
          red = "#e78284";
          maroon = "#ea999c";
          peach = "#ef9f76";
          yellow = "#e5c890";
          green = "#a6d189";
          teal = "#81c8be";
          sky = "#99d1db";
          sapphire = "#85c1dc";
          blue = "#8caaee";
          lavender = "#babbf1";
          text = "#c6d0f5";
          subtext1 = "#b5bfe2";
          subtext0 = "#a5adce";
          overlay2 = "#949cbb";
          overlay1 = "#838ba7";
          overlay0 = "#737994";
          surface2 = "#626880";
          surface1 = "#51576d";
          surface0 = "#414559";
          base = "#303446";
          mantle = "#292c3c";
          crust = "#232634";
        };
      };
    };
  };

  # Keep your existing dotfiles using relative paths
  home.file = {
    ".config/hypr".source = config.lib.file.mkOutOfStoreSymlink ../../../hypr;
    ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink ../../../waybar;
    ".config/kitty".source = config.lib.file.mkOutOfStoreSymlink ../../../kitty;
  };

  # Set environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    XDG_CONFIG_HOME = "$HOME/.config";
    ZDOTDIR = "$HOME/.config/zsh";
    NVM_DIR = "$HOME/.config/nvm";
    SHELL = "${pkgs.zsh}/bin/zsh";
    NVIM_APPNAME = "nvim";
  };
}
