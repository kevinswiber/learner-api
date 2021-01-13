#!/usr/bin/env node

const { execSync, spawn } = require('child_process');
const app = require('./app')

const server = app.listen(0, () => {
  const port = server.address().port;

  const branchName = (process.env.BRANCH_NAME ||
    execSync('git symbolic-ref --short HEAD') ||
    'main').toString().trim();

  const env = Object.assign({}, process.env, {
    BRANCH_NAME: branchName,
    JOB_NAME: `postman/learner-api/${branchName}`
  });

  const fetch = spawn('./ci/fetch-postman-assets.sh', { env: env, stdio: 'inherit' });

  const fetchSignalHandler = (signal) => {
    fetch.kill(signal);
  };
  process.on('SIGINT', fetchSignalHandler);
  process.on('SIGTERM', fetchSignalHandler);

  fetch.on('close', (code) => {
    if (code != 0) {
      process.exit(code);
    }
    process.removeListener('SIGINT', fetchSignalHandler);
    process.removeListener('SIGTERM', fetchSignalHandler);

    let args = [
      'run', '--env-var', `url=http://localhost:${port}`,
      '-e', './postman_environment.json',
      '--reporters', 'cli,junit'];

    if (process.env.TEST_TYPE === 'contracttest') {
      args = args.concat(['--env-var', `env-apiKey=${process.env.POSTMAN_API_KEY}`]);
    }

    args.push('./postman_collection.json');

    const newman = spawn('./node_modules/.bin/newman', args, { stdio: 'inherit' });

    const newmanSignalHandler = (signal) => {
      newman.kill(signal);
    };
    process.on('SIGINT', newmanSignalHandler);
    process.on('SIGTERM', newmanSignalHandler);

    newman.on('close', (code) => {
      if (code != 0) {
        process.exit(code);
      }

      server.close();
      execSync('rm ./postman_collection.json ./postman_environment.json')
    });
  });
});
