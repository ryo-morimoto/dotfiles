{ gstack-skills, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      personal = {
        path = ../../skills;
      };
      gstack = {
        path = gstack-skills;
      };
    };

    skills = {
      enable = [
        "office-hours"
        "plan-ceo-review"
        "plan-eng-review"
        "plan-design-review"
        "plan-devex-review"
        "design-consultation"
        "design-shotgun"
        "design-html"
        "design-review"
        "review"
        "ship"
        "land-and-deploy"
        "canary"
        "benchmark"
        "qa"
        "qa-only"
        "open-gstack-browser"
        "setup-browser-cookies"
        "setup-deploy"
        "retro"
        "investigate"
        "document-release"
        "cso"
        "autoplan"
        "devex-review"
        "careful"
        "freeze"
        "guard"
        "unfreeze"
        "gstack-upgrade"
        "learn"
        "context7-mcp"
        "design-thinking"
        "domain-modeling"
        "fp-typescript"
        "mermaid-validator"
        "repo-doctor"
      ];
      enableAll = false;
      explicit = {
        gstack-browse = {
          from = "gstack";
          path = "browse";
        };
        gstack-codex = {
          from = "gstack";
          path = "codex";
        };
      };
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
