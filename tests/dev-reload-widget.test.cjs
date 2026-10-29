const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.join(__dirname, "../autoconfig/foxbook-dev-temp-addon.cfg"), "utf8"
);

function setup({ introduced = false, placed = false, provider = "xul" } = {}) {
  let widget = { provider };
  let placement = placed ? { area: "nav-bar" } : null;
  let node = null;
  let pref = introduced;
  let created = 0;
  let removed = 0;
  let added = 0;
  let definition;
  const messages = [];
  const document = {
    createXULElement() {
      return {
        attributes: {}, style: { values: {}, setProperty(key, value) { this.values[key] = value; } },
        setAttribute(key, value) { this.attributes[key] = value; },
        addEventListener() {},
      };
    },
    getElementById(id) {
      if (id === "nav-bar-customization-target") return { append(value) { node = value; } };
      return node;
    },
  };
  const ui = {
    PROVIDER_API: "api", AREA_NAVBAR: "nav-bar",
    getWidget() { return widget; },
    createWidget(value) { created++; definition = value; widget = { provider: "api" }; },
    getPlacementOfWidget() { return placement; },
    removeWidgetFromArea() { removed++; placement = null; node = null; },
    addWidgetToArea() { added++; placement = { area: "nav-bar" }; node = definition.onBuild(document); },
  };
  const prefs = {
    getBoolPref() { return pref; },
    setBoolPref(_key, value) { pref = value; },
    savePrefFile() {},
  };
  const services = {
    "@mozilla.org/preferences-service;1": prefs,
    "@mozilla.org/consoleservice;1": { logStringMessage(message) { messages.push(message); } },
    "@mozilla.org/observer-service;1": { addObserver() {} },
  };
  const context = vm.createContext({
    Components: { classes: new Proxy({}, { get(_target, key) { return { getService() { return services[key]; } }; } }), interfaces: {} },
  });
  vm.runInContext(source, context);
  context.window = { CustomizableUI: ui, document };
  return {
    run() { vm.runInContext("foxbookDevInstallReloadWidget(window)", context); },
    get state() { return { created, removed, added, pref, placement, node, messages }; },
  };
}

test("a placeholder XUL wrapper does not prevent registration and an icon is supplied", () => {
  const fixture = setup();
  fixture.run();
  assert.equal(fixture.state.created, 1);
  assert.equal(fixture.state.added, 1);
  assert.equal(fixture.state.pref, true);
  assert.match(fixture.state.node.style.values["list-style-image"], /reload\.svg/);
  assert.deepEqual(fixture.state.messages, []);
  fixture.run();
  assert.equal(fixture.state.created, 1);
  assert.equal(fixture.state.added, 1);
});

test("an incomplete first placement is replaced", () => {
  const fixture = setup({ placed: true });
  fixture.run();
  assert.equal(fixture.state.created, 1);
  assert.equal(fixture.state.removed, 1);
  assert.equal(fixture.state.added, 1);
  assert.equal(fixture.state.pref, true);
});

test("a user-removed widget is registered without being placed again", () => {
  const fixture = setup({ introduced: true });
  fixture.run();
  assert.equal(fixture.state.created, 1);
  assert.equal(fixture.state.added, 0);
  assert.equal(fixture.state.placement, null);
});
