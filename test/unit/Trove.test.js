const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

describe("Trove Unit test", () => {
  async function deployVaultFixure() {
    const [owner, otherAccount] = await ethers.getSigners();

    const chainId = network.config.chainId;

    const troveManager = networkConfig[chainId]["troveManager"];

    const vestaParams = networkConfig[chainId]["vestaParams"];
    const borrowerOperations = networkConfig[chainId]["borrowerOperations"];
    const priceFeed = networkConfig[chainId]["priceFeed"];
    const sortedTroves = networkConfig[chainId]["sortedTroves"];
    const VSTStable = networkConfig[chainId]["VSTStable"];

    const targetICR = ethers.utils.parseEther("1.2");
    const deviationICR = ethers.utils.parseEther("0.1");

    const HintHelpers = await ethers.getContractFactory("HintHelpers");
    const hintHelpers = await HintHelpers.deploy(troveManager, sortedTroves);

    const CalidoEther = await ethers.getContractFactory("CalidoEther");
    const cdEther = await CalidoEther.deploy();

    const Trove = await ethers.getContractFactory("Trove");

    const trove = await Trove.deploy(deviationICR, targetICR, cdEther.address);

    await cdEther.transferOwnership(trove.address);

    await trove.setVestaProtocolAddresses(
      troveManager,
      hintHelpers.address,
      vestaParams,
      borrowerOperations,
      priceFeed,
      sortedTroves,
      VSTStable
    );

    //Get Vesta Contracts for testing
    const troveManagerContract = await ethers.getContractAt(
      "ITroveManager",
      troveManager
    );

    return { trove, owner, otherAccount, troveManagerContract, cdEther };
  }

  describe("#depositETH", () => {
    it("should successfull deposit Ether to the trove", async () => {
      const { trove, otherAccount, cdEther } = await loadFixture(
        deployVaultFixure
      );

      await trove
        .connect(otherAccount)
        .depositETH({ value: ethers.utils.parseEther("10") });

      // account should have 10 cdEther

      const _balance = await cdEther.balanceOf(otherAccount.address);

      assert(_balance.eq(ethers.utils.parseEther("10")));
    });
  });

  describe("#addCollateral", () => {
    it("should open a new trove if no trove is active", async () => {
      const { trove, otherAccount, troveManagerContract } = await loadFixture(
        deployVaultFixure
      );

      const tx = {
        to: trove.address,
        value: ethers.utils.parseEther("1"),
      };

      await otherAccount.sendTransaction(tx);

      await trove.addCollateral(ethers.utils.parseEther("1.0"));

      const troveStatus = await troveManagerContract.getTroveStatus(
        ethers.constants.AddressZero,
        trove.address
      );

      assert(troveStatus.eq(1));

      const currentICR = await trove.getCurrentICRVault();

      assert(currentICR.eq(ethers.utils.parseEther("1.2")));
    });

    it("should adjust the ICR on an active trove", async () => {
      const { trove, otherAccount, troveManagerContract } = await loadFixture(
        deployVaultFixure
      );

      const tx = {
        to: trove.address,
        value: ethers.utils.parseEther("1"),
      };

      await otherAccount.sendTransaction(tx);

      await trove.addCollateral(ethers.utils.parseEther("0.5"));

      await trove.addCollateral(ethers.utils.parseEther("0.2"));

      const troveInfo = await troveManagerContract.getEntireDebtAndColl(
        ethers.constants.AddressZero,
        trove.address
      );

      assert(troveInfo.coll.eq(ethers.utils.parseEther("0.7")));
    });
  });
});
