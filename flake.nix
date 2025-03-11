{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    secrets = {
      url = "github:regular/secrets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tre-cli-tools-nixos = {
      url = "github:regular/tre-cli-tools-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, systems, secrets, nixpkgs, ... }@inputs: let
    eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f {
      inherit system;
      pkgs = nixpkgs.legacyPackages.${system};
    });
  in {
    nixosModules.default = {
      imports = [
        (import (./options.nix) self)
        (import (./service.nix) self)
      ];
    };
    nixosConfigurations.demo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        secrets.nixosModules.default
        {
          services.tre-backup.demo = {
            enable = true;
            interval = "1min";
            store = "demo-store";
          };
          secrets.tre-backup-demo = {
            source = {
              vault = "TestVault";
              item = "ssb/demo";
              fields = [ "backup-key.json" ];
            };
          };
        }
      ];
    };
    packages = eachSystem ( { pkgs, system }: let 
      cli-tools = inputs.tre-cli-tools-nixos.packages.${system}.default;
      extraModulePath = "${cli-tools}/lib/node_modules/tre-cli-tools/node_modules";
    in {
      default = pkgs.buildNpmPackage rec {
        version = cli-tools.version;
        pname = "tre-backup";

        dontNpmBuild = true;
        makeCacheWritable = true;
        npmFlags = [ "--omit=dev" "--omit=optional"];

        npmDepsHash = "sha256-8vKniyyD8nghdlIyCuU5xj+cwUo0GmjLGn82fkgHSwc=";

        src = ./src;

        postBuild = ''
          mkdir -p $out/lib/node_modules/${pname}
          cat <<EOF > $out/lib/node_modules/${pname}/extra-modules-path.js
          process.env.NODE_PATH += ':${extraModulePath}' 
          require('module').Module._initPaths()
          EOF
        '';

        meta = {
          description = "tre-backup -- live backups of flumedb";
          license = pkgs.lib.licenses.mit;
          mainProgram = pname;
          maintainers = [ "jan@lagomorph.de" ];
        };
      };
    });

    devShells = eachSystem ( { pkgs, system, ... }: {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.nodejs
          pkgs.python3
          pkgs.typescript
        ];
      };
    });
  };
}
