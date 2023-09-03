const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { priceSigner } = require("./getPriceSig.js");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
require("dotenv").config();

let loadEnv = async function (isMainnetFork) {
  //Reset the fork if it's genesis
  console.log("isMainnetFork", isMainnetFork);
  if (isMainnetFork) {
    console.log("Resetting the mainnet fork...");
    await helpers.reset(
      "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      17253963 // Block number 13/05/2023
    );
  } else {
    console.log("Resetting the local fork...");
    await helpers.reset();
    console.log("Resetted the local fork");
  }

  console.log("Setting up enviroment...");

  [owner, address1] = await ethers.getSigners();

  // Mainnet weth address
  if (isMainnetFork) {
    // Get the WETH from the mainnet fork
    console.log("Getting WETH from the mainnet fork...");
    wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    weth = await ethers.getContractAt(
      "contracts/interfaces/IWETH.sol:IWETH",
      wethAddress
    );
    console.log("Got WETH from the mainnet fork:", wethAddress);
  } else {
    // Deploy a WETH contract
    console.log("Deploying WETH...");
    const WETH = await ethers.getContractFactory("WETH");
    weth = await WETH.deploy();
    await weth.deployed();
    wethAddress = weth.address;
    console.log("Deployed WETH:", wethAddress);
  }

  /****************************************************************
  DEPLOY PROXIES
  They will serve as an entry point for the upgraded contracts
  ******************************************************************/

  // Deploy and initialize addresses provider proxy
  const AddressProvider = await ethers.getContractFactory("AddressProvider");
  addressProvider = await upgrades.deployProxy(AddressProvider);

  console.log("Deployed addressProvider");

  console.log("Deployed All Proxies");

  /****************************************************************
  DEPLOY NON-PROXY CONTRACTS
  Deploy contracts that are not updatable
  ******************************************************************/

  // Deploy and initialize trading vault
  const TradingVault = await ethers.getContractFactory("TradingVault");
  tradingVault = await TradingVault.deploy();

  // Deploy liquidity position metadata contracts
  const LiquidityPair721Metadata = await ethers.getContractFactory(
    "LiquidityPair721Metadata"
  );
  liquidityPair721Metadata = await LiquidityPair721Metadata.deploy();
  await liquidityPair721Metadata.deployed();
  const LiquidityPair1155Metadata = await ethers.getContractFactory(
    "LiquidityPair1155Metadata"
  );
  liquidityPair1155Metadata = await LiquidityPair1155Metadata.deploy();
  await liquidityPair1155Metadata.deployed();

  // Deploy Test NFT contracts
  const TestERC721 = await ethers.getContractFactory("TestERC721");
  testERC721 = await TestERC721.deploy("Test 721", "T721");
  await testERC721.deployed();
  const TestERC721_2 = await ethers.getContractFactory("TestERC721");
  testERC721_2 = await TestERC721_2.deploy("Test 721 2", "TNFT721_2");
  await testERC721_2.deployed();
  const TestERC1155 = await ethers.getContractFactory("TestERC1155");
  testERC1155 = await TestERC1155.deploy("Test 1155", "T1155");

  // Deploy price curves contracts
  const ExponentialCurve = await ethers.getContractFactory(
    "ExponentialPriceCurve"
  );
  exponentialCurve = await ExponentialCurve.deploy();
  await exponentialCurve.deployed();
  const LinearCurve = await ethers.getContractFactory("LinearPriceCurve");
  linearCurve = await LinearCurve.deploy();
  await linearCurve.deployed();

  console.log("Deployed Non-Proxies");

  const setLiquidityPair721MetadataTx =
    await addressProvider.setLiquidityPair721Metadata(
      liquidityPair721Metadata.address
    );
  await setLiquidityPair721MetadataTx.wait();
  const setLiquidityPair1155MetadataTx =
    await addressProvider.setLiquidityPair1155Metadata(
      liquidityPair1155Metadata.address
    );
  await setLiquidityPair1155MetadataTx.wait();

  const setWETHTx = await addressProvider.setWETH(weth.address);
  await setWETHTx.wait();

  // Set price curves
  const setExponentialCurveTx = await tradingPoolRegistry.setPriceCurve(
    exponentialCurve.address,
    true
  );
  await setExponentialCurveTx.wait();
  const setLinearCurveTx = await tradingPoolRegistry.setPriceCurve(
    linearCurve.address,
    true
  );
  await setLinearCurveTx.wait();

  console.log("loaded");
};

function loadTest(isMainnetFork) {
  before(() => loadEnv(isMainnetFork));
}

function loadTestAlways(isMainnetFork) {
  beforeEach(() => loadEnv(isMainnetFork));
}

exports.loadTest = loadTest;
exports.loadTestAlways = loadTestAlways;
