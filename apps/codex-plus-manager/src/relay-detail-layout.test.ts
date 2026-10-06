import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const css = await readFile(new URL("./styles.css", import.meta.url), "utf8");
const app = await readFile(new URL("./App.tsx", import.meta.url), "utf8");

test("provider detail keeps its heading and actions in separate grid tracks", () => {
  assert.match(css, /\.relay-detail-header\s*\{[^}]*display: grid;[^}]*grid-template-columns: minmax\(0, 1fr\) auto;/);
  assert.match(css, /\.relay-editor-heading\s*\{[^}]*grid-template-columns: 36px minmax\(0, 1fr\);/);
  assert.match(css, /\.relay-editor-actions > button\s*\{[^}]*flex-shrink: 0;[^}]*white-space: nowrap;/);
});

test("provider detail responds to the available pane width, not the window width", () => {
  assert.match(css, /\.relay-detail-page\s*\{[^}]*container-name: relay-detail;[^}]*container-type: inline-size;/);
  assert.match(css, /@container relay-detail \(max-width: 640px\)\s*\{\s*\.relay-detail-header\s*\{[^}]*grid-template-columns: minmax\(0, 1fr\);/);
  assert.match(css, /\.relay-editor-heading-copy strong\s*\{[^}]*text-overflow: ellipsis;/);
  assert.match(app, /<strong title=\{draft\.name/);
});
