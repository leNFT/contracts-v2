const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

describe("TradingPoolRegistry", function () {
  let TradingPoolRegistry,
    tradingPoolRegistry,
    owner,
    AddressProvider,
    addressProvider;

  before(async () => {
    AddressProvider = await ethers.getContractFactory("AddressProvider");
    addressProvider = await upgrades.deployProxy(AddressProvider);
    TradingPoolRegistry = await ethers.getContractFactory(
      "TradingPoolRegistry"
    );
    [owner] = await ethers.getSigners();
    tradingPoolRegistry = await upgrades.deployProxy(TradingPoolRegistry, [
      addressProvider.address,
      "1000", // Default protocol fee (10%)
      "25000000000000000000", // TVLSafeguard
    ]);

    // Set the address in the address provider contract
    await addressProvider.setTradingPoolRegistry(tradingPoolRegistry.address);

    // Take a snapshot before the tests start
    snapshotId = await ethers.provider.send("evm_snapshot", []);
  });

  beforeEach(async function () {
    // Restore the blockchain state to the snapshot before each test
    await ethers.provider.send("evm_revert", [snapshotId]);

    // Take a snapshot before the tests start
    snapshotId = await ethers.provider.send("evm_snapshot", []);
  });

  it("Should be able to add a new price curve", async function () {
    // Deploy a new price curve
    const LinearCurve = await ethers.getContractFactory("LinearPriceCurve");
    const linearCurve = await LinearCurve.deploy();
    await linearCurve.deployed();

    expect(
      await tradingPoolRegistry.isPriceCurve(linearCurve.address)
    ).to.equal(false);

    // Add the price curve
    const tx = await tradingPoolRegistry.setPriceCurve(
      linearCurve.address,
      true
    );
    await tx.wait();

    expect(
      await tradingPoolRegistry.isPriceCurve(linearCurve.address)
    ).to.equal(true);
  });
  it("Should be able to set the tvl safeguard", async function () {
    // set the tvl safeguard
    const tx = await tradingPoolRegistry.setTVLSafeguard(
      ethers.utils.parseEther("100")
    );
    await tx.wait();

    // check the tvl safeguard
    expect(await tradingPoolRegistry.getTVLSafeguard()).to.equal(
      ethers.utils.parseEther("100")
    );
  });
  it("Should be able to set the protocol fee percentage", async function () {
    // set the protocol fee percentage
    const tx = await tradingPoolRegistry.setProtocolFeePercentage(
      3000 // 30%
    );
    await tx.wait();

    // check the protocol fee percentage
    expect(await tradingPoolRegistry.getProtocolFeePercentage()).to.equal(3000);
  });
});
