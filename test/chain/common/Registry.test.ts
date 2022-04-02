import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import { Registry, Registry__factory } from '../../../src/types';

describe('Registry', () => {
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let charles: SignerWithAddress;
  let registry: Registry;

  before(async () => {
    [alice, bob, charles] = await ethers.getSigners();
    registry = await new Registry__factory(alice).deploy();
  });

  describe('set and read contract', async () => {
    it('should be able to set predefined constant contract', async () => {
      const wethToken = await registry.WETH_TOKEN();
      await registry.updateContract(wethToken, bob.address);

      const addr = await registry.getContract(wethToken);
      expect(addr.toLowerCase()).eq(bob.address.toLowerCase());
    });

    it('should be able to set a random contract', async () => {
      const randomName = 'Some random contract name';
      await registry.updateContract(randomName, charles.address);

      const addr = await registry.getContract(randomName);
      expect(addr.toLowerCase()).eq(charles.address.toLowerCase());
    });
  });

  describe('set and read mapped token', async () => {
    it('should be able to map ERC20 token', async () => {
      await registry.mapToken(alice.address, bob.address, 20);
      const [mainchain, sidechain, version] = await registry.mainchainMap(alice.address);
      expect(mainchain.toLowerCase()).eq(alice.address.toLowerCase());
      expect(sidechain.toLowerCase()).eq(bob.address.toLowerCase());
      expect(version as any).eq(20);
    });
  });
});
