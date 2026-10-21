# Tak_OS · mariadb.nix — Declarative MariaDB service wrapper
# github.com/tak0dan/Tak_OS · GNU GPLv3
#
# Replaces script-generated edits with one typed ownership point:
#   - service enable/disable
#   - data directory
#   - ensured databases / users
#   - optional local client tools
{ config, lib, pkgs, ... }:

let
  cfg = config.takos.mariadb;
  inherit (lib) mkEnableOption mkIf mkOption types;
in
{
  options.takos.mariadb = {
    enable = mkEnableOption "Tak_OS MariaDB service";

    package = mkOption {
      type = types.package;
      default = pkgs.mariadb;
      description = "MariaDB/MySQL package to run for the local database service.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/mysql";
      description = "MariaDB data directory.";
    };

    user = mkOption {
      type = types.str;
      default = "mysql";
      description = "User account under which MariaDB runs.";
    };

    group = mkOption {
      type = types.str;
      default = "mysql";
      description = "Group account under which MariaDB runs.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {
        mysqld = {
          "bind-address" = "127.0.0.1";
          port = 3306;
        };
      };
      description = "MariaDB settings passed through to services.mysql.settings.";
    };

    initialDatabases = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Initial database name to create on first startup.";
            };
            schema = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Optional schema file loaded when the database is first created.";
            };
          };
        }
      );
      default = [ ];
      description = "Databases created on first service startup.";
    };

    initialScript = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional SQL script run on first service startup.";
    };

    ensureDatabases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Databases that must exist.";
    };

    ensureUsers = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Database user to ensure.";
            };
            ensurePermissions = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Permissions to ensure for the user.";
            };
          };
        }
      );
      default = [ ];
      description = "Database users that must exist with ensured permissions.";
    };

    tools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install local MariaDB command-line tools.";
      };

      workbench = mkOption {
        type = types.bool;
        default = false;
        description = "Install MySQL Workbench together with the local MariaDB tools.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.mysql = {
      enable = true;
      package = cfg.package;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      settings = cfg.settings;
      initialDatabases = cfg.initialDatabases;
      initialScript = cfg.initialScript;
      ensureDatabases = cfg.ensureDatabases;
      ensureUsers = cfg.ensureUsers;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    environment.systemPackages = lib.optionals cfg.tools.enable (
      [ cfg.package ] ++ lib.optionals cfg.tools.workbench [ pkgs.mysql-workbench ]
    );
  };
}
