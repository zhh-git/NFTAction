import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NFTContractMoudles", (m) => {
  const deployer = m.getAccount(0);

  const nftContract = m.contract(
    "NFTContract",
    ["zhhNFT", "zhhNFT", "https://violet-tiny-marmot-772.mypinata.cloud/ipfs/"],
    { from: deployer }
  );

  m.call(
    nftContract, // 第1个参数：要调用的合约实例
    "owner", // 第2个参数：要调用的合约方法名（字符串）
    [], // 第3个参数：调用方法时传入的参数（无参数则传空数组）
    {
      // 第4个参数：调用配置项
      from: deployer, // 调用这个方法的账户（部署者）
    }
  );
  return {
    nftContract,
  };
});
