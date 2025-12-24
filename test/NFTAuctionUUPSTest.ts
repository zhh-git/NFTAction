import assert from "assert/strict";
import { describe, it, before, after } from "node:test";
import { network } from "hardhat";

const { viem } = await network.connect();

describe("NFTAuction", function () {
  let deployer: Awaited<ReturnType<typeof viem.getWalletClients>>[number];
  // 提前声明类型，避免隐式 any
  let nftAuctionProxy: Awaited<ReturnType<typeof viem.getContractAt>>;
  let publicClient: Awaited<ReturnType<typeof viem.getPublicClient>>;
  let proxy: Awaited<ReturnType<typeof viem.deployContract>>;

  before(async function () {
    [deployer] = await viem.getWalletClients();
    publicClient = await viem.getPublicClient();
    const implV1 = await viem.deployContract("NFTAuction", undefined, {
      client: { wallet: deployer },
    });
    //通过MyERC1967Proxy部署代理
    proxy = await viem.deployContract(
      "MyERC1967Proxy",
      [implV1.address, "0x"],
      { client: { wallet: deployer } }
    );
    console.log("Before upgrade - proxy:", proxy.address);
    console.log("Before upgrade - implementation:", implV1.address);

    // 将代理合约关联到NFTAuction接口
    nftAuctionProxy = await viem.getContractAt("NFTAuction", proxy.address);
  });

  it("success", async function () {
    // 定义初始化参数
    const platformFeeRecipient = deployer.account.address;
    const platformFeePercentage = 100n; // 100 basis points = 1%
    try {
      const hash = await nftAuctionProxy.write.initialize(
        [platformFeeRecipient, platformFeePercentage],
        {
          account: deployer.account, // 显式指定调用账户
        }
      );
      // 等待交易确认
      await publicClient.waitForTransactionReceipt({ hash });
      const admin = (await nftAuctionProxy.read.admin()) as `0x${string}`;
      assert.strictEqual(admin.toLowerCase(), deployer.account.address.toLowerCase());
      const recipient =
        (await nftAuctionProxy.read.platformFeeRecipient()) as `0x${string}`;
      const percentage =
        (await nftAuctionProxy.read.platformFeePercentage()) as bigint;
      console.log("recipient：", recipient);
      console.log("percentage：", percentage);
    } catch (error) {
      console.error("Initialization failed:", error);
      throw error;
    }
  });

  after(async function () {
    const implV2 = await viem.deployContract("NFTAuctionV2", undefined, {
      client: { wallet: deployer },
    });
    console.log("after upgrade - implementation:", implV2.address);
    await nftAuctionProxy.write.upgradeToAndCall([implV2.address, "0x"], {
      account: deployer.account,
    });
    const nftAuctionV2AtProxy = await viem.getContractAt("NFTAuctionV2", proxy.address);
    await nftAuctionV2AtProxy.write.setTestParam([10n]);
    const testparam = await nftAuctionV2AtProxy.read.testParam();
    console.log("testParam: ", testparam);
  });
});
