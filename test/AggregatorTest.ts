import assert from "assert/strict";
import { describe, it, before, after } from "node:test";
import { network } from "hardhat";
import { parseEther } from "viem";
const { viem } = await network.connect();

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe("AggregatorTest", function() {

    let aggregator: Awaited<ReturnType<typeof viem.deployContract>>;

    before(async function () {
        aggregator = await viem.deployContract("AggregatorTest");
    });

    it("testChange", async function () {
        const usd1 = await aggregator.read.ethToUsd([1000000000000000000n]);
        console.log("usd1: ", usd1);
    });
});