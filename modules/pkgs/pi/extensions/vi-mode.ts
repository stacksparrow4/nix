import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Mode = "insert" | "normal";
type Register = { text: string; linewise: boolean };
type Target = { off: number; inclusive: boolean; linewise: boolean };
type Span = { start: number; end: number; linewise: boolean };
type Snapshot = {
  state: { lines: string[]; cursorLine: number; cursorCol: number };
  pastes: Map<number, string>;
  pasteCounter: number;
};
type Base = { count: number; hasCount: boolean };
type Parsed =
  | (Base & { kind: "motion"; op: string | null; m: string; arg?: string })
  | (Base & { kind: "line"; op: string })
  | (Base & { kind: "obj"; op: string; obj: string })
  | (Base & { kind: "simple"; c: string; arg?: string });

const PENDING = Symbol("pending");
const INVALID = Symbol("invalid");

const BAR = "\x1b[6 q";
const BLOCK = "\x1b[2 q";
const RESET = "\x1b[0 q";

const OPS = new Set(["d", "c", "y", "g~", "gu", "gU"]);
const MOTIONS = new Set(["h", "l", "j", "k", "w", "W", "b", "B", "e", "E", "0", "^", "$", "G", "gg", ";", ",", "%", " ", "_"]);
const SIMPLE = new Set(["x", "X", "D", "C", "Y", "s", "S", "p", "P", "u", "i", "a", "I", "A", "o", "O", "J", "~", "."]);
const CHANGES = new Set(["x", "X", "D", "C", "s", "S", "p", "P", "i", "a", "I", "A", "o", "O", "J", "~", "r"]);
const REVERSE: Record<string, string> = { f: "F", F: "f", t: "T", T: "t" };
const QUOTES = new Set(["\"", "'", "`"]);
const BRACKETS: Record<string, [string, string]> = {
  "(": ["(", ")"],
  ")": ["(", ")"],
  b: ["(", ")"],
  "[": ["[", "]"],
  "]": ["[", "]"],
  "{": ["{", "}"],
  "}": ["{", "}"],
  B: ["{", "}"],
  "<": ["<", ">"],
  ">": ["<", ">"],
};

