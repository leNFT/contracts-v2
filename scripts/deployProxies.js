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
    constructorArgs: [addressProvider.address, addresses.ETH.address],
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
  const Liquidity721Metadata = await ethers.getContractFactory(
    "Liquidity721Metadata"
  );
  liquidity721Metadata = await Liquidity721Metadata.deploy(
    addressProvider.address
  );
  await liquidity721Metadata.deployed();
  addresses["Liquidity721Metadata"] = liquidity721Metadata.address;
  const Liquidity1155Metadata = await ethers.getContractFactory(
    "Liquidity1155Metadata"
  );
  liquidity1155Metadata = await Liquidity1155Metadata.deploy(
    addressProvider.address
  );
  await liquidity1155Metadata.deployed();
  addresses["Liquidity1155Metadata"] = liquidity1155Metadata.address;

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

  console.log("Deployed Non-Proxy Contracts");

  /****************************************************************
  DEPLOY TEST CONTRACTS
  Deploy contracts that are used or testing
  ******************************************************************/
  // if (chainID != 1) {
  //   console.log("Deploying Test Contracts");
  //   // Deploy Test NFT contracts
  //   const TestERC721 = await ethers.getContractFactory("TestERC721");
  //   blueTestERC721 = await TestERC721.deploy(
  //     "Blue Test 721",
  //     "BT721",
  //     "https://upload.wikimedia.org/wikipedia/commons/f/fd/000080_Navy_Blue_Square.svg"
  //   );
  //   await blueTestERC721.deployed();
  //   addresses["Test"]["Blue721"] = blueTestERC721.address;
  //   redTestERC721 = await TestERC721.deploy(
  //     "Red Test 721",
  //     "RT721",
  //     "https://upload.wikimedia.org/wikipedia/commons/6/62/Solid_red.svg"
  //   );
  //   await redTestERC721.deployed();
  //   addresses["Test"]["Red721"] = redTestERC721.address;
  //   greenTestERC721 = await TestERC721.deploy(
  //     "Green Test 721",
  //     "GT721",
  //     "https://upload.wikimedia.org/wikipedia/commons/2/29/Solid_green.svg"
  //   );
  //   await greenTestERC721.deployed();
  //   addresses["Test"]["Green721"] = greenTestERC721.address;
  //   const TestERC1155 = await ethers.getContractFactory("TestERC1155");
  //   blueTestERC1155 = await TestERC1155.deploy(
  //     "Blue Test 1155",
  //     "BT1155",
  //     "https://upload.wikimedia.org/wikipedia/commons/f/fd/000080_Navy_Blue_Square.svg"
  //   );
  //   await blueTestERC1155.deployed();
  //   addresses["Test"]["Blue1155"] = blueTestERC1155.address;

  //   console.log("Deployed Test Contracts");
  // }

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

  console.log("Setting up protocol");

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

  console.log("Protocol setup complete");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
