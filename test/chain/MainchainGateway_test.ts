import {ERC20FullContract, ERC721FullMintableContract } from '@axie/contract-library';
import {
  expectTransactionFailed,
  resetAfterAll,
  web3Pool,
} from '@axie/contract-test-utils';
import { expect } from 'chai';
import * as _ from 'lodash';
import 'mocha';

import BN = require('bn.js');
import web3Utils = require('web3-utils');
import { MainchainGatewayManagerContract } from '../../src/contract/mainchain_gateway_manager';
import { MainchainGatewayProxyContract } from '../../src/contract/mainchain_gateway_proxy';
import { RegistryContract } from '../../src/contract/registry';
import { ValidatorContract } from '../../src/contract/validator';
import { WETHDevContract } from '../../src/contract/w_e_t_h_dev';

const ethToWei = (eth: number) => new BN(web3Utils.toWei(eth.toString(), 'ether'));

const sign = async (account: string, ...params: any): Promise<string> => {
  const data = web3Utils.soliditySha3(...params);
  // Ganache return the signatures directly
  const signatures = await web3Pool.web3s[0].eth.sign(data, account);
  return `01${signatures.slice(2)}`;
};

const getCombinedSignatures = async (
  reversed: boolean,
  accounts: string[],
  ...params: any
): Promise<{ accounts: string[], signatures: string }> => {
  const sortedAccounts = accounts
    .map(account => account.toLowerCase())
    .sort();

  let signatures = '';
  for (const account of sortedAccounts) {
    const signature = await sign(account, ...params);
    if (reversed) {
      signatures = signature + signatures;
    } else {
      signatures += signature;
    }
  }

  signatures = '0x' + signatures;

  return {
    accounts: sortedAccounts,
    signatures,
  };
};

