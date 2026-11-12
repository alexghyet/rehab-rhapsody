/* Browser integration check. Audio playback is real HTMLMediaElement playback.
 * Optional BLE coverage simulates navigator.bluetooth, never a physical radio.
 * Run after flutter build web and serving build/web:
 * npm install --prefix build/demo-smoke --no-save playwright-core@1.65.0
 * node scripts/demo_browser_smoke.cjs http://127.0.0.1:7357
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const baseUrl = process.argv[2] || 'http://127.0.0.1:7357';
const out = path.join(root, 'build/demo-smoke');
fs.mkdirSync(out, { recursive: true });
const report = {
  baseUrl,
  audio: 'Real HTMLMediaElement.play and playing events; playback is not stubbed.',
  bluetooth: 'Simulated browser device only; no claim of physical radio validation.',
  largeText: 'Not emulated here; use Flutter widget tests for MediaQuery text scaling.',
  cases: [],
};

function instrumentation() {
  const media = { calls: [], playing: [], failures: [], cleanupEvents: 0, elements: [] };
  const registered = new WeakSet();
  const original = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    if (!registered.has(this)) {
      registered.add(this);
      media.elements.push(this);
      this.addEventListener('playing', () => {
        media.playing.push({ src: this.currentSrc || this.src, at: performance.now() });
      });
      this.addEventListener('error', () => {
        if (!this.getAttribute('src')) {
          // audioplayers releases a retired source by clearing src. Chrome may
          // emit an error for that intentional cleanup after playback stopped.
          ++media.cleanupEvents;
          return;
        }
        media.failures.push({ src: this.currentSrc || this.src, error: this.error?.message });
      });
    }
    media.calls.push({ src: this.currentSrc || this.src, at: performance.now() });
    const result = original.apply(this, args);
    if (result?.catch) result.catch(error => {
      media.failures.push({ name: error.name, message: error.message });
    });
    return result;
  };
  window.__demoSmoke = { media };
}

function simulatedBluetooth() {
  const serviceUuid = 'b8141000-8c3f-4b0b-9a7c-1a16adcc7a21';
  const motionUuid = 'b8141001-8c3f-4b0b-9a7c-1a16adcc7a21';
  const state = { requests: [], connected: false, notifying: false, moving: false, tiltDegrees: 0, sending: true, sequence: 0, frames: 0 };
  const device = new EventTarget();
  device.id = 'smoke-simulated-baton';
  device.name = 'Rehab Rhapsody';
  const characteristic = new EventTarget();
  characteristic.uuid = motionUuid;
  characteristic.properties = {
    broadcast: false, read: false, writeWithoutResponse: false, write: false,
    notify: true, indicate: false, authenticatedSignedWrites: false,
    reliableWrite: false, writableAuxiliaries: false,
  };
  characteristic.getDescriptors = async () => [];
  characteristic.startNotifications = async () => {
    state.notifying = true;
    return characteristic;
  };
  characteristic.stopNotifications = async () => {
    state.notifying = false;
    return characteristic;
  };
  const service = {
    uuid: serviceUuid, isPrimary: true, device,
    getCharacteristics: async () => [characteristic],
    getCharacteristic: async uuid => {
      if (uuid !== motionUuid) throw new DOMException('Unknown characteristic', 'NotFoundError');
      return characteristic;
    },
  };
  characteristic.service = service;
  device.gatt = {
    device, connected: false,
    async connect() {
      state.connected = this.connected = true;
      return this;
    },
    disconnect() {
      if (!this.connected) return;
      state.connected = this.connected = false;
      state.notifying = false;
      device.dispatchEvent(new Event('gattserverdisconnected'));
    },
    getPrimaryServices: async () => [service],
    getPrimaryService: async uuid => {
      if (uuid !== serviceUuid) throw new DOMException('Unknown service', 'NotFoundError');
      return service;
    },
  };
  const bluetooth = new EventTarget();
  bluetooth.getAvailability = async () => true;
  bluetooth.getDevices = async () => [device];
  bluetooth.requestDevice = async options => {
    state.requests.push({ options, userActivation: navigator.userActivation.isActive });
    return device;
  };
  Object.defineProperty(navigator, 'bluetooth', { configurable: true, value: bluetooth });
  setInterval(() => {
    if (!state.connected || !state.notifying || !state.sending) return;
    const buffer = new ArrayBuffer(20);
    const value = new DataView(buffer);
    value.setUint8(0, 1);
    value.setUint16(2, state.sequence++ & 0xffff, true);
    value.setUint32(4, Math.round(performance.now() * 1000) >>> 0, true);
    const angle = state.tiltDegrees * Math.PI / 180;
    value.setInt16(8, Math.round(Math.sin(angle) / 0.000122), true);
    value.setInt16(10, 0, true);
    value.setInt16(12, Math.round(Math.cos(angle) / 0.000122), true);
    value.setInt16(14, state.moving ? 3000 : 0, true);
    value.setInt16(16, 0, true);
    value.setInt16(18, 0, true);
    characteristic.value = value;
    characteristic.dispatchEvent(new Event('characteristicvaluechanged'));
    ++state.frames;
  }, 60);
  window.__simulatedBaton = { state, device };
}

async function semanticText(page) {
  return page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics'))
    .map(e => [e.getAttribute('aria-label') || '', e.textContent || ''].join(' ')).join('\n'));
}

async function waitText(page, text, timeout = 10000) {
  await page.waitForFunction(expected => Array.from(document.querySelectorAll('flt-semantics'))
    .some(e => `${e.getAttribute('aria-label') || ''} ${e.textContent || ''}`.includes(expected)), text, { timeout });
}

async function enableSemantics(page) {
  await page.goto(baseUrl, { waitUntil: 'networkidle' });
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 20000 });
  await placeholder.evaluate(element => element.click());
  await page.getByRole('button', { name: 'Start song', exact: true }).waitFor({ timeout: 10000 });
}

async function clickButton(page, name) {
  const button = page.getByRole('button', { name, exact: true });
  await button.waitFor({ state: 'attached', timeout: 10000 });
  // No scroll fallback: every action must fit the current screen. Wait for
  // route transitions to settle, then click the canvas at the semantic bounds.
  const viewport = page.viewportSize();
  let previous;
  for (let attempt = 0; attempt < 80; ++attempt) {
    const box = await button.boundingBox();
    if (box && box.x >= 0 && box.y >= 0 && box.x + box.width <= viewport.width + 1
        && box.y + box.height <= viewport.height + 1 && previous
        && Math.abs(box.y - previous.y) < 0.2 && Math.abs(box.x - previous.x) < 0.2) {
      assert.ok(box.width >= 44 && box.height >= 44, `${name} has an undersized touch target`);
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      return;
    }
    previous = box;
    await page.waitForTimeout(50);
  }
  throw new Error(`Button does not fit without scrolling: ${name}`);
}

async function chooseMode(page, mode) {
  await clickButton(page, 'Choose play mode');
  await clickButton(page, mode);
}

async function openSetting(page, name) {
  await clickButton(page, 'Settings');
  await clickButton(page, name);
}

async function connectBaton(page) {
  await clickButton(page, 'Baton settings');
  await clickButton(page, 'Connect baton');
  await page.getByRole('button', { name: 'Disconnect baton', exact: true }).waitFor();
  await waitText(page, 'readings/s');
  await clickButton(page, 'Close settings');
}

async function assertScreenFits(page) {
  const viewport = page.viewportSize();
  for (const button of await page.getByRole('button').all()) {
    const box = await button.boundingBox();
    if (!box) continue;
    const label = await button.getAttribute('aria-label') || await button.textContent();
    assert.ok(box.x >= -1 && box.y >= -1 && box.x + box.width <= viewport.width + 1
      && box.y + box.height <= viewport.height + 1, `Off-screen button: ${label}`);
    assert.ok(box.width >= 44 && box.height >= 44, `Small touch target: ${label}`);
  }
}

async function settingsChecks(page, entry) {
  for (const name of ['Mode of play', 'Instrument', 'Target height', 'Volume',
      'Tempo', 'Your baton', 'Arm motion', 'How to play']) {
    await openSetting(page, name);
    await page.waitForTimeout(300);
    await assertScreenFits(page);
    if (name === 'How to play') {
      for (let step = 0; step < 4; step++) {
        await clickButton(page, 'Next');
        await assertScreenFits(page);
      }
    }
    await page.screenshot({ path: path.join(out, `${entry.name}-${name.replaceAll(' ', '-')}.png`) });
    await clickButton(page, 'Close settings');
  }
  // A settings panel pauses audible playback, and closing it stays paused.
  await clickButton(page, 'Start song');
  await page.getByRole('button', { name: 'Pause song', exact: true }).waitFor();
  await clickButton(page, 'Settings');
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  await clickButton(page, 'Close settings');
  await page.getByRole('button', { name: /^(Start|Resume) song$/ }).waitFor();
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  entry.checked = ['all eight settings pages fit without scrolling', '44px minimum visible controls',
    'button-paged instructions', 'opening settings pauses sound', 'closing settings does not resume'];
}

async function mediaSnapshot(page) {
  return page.evaluate(() => ({
    calls: window.__demoSmoke.media.calls,
    playing: window.__demoSmoke.media.playing,
    failures: window.__demoSmoke.media.failures,
    cleanupEvents: window.__demoSmoke.media.cleanupEvents,
    currentlyPlaying: window.__demoSmoke.media.elements.filter(e => !e.paused && !e.ended).length,
  }));
}

async function playPad(page, pitch = 'C', octave = 4) {
  const before = (await mediaSnapshot(page)).playing.length;
  await clickButton(page, `Play ${pitch}, octave ${octave}`);
  await waitText(page, `Current note ${pitch}, octave ${octave}`);
  await page.waitForFunction(count => window.__demoSmoke.media.playing.length > count, before, { timeout: 10000 });
}

async function runCase(browser, name, viewport, body, simulated = false) {
  const entry = { name, viewport, simulatedBluetooth: simulated, passed: false, consoleErrors: [], pageErrors: [], requests: [] };
  report.cases.push(entry);
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1 });
  await context.addInitScript(instrumentation);
  if (simulated) await context.addInitScript(simulatedBluetooth);
  const page = await context.newPage();
  page.on('console', message => { if (message.type() === 'error') entry.consoleErrors.push(message.text()); });
  page.on('pageerror', error => entry.pageErrors.push(error.message));
  page.on('response', response => {
    if (response.url().includes('/audio/')) entry.requests.push({ url: response.url(), status: response.status() });
  });
  try {
    await enableSemantics(page);
    await assertScreenFits(page);
    await page.screenshot({ path: path.join(out, `${name}-initial.png`) });
    await body(page, entry);
    entry.media = await mediaSnapshot(page);
    assert.equal(entry.pageErrors.length, 0, JSON.stringify(entry.pageErrors));
    assert.equal(entry.media.failures.length, 0, JSON.stringify(entry.media.failures));
    entry.passed = true;
    console.log(`PASS ${name}: ${entry.media.playing.length} real audio playing events`);
  } catch (error) {
    entry.error = error.stack || String(error);
    entry.media = await mediaSnapshot(page).catch(() => null);
    entry.semantics = await semanticText(page).catch(() => 'unavailable');
    await page.screenshot({ path: path.join(out, `${name}-failure.png`) }).catch(() => {});
    console.error(`FAIL ${name}: ${error.message}`);
  } finally {
    fs.writeFileSync(path.join(out, 'browser-smoke-report.json'), JSON.stringify(report, null, 2));
    await context.close();
  }
}

async function musicChecks(page, entry) {
  await chooseMode(page, 'Free play');
  for (const instrument of ['Piano', 'Strings', 'Flute', 'Drums']) {
    await openSetting(page, 'Instrument');
    await clickButton(page, instrument);
    await clickButton(page, 'Close settings');
    await playPad(page);
    entry.requests.forEach(response => assert.ok(response.status >= 200 && response.status < 300,
      `Audio request failed with ${response.status}: ${response.url}`));
  }
  await page.screenshot({ path: path.join(out, `${entry.name}-music.png`) });
  await clickButton(page, 'Pause session');
  await waitText(page, 'Current note, no note playing');
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  await chooseMode(page, 'Guided');
  await waitText(page, 'Step 1 of 14');
  await playPad(page);
  await waitText(page, 'Step 2 of 14');
  await playPad(page);
  await waitText(page, 'Step 3 of 14');
  await waitText(page, 'Next: G4');
  await clickButton(page, 'Pause session');
  await waitText(page, 'Current note, no note playing');
  await clickButton(page, 'Reset timer');
  await waitText(page, '00:00:00');
  entry.checked = ['four instruments', 'real audio playing events', 'current note', 'pause silence', 'guided melody advancement', 'reset'];
}

async function bluetoothChecks(page, entry) {
  await chooseMode(page, 'Free play');
  await connectBaton(page);
  await waitText(page, 'Live');
  const state = await page.evaluate(() => window.__simulatedBaton.state);
  assert.equal(state.requests.length, 1);
  assert.equal(state.requests[0].userActivation, true, 'Web chooser lost its user gesture');
  assert.deepEqual(state.requests[0].options.filters[0].services, ['b8141000-8c3f-4b0b-9a7c-1a16adcc7a21']);
  await clickButton(page, 'Start session');
  const before = (await mediaSnapshot(page)).playing.length;
  await page.evaluate(() => { window.__simulatedBaton.state.moving = true; });
  await page.waitForFunction(count => window.__demoSmoke.media.playing.length > count, before, { timeout: 10000 });
  await waitText(page, 'Current note G, octave 4');
  await page.evaluate(() => { window.__simulatedBaton.state.moving = false; });
  await waitText(page, 'Current note, no note playing');
  await clickButton(page, 'Baton settings');
  await clickButton(page, 'Disconnect baton');
  await waitText(page, 'Baton not connected');
  await clickButton(page, 'Connect baton');
  await page.getByRole('button', { name: 'Disconnect baton', exact: true }).waitFor();
  await waitText(page, 'readings/s');
  await page.evaluate(() => window.__simulatedBaton.device.gatt.disconnect());
  await waitText(page, 'Baton not connected');
  await waitText(page, 'Baton disconnected');
  entry.simulatedBaton = await page.evaluate(() => window.__simulatedBaton.state);
  entry.checked = ['simulated Web Bluetooth connection', 'user gesture preserved', 'service filter', 'live decoded frames', 'motion-to-real-audio', 'release stops note', 'disconnect pauses', 'reconnect', 'unexpected link loss'];
  await page.screenshot({ path: path.join(out, `${entry.name}-disconnected.png`) });
}

async function songChecks(page, entry) {
  const chart = readSongChart();
  await clickButton(page, 'Start song');
  await page.getByRole('button', { name: 'Pause song', exact: true }).waitFor();
  await waitText(page, 'Count-in');
  // Use the real media clock, then click the real timing-only input near its
  // target. Playback, Flutter clock, scoring and foreground note all run normally.
  for (const note of chart.notes.slice(0, 3)) {
    await page.waitForFunction(at => window.__demoSmoke.media.elements.some(e =>
      e.src.includes('/songs/ode_to_joy.wav') && !e.paused && e.currentTime >= at - 0.08), note.at / 1e6);
    await clickButton(page, 'Play note');
  }
  await waitText(page, `3/${chart.notes.length}`);
  await waitText(page, 'Perfect timing!');
  await page.screenshot({ path: path.join(out, `${entry.name}-playing.png`) });
  await clickButton(page, 'Pause song');
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  const pausedAt = await page.evaluate(() => window.__demoSmoke.media.elements.find(e => e.src.includes('/songs/ode_to_joy.wav')).currentTime);
  await page.waitForTimeout(400);
  assert.equal(await page.evaluate(() => window.__demoSmoke.media.elements.find(e => e.src.includes('/songs/ode_to_joy.wav')).currentTime), pausedAt);
  await clickButton(page, 'Resume song');
  await page.waitForFunction(at => window.__demoSmoke.media.elements.some(e => e.src.includes('/songs/ode_to_joy.wav') && e.currentTime > at + 0.15), pausedAt);
  // Move the real media clock near its end to exercise EOF and retained results
  // without making every browser check wait through a complete arrangement.
  await page.evaluate(() => {
    const backing = window.__demoSmoke.media.elements.find(e => e.src.includes('/songs/ode_to_joy.wav'));
    backing.currentTime = backing.duration - 0.6;
  });
  await page.getByRole('button', { name: 'Play again', exact: true }).waitFor();
  await waitText(page, 'You made music!');
  await clickButton(page, 'Restart');
  await page.getByRole('button', { name: 'Start song', exact: true }).waitFor();
  await waitText(page, `0/${chart.notes.length}`);
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  entry.checked = ['real backing audio', 'four-beat count-in', 'three timed hits with automatic pitch', 'foreground note audio', 'score/combo feedback', 'pause freezes media', 'resume preserves position', 'real media EOF retains result', 'restart resets score and stops sound'];
}

async function songBluetoothChecks(page, entry) {
  const chart = readSongChart();
  await connectBaton(page);
  // Set a comfortable, stationary target using the live sensor value.
  await clickButton(page, 'Adjust target');
  await clickButton(page, 'Use current position');
  await waitText(page, 'In target');
  await clickButton(page, 'Close settings');
  await clickButton(page, 'Start song');
  await page.getByRole('button', { name: 'Pause song', exact: true }).waitFor();
  // No taps or gyro motion: remaining inside the band is sufficient.
  await waitText(page, `3/${chart.notes.length}`);
  const played = (await mediaSnapshot(page)).playing.map(item => item.src);
  assert.ok(played.some(src => src.includes('piano_64.wav')), 'Automatic E4 target was not played');
  assert.ok(played.some(src => src.includes('piano_65.wav')), 'Automatic F4 target was not played');
  const state = await page.evaluate(() => window.__simulatedBaton.state);
  assert.equal(state.moving, false);
  await page.evaluate(() => { window.__simulatedBaton.state.tiltDegrees = -35; });
  await waitText(page, 'Higher');
  await page.waitForFunction(at => window.__demoSmoke.media.elements.some(e =>
    e.src.includes('/songs/ode_to_joy.wav') && !e.paused && e.currentTime >= at + 0.35), chart.notes[3].at / 1e6);
  await waitText(page, `3/${chart.notes.length}`);
  await page.evaluate(() => { window.__simulatedBaton.state.tiltDegrees = 0; });
  await waitText(page, 'In target');
  await waitText(page, `4/${chart.notes.length}`);
  // A linked device that stops sending cannot earn further held-target notes.
  await page.evaluate(() => { window.__simulatedBaton.state.sending = false; });
  await page.waitForFunction(at => window.__demoSmoke.media.elements.some(e =>
    e.src.includes('/songs/ode_to_joy.wav') && !e.paused && e.currentTime >= at + 0.35), chart.notes[5].at / 1e6);
  await waitText(page, `4/${chart.notes.length}`);
  await page.screenshot({ path: path.join(out, `${entry.name}-target.png`) });
  await page.evaluate(() => window.__simulatedBaton.device.gatt.disconnect());
  await page.getByRole('button', { name: 'Resume song', exact: true }).waitFor();
  await page.waitForFunction(() => window.__demoSmoke.media.elements.every(e => e.paused || e.ended));
  entry.checked = ['target captures live comfortable position', 'stationary in-zone hold scores successive pitches without taps', 'outside target does not score', 'returning to target resumes hits', 'stale held reading does not score', 'link loss pauses backing and foreground audio'];
}

function readSongChart() {
  return JSON.parse(fs.readFileSync(path.join(root, 'assets/audio/songs/manifest.json'), 'utf8'))[0];
}

function loadPlaywright() {
  const packageDirectory = path.join(out, 'node_modules/playwright-core');
  if (!fs.existsSync(path.join(packageDirectory, 'package.json'))) {
    throw new Error('Browser smoke dependencies are missing. From the repository root, run: '
      + 'npm install --prefix build/demo-smoke --no-save playwright-core@1.65.0');
  }
  return require(packageDirectory);
}

(async () => {
  const { chromium } = loadPlaywright();
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    await runCase(browser, 'settings-mobile-320', { width: 320, height: 568 }, settingsChecks);
    await runCase(browser, 'song-desktop', { width: 1280, height: 1000 }, songChecks);
    await runCase(browser, 'song-mobile-320', { width: 320, height: 568 }, songChecks);
    await runCase(browser, 'song-simulated-ble', { width: 1280, height: 1000 }, songBluetoothChecks, true);
    await runCase(browser, 'song-target-mobile-320', { width: 320, height: 568 }, songBluetoothChecks, true);
    await runCase(browser, 'desktop', { width: 1280, height: 1000 }, musicChecks);
    await runCase(browser, 'mobile-320', { width: 320, height: 568 }, musicChecks);
    await runCase(browser, 'simulated-ble', { width: 1280, height: 1000 }, bluetoothChecks, true);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(out, 'browser-smoke-report.json'), JSON.stringify(report, null, 2));
  }
  if (report.cases.some(entry => !entry.passed)) process.exitCode = 1;
})().catch(error => {
  report.fatal = error.stack || String(error);
  fs.writeFileSync(path.join(out, 'browser-smoke-report.json'), JSON.stringify(report, null, 2));
  console.error(error);
  process.exitCode = 1;
});
