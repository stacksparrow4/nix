{
  flake.homeModules.openrouter = {
    sprrw.ai.pi.models.providers.openrouter.modelOverrides."deepseek/deepseek-v4.1-flash".compat.openRouterRouting =
      {
        only = [ "inference-net" ];
        quantizations = [ "fp8" ];
        allow_fallbacks = false;
      };
  };
}
