const { filterDisks } = require('./filter');
const { runLsblk } = require('./shell');

function friendlyName(device) {
  const model = [device.vendor, device.model].filter(Boolean).join(' ').trim();
  return model || device.name || device.kname || device.path;
}

async function listDisks() {
  const data = await runLsblk();
  const disks = await filterDisks(data.blockdevices || []);
  return disks.map((device) => ({
    name: friendlyName(device),
    path: device.path,
  }));
}

module.exports = listDisks;
