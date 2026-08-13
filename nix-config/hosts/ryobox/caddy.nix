{ config, pkgs, ... }:

{
  # Tailnet-only reverse proxy. ryobox.xyz records point at the ryobox
  # Tailscale IP, and Caddy gets public certificates through Cloudflare DNS-01.
  services.caddy = {
    enable = true;
    globalConfig = ''
      default_bind 100.116.123.65 fd7a:115c:a1e0::a736:7b41
      auto_https disable_redirects
    '';
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.2" ];
      hash = "sha256-mqIa0wI/VfjDblg0NnkzKllWHXZZPLwHP8xEVSwZuPE=";
    };
    virtualHosts = {
      "collie.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          route {
            request_header -Tailscale-User-Login

            forward_auth unix/${config.services.tailscaleAuth.socketPath} {
              uri /auth
              header_up Remote-Addr {remote_host}
              header_up Remote-Port {remote_port}
              header_up Original-URI {uri}
              copy_headers {
                Tailscale-User>Tailscale-User-Login
              }
            }

            reverse_proxy 127.0.0.1:8787
          }
        '';
      };
      "plane.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          reverse_proxy 127.0.0.1:8090
        '';
      };
      "git.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          reverse_proxy 127.0.0.1:3000
        '';
      };
      "hermes.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          reverse_proxy 127.0.0.1:9120 {
            header_up Host 127.0.0.1:9120
            header_up Origin http://127.0.0.1:9120
            header_up X-Forwarded-Host hermes.ryobox.xyz
            header_up X-Forwarded-Proto https
          }
        '';
      };
      # OpenHands Agent Canvas — Docker on 127.0.0.1:8000.
      # UI lives at /canvas; APIs at /api and /api/automation.
      "agent-canvas.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          route {
            request_header -Tailscale-User-Login

            forward_auth unix/${config.services.tailscaleAuth.socketPath} {
              uri /auth
              header_up Remote-Addr {remote_host}
              header_up Remote-Port {remote_port}
              header_up Original-URI {uri}
              copy_headers {
                Tailscale-User>Tailscale-User-Login
              }
            }

            reverse_proxy 127.0.0.1:8000 {
              # Live agent events use WebSocket / SSE.
              transport http {
                read_timeout 3600s
                write_timeout 3600s
              }
            }
          }
        '';
      };
      "*.p.ryobox.xyz" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          route {
            request_header -Tailscale-User-Login

            forward_auth unix/${config.services.tailscaleAuth.socketPath} {
              uri /auth
              header_up Remote-Addr {remote_host}
              header_up Remote-Port {remote_port}
              header_up Original-URI {uri}
              copy_headers {
                Tailscale-User>Tailscale-User-Login
              }
            }

            @allowed header Tailscale-User-Login ryo.morimoto.dev@gmail.com
            handle @allowed {
              reverse_proxy https://127.0.0.1:443 {
                header_up Host {http.request.host}
                transport http {
                  tls_trust_pool file ${../../certs/portless-wildcard.crt}
                  tls_server_name {http.request.host}
                }
              }
            }

            respond "Forbidden" 403
          }
        '';
      };
    };
  };

  # Caddy: Cloudflare API token for DNS-01 certificate challenges.
  age.secrets.caddy-cloudflare = {
    file = ../../secrets/caddy-cloudflare.age;
    owner = "caddy";
    group = "caddy";
    mode = "0400";
  };

  systemd.services.caddy = {
    after = [
      "portless.service"
      "tailscale-address-ready.service"
      "tailscale-nginx-auth.socket"
      "tailscale-serve-reset.service"
    ];
    requires = [
      "tailscale-address-ready.service"
      "tailscale-nginx-auth.socket"
      "tailscale-serve-reset.service"
    ];
    wants = [ "portless.service" ];
    serviceConfig.EnvironmentFile = config.age.secrets.caddy-cloudflare.path;
  };

  users.users.caddy.extraGroups = [ config.services.tailscaleAuth.group ];
}
