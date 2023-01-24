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
    const [owner, otherAccount, mockManagerContract] =
      await ethers.getSigners();

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

    const Trove = await ethers.getContractFactory("Trove");

    const trove = await Trove.deploy(deviationICR, targetICR);

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

    await trove.setManagerContract(mockManagerContract.address);

    return {
      trove,
      owner,
      otherAccount,
      troveManagerContract,
      mockManagerContract,
    };
  }

  describe("#activateVault", () => {
    it("should succesfully create a new vault on vesta protocol", async () => {
      const { trove, otherAccount, troveManagerContract } = await loadFixture(
        deployVaultFixure
      );

      const depositAmount = ethers.utils.parseEther("1");
      const tx = {
        to: trove.address,
        value: depositAmount,
      };
      await otherAccount.sendTransaction(tx);

      await trove.activateVault();

      const troveDetails = await troveManagerContract.getEntireDebtAndColl(
        ethers.constants.AddressZero,
        trove.address
      );

      assert(troveDetails[1].eq(depositAmount));
    });

    it("should fail if vault is already activated", async () => {
      const { trove, otherAccount } = await loadFixture(deployVaultFixure);

      const depositAmount = ethers.utils.parseEther("1");
      const tx = {
        to: trove.address,
        value: depositAmount,
      };
      await otherAccount.sendTransaction(tx);

      await trove.activateVault();

      await expect(trove.activateVault()).to.revertedWithCustomError(
        trove,
        "Trove__TroveIsActive"
      );
    });

    it("should fail if the vault contract have no balance", async () => {
      const { trove } = await loadFixture(deployVaultFixure);

      await expect(trove.activateVault()).to.revertedWithCustomError(
        trove,
        "Trove__NoEtherBalance"
      );
    });
  });

  describe("#depositETH", () => {
    it("should successfull deposit Ether to the trove and change the trove", async () => {
      const { trove, otherAccount, troveManagerContract } = await loadFixture(
        deployVaultFixure
      );

      const depositAmount = ethers.utils.parseEther("1");
      const tx = {
        to: trove.address,
        value: depositAmount,
      };
      await otherAccount.sendTransaction(tx);

      await trove.activateVault();

      const troveDetailsBefore =
        await troveManagerContract.getEntireDebtAndColl(
          ethers.constants.AddressZero,
          trove.address
        );

      await trove
        .connect(otherAccount)
        .depositETH({ value: ethers.utils.parseEther("10") });

      // account should have 10 cdEther

      const troveDetailsAfter = await troveManagerContract.getEntireDebtAndColl(
        ethers.constants.AddressZero,
        trove.address
      );

      console.log(troveDetailsAfter);

      assert(
        troveDetailsAfter.coll
          .sub(ethers.utils.parseEther("10"))
          .eq(troveDetailsBefore.coll)
      );

      const currentICR = await trove.getCurrentICRVault();

      assert(currentICR.eq(ethers.utils.parseEther("1.2")));
    });

    it("should fail when no ether transfered within transaction", async () => {
      const { trove, otherAccount } = await loadFixture(deployVaultFixure);

      const depositAmount = ethers.utils.parseEther("1");
      const tx = {
        to: trove.address,
        value: depositAmount,
      };
      await otherAccount.sendTransaction(tx);

      await trove.activateVault();

      await expect(
        trove.connect(otherAccount).depositETH()
      ).to.revertedWithCustomError(trove, "Trove__NonZeroAmount");
    });

    it("should fail when the trove is not active", async () => {
      const { trove, otherAccount } = await loadFixture(deployVaultFixure);

      await expect(
        trove
          .connect(otherAccount)
          .depositETH({ value: ethers.utils.parseEther("10") })
      ).to.revertedWithCustomError(trove, "Trove__TroveIsNotActive");
    });
  });
});
