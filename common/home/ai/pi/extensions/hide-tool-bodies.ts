import {
	createBashToolDefinition,
	createEditToolDefinition,
	createReadToolDefinition,
	createWriteToolDefinition,
	type ExtensionAPI,
} from "@mariozechner/pi-coding-agent";
import { Container } from "@mariozechner/pi-tui";

export default function (pi: ExtensionAPI) {
	const cwd = process.cwd();
	let hidden = false;

	pi.registerShortcut("ctrl+shift+h", {
		description: "Toggle hiding the body of tool calls",
		handler: async (ctx) => {
			hidden = !hidden;
			ctx.ui.setToolsExpanded(ctx.ui.getToolsExpanded());
		},
	});

	const defs = [
		createReadToolDefinition(cwd),
		createBashToolDefinition(cwd),
		createEditToolDefinition(cwd),
		createWriteToolDefinition(cwd),
	];

	for (const def of defs) {
		const originalRenderResult = def.renderResult;
		pi.registerTool({
			...def,
			renderResult: originalRenderResult
				? (result, options, theme, context) => {
						if (hidden) return new Container();
						return originalRenderResult(result, options, theme, context);
					}
				: undefined,
		});
	}
}
