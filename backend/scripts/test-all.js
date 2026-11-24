import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const services = ['licensing-service', 'advertising-service', 'media-service'];

console.log('====================================================');
console.log('   RUNNING SUITE TESTS ACROSS ALL HINOPT BACKEND    ');
console.log('====================================================');

let allPassed = true;

for (const s of services) {
  const serviceDir = path.resolve(__dirname, '..', s);
  console.log(`\n▶ Testing ${s}...`);

  const result = await new Promise((resolve) => {
    const proc = spawn('node', ['--test'], {
      cwd: serviceDir,
      stdio: 'inherit'
    });
    proc.on('close', (code) => resolve(code === 0));
  });

  if (!result) {
    allPassed = false;
    console.error(`✖ Test failed in ${s}`);
  } else {
    console.log(`✔ ${s} passed cleanly.`);
  }
}

if (!allPassed) {
  console.error('\n✖ One or more test suites failed.');
  process.exit(1);
} else {
  console.log('\n✔ All HINOPT backend microservice tests PASSED successfully!');
}
