{
  config,
  lib,
  compound-engineering-plugin,
  ...
}:

let
  policy = import ./policy.nix { inherit config; };
  ceSkillsPath = "${compound-engineering-plugin}/plugins/compound-engineering/skills";
  ceWorkflowPrompts = [
    {
      prompt = "ce-brainstorm";
      skill = "ce:brainstorm";
      source = "ce-brainstorm";
      description = "Explore requirements and approaches before planning";
      argumentHint = "[feature idea or problem to explore]";
    }
    {
      prompt = "ce-compound";
      skill = "ce:compound";
      source = "ce-compound";
      description = "Document a recently solved problem to compound your team's knowledge";
      argumentHint = null;
    }
    {
      prompt = "ce-ideate";
      skill = "ce:ideate";
      source = "ce-ideate";
      description = "Discover high-impact project improvements through divergent ideation and adversarial filtering";
      argumentHint = "[feature, focus area, or constraint]";
    }
    {
      prompt = "ce-plan";
      skill = "ce:plan";
      source = "ce-plan";
      description = "Turn feature ideas into detailed implementation plans";
      argumentHint = "[optional: feature description, requirements doc path, plan path to deepen, or improvement idea]";
    }
    {
      prompt = "ce-review";
      skill = "ce:review";
      source = "ce-review";
      description = "Multi-agent code review before merging";
      argumentHint = "[blank to review current branch, or provide PR link]";
    }
    {
      prompt = "ce-work";
      skill = "ce:work";
      source = "ce-work";
      description = "Execute plans with worktrees and task tracking";
      argumentHint = "[Plan doc path or description of work. Blank to auto use latest plan doc]";
    }
  ];
  ceCodexSupplementalSkills = [
    {
      name = "feature-video";
      source = "feature-video";
    }
    {
      name = "resolve-pr-feedback";
      source = "resolve-pr-feedback";
    }
    {
      name = "test-browser";
      source = "test-browser";
    }
  ];
  compoundEngineering = {
    plugin = compound-engineering-plugin;
    skillsPath = ceSkillsPath;
    claude = {
      marketplaceName = "every-marketplace";
      marketplaceSource = compound-engineering-plugin;
      enabledPlugins = {
        "compound-engineering@every-marketplace" = true;
        "coding-tutor@every-marketplace" = true;
      };
    };
    codex = {
      skills = builtins.listToAttrs (
        map (
          workflow: lib.nameValuePair workflow.skill "${ceSkillsPath}/${workflow.source}"
        ) ceWorkflowPrompts
        ++ map (
          skill: lib.nameValuePair skill.name "${ceSkillsPath}/${skill.source}"
        ) ceCodexSupplementalSkills
      );
      prompts = builtins.listToAttrs (
        map (
          workflow:
          lib.nameValuePair workflow.prompt {
            inherit (workflow)
              argumentHint
              description
              skill
              ;
          }
        ) ceWorkflowPrompts
      );
    };
  };
in
{
  imports = [
    ./claude-code.nix
    ./codex.nix
    ./opencode.nix
    ./skills.nix
  ];

  _module.args = {
    inherit
      compoundEngineering
      policy
      ;
  };
}
