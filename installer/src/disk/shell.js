const { execFile } = require('node:child_process');

function runLsblk() {
  return new Promise((resolve, reject) => {
    execFile(
      '/usr/bin/lsblk',
      ['--json', '--bytes', '--output', 'NAME,KNAME,PATH,TYPE,SIZE,MODEL,RM,ROTA,TRAN,FSTYPE,MOUNTPOINTS'],
      { maxBuffer: 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }
        try {
          resolve(JSON.parse(stdout));
        } catch (parseError) {
          reject(parseError);
        }
      },
    );
  });
}

function runFindmnt() {
  return new Promise((resolve, reject) => {
    execFile(
      '/usr/bin/findmnt',
      ['--noheadings', '--output', 'SOURCE', '--target', '/'],
      { maxBuffer: 64 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr.trim() || error.message));
          return;
        }
        resolve(stdout.trim());
      },
    );
  });
}

module.exports = { runFindmnt, runLsblk };
