import {
  expectTransactionFailed,
  resetAfterAll,
  web3Pool,
} from '@axie/contract-test-utils';
import BN = require('bn.js');
import 'mocha';
import web3Utils = require('web3-utils');

import { expect } from 'chai';
// tslint:disable-next-line: no-implicit-dependencies
import { AbiCoder } from 'web3-eth-abi';
import { WETHDevContract } from '../../src';
import { GameContract } from '../../src/contract/game';
import { IMatchContract } from '../../src/contract/i_match';

const ethToWei = (eth: number) => new BN(web3Utils.toWei(eth.toString(), 'ether'));

enum Action {
  Appeal = 0,
  CreateMatch = 1,
  JoinMatch = 2,
  UnjoinMatch = 3,
}

const extraDataToGame = (action: Action, matchId: BN, joinFee?: number | string) => {
  const types = ['uint256', 'uint256'];
  const values = [new BN(action).toString(), matchId.toString()];

  if (joinFee !== undefined) {
    types.push('uint256');
    values.push(new BN(joinFee).toString());
  }

  return new AbiCoder().encodeParameters(types, values);
};

describe('Match contract', () => {
  let alice: string;
  let bob: string;
  let charles: string;
  let ezreal: string;
  let gameContract: GameContract;
  let wethContract: WETHDevContract;

  const initBalance = ethToWei(1000);

  before(async () => {
    [alice, bob, charles, ezreal] = await web3Pool.ethGetAccounts();
    wethContract = await WETHDevContract.deploy().send(web3Pool);
    await wethContract.addMinters([alice]).send();
    await wethContract.mint(alice, initBalance).send();
    await wethContract.mint(bob, initBalance).send();
    await wethContract.mint(charles, initBalance).send();
    await wethContract.mint(ezreal, initBalance).send();

    const minPlayer = new BN(4);
    const maxPlayer = new BN(4);
    const operationCost = ethToWei(100);
    const unjoinCost = ethToWei(25);
    const appealCost = ethToWei(50);
    const rewardTimeDue = new BN(0);
    gameContract = await GameContract.deploy(
      minPlayer,
      maxPlayer,
      operationCost,
      unjoinCost,
      appealCost,
      rewardTimeDue,
      wethContract.address,
    ).send(web3Pool);
  });

  describe('Test create, join & unjoin match', () => {
    const joinFee = ethToWei(26);
    const matchId = new BN(0);

    it('Alice: approve and create a match but fail', async () => {
      const joinFeeDummy = ethToWei(2);
      const extraData = extraDataToGame(Action.CreateMatch, matchId, joinFeeDummy.toString(10));

      await expectTransactionFailed(
        wethContract.approveAndCall(
          gameContract.address,
          joinFeeDummy,
          extraData,
        ).send(),
      );
    });

    it('Alice: approve and create a match', async () => {
      const extraData = extraDataToGame(Action.CreateMatch, matchId, joinFee.toString(10));

      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraData,
      ).send();

      const gameBalance = await wethContract.balanceOf(gameContract.address).call();
      expect(gameBalance.toString()).to.eq(joinFee.toString());
    });

    it('Bob: approve and join a match', async () => {
      const extraData = extraDataToGame(Action.JoinMatch, matchId, joinFee.toString(10));

      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraData,
      ).send({ from: bob });

      const gameBalance = await wethContract.balanceOf(gameContract.address).call();
      expect(gameBalance.toString()).to.eq(joinFee.muln(2).toString());
    });

    it('Alice: unjoin a match', async () => {
      await gameContract.unjoinMatchAndCharge(matchId).send();

      const gameBalance = await wethContract.balanceOf(gameContract.address).call();
      const unjoinCost = await gameContract.unjoinCost().call();
      const aliceBalance = await wethContract.balanceOf(alice).call();

      expect(gameBalance.toString()).to.eq(unjoinCost.add(joinFee).toString());
      expect(aliceBalance.toString()).to.eq(initBalance.sub(unjoinCost).toString());
    });

    it('Bob: unjoin a match', async () => {
      await gameContract.unjoinMatchAndCharge(matchId).send({ from: bob });

      const gameBalance = await wethContract.balanceOf(gameContract.address).call();
      const unjoinCost = await gameContract.unjoinCost().call();
      const bobBalance = await wethContract.balanceOf(bob).call();

      expect(gameBalance.toString()).to.eq(unjoinCost.muln(2).toString());
      expect(bobBalance.toString()).to.eq(initBalance.sub(unjoinCost).toString());
    });

    it('Bob: reunjoin but fail', async () => {
      await expectTransactionFailed(gameContract.unjoinMatchAndCharge(matchId).send({ from: bob }));
    });

    it('Charles: join but too late', async () => {
      await expectTransactionFailed(gameContract.joinMatchAndCharge(matchId).send({ from: charles }));
    });

    it('Charles: join a not created match', async () => {
      await expectTransactionFailed(gameContract.joinMatchAndCharge(new BN(1)).send({ from: charles }));
    });
  });

  describe('Test a normal match', () => {
    const joinFee = ethToWei(50);
    const matchId = new BN(1);

    it('Ezreal: approve & create a match ', async () => {
      await wethContract.approve(gameContract.address, joinFee).send({ from: ezreal });
      await gameContract.createMatchAndCharge(matchId, joinFee).send({ from: ezreal });

      const balance = await wethContract.balanceOf(ezreal).call();
      expect(balance.toString()).to.eq(initBalance.sub(joinFee).toString());

      const players = await gameContract.getTotalPlayer(matchId).call();
      expect(new BN(1).toString()).to.eq(players.toString());
    });

    it('Alice, Bob: approve & join a match ', async () => {
      const extraData = extraDataToGame(Action.JoinMatch, matchId, joinFee.toString(10));

      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraData,
      ).send({ from: alice });
      const players1 = await gameContract.getTotalPlayer(matchId).call();
      expect(new BN(2).toString()).to.eq(players1.toString());

      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraData,
      ).send({ from: bob });
      const players2 = await gameContract.getTotalPlayer(matchId).call();
      expect(new BN(3).toString()).to.eq(players2.toString());
    });

    it('Server: update match result but fail', async () => {
      await expectTransactionFailed(
        gameContract.setMatchResult(matchId, alice).send(),
      );
    });

    it('Charles: join match', async () => {
      const extraData = extraDataToGame(Action.JoinMatch, matchId, joinFee.toString(10));

      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraData,
      ).send({ from: charles });

      const players = await gameContract.getTotalPlayer(matchId).call();
      expect(new BN(4).toString()).to.eq(players.toString());
    });

    it('Server: update match result successfully', async () => {
      await gameContract.setMatchResult(matchId, alice).send();
    });

    it('Alice: withdraw her reward', async () => {
      const originBalance = await wethContract.balanceOf(alice).call();
      const reward = await gameContract.getPendingRewards().call();
      const operationCost = await gameContract.operationCost().call();

      expect(reward.toString()).to.eq(joinFee.muln(4).sub(operationCost).toString());

      await gameContract.withdrawPendingRewards().send({ from: alice });

      const balance = await wethContract.balanceOf(alice).call();
      expect(balance.toString()).to.eq(originBalance.add(reward).toString());
    });

    it('Alice: re-withdraw her reward', async () => {
      await expectTransactionFailed(
        gameContract.withdrawPendingRewards().send({ from: alice }),
      );
    });
  });

  describe('Test a normal match with appealing', () => {
    const joinFee = ethToWei(50);
    const matchId = new BN(2);

    it('Alice, Bob, Charles, Ezreal: join match', async () => {
      await wethContract.approveAndCall(
        gameContract.address,
        joinFee,
        extraDataToGame(Action.CreateMatch, matchId, joinFee.toString(10)),
      ).send({ from: alice });

      const extraData = extraDataToGame(Action.JoinMatch, matchId, joinFee.toString(10));
      await Promise.all([
        wethContract.approveAndCall(gameContract.address, joinFee, extraData).send({ from: bob }),
        wethContract.approveAndCall(gameContract.address, joinFee, extraData).send({ from: charles }),
        wethContract.approveAndCall(gameContract.address, joinFee, extraData).send({ from: ezreal }),
      ]);
    });

    it('Server: set match result', async () => {
      await gameContract.setMatchResult(matchId, alice).send();
    });

    it('Charles: appeal the match', async () => {
      const appealCost = await gameContract.appealCost().call();
      const extraData = extraDataToGame(Action.Appeal, matchId);
      await wethContract.approveAndCall(gameContract.address, appealCost, extraData).send();
    });

    it('Alice: withdraw her reward but fail', async () => {
      await expectTransactionFailed(
        gameContract.withdrawPendingRewards().send({ from: alice }),
      );
    });

    it('Server: update match result', async () => {
      await expectTransactionFailed(gameContract.setMatchResult(matchId, charles).send());
      await gameContract.updateMatchResult(matchId, charles).send();
    });

    it('Alice: withdraw her reward but fail', async () => {
      await expectTransactionFailed(
        gameContract.withdrawPendingRewards().send({ from: alice }),
      );
    });

    it('Charles: withdraw his reward', async () => {
      await gameContract.withdrawPendingRewardsFor(charles).send();
    });
  });
});
