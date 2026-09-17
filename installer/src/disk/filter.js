const { runFindmnt } = require('./shell');

const LOOP_DEVICE_RE = /(?:^|[^a-z])loop(?:back)?(?:\d+)?(?:$|[^a-z])/i;
const PARTITION_RE = /^(\/dev\/(?:sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|nvme\d+n\d+|mmcblk\d+|md\d+))(?:p?\d+)?$/;

function deviceText(device) {
  return [device.path, device.name, device.kname, device.type, device.tran].filter(Boolean).join(' ');
}

function isLoopDevice(device) {
  return device.type === 'loop' || LOOP_DEVICE_RE.test(deviceText(device));
}

function partitionParent(path) {
  return PARTITION_RE.exec(path || '')?.[1] || path;
}

function hasMountpoint(device, mountpoint) {
  return (device.mountpoints || []).includes(mountpoint)
    || (device.children || []).some((child) => hasMountpoint(child, mountpoint));
}

function isBootDisk(device, bootSource, mountedBootDisk) {
  const devicePath = device.path || '';
  return devicePath === mountedBootDisk
    || (bootSource && partitionParent(bootSource) === devicePath)
    || hasMountpoint(device, '/');
}

async function filterDisks(devices) {
  const bootSource = await runFindmnt().catch(() => '');
  const mountedBootDisk = (devices || []).find((device) => hasMountpoint(device, '/'))?.path || '';
  return (devices || []).filter((device) => device.type === 'disk')
    .filter((device) => !isLoopDevice(device))
    .filter((device) => !isBootDisk(device, bootSource, mountedBootDisk));
}

module.exports = { filterDisks, isBootDisk, isLoopDevice };
