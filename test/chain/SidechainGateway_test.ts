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
import { RegistryContract } from '../../src/contract/registry';
import { SidechainGatewayManagerContract } from '../../src/contract/sidechain_gateway_manager';
import { SidechainGatewayProxyContract } from '../../src/contract/sidechain_gateway_proxy';
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

describe('Sidechain gateway', () => {
  resetAfterAll();

  let alice: string;
  let bob: string;
  let charles: string;
  let sidechainGateway: SidechainGatewayManagerContract;
  let registry: RegistryContract;
  let validator: ValidatorContract;
  let sidechainGatewayProxy: SidechainGatewayProxyContract;
  let weth: WETHDevContract;
  let erc721: ERC721FullMintableContract;

  before(async () => {
    [alice, bob, charles] = await web3Pool.ethGetAccounts();
    sidechainGateway = await SidechainGatewayManagerContract.deploy().send(web3Pool);
    weth = await WETHDevContract.deploy('WETH', 'WETH', 18).send(web3Pool);
    erc721 = await ERC721FullMintableContract.deploy('ERC721', '721', '').send(web3Pool);
    registry = await RegistryContract.deploy().send(web3Pool);
    validator = await ValidatorContract.deploy().send(web3Pool);
    await validator.addValidators([alice, bob, charles]).send();

    sidechainGatewayProxy = await SidechainGatewayProxyContract
      .deploy(sidechainGateway.address, registry.address, validator.address, new BN(2)).send(web3Pool);

    // Use the contract logic in place of proxy address
    sidechainGateway = new SidechainGatewayManagerContract(sidechainGatewayProxy.address, web3Pool);
    await sidechainGateway.updateQuorum(new BN(2)).send();
    await weth.addMinters([sidechainGateway.address, alice]).send();
    await erc721.addMinters([sidechainGateway.address, alice]).send();
  });

  describe('test deposit', async () => {
    it('deploy WETH and update registry', async () => {
      const wethToken = await registry.WETH_TOKEN().call();
      await registry.updateContract(wethToken, weth.address).send();
    });

    it('should not be able to deposit weth when weth is not mapped', async () => {
      await expectTransactionFailed(sidechainGateway.depositERCTokenFor(
        new BN(0),
        alice,
        weth.address,
        20,
        ethToWei(1),
      ).send());
    });

    it('should be able to call deposit weth but not release yet', async () => {
      await registry.mapToken(bob, weth.address, 20).send();
      await sidechainGateway.depositERCTokenFor(
        new BN(0),
        alice,
        weth.address,
        20,
        ethToWei(1),
      ).send();

      const balance = await weth.balanceOf(alice).call();
      expect(balance.toNumber()).eq(0);
    });

    it('should be able to call deposit and release token', async () => {
      const amount = ethToWei(1);
      await sidechainGateway.depositERCTokenFor(
        new BN(0),
        alice,
        weth.address,
        20,
        amount,
      ).send({
        from: bob,
      });

      const balance = await weth.balanceOf(alice).call();
      expect(balance.toString()).eq(amount.toString());
    });

    it('should not be able to deposit again', async () => {
      const amount = ethToWei(1);
      await expectTransactionFailed(
        sidechainGateway.depositERCTokenFor(
          new BN(0),
          alice,
          weth.address,
          20,
          amount,
        ).send({
          from: bob,
        }),
      );
    });

    it('should be able to trust the majority', async () => {
      const amount = ethToWei(1);
      await sidechainGateway.depositERCTokenFor(
        new BN(2),
        bob,
        weth.address,
        20,
        amount.muln(2),
      ).send({
        from: bob,
      });

      await sidechainGateway.depositERCTokenFor(
        new BN(2),
        bob,
        weth.address,
        20,
        amount,
      ).send({
        from: alice,
      });

      let balance = await weth.balanceOf(bob).call();
      expect(balance.toString()).eq('0');

      await sidechainGateway.depositERCTokenFor(
        new BN(2),
        bob,
        weth.address,
        20,
        amount,
      ).send({
        from: charles,
      });

      const [owner, token, tokenNumber] = await sidechainGateway.deposits(new BN(2)).call();
      expect(owner.toLowerCase()).eq(bob.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(tokenNumber.toString()).eq(amount.toString());

      balance = await weth.balanceOf(bob).call();
      expect(balance.toString()).eq(amount.toString());
    });

    it('should be able to deposit ERC721 token', async () => {
      await registry.mapToken(charles, erc721.address, 721).send();
      await sidechainGateway.depositERCTokenFor(
        new BN(1),
        bob,
        erc721.address,
        721,
        new BN(100),
      ).send({
        from: bob,
      });

      await sidechainGateway.depositERCTokenFor(
        new BN(1),
        bob,
        erc721.address,
        721,
        new BN(100),
      ).send({
        from: charles,
      });

      const owner = await erc721.ownerOf(new BN(100)).call();
      expect(owner.toLowerCase()).eq(bob.toLowerCase());
    });
  });

  describe('test withdrawal', async () => {
    it('should not be able to withdraw ETH when not enough balance', async () => {
      await weth.approve(sidechainGateway.address, new BN(2).pow(new BN(255))).send({ from: charles });
      await expectTransactionFailed(sidechainGateway.withdrawETH(ethToWei(1)).send({ from: charles }));
    });

    it('should be able to withdraw ETH', async () => {
      await weth.mint(charles, ethToWei(1)).send();
      await sidechainGateway.withdrawETH(ethToWei(1)).send({ from: charles });

      const [owner, token, mainchainToken, standard, amount] = await sidechainGateway.withdrawals(new BN(0)).call();
      expect(owner.toLowerCase()).eq(charles.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(mainchainToken.toLowerCase()).eq(bob.toLowerCase());
      expect(standard).eq(20);
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should not be able to withdraw not owned ERC721', async () => {
      await erc721.setApprovalForAll(sidechainGateway.address, true).send();
      await expectTransactionFailed(sidechainGateway.withdrawERC721(erc721.address, new BN(1)).send());
    });

    it('should be able to withdraw ERC721 for', async () => {
      await erc721.mint(alice, new BN(1)).send();
      await sidechainGateway.withdrawalERC721For(bob, erc721.address, new BN(1)).send();
      const [owner, token, mainchainToken, standard, id] = await sidechainGateway.withdrawals(new BN(1)).call();

      expect(owner.toLowerCase()).eq(bob.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(mainchainToken.toLowerCase()).eq(charles.toLowerCase());
      expect(standard).eq(721);
      expect(id.toString()).eq('1');
    });

    it('should not be able have more than 10 withdrawals', async () => {
      await weth.mint(alice, ethToWei(100000)).send();
      await weth.approve(sidechainGateway.address, new BN(2).pow(new BN(255))).send();

      for (let i = 0; i < 10; i++) {
        await sidechainGateway.withdrawERC20(weth.address, ethToWei(1).muln(i)).send();
      }

      await expectTransactionFailed(sidechainGateway.withdrawERC20(weth.address, ethToWei(1)).send());
    });

    it('should be able to return correct pending withdrawal', async () => {
      const [ids, entries] = await sidechainGateway.getPendingWithdrawals(alice).call();
      expect(ids.length).eq(10);
      for (let i = 0; i < 10; i++) {
        expect(entries[i].tokenAddress.toLowerCase()).eq(weth.address.toLowerCase());
        expect(entries[i].tokenNumber.toString()).eq(ethToWei(1).muln(i).toString());
      }
    });

    it('should be able to acknowleged token withdrawal', async () => {
      await sidechainGateway.acknowledWithdrawalOnMainchain(new BN(3)).send();
      const [withdrawalIds] = await sidechainGateway.getPendingWithdrawals(alice).call();
      expect(withdrawalIds.length).eq(10);
      await sidechainGateway.acknowledWithdrawalOnMainchain(new BN(3)).send({ from: bob });
      const [ids, entries] = await sidechainGateway.getPendingWithdrawals(alice).call();
      expect(ids.length).eq(9);
      expect(entries[1].tokenNumber.toString()).eq(ethToWei(1).muln(9).toString());
    });

    it('should be able to submit withdrawal signatures', async () => {
      const id = new BN(0);
      const { signatures: sig1 } = await getCombinedSignatures(false, [alice], 'withdrawETH', 1, 2, 3);

      await sidechainGateway.submitWithdrawalSignatures(id, false, sig1).send();
      const { signatures: sig2 } = await getCombinedSignatures(false, [bob], 'withdrawETH', 1, 2, 3);
      await sidechainGateway.submitWithdrawalSignatures(id, false, sig2).send({ from: bob });
      const firstSigner = await sidechainGateway.withdrawalSigners(id, new BN(0)).call();
      expect(firstSigner.toLowerCase()).eq(alice.toLowerCase());

      const aliceSig = await sidechainGateway.withdrawalSig(id, alice).call();
      expect(aliceSig).eq(sig1);
      const bobSig = await sidechainGateway.withdrawalSig(id, bob).call();
      expect(bobSig).eq(sig2);

      const signers = await sidechainGateway.getWithdrawalSigners(id).call();
      expect(signers[0].toLowerCase()).eq(alice.toLowerCase());
      expect(signers[1].toLowerCase()).eq(bob.toLowerCase());

      const allSig = await sidechainGateway.getWithdrawalSignatures(new BN(0)).call();
      expect(allSig[0]).eq(sig1);
      expect(allSig[1]).eq(sig2);
    });

    it('should be able to request signature again', async () => {
      await expectTransactionFailed(sidechainGateway.requestSignatureAgain(new BN(0)).send());
      await sidechainGateway.requestSignatureAgain(new BN(0)).send({ from: charles });
    });
  });
});
