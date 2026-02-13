/**
 * Message Queue Extension
 *
 * Polls a JSONL queue file for messages written by external tools (e.g. acorn).
 * Delivers them to the agent via sendUserMessage on session start and ongoing.
 *
 * Queue file path mirrors acorn's compute_queue_file():
 *   ~/.pi/queues/<safe-cwd>.jsonl
 *
 * Each JSONL line: {"message": "...", "mode": "followUp"|"steer"}
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

function getQueueFile(cwd: string): string {
	const safePath = cwd.toLowerCase().replace(/\//g, "-").replace(/^-/, "");
	return join(homedir(), ".pi", "queues", `${safePath}.jsonl`);
}

interface QueueEntry {
	message: string;
	mode?: "followUp" | "steer";
}

function readAndClearQueue(queueFile: string): QueueEntry[] {
	if (!existsSync(queueFile)) return [];

	const raw = readFileSync(queueFile, "utf-8").trim();
	if (!raw) return [];

	const entries: QueueEntry[] = [];
	for (const line of raw.split("\n")) {
		const trimmed = line.trim();
		if (!trimmed) continue;
		try {
			entries.push(JSON.parse(trimmed));
		} catch {
			// skip malformed lines
		}
	}

	// Clear the file after reading
	writeFileSync(queueFile, "");
	return entries;
}

export default function (pi: ExtensionAPI) {
	let pollTimer: ReturnType<typeof setInterval> | undefined;
	let queueFile: string;
	let ctx: ExtensionContext | undefined;

	function deliverEntries(entries: QueueEntry[]) {
		for (const entry of entries) {
			if (!entry.message) continue;

			const idle = ctx?.isIdle() ?? true;
			if (idle) {
				pi.sendUserMessage(entry.message);
			} else {
				const deliverAs = entry.mode === "steer" ? "steer" : "followUp";
				pi.sendUserMessage(entry.message, { deliverAs });
			}
		}
	}

	function poll() {
		const entries = readAndClearQueue(queueFile);
		if (entries.length > 0) {
			deliverEntries(entries);
		}
	}

	pi.on("session_start", async (_event, context) => {
		ctx = context;
		queueFile = getQueueFile(context.cwd);

		// Ensure queues directory exists
		const queuesDir = join(homedir(), ".pi", "queues");
		if (!existsSync(queuesDir)) {
			mkdirSync(queuesDir, { recursive: true });
		}

		// Deliver any messages already queued before session started
		const pending = readAndClearQueue(queueFile);
		if (pending.length > 0) {
			deliverEntries(pending);
		}

		// Start polling every 500ms
		pollTimer = setInterval(poll, 500);
	});

	pi.on("session_shutdown", async () => {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = undefined;
		}
	});

	pi.registerCommand("queue-status", {
		description: "Show pending messages in the queue file",
		handler: async (_args, context) => {
			const file = getQueueFile(context.cwd);
			if (!existsSync(file)) {
				context.ui.notify("Queue file does not exist (no pending messages)", "info");
				return;
			}
			const raw = readFileSync(file, "utf-8").trim();
			const count = raw ? raw.split("\n").filter((l) => l.trim()).length : 0;
			context.ui.notify(`${count} message(s) pending in queue`, "info");
		},
	});
}
