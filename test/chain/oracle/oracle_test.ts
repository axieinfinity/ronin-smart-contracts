/* tslint:disable: no-console */
import { web3Pool } from '@axie/contract-test-utils';
import BN = require('bn.js');
import { expect } from 'chai';
import * as _ from 'lodash';
import 'mocha';
import web3Utils = require('web3-utils');
import { web3Pool as roninWeb3 } from '../../../src/web3';

import { AcknowledgementContract, MainchainValidatorContract, RoninWETHContract, WETHContract } from '../../../src';
import { MainchainGatewayManagerContract } from '../../../src/contract/mainchain_gateway_manager';
import { MainchainGatewayProxyContract } from '../../../src/contract/mainchain_gateway_proxy';
import { RegistryContract } from '../../../src/contract/registry';
import { SidechainGatewayManagerContract } from '../../../src/contract/sidechain_gateway_manager';
import { SidechainGatewayProxyContract } from '../../../src/contract/sidechain_gateway_proxy';
import { SidechainValidatorContract } from '../../../src/contract/sidechain_validator';

const SIDECHAIN_VALIDATOR = '0x0000000000000000000000000000000000000011';
const SIDECHAIN_ACKNOWLEDGEMENT = '0x0000000000000000000000000000000000000022';
const VALIDATOR_ADDRESS = '0x4a4bc674A97737376cFE990aE2fE0d2B6E738393';

const waitChainSync = () => new Promise(
  // tslint:disable-next-line: no-shadowed-variable
  (resolve, _) =>
    setTimeout(
      () => resolve(),
      40000,
    ),
);

const ethToWei = (eth: number) => new BN(web3Utils.toWei(eth.toString(), 'ether'));

