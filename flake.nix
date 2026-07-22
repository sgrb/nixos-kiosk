{
  description = "NixOS kiosk mode with greetd + qtile + bwrap sandbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    uinstall.url = "github:sgrb/nixos-unattended-install";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, uinstall, disko, ... }:
  let
    kioskFlakeModule = import ./modules/kiosk-flake.nix;
  in
  {
    flakeModules.default = args:
      kioskFlakeModule (args // { inherit uinstall disko; });

    nixosModules.kiosk = ./modules/kiosk.nix;
  };
}
