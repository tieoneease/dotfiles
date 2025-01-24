{
  description = "Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:mitchellh/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ghostty, nixgl, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nixGLPrefix = "${nixgl.packages.${system}.nixGLIntel}/bin/nixGLIntel";
    in {
      homeConfigurations."chungsam" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ 
          ./home.nix
          {
            nixpkgs.overlays = [
              ghostty.overlays.default
              (final: prev: {
                ghostty = prev.ghostty.overrideAttrs (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];
                  postFixup = (old.postFixup or "") + ''
                    wrapProgram $out/bin/ghostty \
                      --prefix PATH : ${nixGLPrefix}
                  '';
                });
              })
            ];
          }
        ];
      };
    };
}
