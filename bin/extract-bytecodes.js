#!/usr/bin/env node

const fs = require('fs');
const mkdirp = require('mkdirp');
const path = require('path');

const JSON_EXT_REGEX = /\.json$/;

const artifactsDir = path.join(__dirname, '../artifacts');
const bytecodesDir = path.join(__dirname, '../src/bytecode');

mkdirp.sync(bytecodesDir);

fs
  .readdirSync(artifactsDir)
  .forEach(filename => {
    if (!filename.match(JSON_EXT_REGEX)) {
      return;
    }

    const contractName = filename.replace(JSON_EXT_REGEX, '');

    const artifactPath = path.join(artifactsDir, filename);
    const bytecodePath = path.join(bytecodesDir, `${contractName}.bytecode.ts`);

    const artifactModifiedTime = fs.statSync(artifactPath).mtimeMs;
    const bytecodeModifiedTime = fs.existsSync(bytecodePath) ? fs.statSync(bytecodePath).mtimeMs : 0;

    if (artifactModifiedTime <= bytecodeModifiedTime) {
      return;
    }

    const artifact = require(artifactPath);
    const data = artifact.compilerOutput.evm.bytecode;
    let bytecode = data.object;

    if (bytecode === '0x') {
      return;
    }

    const replaceLibraryReference = (bytecode, reference, libraryName) => {
      if (libraryName.length > 36) {
        // Just an unreasonable reason to reduce engineering cost.
        throw new Error(`Library name "${libraryName}" too long.`);
      }

      const { start } = reference;
      let linkId = `__${libraryName}`;

      while (linkId.length < 40) {
        linkId += '_';
      }

      return `${bytecode.slice(0, start * 2 + 2)}${linkId}${bytecode.slice(start * 2 + 42)}`;
    };

    Object.keys(data.linkReferences).forEach(fileName => {
      Object.keys(data.linkReferences[fileName]).forEach(libraryName => {
        data.linkReferences[fileName][libraryName].forEach(reference => {
          bytecode = replaceLibraryReference(bytecode, reference, libraryName);
        });
      });
    });

    fs.writeFileSync(
      bytecodePath,
      `export default '${bytecode}';\n`,
      'utf8',
    );

    console.log(`Extracted bytecode: ${contractName}.`)
  });
