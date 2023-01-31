const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

desscribe("CalidaManager Unit Test", () => {
  async function deployCalidaManagerFixture() {
    const [owner, otherAccount] = await ethers.getSigners();

    const chainId = network.config.chainId;
  }
});
