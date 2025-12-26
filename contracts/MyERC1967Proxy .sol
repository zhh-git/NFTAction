// contracts/Proxies.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
    在部署脚本直接引用ERC1967Proxy会导致部署失败，所以重新继承了这个，原因查资料是说无法直接编译依赖里面的合约
    解决办法：第一个就是当前这个
    第二个是配置文件配置编译依赖中的合约

    那正式环境上应该如何解决这个问题
 */

// 导入 OpenZeppelin 的 ERC1967Proxy
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// 重新导出（仅用于让 Hardhat 编译该合约，无需修改逻辑）
contract MyERC1967Proxy is ERC1967Proxy {
    // 复用父类构造函数
    constructor(address implementation, bytes memory data) 
        ERC1967Proxy(implementation, data) 
    {}
}