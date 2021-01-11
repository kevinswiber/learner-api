const { execSync, spawn } = require('child_process');
const app = require('./app')

const server = app.listen(0, () => {
  const port = server.address().port;

  let gitBranch = execSync('git symbolic-ref --short HEAD');
  if (gitBranch) {
    gitBranch = gitBranch.toString().trim();
  }
  const branchName = process.env.BRANCH_NAME || gitBranch || 'main';
  const env = Object.assign({}, process.env, {
    BRANCH_NAME: branchName,
    JOB_NAME: `postman/learner-api/${branchName}`
  });

  const fetch = spawn('./ci/fetch-postman-assets.sh', { env: env, stdio: 'inherit' })
  fetch.on('close', (code) => {
    if (code != 0) {
      process.exit(code);
    }

    const args = [
      'run', '--env-var', `url=http://localhost:${port}`,
      '-e', './postman_environment.json',
      '--reporters', 'cli,junit',
      '--reporter-junit-export', 'newman/report.xml',
      './postman_collection.json'
    ];

    const newman = spawn('./node_modules/.bin/newman', args, { stdio: 'inherit' });
    newman.on('close', (code) => {
      if (code != 0) {
        process.exit(code);
      }

      server.close();
      execSync('rm ./postman_collection.json ./postman_environment.json')
    })

  })
})
