{ pkgs ? import <nixpkgs> {} }:

with pkgs; [
  nerd-fonts.fira-code
  nerd-fonts.jetbrains-mono
  nerd-fonts.hack
  nerd-fonts.sauce-code-pro  # This is the Nerd Fonts version of Source Code Pro
  nerd-fonts.roboto-mono
  nerd-fonts.ubuntu-mono
  nerd-fonts.droid-sans-mono
  nerd-fonts.meslo-lg
  # Adding Inconsolata variants
  nerd-fonts.inconsolata
  nerd-fonts.inconsolata-go
  nerd-fonts.inconsolata-lgc
]
