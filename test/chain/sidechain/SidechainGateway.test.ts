import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';

import {
  Acknowledgement,
  Acknowledgement__factory,
  MockERC721,
  MockERC721__factory,
  Registry,
  Registry__factory,
  RoninWETH,
  RoninWETH__factory,
  SidechainGatewayManager,
  SidechainGatewayManager__factory,
  SidechainGatewayProxy,
  SidechainGatewayProxy__factory,
  SidechainValidator,
  SidechainValidator__factory,
} from '../../../src/types';

const ethToWei = (eth: number) => ethers.utils.parseEther(eth.toString());

const withdrawalERC20Hash = (withdrawalId: number, user: string, token: string, amount: number) =>
  ethers.utils.solidityKeccak256(
    ['string', 'uint256', 'address', 'address', 'uint256'],
    ['withdrawERC20', withdrawalId, user, token, amount]
  );

const sign = async (signer: SignerWithAddress, data: string): Promise<string> => {
  // Ganache return the signatures directly
  const signatures = await signer.signMessage(data);
  return `01${signatures.slice(2)}`;
};

const getCombinedSignatures = async (
  reversed: boolean,
  accounts: SignerWithAddress[],
  data: string
): Promise<{ accounts: string[]; signatures: string }> => {
  const sortedAccounts = accounts.sort((a, b) => a.address.toLowerCase().localeCompare(b.address.toLowerCase()));

  let signatures = '';
  for (const account of sortedAccounts) {
    const signature = await sign(account, data);
    if (reversed) {
      signatures = signature + signatures;
    } else {
      signatures += signature;
    }
  }

  signatures = '0x' + signatures;

  return {
    accounts: sortedAccounts.map((account) => account.address.toLowerCase()),
    signatures,
  };
};

