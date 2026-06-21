import { execFile } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  type ExtensionAPI,
  formatSize,
  type TruncationResult,
  truncateHead,
  withFileMutationQueue,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const execFileAsync = promisify(execFile);

const SearchParams = Type.Object({
  query: Type.String({ description: "The search query" }),
});

interface SearchDetails {
  query: string;
  truncation?: TruncationResult;
  fullOutputPath?: string;
  error?: string;
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Brave Search",
    description: `Search the web via Brave Search (the 'bx' CLI). Output is JSON, truncated to ${DEFAULT_MAX_LINES} lines or ${formatSize(
      DEFAULT_MAX_BYTES,
    )} (whichever is hit first); if truncated, full output is saved to a temp file.`,
    promptSnippet: "Search the web with the web_search tool",
    parameters: SearchParams,

    async execute(_toolCallId, params, signal, _onUpdate, _ctx) {
      let output: string;
      try {
        const { stdout } = await execFileAsync("bx", ["context", params.query, "--max-tokens", "2048"], {
          signal,
          encoding: "utf-8",
          maxBuffer: 100 * 1024 * 1024,
        });
        output = stdout;
      } catch (err: any) {
        if (err?.name === "AbortError" || signal?.aborted) {
          throw new Error("aborted");
        }
        const stderr = typeof err?.stderr === "string" ? err.stderr.trim() : "";
        const msg = stderr || err?.message || "unknown error";
        return {
          content: [{ type: "text", text: `web_search failed: ${msg}` }],
          details: { query: params.query, error: msg } as SearchDetails,
        };
      }

      if (!output.trim()) {
        return {
          content: [{ type: "text", text: "No results found" }],
          details: { query: params.query } as SearchDetails,
        };
      }

      const truncation = truncateHead(output, {
        maxLines: DEFAULT_MAX_LINES,
        maxBytes: DEFAULT_MAX_BYTES,
      });

      const details: SearchDetails = { query: params.query };
      let resultText = truncation.content;

      if (truncation.truncated) {
        const tempDir = await mkdtemp(join(tmpdir(), "pi-web-search-"));
        const tempFile = join(tempDir, "output.json");
        await withFileMutationQueue(tempFile, async () => {
          await writeFile(tempFile, output, "utf8");
        });

        details.truncation = truncation;
        details.fullOutputPath = tempFile;

        const truncatedLines = truncation.totalLines - truncation.outputLines;
        const truncatedBytes = truncation.totalBytes - truncation.outputBytes;

        resultText += `\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines`;
        resultText += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}).`;
        resultText += ` ${truncatedLines} lines (${formatSize(truncatedBytes)}) omitted.`;
        resultText += ` Full output saved to: ${tempFile}]`;
      }

      return {
        content: [{ type: "text", text: resultText }],
        details,
      };
    },

    renderCall(args, theme, _context) {
      const text =
        theme.fg("toolTitle", theme.bold("web_search ")) +
        theme.fg("accent", `"${args.query}"`);
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded, isPartial }, theme, _context) {
      const details = result.details as SearchDetails | undefined;

      if (isPartial) {
        return new Text(theme.fg("warning", "Searching..."), 0, 0);
      }

      if (details?.error) {
        return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
      }

      if (!expanded) {
        return new Text("", 0, 0);
      }

      let text = theme.fg("success", "Search results");
      if (details?.truncation?.truncated) {
        text += theme.fg("warning", " (truncated)");
      }

      const content = result.content[0];
      if (content?.type === "text") {
        const lines = content.text.split("\n").slice(0, 40);
        for (const line of lines) {
          text += `\n${theme.fg("dim", line)}`;
        }
      }
      if (details?.fullOutputPath) {
        text += `\n${theme.fg("dim", `Full output: ${details.fullOutputPath}`)}`;
      }

      return new Text(text, 0, 0);
    },
  });
}
