import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NFTAuctionMoudles", (m) => {
  const deployer = m.getAccount(0);

  const platformFeeRecipient = m.getAccount(1); //部署通过配置获取，如果正式网上应该如何配置，也是前期要求在配置文件中提前配置好吗

  //1、部署逻辑合约
  const nftImplementation = m.contract("NFTAuction", [], {id: "nftImplementation", from: deployer });

  //2、编码初始化函数调用数据
  //如果你的initialize函数有参数需要传递参数
  const initialzeData = m.encodeFunctionCall(nftImplementation, "initialize", [
    platformFeeRecipient,
    100,
  ]);

  //3、部署代理合约，MyERC1967Proxy
  const proxy = m.contract("MyERC1967Proxy", [
    nftImplementation, //实现合约
    initialzeData, //初始化数据
  ], {id: "proxy"});

  //4、将代理合约连接到NFTAuction接口，方便后续调用
  const nftAuctionProxy = m.contractAt("NFTAuction", proxy, {id: "nftAuctionProxy"});

  //通过代理合约去调用
  m.call(
    nftAuctionProxy, // 第1个参数：要调用的合约实例
    "owner", // 第2个参数：要调用的合约方法名（字符串）
    [], // 第3个参数：调用方法时传入的参数（无参数则传空数组）
    {
      // 第4个参数：调用配置项
      from: deployer, // 调用这个方法的账户（部署者）
    }
  );

  return {
    nftAuction: proxy, //应该导出 proxy 还是关联后的nftAuctionProxy
  };
}); //目前该部署脚本部署失败