describe('Mainchain gateway', () => {
  resetAfterAll();

  let alice: string;
  let bob: string;
  let charles: string;
  let mainchainGateway: MainchainGatewayManagerContract;
  let registry: RegistryContract;
  let validator: ValidatorContract;
  let mainchainGatewayProxy: MainchainGatewayProxyContract;
  let weth: WETHDevContract;
  let erc20: ERC20FullContract;
  let erc721: ERC721FullMintableContract;

  before(async () => {
    [alice, bob, charles] = await web3Pool.ethGetAccounts();
    mainchainGateway = await MainchainGatewayManagerContract.deploy().send(web3Pool);
    weth = await WETHDevContract.deploy().send(web3Pool);
    registry = await RegistryContract.deploy().send(web3Pool);
    validator = await ValidatorContract.deploy().send(web3Pool);

    mainchainGatewayProxy = await MainchainGatewayProxyContract
      .deploy(mainchainGateway.address, registry.address, validator.address, new BN(2)).send(web3Pool);

    // Use the contract logic in place of proxy address
    mainchainGateway = new MainchainGatewayManagerContract(mainchainGatewayProxy.address, web3Pool);
  });

  describe('test deposit', async () => {
    it('deploy WETH and update registry', async () => {
      const wethToken = await registry.WETH_TOKEN().call();
      await registry.updateContract(wethToken, weth.address).send();
    });

    it('should not be able to deposit eth when weth is not mapped', async () => {
      await expectTransactionFailed(mainchainGateway.depositEth().send({
        value: ethToWei(1),
      }));
    });

    it('should be able to deposit eth after weth is mapped', async () => {
      await registry.mapToken(weth.address, weth.address, 20).send();
      await mainchainGateway.depositEth().send({
        value: ethToWei(1),
      });

      const depositCount = await mainchainGateway.depositCount().call();
      expect(depositCount.toNumber()).eq(1);
      const [owner, token, , , amount] = await mainchainGateway.deposits(new BN(0)).call();
      expect(owner.toLowerCase()).eq(alice.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should be able to deposit ERC20', async () => {
      erc20 = await ERC20FullContract.deploy('ERC20', 'E20', 0, new BN('1000000000')).send(web3Pool);
      await erc20.addMinters([alice]).send();
      await erc20.mint(alice, new BN(1000)).send();
      await erc20.mint(bob, new BN(1000)).send();
      await erc20.approve(mainchainGateway.address, new BN('1000000000')).send();
      await expectTransactionFailed(mainchainGateway.depositERC20(erc20.address, new BN(100)).send());

      await registry.mapToken(erc20.address, weth.address, 20).send();
      await mainchainGateway.depositERC20(erc20.address, new BN(100)).send();

      const [owner, token, sidechain, standard, amount] = await mainchainGateway.deposits(new BN(1)).call();
      expect(owner.toLowerCase()).eq(alice.toLowerCase());
      expect(token.toLowerCase()).eq(erc20.address.toLowerCase());
      expect(sidechain.toLowerCase()).eq(weth.address.toLowerCase());
      expect(standard).eq(20);
      expect(amount.toNumber()).eq(100);
    });

    it('should be able to deposit ERC-721', async () => {
      erc721 = await ERC721FullMintableContract.deploy('ERC721', '721', '').send(web3Pool);
      await erc721.addMinters([alice]).send();
      await erc721.mint(alice, new BN(0)).send();
      await erc721.mint(bob, new BN(1)).send();

      await registry.mapToken(erc721.address, erc721.address, 721).send();
      await expectTransactionFailed(mainchainGateway.depositERC721(erc721.address, new BN(0)).send());

      await erc721.setApprovalForAll(mainchainGateway.address, true).send();
      await mainchainGateway.depositERC721(erc721.address, new BN(0)).send();

      await erc721.setApprovalForAll(mainchainGateway.address, true).send({ from: charles });

      await expectTransactionFailed(mainchainGateway.depositERC721(erc721.address, new BN(2)).send({ from: charles }));
      await erc721.mint(charles, new BN(2)).send();
      await mainchainGateway.depositERC721(erc721.address, new BN(2)).send({ from: charles });

      const [owner, token, sidechain, standard, tokenId] = await mainchainGateway.deposits(new BN(3)).call();
      expect(owner.toLowerCase()).eq(charles.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(sidechain.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(standard).eq(721);
      expect(tokenId.toNumber()).eq(2);
    });

    it('should be able to deposit bulk', async () => {
      await erc721.mint(alice, new BN(3)).send();
      await erc721.mint(bob, new BN(4)).send();
      await erc721.setApprovalForAll(mainchainGateway.address, true).send();

      await expectTransactionFailed(
        mainchainGateway.depositBulkFor(
          bob,
          [erc20.address, erc721.address, erc721.address],
          [new BN(1000), new BN(3), new BN(4)],
        ).send(),
      );

      await erc721.transferFrom(bob, alice, new BN(4)).send({ from: bob });

      await mainchainGateway.depositBulkFor(
        bob,
        [erc20.address, erc721.address, erc721.address],
        [new BN(10), new BN(3), new BN(4)],
      ).send();

      const depositCount = await mainchainGateway.depositCount().call();
      expect(depositCount.toNumber()).eq(7);
      const [owner, token, , , tokenId] = await mainchainGateway.deposits(new BN(6)).call();
      expect(owner.toLowerCase()).eq(bob.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(tokenId.toNumber()).eq(4);
    });
  });

  describe('test withdrawal', async () => {
    it('add validator', async () => {
      await validator.addValidators([alice, bob]).send();

      const aliceValidator = await validator.isValidator(alice).call();
      expect(aliceValidator).eq(true);
      const bobValidator = await validator.isValidator(bob).call();
      expect(bobValidator).eq(true);
    });

    it('should not be able to withdraw without enough signature', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice],
        'withdrawERC20',
        1,
        alice,
        weth.address,
        ethToWei(1).toString(),
      );

      await expectTransactionFailed(
        mainchainGateway.withdrawToken(new BN(1), weth.address, ethToWei(1), signatures).send(),
      );
    });

    it('should not be able to withdraw eth with wrong order of signatures', async () => {
      const { signatures } = await getCombinedSignatures(
        true,
        [alice, bob],
        'withdrawERC20',
        1,
        alice,
        weth.address,
        ethToWei(1).toString(),
      );
      await expectTransactionFailed(
        mainchainGateway.withdrawToken(new BN(1), weth.address, ethToWei(1), signatures).send(),
      );
    });

    it('should be able to withdraw eth', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC20',
        1,
        alice,
        weth.address,
        ethToWei(0.5).toString(),
      );
      const beforeBalance = await web3Pool.ethGetBalance(alice);
      await mainchainGateway.withdrawERC20For(
        new BN(1), alice, weth.address, ethToWei(0.5), signatures,
      ).send({ from: bob });
      const afterBalance = await web3Pool.ethGetBalance(alice);
      expect(afterBalance.sub(beforeBalance).toString()).eq(ethToWei(0.5).toString());
    });

    it('should not able to withdraw with same withdrawalId', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC20',
        1,
        alice,
        weth.address,
        ethToWei(0.5).toString(),
      );

      await expectTransactionFailed(
        mainchainGateway.withdrawERC20For(new BN(1), alice, weth.address, ethToWei(0.5), signatures)
          .send({ from: bob }),
      );

    });

    it('should be able to withdraw for self', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC20',
        2,
        alice,
        weth.address,
        ethToWei(0.5).toString(),
      );

      await mainchainGateway.withdrawToken(new BN(2), weth.address, ethToWei(0.5), signatures).send();
    });

    it('should be able to withdraw locked erc20', async () => {
      const erc20Balance = await erc20.balanceOf(mainchainGateway.address).call();
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC20',
        3,
        alice,
        erc20.address,
        erc20Balance.toString(),
      );

      const beforeBalance = await erc20.balanceOf(alice).call();
      await mainchainGateway.withdrawERC20(new BN(3), erc20.address, erc20Balance, signatures).send();
      const afterBalance = await erc20.balanceOf(alice).call();
      expect(beforeBalance.add(erc20Balance).toString()).eq(afterBalance.toString());
    });

    it('should be able to mint new erc20 token when withdrawing', async () => {
      await erc20.addMinters([mainchainGateway.address]).send();

      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC20',
        4,
        bob,
        erc20.address,
        1000,
      );

      const beforeBalance = await erc20.balanceOf(bob).call();
      await mainchainGateway.withdrawERC20For(new BN(4), bob, erc20.address, new BN(1000), signatures).send();
      const afterBalance = await erc20.balanceOf(bob).call();
      expect(beforeBalance.addn(1000).toString()).eq(afterBalance.toString());
    });

    it('should be able to withdraw locked erc721', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC721',
        5,
        charles,
        erc721.address,
        4,
      );

      await mainchainGateway.withdrawERC721(new BN(5), erc721.address, new BN(4), signatures).send({ from: charles });
      const owner = await erc721.ownerOf(new BN(4)).call();

      expect(owner.toLowerCase()).eq(charles.toLowerCase());
    });

    it('should be able to mint new erc721 when withdrawing', async () => {
      await erc721.addMinters([mainchainGateway.address, alice]).send();

      await erc721.mint(alice, new BN(500)).send();

      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        'withdrawERC721',
        6,
        bob,
        erc721.address,
        1000,
      );

      await mainchainGateway.withdrawERC721For(new BN(6), bob, erc721.address, new BN(1000), signatures).send();
      const owner = await erc721.ownerOf(new BN(1000)).call();
      expect(owner.toLowerCase()).eq(bob.toLowerCase());
    });
  });
});
