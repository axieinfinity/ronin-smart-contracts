import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

import {
  ERC20,
  ERC20Mintable,
  ERC20Mintable__factory,
  ERC20__factory,
  ERC721PresetMinterPauserAutoId__factory,
  MainchainGatewayManager,
  MainchainGatewayManager__factory,
  MainchainGatewayProxy,
  MainchainGatewayProxy__factory,
  MainchainValidator,
  MainchainValidator__factory,
  MockERC721,
  MockERC721__factory,
  PausableAdmin__factory,
  Registry,
  Registry__factory,
  WETH,
  WETH__factory,
} from '../../../src/types';
import { withdrawalERC20Hash, getCombinedSignatures, ethToWei, withdrawalERC721Hash } from '../../../src/utils';

let alice: SignerWithAddress;
let bob: SignerWithAddress;
let charles: SignerWithAddress;
let mainchainGateway: MainchainGatewayManager;
let registry: Registry;
let validator: MainchainValidator;
let mainchainGatewayProxy: MainchainGatewayProxy;
let weth: WETH;
let erc20: ERC20Mintable;
let erc721: MockERC721;

describe('Mainchain gateway', () => {
  before(async () => {
    [alice, bob, charles] = await ethers.getSigners();
    mainchainGateway = await new MainchainGatewayManager__factory(alice).deploy();
    weth = await new WETH__factory(alice).deploy();
    registry = await new Registry__factory(alice).deploy();

    const validatorStr = await registry.VALIDATOR();
    validator = await new MainchainValidator__factory(alice).deploy([alice.address, bob.address], 99, 100);
    await registry.updateContract(validatorStr, validator.address);

    mainchainGatewayProxy = await new MainchainGatewayProxy__factory(alice).deploy(
      mainchainGateway.address,
      registry.address
    );

    // Use the  logic in place of proxy address
    mainchainGateway = MainchainGatewayManager__factory.connect(mainchainGatewayProxy.address, alice);
  });

  describe('test deposit', async () => {
    it('deploy WETH and update registry', async () => {
      const wethToken = await registry.WETH_TOKEN();
      await registry.updateContract(wethToken, weth.address);
    });

    it('should not be able to deposit eth when weth is not mapped', async () => {
      await expect(mainchainGateway.depositEth({ value: ethToWei(1) })).reverted;
    });

    it('should be able to deposit eth after weth is mapped', async () => {
      await registry.mapToken(weth.address, weth.address, 20);
      await mainchainGateway.depositEth({ value: ethToWei(1) });

      const depositCount = await mainchainGateway.depositCount();
      expect(depositCount.toNumber()).eq(1);
      const [owner, token, , , amount] = await mainchainGateway.deposits(0);
      expect(owner.toLowerCase()).eq(alice.address.toLowerCase());
      expect(token.toLowerCase()).eq(weth.address.toLowerCase());
      expect(amount.toString()).eq(ethToWei(1).toString());
    });

    it('should be able to deposit ERC20', async () => {
      erc20 = await new ERC20Mintable__factory(alice).deploy();
      await erc20.addMinters([alice.address]);
      await erc20.mint(alice.address, 1000);
      await erc20.mint(bob.address, 1000);
      await erc20.approve(mainchainGateway.address, 1000000000);
      await expect(mainchainGateway.depositERC20(erc20.address, 100)).reverted;

      await registry.mapToken(erc20.address, weth.address, 20);
      await mainchainGateway.depositERC20(erc20.address, 100);

      const [owner, token, sidechain, standard, amount] = await mainchainGateway.deposits(1);
      expect(owner.toLowerCase()).eq(alice.address.toLowerCase());
      expect(token.toLowerCase()).eq(erc20.address.toLowerCase());
      expect(sidechain.toLowerCase()).eq(weth.address.toLowerCase());
      expect(standard).eq(20);
      expect(amount.toNumber()).eq(100);
    });

    it('should be able to deposit ERC721', async () => {
      erc721 = await new MockERC721__factory(alice).deploy('ERC721', '721', '');
      await erc721['mint(address,uint256)'](alice.address, 0);
      await erc721['mint(address,uint256)'](bob.address, 1);

      await registry.mapToken(erc721.address, erc721.address, 721);
      await expect(mainchainGateway.depositERC721(erc721.address, 0)).reverted;

      await erc721.setApprovalForAll(mainchainGateway.address, true);
      await mainchainGateway.depositERC721(erc721.address, 0);

      await erc721.connect(charles).setApprovalForAll(mainchainGateway.address, true);

      await expect(mainchainGateway.connect(charles).depositERC721(erc721.address, 2)).reverted;
      await erc721['mint(address,uint256)'](charles.address, 2);
      await mainchainGateway.connect(charles).depositERC721(erc721.address, 2);

      const [owner, token, sidechain, standard, tokenId] = await mainchainGateway.deposits(3);
      expect(owner.toLowerCase()).eq(charles.address.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(sidechain.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(standard).eq(721);
      expect(tokenId.toNumber()).eq(2);
    });

    it('should be able to deposit bulk', async () => {
      await erc721['mint(address,uint256)'](alice.address, 3);
      await erc721['mint(address,uint256)'](bob.address, 4);
      await erc721.setApprovalForAll(mainchainGateway.address, true);

      await expect(
        mainchainGateway.depositBulkFor(bob.address, [erc20.address, erc721.address, erc721.address], [1000, 3, 4])
      ).reverted;

      await erc721.connect(bob).transferFrom(bob.address, alice.address, 4);

      await mainchainGateway.depositBulkFor(bob.address, [erc20.address, erc721.address, erc721.address], [10, 3, 4]);

      const depositCount = await mainchainGateway.depositCount();
      expect(depositCount.toNumber()).eq(7);
      const [owner, token, , , tokenId] = await mainchainGateway.deposits(6);
      expect(owner.toLowerCase()).eq(bob.address.toLowerCase());
      expect(token.toLowerCase()).eq(erc721.address.toLowerCase());
      expect(tokenId.toNumber()).eq(4);
    });
  });

  describe('test withdrawal', async () => {
    it('should not be able to withdraw without enough signature', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice],
        withdrawalERC20Hash(1, alice.address, weth.address, ethToWei(1))
      );

      await expect(mainchainGateway.withdrawToken(1, weth.address, ethToWei(1), signatures)).reverted;
    });

    it('should not be able to withdraw eth with wrong order of signatures', async () => {
      const { signatures } = await getCombinedSignatures(
        true,
        [alice, bob],
        withdrawalERC20Hash(1, alice.address, weth.address, ethToWei(1))
      );
      await expect(mainchainGateway.withdrawToken(1, weth.address, ethToWei(1), signatures)).reverted;
    });

    it('should be able to withdraw eth', async () => {
      const hash = withdrawalERC20Hash(1, alice.address, weth.address, ethToWei(0.5));
      const { signatures } = await getCombinedSignatures(false, [alice, bob], hash);
      const beforeBalance = await alice.getBalance();
      await mainchainGateway.connect(bob).withdrawERC20For(1, alice.address, weth.address, ethToWei(0.5), signatures);
      const afterBalance = await alice.getBalance();
      expect(afterBalance.sub(beforeBalance).toString()).eq(ethToWei(0.5).toString());
    });

    it('should not able to withdraw with same withdrawalId', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC20Hash(1, alice.address, weth.address, ethToWei(0.5))
      );

      await expect(
        mainchainGateway.connect(bob).withdrawERC20For(1, alice.address, weth.address, ethToWei(0.5), signatures)
      ).reverted;
    });

    it('should be able to withdraw for self', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC20Hash(2, alice.address, weth.address, ethToWei(0.5))
      );

      await mainchainGateway.withdrawToken(2, weth.address, ethToWei(0.5), signatures);
    });

    it('should be able to withdraw locked erc20', async () => {
      const erc20Balance = await erc20.balanceOf(mainchainGateway.address);
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC20Hash(3, alice.address, erc20.address, erc20Balance)
      );

      const beforeBalance = await erc20.balanceOf(alice.address);
      await mainchainGateway.withdrawERC20(3, erc20.address, erc20Balance, signatures);
      const afterBalance = await erc20.balanceOf(alice.address);
      expect(beforeBalance.add(erc20Balance).toString()).eq(afterBalance.toString());
    });

    it('should be able to mint new erc20 token when withdrawing', async () => {
      await erc20.addMinters([mainchainGateway.address]);

      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC20Hash(4, bob.address, erc20.address, 1000)
      );

      const beforeBalance = await erc20.balanceOf(bob.address);
      await mainchainGateway.withdrawERC20For(4, bob.address, erc20.address, 1000, signatures);
      const afterBalance = await erc20.balanceOf(bob.address);
      expect(beforeBalance.add(1000).toString()).eq(afterBalance.toString());
    });

    it('should be able to withdraw locked erc721', async () => {
      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC721Hash(5, charles.address, erc721.address, 4)
      );

      await mainchainGateway.connect(charles).withdrawERC721(5, erc721.address, 4, signatures);
      const owner = await erc721.ownerOf(4);

      expect(owner.toLowerCase()).eq(charles.address.toLowerCase());
    });

    it('should be able to mint new erc721 when withdrawing', async () => {
      const MINTER_ROLE = await erc721.MINTER_ROLE();
      await erc721.grantRole(MINTER_ROLE, mainchainGateway.address);
      await erc721.grantRole(MINTER_ROLE, alice.address);

      await erc721['mint(address,uint256)'](alice.address, 500);

      const { signatures } = await getCombinedSignatures(
        false,
        [alice, bob],
        withdrawalERC721Hash(6, bob.address, erc721.address, 1000)
      );

      await mainchainGateway.withdrawERC721For(6, bob.address, erc721.address, 1000, signatures);
      const owner = await erc721.ownerOf(1000);
      expect(owner.toLowerCase()).eq(bob.address.toLowerCase());
    });

    it('should be able to set pausable admin ', async () => {
      const pausableAdmin = await new PausableAdmin__factory(alice).deploy(mainchainGateway.address);
      await mainchainGateway.changeAdmin(pausableAdmin.address);

      await pausableAdmin.pauseGateway();
      const paused = await mainchainGateway.paused();
      expect(paused).eq(true);
    });
  });
});
