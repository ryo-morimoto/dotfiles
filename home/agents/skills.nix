{
  pm-skills,
  evolutionary-naming,
  mattpocock-skills,
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
      evolutionary-naming = {
        path = evolutionary-naming;
        subdir = "skills";
      };
      mattpocock = {
        path = mattpocock-skills;
      };
    }
    // pmSources;

    skills = {
      enable = [
        "context7-mcp"
        "design-thinking"
        "domain-modeling"
        "fp-typescript"
        "mermaid-validator"
        "repo-doctor"
        "evolutionary-naming"
        "rdra-setup"
        "rdra-ingest"
        "rdra-reverse"
        "rdra-check"
        "rdra-review"
        "rdra-summary"
        "design-an-interface"
        "grill-me"
        "improve-codebase-architecture"
      ];
      enableAll = pmCategories;
    };

    targets = {
      claude.enable = true;
      codex.enable = true;
      agents.enable = true;
    };
  };
}
