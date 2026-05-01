{ apmDsl, apmLock }:

let
  mkLeaves =
    names:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = { };
      }) names
    );

  codeReviewAgents = [
    "ce-adversarial-reviewer"
    "ce-agent-native-reviewer"
    "ce-api-contract-reviewer"
    "ce-cli-readiness-reviewer"
    "ce-correctness-reviewer"
    "ce-data-migrations-reviewer"
    "ce-deployment-verification-agent"
    "ce-dhh-rails-reviewer"
    "ce-julik-frontend-races-reviewer"
    "ce-kieran-python-reviewer"
    "ce-kieran-rails-reviewer"
    "ce-kieran-typescript-reviewer"
    "ce-learnings-researcher"
    "ce-maintainability-reviewer"
    "ce-performance-reviewer"
    "ce-previous-comments-reviewer"
    "ce-project-standards-reviewer"
    "ce-reliability-reviewer"
    "ce-schema-drift-detector"
    "ce-security-reviewer"
    "ce-swift-ios-reviewer"
    "ce-testing-reviewer"
  ];

  docReviewAgents = [
    "ce-adversarial-document-reviewer"
    "ce-coherence-reviewer"
    "ce-design-lens-reviewer"
    "ce-feasibility-reviewer"
    "ce-product-lens-reviewer"
    "ce-scope-guardian-reviewer"
    "ce-security-lens-reviewer"
  ];

  compoundAgents = [
    "ce-git-history-analyzer"
    "ce-issue-intelligence-analyst"
    "ce-pattern-recognition-specialist"
    "ce-repo-research-analyst"
    "ce-session-historian"
  ];

  agents = mkLeaves (
    codeReviewAgents
    ++ docReviewAgents
    ++ compoundAgents
    ++ [
      "ce-best-practices-researcher"
      "ce-figma-design-sync"
      "ce-framework-docs-researcher"
    ]
  );

  skills = {
    ce-brainstorm = {
      requires.skills = [
        "ce-doc-review"
        "ce-plan"
        "ce-proof"
        "ce-work"
      ];
    };

    ce-code-review = {
      requires.agents = codeReviewAgents;
    };

    ce-commit = { };

    ce-commit-push-pr = {
      requires.skills = [
        "ce-commit"
        "ce-demo-reel"
      ];
    };

    ce-compound = {
      requires.skills = [
        "ce-compound-refresh"
        "ce-session-inventory"
      ];
      requires.agents = compoundAgents;
    };

    ce-compound-refresh = {
      requires.agents = [
        "ce-pattern-recognition-specialist"
        "ce-repo-research-analyst"
      ];
    };

    ce-demo-reel = { };

    ce-doc-review = {
      requires.agents = docReviewAgents;
    };

    ce-plan = {
      requires.agents = [
        "ce-best-practices-researcher"
        "ce-framework-docs-researcher"
      ];
    };

    ce-proof = { };

    ce-session-inventory = {
      requires.agents = [
        "ce-session-historian"
      ];
    };

    ce-test-browser = { };

    ce-work = {
      requires.skills = [
        "ce-code-review"
        "ce-commit"
        "ce-commit-push-pr"
        "ce-worktree"
      ];
      requires.agents = [
        "ce-figma-design-sync"
      ];
    };

    ce-worktree = { };

    lfg = {
      requires.skills = [
        "ce-code-review"
        "ce-commit-push-pr"
        "ce-plan"
        "ce-test-browser"
        "ce-work"
      ];
    };
  };

  selectedSkills = [
    "ce-brainstorm"
    "ce-code-review"
    "ce-compound"
    "ce-doc-review"
    "ce-plan"
    "ce-work"
    "lfg"
  ];
in
{
  inherit
    agents
    selectedSkills
    skills
    ;

  dependencies = apmDsl.mkPrimitiveDependencies {
    lock = apmLock;
    package = "compound-engineering";
    inherit
      agents
      selectedSkills
      skills
      ;
  };
}
