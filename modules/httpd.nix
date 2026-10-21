# Tak_OS · httpd.nix — Apache HTTPD with PHP (LAMP stack)
# github.com/tak0dan/Tak_OS · GNU GPLv3
# When lamp is enabled but mariadb is disabled, the stack runs its own
# MySQL/MariaDB instance on port 3307 with a separate data directory.
# When mariadb is also enabled, it shares the system's MySQL on port 3306.
{ config, lib, pkgs, ... }:

let
  cfg = config.takos.httpd;
  mariadbEnabled = config.takos.mariadb.enable;
  inherit (lib) mkEnableOption mkIf mkOption mkDefault mkMerge types;
in
{
  options.takos.httpd = {
    enable = mkEnableOption "Tak_OS Apache HTTPD with PHP";

    adminAddr = mkOption {
      type = types.str;
      default = "post@localhost";
      description = "Server admin email for HTTPD.";
    };

    serverName = mkOption {
      type = types.str;
      default = "localhost";
      description = "ServerName for the default virtual host.";
    };

    documentRoot = mkOption {
      type = types.str;
      default = "/var/www/html";
      description = "Document root for the default virtual host.";
    };

    enablePHP = mkOption {
      type = types.bool;
      default = true;
      description = "Enable PHP support in Apache.";
    };

    mysqlPort = mkOption {
      type = types.int;
      default = 3307;
      description = "Port for the stack's MySQL when mariadb feature is disabled.";
    };

    mysqlDataDir = mkOption {
      type = types.str;
      default = "/var/lib/mysql-lamp";
      description = "Data directory for the stack's MySQL when mariadb feature is disabled.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.httpd = {
        enable = true;
        adminAddr = cfg.adminAddr;
        enablePHP = cfg.enablePHP;
        virtualHosts."${cfg.serverName}" = {
          documentRoot = cfg.documentRoot;
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.documentRoot} 0755 root root - -"
      ];
    }

    (mkIf (!mariadbEnabled) {
      services.mysql = {
        enable = true;
        package = pkgs.mariadb;
        user = "mysql";
        group = "mysql";
        dataDir = cfg.mysqlDataDir;
        settings = {
          mysqld = {
            port = cfg.mysqlPort;
            bind-address = "127.0.0.1";
            skip-networking = false;
          };
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.mysqlDataDir} 0750 mysql mysql - -"
      ];
    })
  ]);
}