describe('test oracle', () => {
  let alice: string;
  let bob: string;
  let admin: string;

  let sidechainGateway: SidechainGatewayManagerContract;
  let sidechainGatewayProxy: SidechainGatewayProxyContract;

  let mainchainGateway: MainchainGatewayManagerContract;
  let mainchainGatewayProxy: MainchainGatewayProxyContract;

  let mainchainRegistry: RegistryContract;
  let sidechainRegistry: RegistryContract;

  let sidechainValidator: SidechainValidatorContract;
  let mainchainValidator: MainchainValidatorContract;

  let sidechainWeth: RoninWETHContract;
  let mainchainWeth: WETHContract;

  let acknowledgement: AcknowledgementContract;

  before(async () => {
    console.log('\tMainchain');
    [alice, bob] = await web3Pool.ethGetAccounts();

    mainchainRegistry = await RegistryContract.deploy().send(web3Pool);
    mainchainWeth = await WETHContract.deploy().send(web3Pool);
    mainchainGateway = await MainchainGatewayManagerContract.deploy().send(web3Pool);

    mainchainValidator = await MainchainValidatorContract
      .deploy([alice, VALIDATOR_ADDRESS], new BN(0), new BN(2)).send(web3Pool);

    expect(true).to.eq(await mainchainValidator.isValidator(VALIDATOR_ADDRESS).call());

    mainchainGatewayProxy = await MainchainGatewayProxyContract
      .deploy(mainchainGateway.address, mainchainRegistry.address).send(web3Pool);

    // Use the contract logic in place of proxy address
    mainchainGateway = new MainchainGatewayManagerContract(mainchainGatewayProxy.address, web3Pool);

    // update registry records
    const VALIDATOR = await mainchainRegistry.VALIDATOR().call();
    await mainchainRegistry.updateContract(VALIDATOR, mainchainValidator.address).send();
    const GATEWAY = await mainchainRegistry.GATEWAY().call();
    await mainchainRegistry.updateContract(GATEWAY, mainchainGateway.address).send();
    // tslint:disable-next-line: no-console
    console.log('\t', { mainchainRegistry: mainchainRegistry.address });
  });

  before(async () => {
    console.log('\tSidechain');
    [admin] = await roninWeb3.ethGetAccounts();
    acknowledgement = new AcknowledgementContract(SIDECHAIN_ACKNOWLEDGEMENT, roninWeb3);
    sidechainValidator = new SidechainValidatorContract(SIDECHAIN_VALIDATOR, roninWeb3);

    sidechainRegistry = await RegistryContract.deploy().send(roninWeb3);
    sidechainWeth = await RoninWETHContract.deploy().send(roninWeb3);

    sidechainGateway = await SidechainGatewayManagerContract.deploy().send(roninWeb3);
    sidechainGatewayProxy = await SidechainGatewayProxyContract
      .deploy(sidechainGateway.address, sidechainRegistry.address, new BN(10)).send(roninWeb3);
    sidechainGateway = new SidechainGatewayManagerContract(sidechainGatewayProxy.address, roninWeb3);

    // update registry records
    const VALIDATOR = await mainchainRegistry.VALIDATOR().call();
    await sidechainRegistry.updateContract(VALIDATOR, sidechainValidator.address).send();
    const GATEWAY = await mainchainRegistry.GATEWAY().call();
    await sidechainRegistry.updateContract(GATEWAY, sidechainGateway.address).send();
    const ACKNOWLEDGEMENT = await mainchainRegistry.ACKNOWLEDGEMENT().call();
    await sidechainRegistry.updateContract(ACKNOWLEDGEMENT, acknowledgement.address).send();

    await acknowledgement.addOperators([sidechainGateway.address]).send();
    await sidechainWeth.addMinters([sidechainGateway.address, admin]).send();
    // tslint:disable-next-line: no-console
    console.log('\t', { sidechainRegistry: sidechainRegistry.address });
  });

  before(async () => {
    const WETH = await mainchainRegistry.WETH_TOKEN().call();
    await mainchainRegistry.updateContract(WETH, mainchainWeth.address).send();
    await sidechainRegistry.updateContract(WETH, sidechainWeth.address).send();

    await sidechainRegistry.mapToken(mainchainWeth.address, sidechainWeth.address, 20).send();
    await mainchainRegistry.mapToken(mainchainWeth.address, sidechainWeth.address, 20).send();
  });

  before(async () => {
    // tslint:disable-next-line: no-shadowed-variable
    await new Promise((resolve, _) => setTimeout(() => resolve(), 30000));
  });

  describe('test validator', async () => {
    it('should be able to add new validator on mainchain', async () => {
      await mainchainValidator.addValidators([bob]).send();
      const bobResult = await mainchainValidator.isValidator(bob).call();
      expect(true).to.eq(bobResult);
    });

    it('should be able to be acknowledged and added the validator on sidechain', async () => {
      await waitChainSync();
      const bobResult = await sidechainValidator.isValidator(bob).call();
      expect(true).to.eq(bobResult);
    });

    it('should be able to remove validator on mainchain', async () => {
      await mainchainValidator.removeValidator(bob).send();
      const bobResult = await mainchainValidator.isValidator(bob).call();
      expect(false).to.eq(bobResult);
    });

    it('should be able to be acknowledged and removed the validator on sidechain', async () => {
      await waitChainSync();
      const bobResult = await sidechainValidator.isValidator(bob).call();
      expect(false).to.eq(bobResult);
    });
  });

  describe('test deposit', async () => {
    it('should be able to deposit on mainchain', async () => {
      await mainchainGateway.depositEth().send({ value: ethToWei(1) });

      const depositCount = await mainchainGateway.depositCount().call();
      expect(depositCount.toNumber()).eq(1);

      const [owner, token, , , amount] = await mainchainGateway.deposits(new BN(0)).call();
      expect(owner.toLowerCase()).eq(alice.toLowerCase());
      expect(token.toLowerCase()).eq(mainchainWeth.address.toLowerCase());
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should be recorded on sidechain', async () => {
      await waitChainSync();
      const balance = await sidechainWeth.balanceOf(alice).call();
      expect(balance.toString()).eq(ethToWei(1).toString());
    });
  });

  describe('test withdrawal', async () => {
    let balance: BN;

    before(async () => {
      await sidechainWeth.mint(admin, ethToWei(1)).send();
      await sidechainWeth.approve(sidechainGateway.address, new BN(2).pow(new BN(255))).send();
      balance = await web3Pool.ethGetBalance(admin);
    });

    it('should be able to withdraw ETH on sidechain', async () => {
      await sidechainGateway.withdrawETH(ethToWei(1)).send();

      const [owner, token, mainchainToken, standard, amount] = await sidechainGateway.withdrawals(new BN(0)).call();
      expect(owner.toLowerCase()).eq(admin.toLowerCase());
      expect(token.toLowerCase()).eq(sidechainWeth.address.toLowerCase());
      expect(mainchainToken.toLowerCase()).eq(mainchainWeth.address.toLowerCase());
      expect(standard).eq(20);
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should be able to withdraw ETH on mainchain', async () => {
      await waitChainSync();

      const [signers, signatures] = await sidechainGateway.getWithdrawalSignatures(new BN(0)).call();
      const combinedSignatures = signers.map((signer, i) => ({
        signer,
        signature: signatures[i],
      }));
      const sortedSignatures = combinedSignatures
        .sort((a, b) => a.signer < b.signer ? 1 : -1)
        .map(({ signature: s }) => s)
        .map(s => s.slice(2))
        .join('');

      const signature = `0x${sortedSignatures}`;

      await mainchainGateway
        .withdrawTokenFor(new BN(0), admin, mainchainWeth.address, ethToWei(1), signature)
        .send();

      const afterBalance = await web3Pool.ethGetBalance(admin);
      expect(afterBalance.sub(balance).toString()).eq(ethToWei(1).toString());
    });
  });
});
