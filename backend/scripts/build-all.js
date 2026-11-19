import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const services = ['licensing-service', 'advertising-service', 'media-service'];

console.log('Building all backend microservices...');

for (const s of services) {
  const serviceDir = path.resolve(__dirname, '..', s);
  console.log(`Compiling ${s}...`);
  const tscPath = path.resolve(serviceDir, 'node_modules', 'typescript', 'bin', 'tsc');
  const res = await new Promise((resolve) => {
    const proc = spawn('node', [tscPath], { cwd: serviceDir, stdio: 'inherit', shell: true });
    proc.on('close', code => resolve(code === 0));
  });
  if (!res) {
    console.error(`Failed to compile ${s}`);
    process.exit(1);
  }
}
console.log('All backend services compiled successfully.');
