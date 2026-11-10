// Run the existing synthetic native matrix using this host's approved curl
// console transport. No crypto, fixture, verdict or device-setting changes.
import net from 'node:net';
import { spawn } from 'node:child_process';
const connect = net.connect;
net.connect = options => {
  if (Number(options.port) !== 8085) return connect(options);
  const child = spawn('curl', ['--noproxy', '*', '--no-buffer', '--connect-timeout', '5', `telnet://${options.host}:8085`], { stdio: ['pipe', 'pipe', 'pipe'] });
  child.stdin.end();
  child.stderr.resume();
  child.on('error', () => child.stdout.emit('error', Error('Console client failed')));
  const stream = child.stdout;
  stream.destroy = () => child.kill('SIGTERM');
  return stream;
};
process.argv = [process.argv[0], process.argv[1], '--x25519', process.env.ROKU_RESTORE_ZIP ?? 'out/native-parity-normal.zip'];
await import('../../../scripts/validate-phone-setup-native.mjs');
