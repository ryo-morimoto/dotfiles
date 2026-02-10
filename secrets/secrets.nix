let
  ryobox = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSX4w51X2nmDnhUXaQdLGyk8c7OPXj8YrWlE+g4xRqJ root@ryobox";
in
{
  "caddy-cloudflare.age".publicKeys = [ ryobox ];
}
