import {
	createBashToolDefinition,
	isToolCallEventType,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const DEFAULT_TIMEOUT_SECONDS = 10;

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (isToolCallEventType("bash", event) && event.input.timeout === undefined) {
			event.input.timeout = DEFAULT_TIMEOUT_SECONDS;
		}
		return undefined;
	});

	const builtIn = createBashToolDefinition(process.cwd());
	const originalRenderResult = builtIn.renderResult;

	const description = builtIn.description.replace(
		/Optionally provide a timeout in seconds\.?$/,
		`If no timeout is given, a default of ${DEFAULT_TIMEOUT_SECONDS} seconds is applied.`,
	);

	pi.registerTool({
		...builtIn,
		description,
		parameters: Type.Object({
			command: Type.String({ description: "Bash command to execute" }),
			timeout: Type.Optional(
				Type.Number({
					description: `Timeout in seconds (optional, defaults to ${DEFAULT_TIMEOUT_SECONDS}s if omitted)`,
				}),
			),
		}),
		renderResult(result, options, theme, context) {
			if (!options.expanded) {
				return new Text("", 0, 0);
			}
			return originalRenderResult!(result, options, theme, context);
		},
	});
}
