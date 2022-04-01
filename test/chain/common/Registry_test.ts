// import {
//   resetAfterAll,
//   resetAfterEach,
//   web3Pool,
// } from '@axie/contract-test-utils';
// import { expect } from 'chai';
// import * as _ from 'lodash';
// import 'mocha';

// import { RegistryContract } from '../../../src/contract/registry';

// describe('Registry', () => {
//   resetAfterAll();
//   resetAfterEach();

//   let alice: string;
//   let bob: string;
//   let charles: string;
//   let registry: RegistryContract;

//   before(async () => {
//     [alice, bob, charles] = await web3Pool.ethGetAccounts();
//     registry = await RegistryContract.deploy().send(web3Pool);
//   });

//   describe('set and read contract', async () => {
//     it('should be able to set predefined constant contract', async () => {
//       const wethToken = await registry.WETH_TOKEN().call();
//       await registry.updateContract(wethToken, bob).send();

//       const addr = await registry.getContract(wethToken).call();
//       expect(addr.toLowerCase()).eq(bob.toLowerCase());
//     });

//     it('should be able to set a random contract', async () => {
//       const randomName = 'Some random contract name';
//       await registry.updateContract(randomName, charles).send();

//       const addr = await registry.getContract(randomName).call();
//       expect(addr.toLowerCase()).eq(charles.toLowerCase());
//     });
//   });

//   describe('set and read mapped token', async () => {
//     it('should be able to map ERC20 token', async () => {
//       await registry.mapToken(alice, bob, 20).send();
//       const [mainchain, sidechain, version] = await registry.mainchainMap(alice).call();
//       expect(mainchain.toLowerCase()).eq(alice.toLowerCase());
//       expect(sidechain.toLowerCase()).eq(bob.toLowerCase());
//       expect(version as any).eq(20);
//     });
//   });
// });
