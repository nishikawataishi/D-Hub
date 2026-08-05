// Chrome DevTools Protocol の最小ドライバ。
// Flutter web は canvas に描画するため DOM セレクタが使えない。
// 座標クリック + スクリーンショットで操作する。
import { writeFileSync } from 'node:fs';

const PORT = 9222;

async function target() {
  const res = await fetch(`http://127.0.0.1:${PORT}/json`);
  const list = await res.json();
  const page = list.find((t) => t.type === 'page');
  if (!page) throw new Error('page target not found');
  return page.webSocketDebuggerUrl;
}

const ws = new WebSocket(await target());
await new Promise((r) => (ws.onopen = r));

let id = 0;
const pending = new Map();
ws.onmessage = (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
  }
};
const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const n = ++id;
    pending.set(n, { resolve, reject });
    ws.send(JSON.stringify({ id: n, method, params }));
  });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function click(x, y) {
  const base = { x: Number(x), y: Number(y), button: 'left', clickCount: 1 };
  await send('Input.dispatchMouseEvent', { type: 'mousePressed', ...base });
  await sleep(60);
  await send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...base });
}

await send('Page.enable');
await send('Runtime.enable');

// iPhone 6.9インチ = 430x932 CSS px / DPR 3 → 撮影結果は 1290x2796
await send('Emulation.setDeviceMetricsOverride', {
  width: 430,
  height: 932,
  deviceScaleFactor: 3,
  mobile: true,
});

// argv は "cmd:arg" 形式で順に実行する
for (const step of process.argv.slice(2)) {
  const i = step.indexOf(':');
  const cmd = i === -1 ? step : step.slice(0, i);
  const arg = i === -1 ? '' : step.slice(i + 1);

  if (cmd === 'goto') {
    await send('Page.navigate', { url: arg });
  } else if (cmd === 'wait') {
    await sleep(Number(arg));
  } else if (cmd === 'click') {
    const [x, y] = arg.split(',');
    await click(x, y);
  } else if (cmd === 'type') {
    await send('Input.insertText', { text: arg });
  } else if (cmd === 'key') {
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: arg, code: arg, windowsVirtualKeyCode: arg === 'Enter' ? 13 : 9 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: arg, code: arg, windowsVirtualKeyCode: arg === 'Enter' ? 13 : 9 });
  } else if (cmd === 'shot') {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(arg, Buffer.from(data, 'base64'));
    console.log('saved', arg);
  } else if (cmd === 'eval') {
    const r = await send('Runtime.evaluate', { expression: arg, returnByValue: true });
    console.log(JSON.stringify(r.result?.value ?? r.result));
  } else {
    throw new Error('unknown command: ' + cmd);
  }
}

ws.close();
