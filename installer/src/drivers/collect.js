const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const fs = require('node:fs');
const path = require('node:path');

const execFileAsync = promisify(execFile);

async function run(command, args = []) {
  try {
    const result = await execFileAsync(command, args, {
      maxBuffer: 8 * 1024 * 1024,
      encoding: 'utf8',
    });
    return { stdout: result.stdout || '', stderr: result.stderr || '' };
  } catch (error) {
    return {
      stdout: error.stdout || '',
      stderr: error.stderr || error.message || '',
      error: [
        `${command} ${args.join(' ')} failed`,
        error.message,
        error.stderr,
      ].filter(Boolean).join(': '),
    };
  }
}

function unique(values) {
  return [...new Set(values.filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function parseLspci(output) {
  const devices = [];
  let current = null;

  for (const line of output.split('\n')) {
    if (/^[0-9a-f]{2}:[0-9a-f]{2}\.\d/.test(line)) {
      if (current) devices.push(current);
      current = { description: line.trim(), driverInUse: '', kernelModules: [] };
      continue;
    }
    if (!current) continue;
    const active = line.match(/Kernel driver in use:\s*(.+)$/);
    const modules = line.match(/Kernel modules:\s*(.+)$/);
    if (active) current.driverInUse = active[1].trim();
    if (modules) current.kernelModules = modules[1].split(',').map((item) => item.trim());
  }
  if (current) devices.push(current);
  return devices;
}

function parseUbuntuDrivers(output) {
  const packages = [];
  for (const line of output.split('\n')) {
    const driverLine = line.match(/driver\s*:\s*([a-z0-9][a-z0-9+.-]*)/i);
    if (driverLine) packages.push(driverLine[1]);
    else if (/^\s*[a-z0-9][a-z0-9+.-]*(?:driver|firmware|microcode)/i.test(line)) {
      packages.push(line.trim().split(/\s+/)[0]);
    }
  }
  return unique(packages);
}

function parseLsmod(output) {
  return unique(output.split('\n').slice(1).map((line) => line.trim().split(/\s+/)[0]));
}

function collectNetworkDrivers() {
  const devices = [];
  const networkRoot = '/sys/class/net';
  try {
    for (const name of fs.readdirSync(networkRoot)) {
      const devicePath = path.join(networkRoot, name, 'device');
      try {
        const driverPath = fs.realpathSync(path.join(devicePath, 'driver'));
        const modulePath = fs.realpathSync(path.join(driverPath, 'module'));
        devices.push({
          interface: name,
          driver: path.basename(driverPath),
          module: path.basename(modulePath),
        });
      } catch (_error) {
        // Loopback, virtual interfaces, and restricted sysfs nodes have no
        // physical driver. They remain represented by the interface name.
        devices.push({ interface: name, driver: '', module: '' });
      }
    }
  } catch (_error) {
    return [];
  }
  return devices;
}

function driverPackage(name) {
  return /^(linux-(?:image|modules|firmware)|linux-firmware|firmware-|nvidia|xserver-xorg-video|oem-|bcmwl|intel-microcode|amd(?:64)?-microcode)/i.test(name);
}

async function collect() {
  const [ubuntuList, ubuntuDevices, lspci, lsusb, lsmod, installed] = await Promise.all([
    run('/usr/bin/ubuntu-drivers', ['list']),
    run('/usr/bin/ubuntu-drivers', ['devices']),
    run('/usr/bin/lspci', ['-nnk']),
    // Keep this invocation portable. The installed lsusb on the target
    // system does not support the GNU-style -nn option.
    run('/usr/bin/lsusb'),
    run('/usr/sbin/lsmod'),
    run('/usr/bin/dpkg-query', ['-W', '-f=${binary:Package}\n']),
  ]);

  const pciDevices = parseLspci(lspci.stdout);
  const recommendedPackages = unique([
    ...parseUbuntuDrivers(ubuntuList.stdout),
    ...parseUbuntuDrivers(ubuntuDevices.stdout),
  ]);
  const installedPackages = unique(installed.stdout.split('\n').filter(driverPackage));
  const kernelModules = unique([
    ...parseLsmod(lsmod.stdout),
    ...pciDevices.flatMap((device) => device.kernelModules),
    ...pciDevices.map((device) => device.driverInUse),
    ...collectNetworkDrivers().flatMap((device) => [device.driver, device.module]),
  ]);

  return {
    collectedAt: new Date().toISOString(),
    completeForCurrentHardware: recommendedPackages.length > 0,
    note: 'Driver recommendations are based on the live system hardware. In-tree kernel drivers are reported as modules; package installation still requires final target-kernel validation.',
    packages: recommendedPackages.map((name) => ({
      name,
      required: true,
      source: 'ubuntu-drivers',
      reason: 'Ubuntu hardware-driver recommendation',
    })),
    installedDriverPackages: installedPackages,
    kernelModules,
    hardware: {
      pci: pciDevices,
      usb: lsusb.stdout.trim().split('\n').filter(Boolean),
      network: collectNetworkDrivers(),
      ubuntuDrivers: {
        list: ubuntuList.stdout.trim(),
        devices: ubuntuDevices.stdout.trim(),
      },
    },
    errors: [ubuntuList, ubuntuDevices, lspci, lsusb, lsmod, installed]
      .filter((result) => result.error)
      .map((result) => result.error),
  };
}

module.exports = { collect };
