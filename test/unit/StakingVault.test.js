const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

describe("StakingVault Unit Test", () => {
  const chainId = network.config.chainId;
  /**
   * Vesta Protocol Addresses
   */
  const troveManager = networkConfig[chainId]["troveManager"];
  const vestaParams = networkConfig[chainId]["vestaParams"];
  const borrowerOperations = networkConfig[chainId]["borrowerOperations"];
  const priceFeed = networkConfig[chainId]["priceFeed"];
  const sortedTroves = networkConfig[chainId]["sortedTroves"];
  const VSTStable = networkConfig[chainId]["VSTStable"];

  /**
   * Setup Parameters
   */
  const targetICR = ethers.utils.parseEther("1.2");
  const permittedSwing = ethers.utils.parseEther("0.05");

  async function deployStakingVaultFixture() {
    const [owner, otherAccount, yieldVaultMock] = await ethers.getSigners();

    //For testing deploy MockHintelper Contract
    const HintHelpers = await ethers.getContractFactory("HintHelpers");
    const hintHelpers = await HintHelpers.deploy(troveManager, sortedTroves);

    // Deploy the StakingVault Contract
    const StakingVault = await ethers.getContractFactory("StakingVault");

    const stakingVault = await StakingVault.deploy(
      ethers.constants.AddressZero,
      yieldVaultMock.address,
      targetICR,
      permittedSwing
    );

    return { stakingVault, owner, otherAccount, hintHelpers };
  }

  async function initializeVestaFinanceAddresses(
    stakingVault,
    hintHelpersAddress
  ) {
    await stakingVault.initializeVSTAddresses(
      hintHelpersAddress,
      borrowerOperations,
      vestaParams,
      troveManager,
      priceFeed,
      sortedTroves
    );
  }

  describe("#initializeVSTAddresses", () => {
    it("should succesful initialize all addresses", async () => {
      const { stakingVault } = await loadFixture(deployStakingVaultFixture);
    });
  });
});
