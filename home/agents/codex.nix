_:
let
  codexSettings = {
    personality = "pragmatic";
    model = "gpt-5.5";
    review_model = "gpt-5.5";
    model_reasoning_effort = "medium";
    sandbox_mode = "danger-full-access";
    approval_policy = "never";
    features = {
      multi_agent = true;
      hooks = true;
    };
    otel.log_user_prompt = false;
  };
in
{
  programs.codex = {
    context = builtins.readFile ./_AGENTS.md;
    enable = true;
    settings = codexSettings;
  };
}
