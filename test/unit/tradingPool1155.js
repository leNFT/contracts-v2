const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
const load = require("../helpers/_loadTest.js");
const { getPriceSig } = require("../helpers/getPriceSig.js");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TradingPool1155", function () {
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

  it("Should get the correct token URI", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.1"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.1")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      2,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Get the token URI from the metadata contract
    const tokenURIMetadata = await liquidityPair1155Metadata.tokenURI(
      tradingPool.address,
      0
    );

    // Get the token URI from the trading pool
    const tokenURI = await tradingPool.tokenURI(0);

    // Compare the two and expect them to be equal
    expect(tokenURI).to.equal(tokenURIMetadata);
  });
  it("Should be able to add liquidity to a trading pool", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("1"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("1")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      2,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // The lp count should be 1
    expect(await tradingPool.getLpCount()).to.equal(1);

    // Get the lp and compare its values
    const lp = await tradingPool.getLP(0);
    expect(lp.lpType).to.equal(0);
    expect(lp.nftId).to.equal(0);
    expect(lp.nftAmount).to.equal(2);
    expect(lp.tokenAmount).to.equal(ethers.utils.parseEther("1"));
    expect(lp.spotPrice).to.equal(ethers.utils.parseEther("1"));
    expect(lp.curve).to.equal(exponentialCurve.address);
    expect(lp.delta).to.equal("50");
    expect(lp.fee).to.equal("500");
  });
  it("Should be able to remove liquidity from a trading pool", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.1"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.1")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      2,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Remove the liquidity
    const removeLiquidityTx = await tradingPool.removeLiquidity(0);
    await removeLiquidityTx.wait();

    // The lp count should be still be 1
    expect(await tradingPool.getLpCount()).to.equal(1);

    // The NFTs should be returned to the caller
    expect(await testERC1155.balanceOf(owner.address, 0)).to.equal(2);

    // Should throw an error when trying to get the lp
    await expect(tradingPool.getLP(0)).to.be.revertedWith("TP:LP_NOT_FOUND");
  });
  it("Should be able to remove liquidity from a trading pool in batch", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.2"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.2")
    );
    await approveTokenTx.wait();
    const depositTx1 = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      1,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx1.wait();
    const depositTx2 = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      1,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx2.wait();

    // Remove the liquidity
    const removeLiquidityBatchTx = await tradingPool.removeLiquidityBatch([
      0, 1,
    ]);
    await removeLiquidityBatchTx.wait();

    // The lp count should be still be 2
    expect(await tradingPool.getLpCount()).to.equal(2);

    // Should throw an error when trying to get the lps
    await expect(tradingPool.getLP(0)).to.be.revertedWith("TP:LP_NOT_FOUND");
    await expect(tradingPool.getLP(1)).to.be.revertedWith("TP:LP_NOT_FOUND");
  });
  it("Should be able to buy one token", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.205"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.205")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      2,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Get the token balance before
    const tokenBalanceBefore = await weth.balanceOf(owner.address);

    // Buy the tokens
    const buyTx = await tradingPool.buy(
      owner.address,
      [0],
      [1],
      ethers.utils.parseEther("0.105")
    );
    await buyTx.wait();

    // Should now own the token again
    expect(await testERC1155.balanceOf(owner.address, 0)).to.equal(1);

    // Get the lp
    const lp = await tradingPool.getLP(0);
    expect(lp.nftId).to.equal(0);
    expect(lp.nftAmount).to.equal(1);
    expect(lp.tokenAmount).to.equal(ethers.utils.parseEther("0.2045"));
    expect(lp.spotPrice).to.equal(ethers.utils.parseEther("0.1005"));

    // Get the token balance after
    const tokenBalanceAfter = await weth.balanceOf(owner.address);
    expect(tokenBalanceBefore.sub(tokenBalanceAfter)).to.equal(
      ethers.utils.parseEther("0.105")
    );

    // Get the protocol fee percentage so we can calculate the protocol fee
    const protocolFeePercentage =
      await tradingPoolRegistry.getProtocolFeePercentage();
    // Calculate the protocol fee
    const protocolFee = BigNumber.from(ethers.utils.parseEther("0.1"))
      .mul("500")
      .mul(protocolFeePercentage)
      .div("10000")
      .div("10000");
    console.log(protocolFee.toString());

    // The fee should be in the fee distribution contract
    expect(
      await feeDistributor.getTotalFeesAt(
        weth.address,
        votingEscrow.getEpoch(await time.latest())
      )
    ).to.equal(protocolFee);
  });
  it("Should be able to buy multiple tokens", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.310525"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.310525")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      2,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Buy the tokens
    const buyTx = await tradingPool.buy(
      owner.address,
      [0],
      [2],
      ethers.utils.parseEther("0.210525")
    );
    await buyTx.wait();

    // Should now own both tokens
    expect(await testERC1155.balanceOf(owner.address, 0)).to.equal(2);

    // Get the lp
    const lp = await tradingPool.getLP(0);
    expect(lp.nftId).to.equal(0);
    expect(lp.tokenAmount).to.equal(ethers.utils.parseEther("0.3095225"));
    expect(lp.spotPrice).to.equal(ethers.utils.parseEther("0.1010025"));
  });
  it("Should be able to sell one token", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 1);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.1"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.1")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      0,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.005"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Balance before
    const tokenBalanceBefore = await weth.balanceOf(owner.address);

    // Buy the tokens
    const sellTx = await tradingPool.sell(
      owner.address,
      [0],
      [1],
      "47500000000000"
    );
    await sellTx.wait();

    expect(await testERC1155.balanceOf(tradingPool.address, 0)).to.equal(1);

    // Get the lp
    const lp = await tradingPool.getLP(0);
    expect(lp.nftId).to.equal(0);
    expect(lp.tokenAmount).to.equal(ethers.utils.parseEther("0.095225"));
    expect(lp.spotPrice).to.equal(
      ethers.utils.parseEther("0.004975124378109453")
    );

    // Balance after
    const tokenBalanceAfter = await weth.balanceOf(owner.address);
    expect(tokenBalanceAfter.sub(tokenBalanceBefore)).to.equal(
      ethers.utils.parseEther("0.00475")
    );

    // Get the protocol fee percentage so we can calculate the protocol fee
    const protocolFeePercentage =
      await tradingPoolRegistry.getProtocolFeePercentage();
    // Calculate the protocol fee
    const protocolFee = ethers.utils
      .parseEther("0.005")
      .mul("500")
      .mul(protocolFeePercentage)
      .div("10000")
      .div("10000");
    console.log(protocolFee.toString());

    // The fee should be in the fee distribution contract
    expect(
      await feeDistributor.getTotalFeesAt(
        weth.address,
        votingEscrow.getEpoch(await time.latest())
      )
    ).to.equal(protocolFee);
  });
  it("Should be able to sell multiple tokens", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 2);
    await mintTestNFTTx.wait();

    const approveNFTTx = await testERC1155.setApprovalForAll(
      tradingPool.address,
      true
    );
    await approveNFTTx.wait();
    // Mint and approve test tokens to the callers address
    const mintTestTokenTx = await weth.deposit({
      value: ethers.utils.parseEther("0.1"),
    });
    await mintTestTokenTx.wait();
    // Deposit the tokens into the market
    const approveTokenTx = await weth.approve(
      tradingPool.address,
      ethers.utils.parseEther("0.1")
    );
    await approveTokenTx.wait();
    const depositTx = await tradingPool.addLiquidity(
      owner.address,
      0,
      0,
      0,
      ethers.utils.parseEther("0.1"),
      ethers.utils.parseEther("0.00005"),
      exponentialCurve.address,
      "50",
      "500"
    );
    await depositTx.wait();

    // Buy the tokens
    const sellTx = await tradingPool.sell(owner.address, [0], [2], 0);
    await sellTx.wait();

    // Should now 0 tokens
    expect(await testERC1155.balanceOf(owner.address, 0)).to.equal(0);

    // Get the lp
    const lp = await tradingPool.getLP(0);
    expect(lp.nftId).to.equal(0);
    expect(lp.nftAmount).to.equal(2);
    expect(lp.tokenAmount).to.equal(
      ethers.utils.parseEther("0.099954488805970149")
    );
    expect(lp.spotPrice).to.equal(
      ethers.utils.parseEther("0.000049751243781095")
    );
  });
  it("Should not be able to add liquidity to a paused pool", async function () {
    // Create a new trading pool
    const createPoolTx = await tradingPool1155Factory.create(
      testERC1155.address,
      weth.address
    );
    createPoolTx.wait();

    const tradingPool = await ethers.getContractAt(
      "TradingPool1155",
      await tradingPoolRegistry.getTradingPool(
        testERC1155.address,
        weth.address
      )
    );

    // Pause the pool
    const pauseTx = await tradingPool.setPause(true);
    await pauseTx.wait();

    // try to add liquidity should fail
    await expect(
      tradingPool.addLiquidity(
        owner.address,
        0,
        0,
        1,
        ethers.utils.parseEther("0.1"),
        "50000000000000",
        exponentialCurve.address,
        "50",
        "500"
      )
    ).to.be.revertedWith("TP:POOL_PAUSED");
  });
});
