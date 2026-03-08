const { OBSWebSocket } = require('obs-websocket-js');
const fs = require("fs");
const path = require("path");
const os = require("os");

if (process.argv.length !== 3) {
  console.log("Usage: obs-cli-tool <cmd>");
  process.exit(1);
}

async function main(cmd) {
  const obs = new OBSWebSocket();

  const obsWsConfig = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config/obs-studio/plugin_config/obs-websocket/config.json"), { encoding: "utf8" }));

  await obs.connect("ws://localhost:4455", obsWsConfig.server_password);

  await obs.call(cmd);

  await obs.disconnect();
}

main(process.argv[2]);