function printable(data: string): string | undefined {
  if ([...data].length === 1 && data >= " " && data !== "\x7f") return data;
  const m = data.match(/^\x1b\[(\d+)(?::(\d*))?(?::\d*)?(?:;(\d+))?u$/);
  if (!m) return undefined;
  const mod = m[3] ? Number(m[3]) - 1 : 0;
  if (mod & 62) return undefined;
  const cp = mod & 1 && m[2] ? Number(m[2]) : Number(m[1]);
  return cp >= 32 && cp !== 127 && cp < 0xe000 ? String.fromCodePoint(cp) : undefined;
}

function lineStart(t: string, off: number): number {
  return off <= 0 ? 0 : t.lastIndexOf("\n", off - 1) + 1;
}

function lineEnd(t: string, off: number): number {
  const i = t.indexOf("\n", off);
  return i < 0 ? t.length : i;
}

function firstNonBlank(t: string, ls: number): number {
  let p = ls;
  while (t[p] === " " || t[p] === "\t") p++;
  return p;
}

function lineIndex(t: string, off: number): number {
  let n = 0;
  for (let i = t.indexOf("\n"); i >= 0 && i < off; i = t.indexOf("\n", i + 1)) n++;
  return n;
}

function lineOffset(t: string, line: number): number {
  let off = 0;
  for (let i = 0; i < line; i++) {
    const nl = t.indexOf("\n", off);
    if (nl < 0) break;
    off = nl + 1;
  }
  return off;
}

function cls(ch: string | undefined, big: boolean): number {
  if (ch === undefined) return -1;
  if (/\s/.test(ch)) return 0;
  if (big) return 1;
  return /[\p{L}\p{N}_]/u.test(ch) ? 1 : 2;
}

function wordForward(t: string, off: number, big: boolean): number {
  let p = off;
  const c = cls(t[p], big);
  if (c > 0) while (p < t.length && cls(t[p], big) === c) p++;
  while (p < t.length && cls(t[p], big) === 0) {
    if (t[p] === "\n" && t[p + 1] === "\n") return p + 1;
    p++;
  }
  return p;
}

function wordEnd(t: string, off: number, big: boolean): number {
  let p = off + 1;
  while (p < t.length && cls(t[p], big) === 0) p++;
  const c = cls(t[p], big);
  while (p + 1 < t.length && cls(t[p + 1], big) === c) p++;
  return Math.max(0, Math.min(p, t.length - 1));
}

function wordBack(t: string, off: number, big: boolean): number {
  let p = off - 1;
  while (p > 0 && cls(t[p], big) === 0) p--;
  const c = cls(t[p], big);
  while (p > 0 && cls(t[p - 1], big) === c) p--;
  return Math.max(0, p);
}

function matchPair(t: string, off: number): number {
  const le = lineEnd(t, off);
  let p = off;
  while (p < le && !"()[]{}".includes(t[p]!)) p++;
  if (p >= le) return -1;
  const [o, c] = BRACKETS[t[p]!]!;
  let depth = 0;
  if (t[p] === o) {
    for (let i = p; i < t.length; i++) {
      if (t[i] === o) depth++;
      else if (t[i] === c && --depth === 0) return i;
    }
  } else {
    for (let i = p; i >= 0; i--) {
      if (t[i] === c) depth++;
      else if (t[i] === o && --depth === 0) return i;
    }
  }
  return -1;
}

function swapCase(s: string): string {
  return [...s].map((ch) => (ch === ch.toUpperCase() ? ch.toLowerCase() : ch.toUpperCase())).join("");
}

function wordObject(t: string, off: number, inner: boolean, big: boolean): Span | null {
  const ls = lineStart(t, off);
  const le = lineEnd(t, off);
  if (le === ls) return null;
  const o = Math.min(off, le - 1);
  const c = cls(t[o], big);
  let s = o;
  let e = o + 1;
  while (s > ls && cls(t[s - 1], big) === c) s--;
  while (e < le && cls(t[e], big) === c) e++;
  if (!inner) {
    if (c === 0) {
      const c2 = cls(t[e], big);
      while (e < le && cls(t[e], big) === c2) e++;
    } else if (e < le && cls(t[e], big) === 0) {
      while (e < le && cls(t[e], big) === 0) e++;
    } else {
      while (s > ls && cls(t[s - 1], big) === 0) s--;
    }
  }
  return { start: s, end: e, linewise: false };
}

function quoteObject(t: string, off: number, inner: boolean, q: string): Span | null {
  const ls = lineStart(t, off);
  const le = lineEnd(t, off);
  const qs: number[] = [];
  for (let i = ls; i < le; i++) if (t[i] === q && t[i - 1] !== "\\") qs.push(i);
  let a = -1;
  let b = -1;
  const at = qs.indexOf(off);
  if (at >= 0) {
    [a, b] = at % 2 === 0 ? [qs[at]!, qs[at + 1] ?? -1] : [qs[at - 1]!, qs[at]!];
  } else {
    const before = qs.filter((x) => x < off).pop();
    const after = qs.findIndex((x) => x > off);
    if (before !== undefined && after >= 0) [a, b] = [before, qs[after]!];
    else if (before === undefined && after >= 0) [a, b] = [qs[after]!, qs[after + 1] ?? -1];
  }
  if (a < 0 || b < 0) return null;
  if (inner) return { start: a + 1, end: b, linewise: false };
  let s = a;
  let e = b + 1;
  if (t[e] === " " || t[e] === "\t") {
    while (t[e] === " " || t[e] === "\t") e++;
  } else {
    while (s > ls && (t[s - 1] === " " || t[s - 1] === "\t")) s--;
  }
  return { start: s, end: e, linewise: false };
}

function bracketObject(t: string, off: number, inner: boolean, [o, c]: [string, string], op: string): Span | null {
  let s = -1;
  if (t[off] === o) {
    s = off;
  } else {
    let depth = 0;
    for (let i = off - 1; i >= 0; i--) {
      if (t[i] === c) depth++;
      else if (t[i] === o) {
        if (depth === 0) {
          s = i;
          break;
        }
        depth--;
      }
    }
  }
  if (s < 0) return null;
  let e = -1;
  let depth = 0;
  for (let i = s + 1; i < t.length; i++) {
    if (t[i] === o) depth++;
    else if (t[i] === c) {
      if (depth === 0) {
        e = i;
        break;
      }
      depth--;
    }
  }
  if (e < 0) return null;
  if (!inner) return { start: s, end: e + 1, linewise: false };
  let a = s + 1;
  let b = e;
  if (t[a] === "\n") {
    a++;
    const ce = lineStart(t, e);
    if (ce > a && /^[ \t]*$/.test(t.slice(ce, e))) b = op === "c" ? ce - 1 : ce;
  }
  return { start: a, end: Math.max(a, b), linewise: false };
}

let restoreHardwareCursor: boolean | null = null;

class ViEditor extends CustomEditor {
  private mode: Mode = "insert";
  private keys = "";
  private reg: Register = { text: "", linewise: false };
  private lastFind: { m: string; ch: string } | null = null;
  private wantCol: number | null = null;
  private redoStack: Snapshot[] = [];
  private redoText: string | null = null;
  private changeMark: number | null = null;
  private changeState: unknown = null;
  private changeText = "";
  private lastChange: { cmd: string; inserted: string[] } | null = null;
  private recording: string[] | null = null;
  private replaying = false;
  private pendingCtrlX = false;
  private lastWord: { idx: number; line: number; start: number; end: number; text: string } | null = null;
  private lastShape: string | null = null;

  constructor(...args: ConstructorParameters<typeof CustomEditor>) {
    super(...args);
    if (restoreHardwareCursor === null) restoreHardwareCursor = this.tui.getShowHardwareCursor();
    this.tui.setShowHardwareCursor(true);
  }

  private get ed(): any {
    return this as any;
  }

  inherit(prev: ViEditor): void {
    const history = (prev as any).history;
    if (Array.isArray(history) && history.length > 0) this.ed.history = [...history];
    this.reg = prev.reg;
  }

  restoreTerminal(): void {
    this.tui.terminal.write(RESET);
    if (restoreHardwareCursor !== null) this.tui.setShowHardwareCursor(restoreHardwareCursor);
    restoreHardwareCursor = null;
  }

  override handleInput(data: string): void {
    if (this.ed.isInPaste || data.includes("\x1b[200~")) {
      if (this.mode === "insert") this.recording?.push(data);
      super.handleInput(data);
      return;
    }
    if (this.pendingCtrlX) {
      this.pendingCtrlX = false;
      if (matchesKey(data, "ctrl+e")) {
        this.lastShape = null;
        this.actionHandlers.get("app.editor.external")?.();
        return;
      }
      this.actionHandlers.get("app.message.copy")?.();
    } else if (matchesKey(data, "ctrl+x")) {
      this.pendingCtrlX = true;
      return;
    }
    if (this.mode === "insert") this.insertInput(data);
    else this.normalInput(data);
  }

  override render(width: number): string[] {
    const lines = super.render(width);
    const shape = this.mode === "insert" ? BAR : BLOCK;
    if (!this.focused) {
      this.lastShape = null;
    } else if (this.lastShape !== shape) {
      this.tui.terminal.write(shape);
      this.lastShape = shape;
    }
    if (this.mode === "normal" && lines.length > 1) {
      const label = ` NORMAL${this.keys ? ` ${this.keys}` : ""} `;
      const last = lines.length - 1;
      if (visibleWidth(lines[last]!) > visibleWidth(label) + 2) {
        lines[last] = truncateToWidth(lines[last]!, width - visibleWidth(label), "") + this.borderColor(label);
      }
    }
    return lines;
  }

  private insertInput(data: string): void {
    if (matchesKey(data, "escape")) {
      if (this.isShowingAutocomplete()) super.handleInput(data);
      this.toNormal();
      return;
    }
    if (matchesKey(data, "ctrl+p")) {
      if (this.historyUp()) this.setOff(this.getText().length);
      return;
    }
    if (matchesKey(data, "ctrl+n")) {
      this.historyDown();
      return;
    }
    if (data === "\x1b." || matchesKey(data, "alt+.")) {
      this.insertLastWord();
      return;
    }
    this.lastWord = null;
    this.wantCol = null;
    this.recording?.push(data);
    super.handleInput(data);
    if (this.changeMark !== null && this.ed.state !== this.changeState) {
      this.changeMark = null;
      this.changeState = null;
      this.recording = null;
    }
  }

  private normalInput(data: string): void {
    let ch = printable(data);
    if (ch === undefined && this.keys === "" && matchesKey(data, "backspace")) ch = "h";
    if (ch === undefined) {
      if (this.keys) {
        this.keys = "";
        return;
      }
      if (matchesKey(data, "ctrl+r")) {
        this.redo();
        this.clampNormal();
        return;
      }
      if (matchesKey(data, "ctrl+p")) {
        this.historyUp();
        this.clampNormal();
        return;
      }
      if (matchesKey(data, "ctrl+n")) {
        this.historyDown();
        this.clampNormal();
        return;
      }
      this.wantCol = null;
      this.lastShape = null;
      super.handleInput(data);
      if ((matchesKey(data, "enter") || matchesKey(data, "ctrl+c")) && this.getText() === "") {
        this.mode = "insert";
      } else {
        this.clampNormal();
      }
      return;
    }
    this.keys += ch;
    if (this.exec(this.keys) === PENDING) return;
    this.keys = "";
  }

  private toInsert(): void {
    this.mode = "insert";
    this.recording = this.replaying ? null : [];
  }

  private toNormal(): void {
    this.mode = "normal";
    this.ed.cancelAutocomplete?.();
    this.finishChange();
    if (this.recording && this.lastChange) this.lastChange.inserted = this.recording;
    this.recording = null;
    const col = this.ed.state.cursorCol;
    if (col > 0) this.ed.setCursorCol(col - 1);
    this.clampNormal();
  }

  private cursorOff(): number {
    const s = this.ed.state;
    let off = 0;
    for (let i = 0; i < s.cursorLine; i++) off += s.lines[i].length + 1;
    return off + s.cursorCol;
  }

  private setOff(off: number): void {
    const t = this.getText();
    const o = Math.max(0, Math.min(off, t.length));
    this.ed.state.cursorLine = lineIndex(t, o);
    this.ed.setCursorCol(o - lineStart(t, o));
  }

  private apply(text: string, off: number): void {
    this.ed.exitHistoryBrowsing?.();
    this.ed.state.lines = text.split("\n");
    this.ed.lastAction = null;
    this.setOff(off);
    this.onChange?.(this.getText());
  }

  private clampNormal(): void {
    if (this.mode !== "normal") return;
    const s = this.ed.state;
    const len = (s.lines[s.cursorLine] ?? "").length;
    if (s.cursorCol > 0 && s.cursorCol >= len) this.ed.setCursorCol(Math.max(0, len - 1));
  }

  private beginChange(): void {
    if (this.changeMark !== null) return;
    this.redoStack = [];
    this.ed.pushUndoSnapshot();
    this.changeMark = this.ed.undoStack.length;
    this.changeState = this.ed.state;
    this.changeText = this.getText();
  }

  private finishChange(): void {
    if (this.changeMark === null) return;
    const stack = this.ed.undoStack?.stack;
    if (this.ed.state === this.changeState && Array.isArray(stack)) {
      if (stack.length > this.changeMark) stack.length = this.changeMark;
      if (stack.length === this.changeMark && this.getText() === this.changeText) stack.pop();
    }
    this.changeMark = null;
    this.changeState = null;
  }

  private snapshot(): Snapshot {
    return structuredClone({ state: this.ed.state, pastes: this.ed.pastes, pasteCounter: this.ed.pasteCounter });
  }

  private undo(): void {
    if (this.redoText !== this.getText()) this.redoStack = [];
    if (!this.ed.undoStack?.length) return;
    this.redoStack.push(this.snapshot());
    this.ed.undo();
    this.redoText = this.getText();
  }

  private redo(): void {
    if (this.redoText !== this.getText()) this.redoStack = [];
    const s = this.redoStack.pop();
    if (!s) return;
    this.ed.pushUndoSnapshot();
    Object.assign(this.ed.state, s.state);
    this.ed.pastes = s.pastes;
    this.ed.pasteCounter = s.pasteCounter;
    this.ed.lastAction = null;
    this.ed.preferredVisualCol = null;
    this.onChange?.(this.getText());
    this.redoText = this.getText();
  }

  private vertical(d: number): void {
    const s = this.ed.state;
    if (this.wantCol === null) this.wantCol = s.cursorCol;
    s.cursorLine += d;
    this.ed.setCursorCol(Math.min(this.wantCol, s.lines[s.cursorLine].length));
  }

  private historyUp(): boolean {
    if (this.ed.state.cursorLine > 0) {
      this.vertical(-1);
      return false;
    }
    this.wantCol = null;
    this.ed.navigateHistory(-1);
    return true;
  }

  private historyDown(): boolean {
    const s = this.ed.state;
    if (s.cursorLine < s.lines.length - 1) {
      this.vertical(1);
      return false;
    }
    this.wantCol = null;
    if (this.ed.historyIndex > -1) this.ed.navigateHistory(1);
    return true;
  }

  private insertLastWord(): void {
    const hist: string[] = this.ed.history ?? [];
    const s = this.ed.state;
    const lw = this.lastWord;
    const cycling = lw !== null && lw.text === this.getText() && s.cursorLine === lw.line && s.cursorCol === lw.end;
    let idx = cycling ? lw!.idx + 1 : 0;
    let word: string | undefined;
    for (; idx < hist.length; idx++) {
      word = hist[idx]!.trim().split(/\s+/).pop();
      if (word) break;
    }
    if (!word) return;
    if (cycling) {
      const line: string = s.lines[lw!.line];
      s.lines[lw!.line] = line.slice(0, lw!.start) + line.slice(lw!.end);
      this.ed.setCursorCol(lw!.start);
    }
    const start = s.cursorCol;
    this.insertTextAtCursor(word);
    this.lastWord = { idx, line: s.cursorLine, start, end: start + word.length, text: this.getText() };
  }

  private parse(s: string): Parsed | typeof PENDING | typeof INVALID {
    let i = 0;
    const num = () => {
      let d = "";
      while (i < s.length && /[0-9]/.test(s[i]!) && !(d === "" && s[i] === "0")) d += s[i++];
      return d;
    };
    const word = (): string | typeof PENDING => {
      if (i >= s.length) return PENDING;
      let w = s[i++]!;
      if (w === "g") {
        if (i >= s.length) return PENDING;
        w += s[i++];
      }
      return w;
    };
    const motion = (m: string, base: Base & { op: string | null }): Parsed | typeof PENDING | typeof INVALID => {
      if ("fFtT".includes(m)) {
        if (i >= s.length) return PENDING;
        return { kind: "motion", m, arg: s[i], ...base };
      }
      return MOTIONS.has(m) ? { kind: "motion", m, ...base } : INVALID;
    };

    const c1 = num();
    const w = word();
    if (w === PENDING) return PENDING;
    if (OPS.has(w)) {
      const c2 = num();
      const m = word();
      if (m === PENDING) return PENDING;
      const base = { count: (c1 ? Number(c1) : 1) * (c2 ? Number(c2) : 1), hasCount: !!(c1 || c2) };
      if (m === w || (w.length === 2 && m === w[1])) return { kind: "line", op: w, ...base };
      if (m === "i" || m === "a") {
        if (i >= s.length) return PENDING;
        return { kind: "obj", op: w, obj: m + s[i], ...base };
      }
      return motion(m, { op: w, ...base });
    }
    const base = { count: c1 ? Number(c1) : 1, hasCount: !!c1 };
    if (w === "r") {
      if (i >= s.length) return PENDING;
      return { kind: "simple", c: "r", arg: s[i], ...base };
    }
    if (SIMPLE.has(w)) return { kind: "simple", c: w, ...base };
    return motion(w, { op: null, ...base });
  }

  private exec(cmd: string): typeof PENDING | undefined {
    const p = this.parse(cmd);
    if (p === PENDING) return PENDING;
    if (p === INVALID) return;
    const t = this.getText();
    const off = this.cursorOff();
    if (!(p.kind === "motion" && !p.op && (p.m === "j" || p.m === "k"))) this.wantCol = null;
    const change = p.kind === "simple" ? CHANGES.has(p.c) : p.op !== null && p.op !== "y";
    if (change && !this.replaying) this.lastChange = { cmd, inserted: [] };
    switch (p.kind) {
      case "motion":
        this.motion(p, t, off);
        break;
      case "line": {
        const last = lineIndex(t, t.length);
        const end = lineEnd(t, lineOffset(t, Math.min(lineIndex(t, off) + p.count - 1, last)));
        this.operate(p.op, { start: lineStart(t, off), end, linewise: true });
        break;
      }
      case "obj": {
        const span = this.textObject(t, off, p.obj, p.op);
        if (span) this.operate(p.op, span);
        break;
      }
      case "simple":
        this.simple(p, t, off);
        break;
    }
    if (this.mode === "normal") {
      this.finishChange();
      this.clampNormal();
    }
    return;
  }

  private motion(p: Extract<Parsed, { kind: "motion" }>, t: string, off: number): void {
    if (!p.op && (p.m === "j" || p.m === "k")) {
      for (let n = 0; n < p.count; n++) {
        if (p.m === "k") this.historyUp();
        else this.historyDown();
      }
      return;
    }
    const tg = this.target(t, off, p.m, p.arg, p.count, p.hasCount, p.op);
    if (!tg) return;
    if (!p.op) {
      this.setOff(tg.off);
      if (p.m === "$") this.wantCol = Infinity;
      return;
    }
    let a = off;
    let b = tg.off;
    if (b < a) [a, b] = [b, a];
    this.operate(
      p.op,
      tg.linewise
        ? { start: lineStart(t, a), end: lineEnd(t, b), linewise: true }
        : { start: a, end: tg.inclusive ? Math.min(b + 1, t.length) : b, linewise: false },
    );
  }

  private target(
    t: string,
    off: number,
    m: string,
    arg: string | undefined,
    n: number,
    hasCount: boolean,
    op: string | null,
  ): Target | null {
    const ls = lineStart(t, off);
    const le = lineEnd(t, off);
    const big = m === "W" || m === "B" || m === "E";
    const cur = lineIndex(t, off);
    const last = lineIndex(t, t.length);
    const mk = (o: number, inclusive = false, linewise = false): Target => ({ off: o, inclusive, linewise });
    switch (m) {
      case "h":
        return mk(Math.max(ls, off - n));
      case "l":
      case " ":
        return mk(Math.min(op ? le : Math.max(ls, le - 1), off + n));
      case "0":
        return mk(ls);
      case "^":
        return mk(firstNonBlank(t, ls));
      case "$": {
        const e = lineEnd(t, lineOffset(t, Math.min(cur + n - 1, last)));
        return mk(op ? e : Math.max(lineStart(t, e), e - 1));
      }
      case "w":
      case "W": {
        if (op === "c" && cls(t[off], big) > 0) {
          let p = off;
          const c = cls(t[off], big);
          while (p + 1 < t.length && cls(t[p + 1], big) === c) p++;
          for (let i = 1; i < n; i++) p = wordEnd(t, p, big);
          return mk(p, true);
        }
        let p = off;
        for (let i = 0; i < n; i++) p = wordForward(t, p, big);
        if (op && p > off) {
          const nl = t.lastIndexOf("\n", p - 1);
          if (nl >= off) p = nl;
        }
        return mk(p);
      }
      case "b":
      case "B": {
        let p = off;
        for (let i = 0; i < n; i++) p = wordBack(t, p, big);
        return mk(p);
      }
      case "e":
      case "E": {
        let p = off;
        for (let i = 0; i < n; i++) p = wordEnd(t, p, big);
        return mk(p, true);
      }
      case "f":
      case "F":
      case "t":
      case "T": {
        this.lastFind = { m, ch: arg! };
        const p = this.findChar(t, off, m, arg!, n, false);
        return p === null ? null : mk(p, m === "f" || m === "t");
      }
      case ";":
      case ",": {
        if (!this.lastFind) return null;
        const lm = m === ";" ? this.lastFind.m : REVERSE[this.lastFind.m]!;
        const p = this.findChar(t, off, lm, this.lastFind.ch, n, true);
        return p === null ? null : mk(p, lm === "f" || lm === "t");
      }
      case "%": {
        const p = matchPair(t, off);
        return p < 0 ? null : mk(p, true);
      }
      case "j":
      case "k": {
        const l = m === "j" ? cur + n : cur - n;
        if (l < 0 || l > last) return null;
        return mk(lineOffset(t, l), false, true);
      }
      case "G":
      case "gg": {
        const l = hasCount ? Math.min(n - 1, last) : m === "G" ? last : 0;
        return mk(firstNonBlank(t, lineOffset(t, l)), false, true);
      }
      case "_":
        return mk(firstNonBlank(t, lineOffset(t, Math.min(cur + n - 1, last))), false, true);
    }
    return null;
  }

  private findChar(t: string, off: number, m: string, ch: string, n: number, repeat: boolean): number | null {
    const ls = lineStart(t, off);
    const le = lineEnd(t, off);
    const fwd = m === "f" || m === "t";
    let p = off;
    if (repeat && m === "t") p++;
    if (repeat && m === "T") p--;
    for (let i = 0; i < n; i++) {
      const q = fwd ? t.indexOf(ch, p + 1) : p - 1 < ls ? -1 : t.lastIndexOf(ch, p - 1);
      if (q < 0 || q < ls || q >= le) return null;
      p = q;
    }
    return m === "t" ? p - 1 : m === "T" ? p + 1 : p;
  }

  private textObject(t: string, off: number, obj: string, op: string): Span | null {
    const inner = obj[0] === "i";
    const k = obj.slice(1);
    if (k === "w" || k === "W") return wordObject(t, off, inner, k === "W");
    if (QUOTES.has(k)) return quoteObject(t, off, inner, k);
    const br = BRACKETS[k];
    return br ? bracketObject(t, off, inner, br, op) : null;
  }

  private operate(op: string, span: Span): void {
    const t = this.getText();
    const off = this.cursorOff();
    let s = span.start;
    let e = span.end;
    const lw = span.linewise;
    const sel = t.slice(s, e);
    if (op === "y") {
      this.reg = { text: sel, linewise: lw };
      const ls = lineStart(t, off);
      if (!lw) this.setOff(s);
      else if (s < ls) this.setOff(s + Math.min(off - ls, lineEnd(t, s) - s));
      return;
    }
    this.beginChange();
    if (op === "d" || op === "c") this.reg = { text: sel, linewise: lw };
    if (op === "c") {
      this.apply(t.slice(0, s) + t.slice(e), s);
      this.toInsert();
      return;
    }
    if (op === "d") {
      if (!lw) {
        this.apply(t.slice(0, s) + t.slice(e), s);
        return;
      }
      let above = false;
      if (e < t.length) e++;
      else if (s > 0) {
        s--;
        above = true;
      }
      const nt = t.slice(0, s) + t.slice(e);
      this.apply(nt, firstNonBlank(nt, above ? lineStart(nt, s) : s));
      return;
    }
    const f = op === "gu" ? (x: string) => x.toLowerCase() : op === "gU" ? (x: string) => x.toUpperCase() : swapCase;
    this.apply(t.slice(0, s) + f(sel) + t.slice(e), s);
  }

  private simple(p: Extract<Parsed, { kind: "simple" }>, t: string, off: number): void {
    const n = p.count;
    const ls = lineStart(t, off);
    const le = lineEnd(t, off);
    const toEol = () => lineEnd(t, lineOffset(t, Math.min(lineIndex(t, off) + n - 1, lineIndex(t, t.length))));
    switch (p.c) {
      case "x":
        if (le > off) this.operate("d", { start: off, end: Math.min(off + n, le), linewise: false });
        break;
      case "X":
        if (off > ls) this.operate("d", { start: Math.max(ls, off - n), end: off, linewise: false });
        break;
      case "D":
        this.operate("d", { start: off, end: toEol(), linewise: false });
        break;
      case "C":
        this.operate("c", { start: off, end: toEol(), linewise: false });
        break;
      case "s":
        this.operate("c", { start: off, end: Math.min(off + n, le), linewise: false });
        break;
      case "S":
        this.operate("c", { start: ls, end: toEol(), linewise: true });
        break;
      case "Y":
        this.operate("y", { start: ls, end: toEol(), linewise: true });
        break;
      case "p":
      case "P":
        this.paste(p.c === "P", n);
        break;
      case "u":
        for (let i = 0; i < n; i++) this.undo();
        break;
      case "i":
        this.beginChange();
        this.toInsert();
        break;
      case "a":
        this.beginChange();
        this.setOff(Math.min(off + 1, le));
        this.toInsert();
        break;
      case "I":
        this.beginChange();
        this.setOff(firstNonBlank(t, ls));
        this.toInsert();
        break;
      case "A":
        this.beginChange();
        this.setOff(le);
        this.toInsert();
        break;
      case "o":
        this.beginChange();
        this.apply(t.slice(0, le) + "\n" + t.slice(le), le + 1);
        this.toInsert();
        break;
      case "O":
        this.beginChange();
        this.apply(t.slice(0, ls) + "\n" + t.slice(ls), ls);
        this.toInsert();
        break;
      case "J":
        this.join(t, off, n);
        break;
      case "~": {
        const end = Math.min(off + n, le);
        if (end <= off) break;
        this.beginChange();
        this.apply(t.slice(0, off) + swapCase(t.slice(off, end)) + t.slice(end), end);
        break;
      }
      case "r":
        if (off + n > le) break;
        this.beginChange();
        this.apply(t.slice(0, off) + p.arg!.repeat(n) + t.slice(off + n), off + n - 1);
        break;
      case ".":
        this.repeat(n, p.hasCount);
        break;
    }
  }

  private paste(before: boolean, n: number): void {
    const r = this.reg;
    if (!r.text && !r.linewise) return;
    this.beginChange();
    const t = this.getText();
    const off = this.cursorOff();
    const ls = lineStart(t, off);
    const le = lineEnd(t, off);
    if (r.linewise) {
      const block = Array(n).fill(r.text).join("\n");
      const nt = before ? t.slice(0, ls) + block + "\n" + t.slice(ls) : t.slice(0, le) + "\n" + block + t.slice(le);
      this.apply(nt, firstNonBlank(nt, before ? ls : le + 1));
      return;
    }
    const block = r.text.repeat(n);
    const at = before || le === ls ? off : Math.min(off + 1, le);
    this.apply(t.slice(0, at) + block + t.slice(at), at + block.length - 1);
  }

  private join(t: string, off: number, count: number): void {
    let text = t;
    let pos = off;
    let changed = false;
    for (let k = 0; k < Math.max(2, count) - 1; k++) {
      const le = lineEnd(text, pos);
      if (le >= text.length) break;
      let q = le + 1;
      while (text[q] === " " || text[q] === "\t") q++;
      const left = text.slice(0, le);
      const empty = lineStart(text, le) === le;
      const sep = empty || q >= text.length || text[q] === "\n" || text[q] === ")" || /[ \t]$/.test(left) ? "" : " ";
      text = left + sep + text.slice(q);
      pos = le;
      changed = true;
    }
    if (!changed) return;
    this.beginChange();
    this.apply(text, pos);
  }

  private repeat(count: number, hasCount: boolean): void {
    const lc = this.lastChange;
    if (!lc) return;
    const cmd = hasCount ? String(count) + lc.cmd.replace(/^[1-9][0-9]*/, "") : lc.cmd;
    this.replaying = true;
    try {
      this.exec(cmd);
      if (this.mode === "insert") {
        for (const d of lc.inserted) super.handleInput(d);
        this.toNormal();
      }
    } finally {
      this.replaying = false;
    }
  }
}

export default function (pi: ExtensionAPI) {
  let editor: ViEditor | undefined;

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const next = new ViEditor(tui, theme, keybindings);
      if (editor) next.inherit(editor);
      editor = next;
      return next;
    });
  });

  pi.on("session_shutdown", () => {
    editor?.restoreTerminal();
  });
}
