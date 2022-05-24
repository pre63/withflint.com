{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?rev=41cc1d5d9584103be4108c1815c350e07c807036";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
          
          ghcVersion = "ghc922";

          haskellPackages = pkgs.haskell.packages.${ghcVersion}.override {
            overrides = self: super: {
              retry = pkgs.haskell.lib.dontCheck super.retry;
            };
          };

          gitVersion = if (self ? shortRev) then self.shortRev else "dirty";
      in {
        devShell = haskellPackages.shellFor {
          packages = pkgs: [
            self.packages.${system}.backend
          ];
          
          buildInputs = with pkgs; [
            elmPackages.elm-review
            elmPackages.elm-format
            elmPackages.elm-live
            elmPackages.elm
            haskellPackages.haskell-language-server
            haskellPackages.cabal-install
            haskellPackages.fourmolu_0_6_0_0
            cabal2nix
          ];
        };

        apps = rec {
          default = withflint;

          fix = {
            type = "app";
            program = "${self.packages.${system}.fix-script}";
          };

          format = {
            type = "app";
            program = "${self.packages.${system}.format-script}";
          };

          withflint = {
            type = "app";
            program = "${self.packages.${system}.withflint-script}";
          };
        };

        packages = rec {
          withflint-image = pkgs.dockerTools.buildImage {
            name = "withflint";

            contents = [
              withflint
              pkgs.glibcLocales
              pkgs.cacert
              pkgs.busybox
              pkgs.bash
            ];

            created = "now";
            
            tag = "latest";

            config = {
              EntryPoint = [ "/bin/withflint" ];
              Env = [
                "LANG=en_US.UTF-8"
                "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
              ];
            };
          };
          
          default = withflint;
          
          backend = haskellPackages.callPackage ./haskell/default.nix {
            name = "withflint-backend";
          };

          frontend = pkgs.callPackage ./elm/default.nix {
            name = "withflint-frontend";
          };

          withflint = pkgs.callPackage ./default.nix {
            inherit frontend gitVersion;
            backend = pkgs.haskell.lib.justStaticExecutables backend;
            name = "withflint";
          };

          withflint-script = pkgs.writeShellScript "withflint.sh" ''
            if test -f ".env"; then
              source .env
            fi
            
            ${withflint}/bin/withflint
          '';

          format-script = pkgs.writeShellScript "format.sh" ''
            ${pkgs.elmPackages.elm-format}/bin/elm-format elm/src --yes
          '';

          fix-script = pkgs.writeShellScript "fix.sh" ''
            ${pkgs.elmPackages.elm-review}/bin/elm-review --compiler ${pkgs.elmPackages.elm}/bin/elm --fix-all --elmjson elm/elm.json
          '';
        };
      }
    );
}
