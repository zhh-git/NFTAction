import assert from "assert/strict";
import { describe, it, before, after } from "node:test";
import { network } from "hardhat";
import { parseEther } from "viem";
const { viem } = await network.connect();
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
describe("NFTAuction", function () {
  // 提前声明类型，避免隐式 any
  let deployer: Awaited<ReturnType<typeof viem.getWalletClients>>[number];
  let seller: Awaited<ReturnType<typeof viem.getWalletClients>>[number];
  let auctioner: Awaited<ReturnType<typeof viem.getWalletClients>>[number];
  let buyer: Awaited<ReturnType<typeof viem.getWalletClients>>[number];
  let nftAuctionProxy: Awaited<ReturnType<typeof viem.getContractAt>>;
  let publicClient: Awaited<ReturnType<typeof viem.getPublicClient>>;
  let proxy: Awaited<ReturnType<typeof viem.deployContract>>;
  let nftContract: Awaited<ReturnType<typeof viem.deployContract>>;

  before(async function () {
    [deployer, auctioner, seller, buyer] = await viem.getWalletClients();
    publicClient = await viem.getPublicClient();
    //1、部署NFT合约
    nftContract = await viem.deployContract("NFTContract", ["zhh", "zhh", "http"], {
      client: { wallet: deployer },
    });
    //2、部署逻辑合约
    const ntfAuction = await viem.deployContract("NFTAuction", undefined, {
      client: { wallet: deployer },
    });
    //3、部署代理合约
    proxy = await viem.deployContract(
      "MyERC1967Proxy",
      [ntfAuction.address, "0x"],
      {
        client: { wallet: deployer },
      }
    );
    console.log("proxy:", proxy.address);
    console.log("implementation:", ntfAuction.address);
    //4、关联代理合约与逻辑合约
    nftAuctionProxy = await viem.getContractAt("NFTAuction", proxy.address);
  });

  it(async function () {
    console.log("deployer Address:", deployer.account.address);
    console.log("seller Address:", seller.account.address); auctioner
    console.log("buyer Address:", buyer.account.address);
    console.log("auctioner Address:", auctioner.account.address);
    //使用NFT合约创建代币 给卖家创建NFT
    const mintTxHash = await nftContract.write.mintNFT([seller.account.address], {
      account: seller.account,
    });

    // 等待交易确认（关键：确保铸造交易上链生效）
    await publicClient.waitForTransactionReceipt({ hash: mintTxHash });

    const nftOwner = await nftContract.read.ownerOf([1n]);
    console.log("NFT Owner of tokenId 1:", nftOwner);

    //使用代理合约
    const platformFeeRecipient = deployer.account.address; //让发布合约的收取手续费
    const platformFeePercentage = 100n; // 100 basis points = 1%
    await nftAuctionProxy.write.initialize(
      [platformFeeRecipient, platformFeePercentage],
      { account: seller.account }
    );

    //卖家 去创建ETH tokenId = 1 的拍卖  会将tokenId=1的这个币转给拍卖合约     

    //遇到问题在创建拍卖的时候 在转账那部判断权限的时候使用的是proxy的合约地址，导致失败，这是什么原因
    //回答：因为卖家调用了拍卖合约中的方法，在代理拍卖合约中调用转账的操作是代理拍卖合约去调用，需要授权NFT给拍卖代理合约

    await nftContract.write.approve(
      [proxy.address, 1n],
      { account: seller.account }
    );


    await nftAuctionProxy.write.createAuction(
      [450n, parseEther("1"), nftContract.address, 1n, ZERO_ADDRESS],
      { account: seller.account }
    );

    //买家ETH 参与竞拍
    await nftAuctionProxy.write.placeBid([parseEther("2"), 0n, ZERO_ADDRESS], {
      account: buyer.account,
      value: parseEther("2"),
    });

    //拍卖结束
    //增加时间 让拍卖结束
    await (publicClient as any).request({ method: "evm_increaseTime", params: [500] });
    //拍卖者结束拍卖
    await nftAuctionProxy.write.endAuction([0n, nftContract.address], {
      account: auctioner.account,
    });

    //断言 买家是tokenId=1的拥有者
    const owner = await nftContract.read.ownerOf([1n]);
    assert.equal(owner, buyer.account.address);


  });
});
