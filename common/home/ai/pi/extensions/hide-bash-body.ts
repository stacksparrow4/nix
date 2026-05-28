import { createBashToolDefinition, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
	const builtIn = createBashToolDefinition(process.cwd());
	const originalRenderResult = builtIn.renderResult;

	pi.registerTool({
		...builtIn,
		renderResult(result, options, theme, context) {
			if (!options.expanded) {
				return new Text("", 0, 0);
			}
			return originalRenderResult!(result, options, theme, context);
		},
	});
}
