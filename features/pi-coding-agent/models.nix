# Local model provider for pi.
#
# Pi's built-in llama.cpp provider reports every router model as non-reasoning,
# so the model is declared explicitly here to enable thinking and vision and to
# pin the real context window. The server itself comes from ../llama-cpp.
{ ... }:
{
  flake.modules.homeManager.pi-coding-agent = {
    programs.pi-coding-agent.models.providers."llama.cpp-custom" = {
      baseUrl = "http://127.0.0.1:8080/v1";
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
          id = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
          name = "Unsloth Qwen3.6-35B-A3B MTP (UD-Q4_K_XL)";
          reasoning = true;
          input = [
            "text"
            "image"
          ];
          # 262144 token context size: the native context length of Qwen3.6.
          contextWindow = 262144;
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
}
