const { expect } = require("chai");
const load = require("../helpers/_loadTest.js");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { BigNumber } = require("ethers");

describe("TradingPool721Factory", () => {
  load.loadTest(false);

  before(async function () {
    // Take a snapshot before the tests start
    snapshotId = await ethers.provider.send("evm_snapshot", []);
  });

  beforeEach(async function () {
    // Restore the blockchain state to the snapshot before each test
    await ethers.provider.send("evm_revert", [snapshotId]);

    // Take a snapshot before the tests start
    snapshotId = await ethers.provider.send("evm_snapshot", []);
  });

  it("Should create a trading pool", async function () {
    const createTx = await tradingPool721Factory.create(
      testERC721.address,
      wethAddress
    );
    await createTx.wait();
    expect(
      await tradingPoolRegistry.getTradingPool(testERC721.address, wethAddress)
    ).to.be.not.equal(ethers.constants.AddressZero);
  });
});
