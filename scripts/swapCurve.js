const { ethers, network } = require("hardhat");

const { networkConfig } = require("../helper-hardhat-config");

async function main() {
  const chainId = network.config.chainId;

  const swapFactoryAddress = networkConfig[chainId]["curveFactoryPool"];

  const swapFactory = await ethers.getContractAt(
    "IFactory",
    swapFactoryAddress
  );

  const dy = await swapFactory.callStatic.get_dy(
    0,
    1,
    ethers.utils.parseEther("1")
  );

  console.log(dy);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
