#!/usr/bin/env node

const fs = require('fs');
const mkdirp = require('mkdirp');
const path = require('path');

const JSON_EXT_REGEX = /\.json$/;

const artifactsDir = path.join(__dirname, '../artifacts');
const abisDir = path.join(__dirname, '../src/abi');

mkdirp.sync(abisDir);

fs
  .readdirSync(artifactsDir)
  .forEach(filename => {
    if (!filename.match(JSON_EXT_REGEX)) {
      return;
    }

    const contractName = filename.replace(JSON_EXT_REGEX, '');

    const artifactPath = path.join(artifactsDir, filename);
    const abiPath = path.join(abisDir, `${contractName}.abi.ts`);

    const artifactModifiedTime = fs.statSync(artifactPath).mtimeMs;
    const abiModifiedTime = fs.existsSync(abiPath) ? fs.statSync(abiPath).mtimeMs : 0;

    if (artifactModifiedTime <= abiModifiedTime) {
      return;
    }

    const artifact = require(artifactPath);
    const { abi } = artifact.compilerOutput;

    fs.writeFileSync(
      abiPath,
      `import { AbiItem } from 'web3-utils';\n\nexport default ${JSON.stringify(abi, null, 2)} as unknown as AbiItem[];\n`,
      'utf8',
    );

    console.log(`Extracted ABIs: ${contractName}.`)
  });
