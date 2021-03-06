{ config, pkgs, ... }:
let
  knedlsepp_at = pkgs.writeTextFile {
    name = "index.html";
    destination = "/share/www/index.html";
    text = ''
      <!DOCTYPE html>
      <html lang="de">
      <head>
          <meta charset="utf-8">
          <title>knedlsepp.at</title>
      </head>
      <body id="home" bgcolor="#000000" link="#eeeeee" vlink="#dddddd" alink="#cccccc" text="#ffffff">
        <center>
        <iframe src="https://giphy.com/embed/26ufdipQqU2lhNA4g" width="480" height="480" frameBorder="0" class="giphy-embed" allowFullScreen></iframe>
        <br>
        <a href="https://gogs.knedlsepp.at">💾 - gogs.knedlsepp.at</a><br><br>
        <a href="https://shell.knedlsepp.at">🐚 - shell.knedlsepp.at</a><br><br>
        <a href="https://uwsgi-example.knedlsepp.at">🐍 - uwsgi-example.knedlsepp.at</a><br><br>
        </center>
      </body>
      </html>
    '';
  };
in
{
  imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
  ec2.hvm = true;
  
  nix.gc.automatic = true;
  nix.gc.dates = "14:09";

  nix.nixPath = [ "nixpkgs=https://nixos.org/channels/nixos-17.03/nixexprs.tar.xz"
                  "nixos-config=/etc/nixos/configuration.nix"
                  "knedlsepp-overlays=https://github.com/knedlsepp/nixpkgs-overlays/archive/master.tar.gz"
  ];

  nixpkgs.overlays = [ (import <knedlsepp-overlays>) ]; # Be aware that we need a nix-collect-garbage to fetch the most current version

  environment.systemPackages = with pkgs; [
    vim
    gitMinimal
    lsof
    htop
  ];

  programs.vim.defaultEditor = true;

  security.hideProcessInformation = true;

  services.openssh.forwardX11 = true;

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."knedlsepp.at" = {
      serverAliases = [ "www.knedlsepp.at" ];
      enableACME = true;
      forceSSL = true;
      root = "${knedlsepp_at}/share/www/";
    };
    virtualHosts."gogs.knedlsepp.at" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:3000";
    };
    virtualHosts."uwsgi-example.knedlsepp.at" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        extraConfig = ''
          uwsgi_pass unix://${config.services.uwsgi.instance.vassals.flask-helloworld.socket};
          include ${pkgs.nginx}/conf/uwsgi_params;
        '';
      };
    };
    virtualHosts."shell.knedlsepp.at" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:4200";
    };
  };

  services.uwsgi = {
    enable = true;
    user = "nginx";
    group = "nginx";
    instance = {
      type = "emperor";
      vassals = {
        flask-helloworld = {
          type = "normal";
          pythonPackages = self: with self; [ flask-helloworld ];
          socket = "${config.services.uwsgi.runDir}/flask-helloworld.sock";
          wsgi-file = "${pkgs.pythonPackages.flask-helloworld}/${pkgs.python.sitePackages}/helloworld/share/flask-helloworld.wsgi";
        };
      };
    };
    plugins = [ "python2" ];
  };

  services.shellinabox = {
    enable = true;
    extraOptions = [ "--localhost-only" ]; # Nginx makes sure it's https
  };

  services.gogs = {
    appName = "Knedlgit";
    enable = true;
    rootUrl = "https://gogs.knedlsepp.at/";
    extraConfig = ''
      [service]
      DISABLE_REGISTRATION = true
      [server]
      DISABLE_SSH = true
      LANDING_PAGE = explore
    '';
  };

  system.autoUpgrade.enable = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 2048;
    }
  ];

  services.fail2ban.enable = true;

  users.extraUsers.sepp = {
    isNormalUser = true;
    description = "Josef Knedlmüller";
    initialPassword = "foo";
  };
}

