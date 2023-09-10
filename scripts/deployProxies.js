const { ethers } = require("hardhat");

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const hre = require("hardhat");
require("dotenv").config();

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  var contractAddresses = require("../../lenft-interface-v2/contractAddresses.json");
  let chainID = hre.network.config.chainId;
  console.log("chainID: ", chainID.toString());
  var addresses = contractAddresses[chainID.toString()];
  const ONE_DAY = 86400;
  [owner] = await ethers.getSigners();

  /****************************************************************
  DEPLOY LIBRARIES
  They will then be linked to the contracts that use them
  ******************************************************************/

  //Deploy libraries
  VaultValidationLogicLib = await ethers.getContractFactory(
    "VaultValidationLogic"
  );
  vaultValidationLogicLib = await VaultValidationLogicLib.deploy();
  addresses["VaultValidationLogic"] = vaultValidationLogicLib.address;
  VaultGeneralLogicLib = await ethers.getContractFactory("VaultGeneralLogic");
  vaultGeneralLogicLib = await VaultGeneralLogicLib.deploy();
  addresses["VaultGeneralLogic"] = vaultGeneralLogicLib.address;

  console.log("Deployed Libraries");

  /****************************************************************
  DEPLOY PROXIES
  They will serve as an entry point for the upgraded contracts
  ******************************************************************/

  // Deploy and initialize addresses provider proxy
  const AddressProvider = await ethers.getContractFactory("AddressProvider");
  addressProvider = await upgrades.deployProxy(AddressProvider);
  addresses["AddressProvider"] = addressProvider.address;

  console.log("Deployed addressProvider");

  // Deploy and initialize trading vault proxy
  const Vault = await ethers.getContractFactory("Vault", {
    libraries: {
      VaultValidationLogic: vaultValidationLogicLib.address,
      VaultGeneralLogic: vaultGeneralLogicLib.address,
    },
  });
  vault = await upgrades.deployProxy(Vault, [addressProvider.address], {
    unsafeAllow: ["external-library-linking", "state-variable-immutable"],
    timeout: 0,
    constructorArgs: [addressProvider.address],
  });
  addresses["Vault"] = vault.address;

  // Deploy and initialize Fee distributor
  const FeeDistributor = await ethers.getContractFactory("FeeDistributor");
  feeDistributor = await upgrades.deployProxy(FeeDistributor, [], {
    unsafeAllow: ["state-variable-immutable"],
    constructorArgs: [addressProvider.address],
  });
  addresses["FeeDistributor"] = feeDistributor.address;

  console.log("Deployed FeeDistributor");

  console.log("Deployed All Proxies");

  /****************************************************************
  DEPLOY NON-PROXY CONTRACTS
  Deploy contracts that are not updatable
  ******************************************************************/

  // Deploy liquidity position metadata contracts
  const LiquidityPair721Metadata = await ethers.getContractFactory(
    "LiquidityPair721Metadata"
  );
  liquidityPair721Metadata = await LiquidityPair721Metadata.deploy(
    addressProvider.address
  );
  await liquidityPair721Metadata.deployed();
  addresses["LiquidityPair721Metadata"] = liquidityPair721Metadata.address;
  const LiquidityPair1155Metadata = await ethers.getContractFactory(
    "LiquidityPair1155Metadata"
  );
  liquidityPair1155Metadata = await LiquidityPair1155Metadata.deploy(
    addressProvider.address
  );
  await liquidityPair1155Metadata.deployed();
  addresses["LiquidityPair1155Metadata"] = liquidityPair1155Metadata.address;
  const SwapLiquidityMetadata = await ethers.getContractFactory(
    "SwapLiquidityMetadata"
  );
  swapLiquidityMetadata = await SwapLiquidityMetadata.deploy(
    addressProvider.address
  );
  addresses["SwapLiquidityMetadata"] = swapLiquidityMetadata.address;

  const ExponentialCurve = await ethers.getContractFactory(
    "ExponentialPriceCurve"
  );
  exponentialCurve = await ExponentialCurve.deploy();
  await exponentialCurve.deployed();
  addresses["ExponentialPriceCurve"] = exponentialCurve.address;
  const LinearCurve = await ethers.getContractFactory("LinearPriceCurve");
  linearCurve = await LinearCurve.deploy();
  await linearCurve.deployed();
  addresses["LinearPriceCurve"] = linearCurve.address;

  /****************************************************************
  SAVE TO DISK
  Write contract addresses to file
  ******************************************************************/

  var fs = require("fs");
  contractAddresses[chainID.toString()] = addresses;
  console.log("contractAddresses: ", contractAddresses);
  fs.writeFileSync(
    "../lenft-interface-v2/contractAddresses.json",
    JSON.stringify(contractAddresses),
    function (err) {
      if (err) throw err;
      console.log("File written to interface folder");
    }
  );

  /****************************************************************
  SETUP TRANSACTIONS
  Broadcast transactions whose purpose is to setup the protocol for use
  ******************************************************************/

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
  const setSwapLiquidityMetadataTx =
    await addressProvider.setSwapLiquidityMetadata(
      swapLiquidityMetadata.address
    );
  await setSwapLiquidityMetadataTx.wait();
  const setFeeDistributorTx = await addressProvider.setFeeDistributor(
    feeDistributor.address
  );
  await setFeeDistributorTx.wait();

  const setVotingEscrowTx = await addressProvider.setVotingEscrow(
    "0x2D826fE97FbCd08bAC45eBA8A77707f62b1D24b9"
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
