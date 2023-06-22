const { expect } = require("chai");
const load = require("../helpers/_loadTest.js");

describe("Deposit", function () {
  load.loadTest(false);
  it("Should create a pool and deposit into it", async function () {
    // Create a pool
    const createTradingPoolTx = await tradingPool721Factory.create(
      testERC721.address,
      wethAddress
    );
    await createTradingPoolTx.wait();
    tradingPool = await ethers.getContractAt(
      "TradingPool721",
      await tradingPoolRegistry.getTradingPool(testERC721.address, wethAddress)
    );

    console.log("Created new pool: ", tradingPool.address);

    // Mint 50 test tokens to the callers address
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();

    // Deposit the tokens into the pool
    const TradingPool = await ethers.getContractFactory("TradingPool721");
    tradingPool = TradingPool.attach(tradingPool.address);
    const approveNFTTx = await testERC721.setApprovalForAll(
      wethGateway.address,
      true
    );
    await approveNFTTx.wait();
    const depositTx = await wethGateway.depositTradingPool721(
      tradingPool.address,
      0,
      [0],
      "100000000000000",
      exponentialCurve.address,
      "0",
      "100",
      { value: "100000000000000" }
    );
    await depositTx.wait();
  });
});
