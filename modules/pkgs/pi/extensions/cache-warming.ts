import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("cache_warming_decision", (_event, _ctx) => {
    return { action: "warm" };
  });
}
