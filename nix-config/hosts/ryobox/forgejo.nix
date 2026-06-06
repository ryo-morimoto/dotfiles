_:

{
  services = {
    postgresql.enable = true;

    forgejo = {
      enable = true;
      lfs.enable = true;

      database = {
        type = "postgres";
        createDatabase = true;
      };

      dump = {
        enable = true;
        interval = "daily";
        type = "zip";
        backupDir = "/var/lib/forgejo/dump";
      };

      settings = {
        server = {
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = 3000;
          DOMAIN = "git.ryobox.xyz";
          ROOT_URL = "https://git.ryobox.xyz/";
          SSH_DOMAIN = "git.ryobox.xyz";
          DISABLE_SSH = true;
          START_SSH_SERVER = false;
        };

        service = {
          DISABLE_REGISTRATION = true;
        };

        repository = {
          DEFAULT_BRANCH = "main";
        };
      };
    };
  };
}
