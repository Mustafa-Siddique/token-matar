import { expect } from "chai";
import { ethers } from "hardhat";

describe("MATAR", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("MATAR");

    const initialOwner = (await ethers.getSigners())[0].address;

    const instance = await ContractFactory.deploy(initialOwner);
    await instance.waitForDeployment();

    expect(await instance.name()).to.equal("MATAR");
  });
});
