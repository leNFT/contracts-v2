const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");
const load = require("../helpers/_loadTest.js");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Vault", function () {
  load.loadTest(true);

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

  it("Should be able to add erc721 liquidity to the vault pool", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const liquidity = await vault.getLiquidity721(0);
    console.log("liquidity", liquidity);

    expect(liquidity.spotPrice.toString()).to.equal(
      ethers.utils.parseEther("0.1").toString()
    );
  });
  it("Should be able to add erc1155 liquidity to the vault pool", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 1);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC1155.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity1155(
      owner.address,
      0,
      testERC1155.address,
      0,
      1,
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const lp = await vault.getLiquidity1155(0);
    console.log("lp", lp);

    expect(lp.spotPrice.toString()).to.equal(
      ethers.utils.parseEther("0.1").toString()
    );
  });

  it("Should be able to buy an erc721 asset", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    console.log("Adding liquidity", testERC721.address);
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    console.log("swapping");

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [],
          tokenIds721: [],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0"),
        },
        buy: {
          liquidityIds: [0],
          liquidity721Indexes: [0],
          liquidity721TokenIds: [0],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("1"),
        },
        swap: {
          liquidityIds: [],
          fromTokenIds721: [],
          bought721Indexes: [],
          toTokenIds721: [],
          toTokenIds721Indexes: [],
        },
      },
      {
        value: ethers.utils.parseEther("0.11"),
      }
    );
    await swapTx.wait();

    console.log("swapped");

    expect(await testERC721.ownerOf(0)).to.equal(owner.address);
  });
  it("Should be able to buy an erc1155 asset", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 1);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC1155.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity1155(
      owner.address,
      0,
      testERC1155.address,
      0,
      1,
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [],
          tokenIds721: [],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0"),
        },
        buy: {
          liquidityIds: [0],
          liquidity721Indexes: [],
          liquidity721TokenIds: [],
          liquidity1155Amounts: [1],
          maximumPrice: ethers.utils.parseEther("1"),
        },
        swap: {
          liquidityIds: [],
          fromTokenIds721: [],
          bought721Indexes: [],
          toTokenIds721: [],
          toTokenIds721Indexes: [],
        },
      },
      {
        value: ethers.utils.parseEther("0.11"),
      }
    );
    await swapTx.wait();

    expect((await testERC1155.balanceOf(owner.address, 0)).toNumber()).to.equal(
      1
    );
  });
  it("Should be able to sell an erc721 asset", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [0],
          tokenIds721: [0],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0.05"),
        },
        buy: {
          liquidityIds: [],
          liquidity721Indexes: [],
          liquidity721TokenIds: [],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0"),
        },
        swap: {
          liquidityIds: [],
          fromTokenIds721: [],
          bought721Indexes: [],
          toTokenIds721: [],
          toTokenIds721Indexes: [],
        },
      },
      {
        value: ethers.utils.parseEther("0.11"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(vault.address);
  });
  it("Should be able to sell an erc1155 asset", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC1155.mint(owner.address, 0, 1);
    await mintTestNFTTx.wait();
    const approveNFTTx = await testERC1155.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity1155(
      owner.address,
      0,
      testERC1155.address,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [0],
          tokenIds721: [],
          tokenAmounts1155: [1],
          minimumPrice: ethers.utils.parseEther("0.05"),
        },
        buy: {
          liquidityIds: [],
          liquidity721Indexes: [],
          liquidity721TokenIds: [],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0"),
        },
        swap: {
          liquidityIds: [],
          fromTokenIds721: [],
          bought721Indexes: [],
          toTokenIds721: [],
          toTokenIds721Indexes: [],
        },
      },
      {
        value: ethers.utils.parseEther("0.11"),
      }
    );
    await swapTx.wait();

    expect((await testERC1155.balanceOf(owner.address, 0)).toNumber()).to.equal(
      0
    );
    expect((await testERC1155.balanceOf(vault.address, 0)).toNumber()).to.equal(
      1
    );
  });
  it("Should be able to swap erc721 for erc721", async function () {
    // Mint two test NFTs
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const mintTestNFTTx2 = await testERC721.mint(owner.address);
    await mintTestNFTTx2.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      ethers.utils.parseEther("0.011"),
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [],
          tokenIds721: [],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0"),
        },
        buy: {
          liquidityIds: [],
          liquidity721Indexes: [],
          liquidity721TokenIds: [],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0"),
        },
        swap: {
          liquidityIds: [0],
          fromTokenIds721: [1],
          bought721Indexes: [],
          toTokenIds721: [0],
          toTokenIds721Indexes: [0],
        },
      },
      {
        value: ethers.utils.parseEther("0.011"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(owner.address);
    expect(await testERC721.ownerOf(1)).to.equal(vault.address);
  });
  it("Should be able to buy an erc721 asset and swap it for another erc721 asset", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const mintTestNFTTx2 = await testERC721.mint(owner.address);
    await mintTestNFTTx2.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    // Add swap liquidity to the vault
    const addLiquidityTx2 = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [1],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.01"),
      exponentialCurve.address,
      100,
      1000,
      ethers.utils.parseEther("0.11"),
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx2.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [],
          tokenIds721: [],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0"),
        },
        buy: {
          liquidityIds: [0],
          liquidity721Indexes: [0],
          liquidity721TokenIds: [0],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0.11"),
        },
        swap: {
          liquidityIds: [1],
          fromTokenIds721: [],
          bought721Indexes: [0],
          toTokenIds721: [1],
          toTokenIds721Indexes: [0],
        },
      },
      {
        value: ethers.utils.parseEther("0.22"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(vault.address);
    expect(await testERC721.ownerOf(1)).to.equal(owner.address);
  });
  it("Should be able to sell an erc721 asset and buy another erc721 asset from different lps", async function () {
    // Mint a test NFT
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const mintTestNFTTx2 = await testERC721.mint(owner.address);
    await mintTestNFTTx2.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    // Add a second liquidity pair to the vault
    const addLiquidityTx2 = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [1],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx2.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [0],
          tokenIds721: [0],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0.05"),
        },
        buy: {
          liquidityIds: [1],
          liquidity721Indexes: [0],
          liquidity721TokenIds: [1],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0.2"),
        },
        swap: {
          liquidityIds: [],
          fromTokenIds721: [],
          bought721Indexes: [],
          toTokenIds721: [],
          toTokenIds721Indexes: [],
        },
      },
      {
        value: ethers.utils.parseEther("0.15"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(vault.address);
    expect(await testERC721.ownerOf(1)).to.equal(owner.address);
  });
  it("Should be able to sell an erc721 asset and swap another erc721 asset", async function () {
    // Mint three test NFTs
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const mintTestNFTTx2 = await testERC721.mint(owner.address);
    await mintTestNFTTx2.wait();
    const mintTestNFTTx3 = await testERC721.mint(owner.address);
    await mintTestNFTTx3.wait();
    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    // Add a second liquidity pair to the vault
    console.log("Adding liquidity", testERC721.address);
    const addLiquidityTx2 = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.01"),
      exponentialCurve.address,
      100,
      1000,
      ethers.utils.parseEther("0.15"),
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx2.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [0],
          tokenIds721: [1],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0.05"),
        },
        buy: {
          liquidityIds: [],
          liquidity721Indexes: [],
          liquidity721TokenIds: [],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0"),
        },
        swap: {
          liquidityIds: [1],
          fromTokenIds721: [2],
          bought721Indexes: [],
          toTokenIds721: [0],
          toTokenIds721Indexes: [0],
        },
      },
      {
        value: ethers.utils.parseEther("0.1"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(owner.address);
    expect(await testERC721.ownerOf(1)).to.equal(vault.address);
    expect(await testERC721.ownerOf(2)).to.equal(vault.address);
  });
  it("Should be able to sell an erc721 asset, buy and erc721 and swap it for another erc721 asset", async function () {
    // Mint four test NFTs
    const mintTestNFTTx = await testERC721.mint(owner.address);
    await mintTestNFTTx.wait();
    const mintTestNFTTx2 = await testERC721.mint(owner.address);
    await mintTestNFTTx2.wait();
    const mintTestNFTTx3 = await testERC721.mint(owner.address);
    await mintTestNFTTx3.wait();
    const mintTestNFTTx4 = await testERC721.mint(owner.address);
    await mintTestNFTTx4.wait();

    const approveNFTTx = await testERC721.setApprovalForAll(
      vault.address,
      true
    );
    await approveNFTTx.wait();

    // Add liquidity to the vault
    const addLiquidityTx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx.wait();

    const addLiquidity2Tx = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [0],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.1"),
      exponentialCurve.address,
      100,
      1000,
      0,
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidity2Tx.wait();

    // Add a second liquidity pair to the vault
    const addLiquidityTx3 = await vault.addLiquidity721(
      owner.address,
      0,
      testERC721.address,
      [1],
      ethers.constants.AddressZero,
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.01"),
      exponentialCurve.address,
      100,
      1000,
      ethers.utils.parseEther("0.15"),
      {
        value: ethers.utils.parseEther("1"),
      }
    );
    await addLiquidityTx3.wait();

    const swapTx = await vault.swap(
      owner.address,
      ethers.constants.AddressZero,
      {
        sell: {
          liquidityIds: [0],
          tokenIds721: [2],
          tokenAmounts1155: [],
          minimumPrice: ethers.utils.parseEther("0.05"),
        },
        buy: {
          liquidityIds: [1],
          liquidity721Indexes: [0],
          liquidity721TokenIds: [0],
          liquidity1155Amounts: [],
          maximumPrice: ethers.utils.parseEther("0.2"),
        },
        swap: {
          liquidityIds: [2],
          fromTokenIds721: [3],
          bought721Indexes: [],
          toTokenIds721: [1],
          toTokenIds721Indexes: [0],
        },
      },
      {
        value: ethers.utils.parseEther("0.3"),
      }
    );
    await swapTx.wait();

    expect(await testERC721.ownerOf(0)).to.equal(owner.address);
    expect(await testERC721.ownerOf(1)).to.equal(owner.address);
    expect(await testERC721.ownerOf(2)).to.equal(vault.address);
    expect(await testERC721.ownerOf(3)).to.equal(vault.address);
  });
});
