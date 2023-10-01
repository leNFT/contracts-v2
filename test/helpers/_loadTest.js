const { ethers } = require("hardhat");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
require("dotenv").config();

let loadEnv = async function (isMainnetFork) {
  //Reset the fork if it's genesis
  console.log("isMainnetFork", isMainnetFork);
  if (isMainnetFork) {
    console.log("Resetting the mainnet fork...");
    await helpers.reset(
      "https://mainnet.infura.io/v3/" + process.env.INFURA_API_KEY,
      18085987
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

  //Deploy libraries
  VaultValidationLogicLib = await ethers.getContractFactory(
    "VaultValidationLogic"
  );
  vaultValidationLogicLib = await VaultValidationLogicLib.deploy();
  VaultGeneralLogicLib = await ethers.getContractFactory("VaultGeneralLogic");
  vaultGeneralLogicLib = await VaultGeneralLogicLib.deploy();

  /****************************************************************
  DEPLOY PROXIES
  They will serve as an entry point for the upgraded contracts
  ******************************************************************/

  // Deploy and initialize addresses provider proxy
  const AddressProvider = await ethers.getContractFactory("AddressProvider");
  addressProvider = await upgrades.deployProxy(AddressProvider);

  console.log("Deployed addressProvider");

  // Deploy and initialize trading vault proxy
  const Vault = await ethers.getContractFactory("Vault", {
    libraries: {
      VaultValidationLogic: vaultValidationLogicLib.address,
      VaultGeneralLogic: vaultGeneralLogicLib.address,
    },
  });
  console.log("Deploying vault");
  console.log("addressProvider.address", addressProvider.address);
  console.log("wethAddress", wethAddress);
  vault = await upgrades.deployProxy(Vault, [addressProvider.address], {
    unsafeAllow: ["external-library-linking", "state-variable-immutable"],
    timeout: 0,
    constructorArgs: [addressProvider.address, wethAddress],
  });

  console.log("Deployed vault");
  // Deploy and initialize Fee distributor
  const FeeDistributor = await ethers.getContractFactory("FeeDistributor");
  feeDistributor = await upgrades.deployProxy(FeeDistributor, [], {
    unsafeAllow: ["state-variable-immutable"],
    constructorArgs: [addressProvider.address],
  });

  console.log("Deployed FeeDistributor");

  console.log("Deployed All Proxies");

  /****************************************************************
  DEPLOY NON-PROXY CONTRACTS
  Deploy contracts that are not updatable
  ******************************************************************/

  // Deploy liquidity position metadata contracts
  const Liquidity721Metadata = await ethers.getContractFactory(
    "Liquidity721Metadata"
  );
  liquidity721Metadata = await Liquidity721Metadata.deploy(
    addressProvider.address
  );
  await liquidity721Metadata.deployed();
  const Liquidity1155Metadata = await ethers.getContractFactory(
    "Liquidity1155Metadata"
  );
  liquidity1155Metadata = await Liquidity1155Metadata.deploy(
    addressProvider.address
  );
  await liquidity1155Metadata.deployed();

  console.log("Deployed LiquidityMetadata");

  // Deploy Test NFT contracts
  const TestERC721 = await ethers.getContractFactory("TestERC721");
  testERC721 = await TestERC721.deploy("Test 721", "T721", "");
  await testERC721.deployed();
  const TestERC721_2 = await ethers.getContractFactory("TestERC721");
  testERC721_2 = await TestERC721_2.deploy("Test 721 2", "TNFT721_2", "");
  await testERC721_2.deployed();
  const TestERC1155 = await ethers.getContractFactory("TestERC1155");
  testERC1155 = await TestERC1155.deploy("Test 1155", "T1155", "");

  console.log("Deployed Test NFTs");

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

  const setLiquidity721MetadataTx =
    await addressProvider.setLiquidity721Metadata(liquidity721Metadata.address);
  await setLiquidity721MetadataTx.wait();
  const setLiquidity1155MetadataTx =
    await addressProvider.setLiquidity1155Metadata(
      liquidity1155Metadata.address
    );
  await setLiquidity1155MetadataTx.wait();

  const setFeeDistributorTx = await addressProvider.setFeeDistributor(
    feeDistributor.address
  );
  await setFeeDistributorTx.wait();

  const setVotingEscrowTx = await addressProvider.setVotingEscrow(
    "0x3c5ebA0872ABcA4D6BD5ecADada8Bc5f12cD4c76"
  );
  await setVotingEscrowTx.wait();

  // Set price curves
  const setExponentialCurveTx = await vault.setPriceCurve(
    exponentialCurve.address,
    true
  );
  await setExponentialCurveTx.wait();
  const setLinearCurveTx = await vault.setPriceCurve(linearCurve.address, true);
  await setLinearCurveTx.wait();

  const setProtocolFeePercentageTx = await vault.setProtocolFeePercentage(1000);
  await setProtocolFeePercentageTx.wait();

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
