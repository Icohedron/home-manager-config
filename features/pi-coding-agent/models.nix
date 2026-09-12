# Local model providers for pi.
#
# Pi's built-in llama.cpp provider reports every router model as non-reasoning,
# so each model is declared explicitly here to enable thinking and vision and to
# pin the real context window. The server itself comes from ../llama-cpp.nix
# (port 8080, started by `mask llama start`).
#
# Nothing here for Atuin AI: it is answered either by GitHub Copilot - which
# pi already reaches through its own github-copilot provider - or by this very
# server (see ../atuin/ai.nix).
{ config, ... }:
let
  # Port and model of that server, from the feature that owns them.
  llamaCpp = config.flake.lib.llamaCppServer;
in
{
  flake.modules.homeManager.pi-coding-agent = {
    programs.pi-coding-agent.models.providers = {
      "llama.cpp-custom" = {
        baseUrl = "http://127.0.0.1:${toString llamaCpp.port}/v1";
        api = "openai-completions";
        apiKey = "local";
        compat = {
          # llama.cpp has no prompt store and ignores reasoning_effort.
          supportsStore = false;
          supportsReasoningEffort = false;
          maxTokensField = "max_tokens";
        };
        models = [
          {
            id = llamaCpp.model.id;
            name = llamaCpp.model.name;
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = llamaCpp.model.contextWindow;
            # Qwen recommends 32K output for normal use and 81920 for hard problems.
            maxTokens = 32768;
            cost = {
              input = 0;
              output = 0;
              cacheRead = 0;
              cacheWrite = 0;
            };
            compat = {
              # Qwen3.6 toggles thinking through
              # chat_template_kwargs.enable_thinking / .preserve_thinking.
              thinkingFormat = "qwen-chat-template";
            };
          }
        ];
      };
    };
  };
}
