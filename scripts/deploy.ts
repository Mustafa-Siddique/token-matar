import { ethers } from "hardhat";

async function main() {
  const ContractFactory = await ethers.getContractFactory("MATAR");

  // TODO: Set addresses for the contract arguments below
  const initialOwner = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4";
  const instance = await ContractFactory.deploy(initialOwner);
  await instance.waitForDeployment();

  console.log(`Contract deployed to ${await instance.getAddress()}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
