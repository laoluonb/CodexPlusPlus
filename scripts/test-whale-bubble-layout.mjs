// 用已安装的 Edge / Chromium 验证真实鲸鱼引擎，不连接当前 Codex。
// CODEX_TEST_BROWSER_PATH 可指定其他 Chromium；CODEX_WHALE_TEST_OUTPUT 可保存截图。
import assert from "node:assert/strict";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import path from "node:path";
import os from "node:os";

const root = new URL("../", import.meta.url);
const compat = await readFile(new URL("assets/extensions/agent-pet/whale-compat.js", root), "utf8");
const engine = (await readFile(new URL("assets/inject/upstream/whale-widget/full-widget-codex.js", root), "utf8"))
  .replace("express()\nrender()\napplySoundSet()", "codexWhaleHost.test = { bubbleRenderModules, bubblePreviewInto, bubbleBox, textBox, root, state };\nexpress()\nrender()\napplySoundSet()");
assert.ok(engine.includes("codexWhaleHost.test ="));
const image = "data:image/png;base64," + (await readFile(new URL("assets/inject/upstream/whale-widget/DSniang1.png", root))).toString("base64");
const output = process.env.CODEX_WHALE_TEST_OUTPUT;
if (output) await mkdir(output, { recursive: true });
const server = createServer((_request, response) => { response.setHeader("Content-Type", "text/html; charset=utf-8"); response.end("<!doctype html><body style='margin:0;font-family:Arial,sans-serif;background:white'></body>"); });
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const profile = await mkdir(path.join(os.tmpdir(), `codex-whale-layout-${Date.now()}`), { recursive: true });
const browser = process.env.CODEX_TEST_BROWSER_PATH || "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const child = spawn(browser, ["--headless=new", "--disable-gpu", "--no-first-run", "--disable-extensions", "--disable-background-networking",
  `--user-data-dir=${profile}`, "--remote-debugging-port=0", "about:blank"], { stdio: "ignore", windowsHide: true });
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let socket, cdp;
try {
  let port;
  for (let i = 0; i < 120; i++) {
    if (child.exitCode !== null) throw Error(`Browser exited: ${child.exitCode}`);
    try { port = Number((await readFile(path.join(profile, "DevToolsActivePort"), "utf8")).split("\n")[0]); } catch {}
    if (port) break;
    await wait(100);
  }
  assert.ok(port, "browser starts");
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  socket = new WebSocket(targets.find((target) => target.type === "page").webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
  let serial = 0;
  const pending = new Map();
  socket.onmessage = ({ data }) => { const response = JSON.parse(data); pending.get(response.id)?.(response); pending.delete(response.id); };
  cdp = async (method, params = {}) => {
    const id = ++serial;
    let timeout;
    const reply = new Promise((resolve, reject) => {
      pending.set(id, resolve);
      timeout = setTimeout(() => { pending.delete(id); reject(Error(`${method} timed out`)); }, 20000);
    });
    socket.send(JSON.stringify({ id, method, params }));
    try { const response = await reply; if (response.error) throw Error(JSON.stringify(response.error)); return response.result; }
    finally { clearTimeout(timeout); }
  };
  const evaluate = async (expression) => {
    const response = await cdp("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (response.exceptionDetails) throw Error(JSON.stringify(response.exceptionDetails));
    return response.result.value;
  };
  await cdp("Emulation.setDeviceMetricsOverride", { width: 1100, height: 900, deviceScaleFactor: 1, mobile: false });
  await cdp("Page.navigate", { url: base });
  for (let i = 0; i < 40; i++) { if (await evaluate("location.origin === " + JSON.stringify(base))) break; await wait(50); }
  await evaluate(`(async () => {
    ${compat}
    codexPlusWhaleMedia.image = ${JSON.stringify(image)};
    const usage = {inputTokens:7441021,cachedInputTokens:0,outputTokens:0,totalTokens:7441021};
    const full = {
      "/dsh-whale/size.json":{ok:true,hasSavedConfig:true,sound:false,scale:1.5},
      "/dsh-whale/api-models.json":{ok:true,codexStatsOn:true,models:[{id:"codex",codex:{}}]},
      "/dsh-whale/bubble.json":{ok:true,config:{items:[]}},
      "/dsh-whale/roles.json":{ok:true,roles:[{id:"default",name:"默认"}]},
      "/dsh-whale/usage-settings.json":{ok:true,settings:{}}
    };
    const platform = {
      session:()=>({session_id:"test",title:"当前对话",host_id:"local"}),
      on:()=>()=>{},
      call:async (route, payload) => {
        if (route === "/whale/history") return {status:"ok",complete:true,periods:{today:{usage},week:{usage:{...usage,totalTokens:52828132}}},records:[],models:[],codex:{ok:true},all:{days:[],events:[]}};
        if (route === "/whale/session") return {status:"ok",sessionId:"test",total:usage,today:usage,rateLimits:[]};
        return {status:200,body:full[payload.path] || {ok:true}};
      }
    };
    const runtime = createCodexPlusWhaleFullRuntime(platform);
    await runtime.initialize();
    const engine = new Function("window","document","fetch","localStorage","setTimeout","clearTimeout","setInterval","clearInterval","requestAnimationFrame","cancelAnimationFrame","MutationObserver","ResizeObserver","AudioContext","webkitAudioContext","Image","Audio",${JSON.stringify(engine)});
    engine(...runtime.environment);
    if (runtime.state.initializationError) throw Error(runtime.state.initializationError);
    window.whaleTest = runtime;
    await runtime.history();
  })()`);
  const cases = [];
  const original = [
    { type: "text", text: "Codex 本机用量", size: 8, bold: true },
    { type: "today", modelId: "codex", size: 20, tpl: "{tokens_today}" },
    { type: "today", modelId: "codex", size: 4, tpl: "今日 tokens · 近7天 {tokens_week}" },
    { type: "balance", modelId: "current-provider", size: 3, tpl: "供应商余额 {balance}" },
    { type: "session", size: 3, tpl: "{session}", len: 20 },
  ];
  const measure = `(() => {
    const tb = document.querySelector(".dshwv-text");
    const box = tb.parentElement.getBoundingClientRect(), rect = tb.getBoundingClientRect();
    const u = box.width / 1026;
    const cx = (rect.left+rect.right)/2, cy = (rect.top+rect.bottom)/2;
    const rows = [...tb.children].filter(n=>n.offsetWidth && n.offsetHeight).map(n=> {
      const r = n.getBoundingClientRect();
      return {text:n.textContent,left:r.left,right:r.right,top:r.top,bottom:r.bottom};
    });
    return {fit:Number(tb.style.getPropertyValue("--codex-whale-content-fit")),cx,cy,u,rows};
  })()`;
  function check(result) {
    assert.ok(result.fit > 0 && result.fit <= 1);
    assert.equal(result.rows.length, 5, "all five usage modules remain visible");
    assert.match(result.rows.map((row) => row.text).join("|"), /7,441,021/);
    assert.match(result.rows.map((row) => row.text).join("|"), /52,828,132/);
    for (const row of result.rows) {
      assert.ok(Math.max(Math.abs(row.left-result.cx), Math.abs(row.right-result.cx)) <= 270*result.u+1, `horizontal: ${row.text}`);
      assert.ok(Math.max(Math.abs(row.top-result.cy), Math.abs(row.bottom-result.cy)) <= 130*result.u+1, `vertical: ${row.text}`);
    }
  }
  for (const width of [180, 300, 408, 625]) {
    for (const left of [false, true]) {
      for (const saved of [false, true]) {
        await evaluate(`(() => {
          const {test,defaultBubbleItems}=whaleTest.host, {root,bubbleBox}=test;
          root.style.setProperty("--dshw-base",${JSON.stringify(width+"px")});
          root.style.left="100px";root.style.top="80px";root.style.transition="none";
          root.classList.toggle("dshwv-left",${left});
          bubbleBox.classList.add("dshwv-pop-open");
          test.textBox.style.transition="none";
          test.bubbleRenderModules(${saved ? JSON.stringify(original) : "defaultBubbleItems([{modules:[]}])[0].modules"});
        })()`);
        await wait(60);
        const result = await evaluate(measure);
        check(result); cases.push({width,left,saved,fit:result.fit});
        if (output && width === 408 && !left) {
          const screenshot = await cdp("Page.captureScreenshot", { format: "png", clip: { x: 70, y: 60, width: 480, height: 490, scale: 1 } });
          await writeFile(path.join(output, saved ? "whale-saved-bubble.png" : "whale-default-bubble.png"), Buffer.from(screenshot.data, "base64"));
        }
      }
    }
  }
  // 保留自定义的多行/长文本，并验证后续变短时恢复字号。
  await evaluate(`whaleTest.host.test.bubbleRenderModules([{type:"text",size:50,text:"很长的自定义提示 ".repeat(30)}])`);
  await wait(60);
  assert.ok((await evaluate(measure)).fit < 1);
  await evaluate(`whaleTest.host.test.bubbleRenderModules([{type:"text",size:2,text:"完成"}])`);
  await wait(60);
  assert.equal((await evaluate(measure)).fit, 1);
  // 异步文本变化和图片解码后重新适配，避免只修复首次渲染。
  await evaluate(`whaleTest.host.test.textBox.querySelector(".dshwv-trow").textContent="较长的异步提示 ".repeat(20)`);
  await wait(60);
  assert.ok((await evaluate(measure)).fit < 1);
  await evaluate(`(async () => {
    const parent=whaleTest.host.test.textBox;
    const img=document.createElement("img");img.style.width="150px";img.style.height="auto";
    parent.appendChild(img);
    img.src=${JSON.stringify(image)};await img.decode();
  })()`);
  await wait(60);
  const loaded = await evaluate(measure);
  assert.ok(loaded.rows.every((row) => Math.max(Math.abs(row.top-loaded.cy), Math.abs(row.bottom-loaded.cy)) <= 130*loaded.u+1));
  // 预览沿用相同布局器。
  await evaluate(`(() => {
    const container=document.createElement("div");container.id="preview";container.style.width="320px";document.body.appendChild(container);
    whaleTest.host.test.bubblePreviewInto(container,${JSON.stringify(original)},320);
  })()`);
  await wait(60);
  assert.ok(await evaluate(`Number(document.querySelector("#preview .dshwv-text").style.getPropertyValue("--codex-whale-content-fit")) < 1`));
  await evaluate(`whaleTest.dispose()`);
  assert.equal(await evaluate(`document.querySelectorAll(".dshwv-root").length`), 0);
  console.log(JSON.stringify({ passed: cases.length, cases, preview: true, restoresFontSize: true, asyncTextAndImages: true, cleanup: true }, null, 2));
} finally {
  if (cdp) { try { await cdp("Browser.close"); } catch {} }
  socket?.close();
  if (child.exitCode === null) child.kill();
  await new Promise((resolve) => server.close(resolve));
}
