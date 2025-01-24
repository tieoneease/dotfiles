{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      # Catppuccin Mocha theme
      background = "#1E1E2E";
      foreground = "#CDD6F4";
      
      # Normal colors
      palette-0 = "#45475A";  # surface1
      palette-1 = "#F38BA8";  # red
      palette-2 = "#A6E3A1";  # green
      palette-3 = "#F9E2AF";  # yellow
      palette-4 = "#89B4FA";  # blue
      palette-5 = "#F5C2E7";  # pink
      palette-6 = "#94E2D5";  # teal
      palette-7 = "#BAC2DE";  # subtext1
      
      # Bright colors
      palette-8 = "#585B70";   # surface2
      palette-9 = "#F38BA8";   # red
      palette-10 = "#A6E3A1";  # green
      palette-11 = "#F9E2AF";  # yellow
      palette-12 = "#89B4FA";  # blue
      palette-13 = "#F5C2E7";  # pink
      palette-14 = "#94E2D5";  # teal
      palette-15 = "#A6ADC8";  # subtext0
      
      # Font configuration
      font-family = "JetBrainsMono Nerd Font";
      font-size = 12;
      
      # Window configuration
      window-padding-x = 10;
      window-padding-y = 10;
      window-theme = "dark";
      
      # Terminal configuration
      cursor-style = "block";
      cursor-blink = true;
      mouse-hide-while-typing = true;
      
      # Shell configuration
      shell = "zsh";
      
      # Performance
      vsync = true;
    };
  };
}
