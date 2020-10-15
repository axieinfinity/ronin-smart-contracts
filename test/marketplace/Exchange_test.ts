import { ERC20FullContract } from '@axie/contract-library';
import {
  expectContractCallFailed,
  expectTransactionFailed,
  resetAfterAll,
  resetAfterEach,
  web3Pool,
} from '@axie/contract-test-utils';
import BN = require('bn.js');
import { expect } from 'chai';
import * as _ from 'lodash';
import 'mocha';
import web3Utils = require('web3-utils');

import {
  ClockAuctionContract,
  ExchangeContract,
  ItemCollectionContract,
  LandContract,
  OfferAuctionContract,
  RegistryContract,
  RoninWETHContract,
} from '../../src';

const maxUint256 = new BN(1).shln(256).subn(1);

const ethToWei = (eth: number) => new BN(web3Utils.toWei(eth.toString(), 'ether'));

describe('Exchange test', () => {
  resetAfterAll();

  let alice: string;
  let bob: string;
  let charles: string;

  let registry: RegistryContract;
  let exchange: ExchangeContract;
  let offerAuction: OfferAuctionContract;
  let clockAuction: ClockAuctionContract;
  let land: LandContract;
  let itemCollection: ItemCollectionContract;

  let roninWETH: RoninWETHContract;
  let exchangeToken: ERC20FullContract;

  let firstErc20: ERC20FullContract;
  let secondErc20: ERC20FullContract;

  const tokenMaxOccurrences = 2;

  before(async () => {
    [alice, bob, charles] = await web3Pool.ethGetAccounts();
    registry = await RegistryContract.deploy().send(web3Pool);

    roninWETH = await RoninWETHContract.deploy().send(web3Pool);
    await roninWETH.addMinters([alice]).send();

    exchangeToken = await ERC20FullContract.deploy(
      'Exchange Token',
      'ExT',
      18,
      ethToWei(200),
    ).send(web3Pool);
    await exchangeToken.addMinters([alice]).send();

    exchange = await ExchangeContract.deploy([roninWETH.address, exchangeToken.address]).send(web3Pool);

    clockAuction = await ClockAuctionContract.deploy(
      new BN(tokenMaxOccurrences),
      registry.address,
      new BN(1000),
    ).send(web3Pool);
    await exchange.addAuctionType(clockAuction.address).send();

    offerAuction = await OfferAuctionContract.deploy(registry.address, new BN(1000)).send(web3Pool);
    await exchange.addAuctionType(offerAuction.address).send();

    const EXCHANGE = await clockAuction.EXCHANGE().call();
    await registry.updateContract(EXCHANGE, exchange.address).send();

    const CLOCK_AUCTION = await clockAuction.CLOCK_AUCTION().call();
    await registry.updateContract(CLOCK_AUCTION, clockAuction.address).send();

    const OFFER_AUCTION = await clockAuction.OFFER_AUCTION().call();
    await registry.updateContract(OFFER_AUCTION, offerAuction.address).send();

    // Token to sell
    firstErc20 = await ERC20FullContract.deploy('1', '1', new BN(0), new BN('1000000000000000000')).send(web3Pool);
    await firstErc20.addMinters([alice]).send();

    secondErc20 = await ERC20FullContract.deploy('2', '2', new BN(0), new BN('1000000000000000000')).send(web3Pool);
    await secondErc20.addMinters([alice]).send();

    land = await LandContract.deploy('').send(web3Pool);
    await land.addMinters([alice]).send();

    itemCollection = await ItemCollectionContract.deploy('item', 'ITEM', 'https://axieinfinity.com').send(web3Pool);
    await itemCollection.addTokenType('1', '1', 'https://axieinfinity.com/1').send();
    await itemCollection.addMinters([alice]).send();
  });

  it('Minting items', async () => {
    await roninWETH.mint(bob, ethToWei(100)).send();
    await roninWETH.mint(charles, ethToWei(100)).send();

    await exchangeToken.mint(bob, ethToWei(100)).send();
    await exchangeToken.mint(charles, ethToWei(100)).send();

    await firstErc20.mint(bob, new BN(1000)).send();
    await firstErc20.mint(charles, new BN(1000)).send();

    await secondErc20.mint(bob, new BN(1000)).send();
    await secondErc20.mint(charles, new BN(1000)).send();

    await land.mint(bob, new BN(0), new BN(0)).send();
    await land.mint(charles, new BN(1), new BN(1)).send();

    await land.mint(bob, new BN(10), new BN(10)).send();
    await land.mint(bob, new BN(11), new BN(11)).send();
    await land.mint(bob, new BN(12), new BN(12)).send();

    await itemCollection.mint(bob, new BN(1), new BN(1)).send();
    await itemCollection.mint(charles, new BN(1), new BN(2)).send();
  });

  describe('Exchange test', async () => {
    it('Should not be able to insert invalid listings', async () => {
      // Wrong address order
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [0, 0],
          [firstErc20.address, secondErc20.address].sort().reverse(),
          [new BN(100), new BN(100)],
        ).send(),
      );

      // Duplicated FT
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [0, 0],
          [firstErc20.address, firstErc20.address],
          [new BN(1), new BN(100)],
        ).send(),
      );

      // Invalid token type
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [2],
          [firstErc20.address],
          [new BN(1)],
        ).send(),
      );

      // Duplicated NFT
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [1, 1],
          [land.address, land.address],
          [new BN(100), new BN(100)],
        ).send(),
      );

      // Wrong NFT order
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [1, 1],
          [land.address, land.address],
          [new BN(100), new BN(1)],
        ).send(),
      );

      // Wrong mapping of token type and token address
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [0],
          [land.address],
          [new BN(1)],
        ).send(),
      );

      // Wrong mapping of token type and token address
      await expectTransactionFailed(
        exchange.createOrGetListing(
          [1],
          [secondErc20.address],
          [new BN(1)],
        ).send(),
      );
    });

    it('Should be able to create unique listing', async () => {
      await exchange.createOrGetListing(
        [0, 0],
        [firstErc20.address, secondErc20.address].sort(),
        [new BN(100), new BN(100)],
      ).send();

      const itemId = await itemCollection.getItemId(new BN(1), new BN(1)).call();
      await exchange.createOrGetListing(
        [1],
        [itemCollection.address],
        [itemId],
      ).send();

      await exchange.createOrGetListing(
        [0, 0],
        [firstErc20.address, secondErc20.address].sort(),
        [new BN(100), new BN(100)],
      ).send();

      // Only 2 listing available
      await expectContractCallFailed(
        exchange.getListing(new BN(2)).call(),
      );

      const [tokenTypes, tokenAddresses, tokenNumbers] = await exchange.getListing(new BN(1)).call();

      expect(tokenTypes.length).eq(1);
      expect(tokenTypes[0].toString()).eq('1');
      expect(tokenAddresses[0].toLowerCase()).eq(itemCollection.address.toLowerCase());
      expect(tokenNumbers[0].toString()).eq(itemId.toString());
    });

    it('Should be able to use only allowed token to exchange', async () => {
      const roninResult = await exchange.isTokenExchangeable(roninWETH.address).call();
      expect(true).to.eq(roninResult);

      const exchangeTokenResult = await exchange.isTokenExchangeable(exchangeToken.address).call();
      expect(true).to.eq(exchangeTokenResult);

      const result = await exchange.isTokenExchangeable(alice).call();
      expect(false).to.eq(result);
    });
  });

  it('Approve exchange contract', async () => {
    await roninWETH.approve(exchange.address, maxUint256).send({ from: bob });
    await roninWETH.approve(exchange.address, maxUint256).send({ from: charles });

    await exchangeToken.approve(exchange.address, maxUint256).send({ from: bob });
    await exchangeToken.approve(exchange.address, maxUint256).send({ from: charles });

    await firstErc20.approve(exchange.address, maxUint256).send({ from: bob });
    await firstErc20.approve(exchange.address, maxUint256).send({ from: charles });

    await secondErc20.approve(exchange.address, maxUint256).send({ from: bob });
    await secondErc20.approve(exchange.address, maxUint256).send({ from: charles });

    await land.setApprovalForAll(exchange.address, true).send({ from: bob });
    await land.setApprovalForAll(exchange.address, true).send({ from: charles });

    await itemCollection.setApprovalForAll(exchange.address, true).send({ from: bob });
    await itemCollection.setApprovalForAll(exchange.address, true).send({ from: charles });
  });

  describe('Clock auction test', async () => {
    it('Should only be able to create auction of the listing that he owns', async () => {
      await clockAuction.createAuction1(
        new BN(0),
        [ethToWei(1), ethToWei(0.5)],
        [ethToWei(1), ethToWei(0.5)],
        [roninWETH.address, exchangeToken.address],
        new BN(1000),
      ).send({ from: bob });

      await clockAuction.createAuction1(
        new BN(1),
        [ethToWei(1), ethToWei(0.5)],
        [ethToWei(1), ethToWei(0.5)],
        [roninWETH.address, exchangeToken.address],
        new BN(1000),
      ).send({ from: bob });

      await expectTransactionFailed(
        clockAuction.createAuction1(
          new BN(1),
          [ethToWei(1), ethToWei(0.5)],
          [ethToWei(1), ethToWei(0.5)],
          [roninWETH.address, exchangeToken.address],
          new BN(1000),
        ).send({ from: charles }),
      );
    });

    it('Should be able to create auction of not existing listing', async () => {
      await clockAuction.createAuction2(
        [1],
        [itemCollection.address],
        [await itemCollection.getItemId(new BN(1), new BN(2)).call()],
        [ethToWei(1), ethToWei(0.5)],
        [ethToWei(1), ethToWei(0.5)],
        [roninWETH.address, exchangeToken.address],
        new BN(1000),
      ).send({ from: charles });
    });

    it('Should not be able to buy the auction with un-allowed token', async () => {
      await expectTransactionFailed(
        clockAuction.settleAuction(
          bob,
          firstErc20.address,
          ethToWei(1.1),
          new BN(1),
        ).send({ from: charles }),
      );
    });

    it('Should not be able to buy the auction with un-allowed token', async () => {
      await expectTransactionFailed(
        clockAuction.settleAuction(
          bob,
          firstErc20.address,
          ethToWei(1.1),
          new BN(1),
        ).send({ from: charles }),
      );
    });

    it('Should be able to buy the auction with WETH token', async () => {
      const prevBalance = await roninWETH.balanceOf(bob).call();

      await clockAuction.settleAuction(
        bob,
        roninWETH.address,
        ethToWei(1.1),
        new BN(1),
      ).send({ from: charles });

      const balance = await roninWETH.balanceOf(bob).call();
      expect(balance.toString()).to.not.eq(prevBalance.toString());
    });

    it('Should be able to buy the auction with exchangeable token', async () => {
      const prevBalance = await exchangeToken.balanceOf(charles).call();

      await clockAuction.settleAuction(
        charles,
        exchangeToken.address,
        ethToWei(1.1),
        new BN(2),
      ).send({ from: bob });

      const balance = await exchangeToken.balanceOf(charles).call();
      expect(balance.toString()).to.not.eq(prevBalance.toString());
    });

    it('Should not be able to buy again', async () => {
      await expectTransactionFailed(
        clockAuction.settleAuction(
          charles,
          exchangeToken.address,
          ethToWei(1.1),
          new BN(2),
        ).send({ from: bob }),
      );
    });
  });

  // describe('Offer Auction test', async () => {
  //   it('Should not be create offer with un-allowed tokens', async () => {
  //     await expectTransactionFailed(
  //       offerAuction.createOffer1(new BN(0), alice, new BN(1000)).send({ from: charles }),
  //     );
  //   });

  //   it('Should be able to create offer with exchangeable tokens and price not more than balance', async () => {
  //     await expectTransactionFailed(
  //       offerAuction.createOffer1(new BN(0), roninWETH.address, ethToWei(101)).send({ from: charles }),
  //     );

  //     await offerAuction.createOffer1(new BN(0), roninWETH.address, new BN(1000)).send({ from: charles });
  //     await offerAuction.createOffer1(new BN(0), exchangeToken.address, new BN(1000)).send({ from: charles });
  //   });

  //   it('Should not be able to accept offer with other token', async () => {
  //     await expectTransactionFailed(
  //       offerAuction.acceptOffer(
  //         charles,
  //         new BN(0),
  //         firstErc20.address,
  //         new BN(1000),
  //       ).send({ from: bob }),
  //     );
  //   });

  //   it('Should able to cancel offer & reject', async () => {
  //     await offerAuction.cancelOffer(exchangeToken.address, new BN(0)).send({ from: charles });
  //     await offerAuction.rejectOffer(charles, roninWETH.address, new BN(0)).send({ from: bob });
  //   });

  //   it('Should able to accept offer', async () => {
  //     await offerAuction.createOffer1(new BN(0), roninWETH.address, ethToWei(1)).send({ from: charles });

  //     const prevBalance = await roninWETH.balanceOf(charles).call();

  //     await offerAuction.acceptOffer(
  //       charles,
  //       new BN(0),
  //       roninWETH.address,
  //       ethToWei(1),
  //     ).send({ from: bob });

  //     const balance = await roninWETH.balanceOf(charles).call();
  //     expect(balance.toString()).to.not.eq(prevBalance.toString());
  //   });
  // });

  describe('Bundle test', async () => {
    it(`Should not create bundle with an item appeared more than ${tokenMaxOccurrences} times`, async () => {
      await clockAuction.createAuction2(
        [1, 1],
        [land.address, land.address],
        [
          await land.getTokenId(new BN(10), new BN(10)).call(),
          await land.getTokenId(new BN(11), new BN(11)).call(),
        ].sort((a, b) => a.cmp(b)),
        [new BN(1000)],
        [new BN(1000)],
        [roninWETH.address],
        new BN(1000),
      ).send({ from: bob });

      await clockAuction.createAuction2(
        [1, 1],
        [land.address, land.address],
        [
          await land.getTokenId(new BN(12), new BN(12)).call(),
          await land.getTokenId(new BN(11), new BN(11)).call(),
        ].sort((a, b) => a.cmp(b)),
        [new BN(1000)],
        [new BN(1000)],
        [roninWETH.address],
        new BN(1000),
      ).send({ from: bob });

      await expectTransactionFailed(
        clockAuction.createAuction2(
          [1, 1, 1],
          [land.address, land.address, land.address],
          [
            await land.getTokenId(new BN(10), new BN(10)).call(),
            await land.getTokenId(new BN(11), new BN(11)).call(),
            await land.getTokenId(new BN(12), new BN(12)).call(),
          ].sort((a, b) => a.cmp(b)),
          [new BN(1000)],
          [new BN(1000)],
          [roninWETH.address],
          new BN(1000),
        ).send({ from: bob }),
      );
    });

    it('Should be able to create & accept the offer for an item in created bundles', async () => {
      await offerAuction.createOffer2(
        [1],
        [land.address],
        [
          await land.getTokenId(new BN(11), new BN(11)).call(),
        ],
        roninWETH.address,
        new BN(1000),
      ).send({ from: charles });

      await offerAuction.acceptOffer(charles, new BN(5), roninWETH.address, new BN(1000)).send({ from: bob });
    });

    it('Should not be existed invalid bundles', async () => {
      const firstResult = await clockAuction.isAuctionExisting(bob, new BN(3)).call();
      expect(false).to.eq(firstResult);

      const secondResult = await clockAuction.isAuctionExisting(bob, new BN(4)).call();
      expect(false).to.eq(secondResult);
    });

    it('Should be able to create bundle with remain items', async () => {
      await clockAuction.createAuction2(
        [1, 1],
        [land.address, land.address],
        [
          await land.getTokenId(new BN(10), new BN(10)).call(),
          await land.getTokenId(new BN(12), new BN(12)).call(),
        ].sort((a, b) => a.cmp(b)),
        [new BN(1000)],
        [new BN(1000)],
        [roninWETH.address],
        new BN(1000),
      ).send({ from: bob });
    });
  });
});
