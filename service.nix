self: { config, lib, pkgs, ... }: 
let
  credsPath = name: "/etc/tre-backup/${name}";
  runtimePath = name: "tre-backup/${name}";

  attrs = config.services.tre-backup;
  enabled_server_names = builtins.filter (name: attrs.${name}.enable) (lib.attrNames attrs);
  servers = builtins.foldl' (acc: x: (acc // { ${x} = attrs.${x}; }) ) {} enabled_server_names;

in with lib; {
  config =  mkIf ((length enabled_server_names) != 0) {

    secrets = mapAttrs' (name: cfg: {
      name = "tre-backup-${name}";
      value = {
        path = credsPath name;
      };
    }) servers;

    systemd.services = mapAttrs' (name: cfg: let
      store = if cfg.store == null then "tre-backup/${name}" else cfg.store;
      globalOpts = "--config %d/${name} --appname backup-${name} --path $STATE_DIRECTORY";
    in {
      name = "tre-backup-${name}";
      value = {
        description = "tre backup for ${name} network";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/tre-backup ${globalOpts}";
          WorkingDirectory = "/tmp";
          LoadCredentialEncrypted = "${name}:${credsPath name}";
          StandardOutput = "journal";
          StandardError = "journal";

          DynamicUser = true;
          RuntimeDirectoryMode = "0750";

          RuntimeDirectory = runtimePath name;
          StateDirectory = store; 
          #Environment = [
          #  "DEBUG=tre-backup:*"
          #];
        };
      };
    }) servers;
  };
}