describe('Sidechain gateway', () => {
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let charles: SignerWithAddress;
  let dan: SignerWithAddress;
  let sidechainGateway: SidechainGatewayManager;
  let registry: Registry;
  let validator: SidechainValidator;
  let acknowledgement: Acknowledgement;
  let sidechainGatewayProxy: SidechainGatewayProxy;
  let weth: RoninWETH;
  let erc721: MockERC721;

  before(async () => {
    [alice, bob, charles, dan] = await ethers.getSigners();
    sidechainGateway = await new SidechainGatewayManager__factory(alice).deploy();
    weth = await new RoninWETH__factory(alice).deploy();
    erc721 = await new MockERC721__factory(alice).deploy('ERC721', '721', '');
    registry = await new Registry__factory(alice).deploy();
    acknowledgement = await new Acknowledgement__factory(alice).deploy(alice.address); // dummy validator contract
    validator = await new SidechainValidator__factory(alice).deploy(
      acknowledgement.address,
      [alice.address, bob.address, charles.address],
      19,
      30
    );
    await acknowledgement.updateValidator(validator.address);

    const validatorContract = await registry.VALIDATOR();
    await registry.updateContract(validatorContract, validator.address);

    const acknowledgementContract = await registry.ACKNOWLEDGEMENT();
    await registry.updateContract(acknowledgementContract, acknowledgement.address);

    sidechainGatewayProxy = await new SidechainGatewayProxy__factory(alice).deploy(
      sidechainGateway.address,
      registry.address,
      10
    );

    // Use the contract logic in place of proxy address
    sidechainGateway = SidechainGatewayManager__factory.connect(sidechainGatewayProxy.address, alice);

    await weth.addMinters([sidechainGateway.address, alice.address]);
    const MINTER_ROLE = await erc721.MINTER_ROLE();
    await erc721.grantRole(MINTER_ROLE, sidechainGateway.address);
    await erc721.grantRole(MINTER_ROLE, alice.address);
    await acknowledgement.addOperators([sidechainGateway.address, validator.address]);
  });

  describe('test deposit', async () => {
    it('deploy WETH and update registry', async () => {
      const wethToken = await registry.WETH_TOKEN();
      await registry.updateContract(wethToken, weth.address);
    });

    it('should not be able to deposit weth when weth is not mapped', async () => {
      await expect(sidechainGateway.depositERCTokenFor(0, alice.address, weth.address, 20, ethToWei(1))).reverted;
    });

    it('should be able to call deposit weth but not release yet', async () => {
      await registry.mapToken(bob.address, weth.address, 20);

      await sidechainGateway.depositERCTokenFor(0, alice.address, weth.address, 20, ethToWei(1));

      const balance = await weth.balanceOf(alice.address);
      expect(balance.toNumber()).eq(0);
    });

    it('should be able to call deposit and release token', async () => {
      const amount = ethToWei(1);
      await sidechainGateway.connect(bob).batchDepositERCTokenFor([0], [alice.address], [weth.address], [20], [amount]);

      const balance = await weth.balanceOf(alice.address);
      expect(balance.toString()).eq(amount.toString());
    });

    it('should not be able to deposit again', async () => {
      const amount = ethToWei(1);
      await expect(sidechainGateway.connect(bob).depositERCTokenFor(0, alice.address, weth.address, 20, amount))
        .reverted;
    });

    it('should be acknowledge again', async () => {
      const amount = ethToWei(1);
      await sidechainGateway.connect(charles).depositERCTokenFor(0, alice.address, weth.address, 20, amount);

      const balance = await weth.balanceOf(alice.address);
      expect(balance.toString()).eq(amount.toString());
    });

    it('should be able to trust the majority', async () => {
      const amount = ethToWei(1);
      await sidechainGateway.connect(bob).depositERCTokenFor(2, bob.address, weth.address, 20, amount.mul(2));

      await sidechainGateway.connect(alice).depositERCTokenFor(2, bob.address, weth.address, 20, amount);

      let balance = await weth.balanceOf(bob.address);
      expect(balance.toString()).eq('0');

      await sidechainGateway.connect(charles).depositERCTokenFor(2, bob.address, weth.address, 20, amount);

      const [owner, token, tokenNumber] = await sidechainGateway.deposits(2);
      expect(owner.toLowerCase()).eq(bob.address.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(tokenNumber.toString()).eq(amount.toString());

      balance = await weth.balanceOf(bob.address);
      expect(balance.toString()).eq(amount.toString());
    });

    it('should be able to deposit ERC721 token', async () => {
      await registry.mapToken(charles.address, erc721.address, 721);
      await sidechainGateway.connect(bob).depositERCTokenFor(1, bob.address, erc721.address, 721, 2);
      await sidechainGateway.connect(charles).depositERCTokenFor(1, bob.address, erc721.address, 721, 2);

      const owner = await erc721.ownerOf(2);
      expect(owner.toLowerCase()).eq(bob.address.toLowerCase());
    });
  });

  describe('test withdrawal', async () => {
    it('should not be able to withdraw ETH when not enough balance', async () => {
      await weth.connect(charles).approve(sidechainGateway.address, BigNumber.from(2).pow(255));
      await expect(sidechainGateway.connect(charles).withdrawETH(ethToWei(1))).reverted;
    });

    it('should be able to withdraw ETH', async () => {
      await weth.mint(charles.address, ethToWei(1));
      await sidechainGateway.connect(charles).withdrawETH(ethToWei(1));

      const [owner, token, mainchainToken, standard, amount] = await sidechainGateway.withdrawals(0);
      expect(owner.toLowerCase()).eq(charles.address.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(mainchainToken.toLowerCase()).eq(bob.address.toLowerCase());
      expect(standard).eq(20);
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should not be able to withdraw not owned ERC721', async () => {
      await erc721.setApprovalForAll(sidechainGateway.address, true);
      await expect(sidechainGateway.withdrawERC721(erc721.address, 1)).reverted;
    });

    it('should be able to withdraw ERC721 for', async () => {
      await erc721['mint(address,uint256)'](alice.address, 1);
      await sidechainGateway.withdrawalERC721For(bob.address, erc721.address, 1);
      const [owner, token, mainchainToken, standard, id] = await sidechainGateway.withdrawals(1);

      expect(owner.toLowerCase()).eq(bob.address.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(mainchainToken.toLowerCase()).eq(charles.address.toLowerCase());
      expect(standard).eq(721);
      expect(id.toString()).eq('1');
    });

    it('should not be able have more than 10 withdrawals', async () => {
      await weth.mint(alice.address, ethToWei(100000));
      await weth.approve(sidechainGateway.address, BigNumber.from(2).pow(255));

      for (let i = 0; i < 10; i++) {
        await sidechainGateway.withdrawERC20(weth.address, ethToWei(1).mul(i));
      }

      await expect(sidechainGateway.withdrawERC20(weth.address, ethToWei(1))).reverted;
    });

    it('should be able to return correct pending withdrawal', async () => {
      const [ids, entries] = await sidechainGateway.getPendingWithdrawals(alice.address);
      expect(ids.length).eq(10);
      for (let i = 0; i < 10; i++) {
        expect(entries[i].tokenAddress.toLowerCase()).eq(weth.address.toLowerCase());
        expect(entries[i].tokenNumber.toString()).eq(ethToWei(1).mul(i).toString());
      }
    });

    it('should be able to acknowleged token withdrawal', async () => {
      await sidechainGateway.acknowledWithdrawalOnMainchain(3);
      const [withdrawalIds] = await sidechainGateway.getPendingWithdrawals(alice.address);
      expect(withdrawalIds.length).eq(10);
      await sidechainGateway.connect(bob).batchAcknowledWithdrawalOnMainchain([3]);
      const [ids, entries] = await sidechainGateway.getPendingWithdrawals(alice.address);
      expect(ids.length).eq(9);
      expect(entries[1].tokenNumber.toString()).eq(ethToWei(1).mul(9).toString());
    });

    it('should be able to submit withdrawal signatures', async () => {
      const hash = withdrawalERC20Hash(1, '0x', '0x', 4);
      const { signatures: sig1 } = await getCombinedSignatures(false, [alice], hash);
      await sidechainGateway.submitWithdrawalSignatures(0, false, sig1);
      const { signatures: sig2 } = await getCombinedSignatures(false, [bob], hash);
      await sidechainGateway.connect(bob).batchSubmitWithdrawalSignatures([0], [false], [sig2]);
      const firstSigner = await sidechainGateway.withdrawalSigners(0, 0);
      expect(firstSigner.toLowerCase()).eq(alice.address.toLowerCase());

      const aliceSig = await sidechainGateway.withdrawalSig(0, alice.address);
      expect(aliceSig).eq(sig1);
      const bobSig = await sidechainGateway.withdrawalSig(0, bob.address);
      expect(bobSig).eq(sig2);

      const signers = await sidechainGateway.getWithdrawalSigners(0);
      expect(signers[0].toLowerCase()).eq(alice.address.toLowerCase());
      expect(signers[1].toLowerCase()).eq(bob.address.toLowerCase());

      const [, allSig] = await sidechainGateway.getWithdrawalSignatures(0);
      expect(allSig[0]).eq(sig1);
      expect(allSig[1]).eq(sig2);
    });

    it('should be able to request signature again', async () => {
      await expect(sidechainGateway.requestSignatureAgain(0)).reverted;
      await sidechainGateway.connect(charles).requestSignatureAgain(0);
    });
  });

  describe('test validator', async () => {
    it('Alice, Bob & Charles should be validators', async () => {
      const aliceResult = await validator.isValidator(alice.address);
      const bobResult = await validator.isValidator(bob.address);
      const charlesResult = await validator.isValidator(charles.address);

      expect(aliceResult).to.eq(true);
      expect(bobResult).to.eq(true);
      expect(charlesResult).to.eq(true);
    });

    it('should not be able to add Dan as a validator because Bob send wrong message', async () => {
      await validator.connect(alice).addValidator(0, dan.address);
      await validator.connect(bob).addValidator(0, '0x0000000000000000000000000000000000000001');
      const danResult = await validator.isValidator(dan.address);
      expect(danResult).to.eq(false);

      await expect(validator.connect(bob).addValidator(0, dan.address)).reverted;
    });

    it('should be able to add Dan as a validator', async () => {
      await validator.connect(alice).addValidator(1, dan.address);
      await validator.connect(bob).addValidator(1, dan.address);
      const danResult = await validator.isValidator(dan.address);

      expect(danResult).to.eq(true);
    });

    it('should not be able to update quorum because Bob would like other quorum', async () => {
      await validator.connect(alice).updateQuorum(2, 29, 40);
      await validator.connect(bob).updateQuorum(2, 19, 40);
      await validator.connect(charles).updateQuorum(2, 29, 40);

      const num = await validator.num();
      const denom = await validator.denom();

      expect(num.toString()).to.eq('19');
      expect(denom.toString()).to.eq('30');
    });

    it('should be able to update the quorum successfully', async () => {
      await validator.connect(dan).updateQuorum(2, 29, 40);

      const num = await validator.num();
      const denom = await validator.denom();
      expect(num.toString()).to.eq('29');
      expect(denom.toString()).to.eq('40');
    });
  });
});
