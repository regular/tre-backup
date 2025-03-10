self: { config, lib, pkgs, ... }: 
with lib;
let 
  serverInstance = name: let 
    crg = config.services.tre-backup.${name};
  in {
    options = {
      enable = mkEnableOption "ssb/tre pub server (sbot)";

      package = mkOption {
        type = types.package;
        default = self.packages.${pkgs.stdenv.system}.default;
        defaultText = literalExpression "pkgs.tre-backup";
        description = "package to use.";
      };

      interval = mkOption {
        type = types.str;
        default = "10sec";
        defaultText = "10sec";
        description = "Period between restarts";
      };

      store = mkOption rec {
        type = types.str;
        default = "tre-backup/${name}";
        description = "WHere (wthin /var/lib) to store the backup";
      };

    };
  };

in {

  options.services.tre-backup = mkOption {
    type = types.attrsOf (types.submodule serverInstance);
    default = {};
    description = "Named instances of tre-backup";
  };

}
