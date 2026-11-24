import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const services = [
  { name: 'Licensing Authority (Port 8081)', dir: 'licensing-service', file: 'dist/index.js' },
  { name: 'Advertising Operations (Port 8082)', dir: 'advertising-service', file: 'dist/index.js' },
  { name: 'Media Ingestion & Retention (Port 8083)', dir: 'media-service', file: 'dist/index.js' }
];

console.log('========================================================');
console.log('   LAUNCHING ALL HINOPT BACKEND MICROSERVICES   ');
console.log('========================================================');

const processes = [];

for (const s of services) {
  const serviceDir = path.resolve(__dirname, '..', s.dir);
  console.log(`Starting ${s.name}...`);
  const proc = spawn('node', [s.file], {
    cwd: serviceDir,
    stdio: 'inherit'
  });
  processes.push(proc);
}

process.on('SIGINT', () => {
  console.log('\nShutting down all backend services...');
  processes.forEach(p => p.kill());
  process.exit(0);
});
