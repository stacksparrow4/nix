{
  flake.modules.homeManager.sprrw-pi = {
    sprrw.ai.pi.settings = {
      hideThinkingBlock = false;
      defaultThinkingLevel = "low";
      enabledModels = [
        "deepseek/deepseek-v4.1-flash-1017"
      ];
    };
  };
}
