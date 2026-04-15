{
  gstack-skills,
  pm-skills,
  lib,
  ...
}:
let
  pmCategories = [
    "pm-data-analytics"
    "pm-execution"
    "pm-go-to-market"
    "pm-market-research"
    "pm-marketing-growth"
    "pm-product-discovery"
    "pm-product-strategy"
    "pm-toolkit"
  ];
  pmSources = lib.listToAttrs (
    map (
      cat:
      lib.nameValuePair cat {
        path = pm-skills;
        subdir = "${cat}/skills";
        idPrefix = cat;
      }
    ) pmCategories
  );
in
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
    }
    // pmSources;

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
      enableAll = pmCategories;
      explicit = {
        browse = {
          from = "gstack";
          path = "browse";
        };
        codex = {
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
