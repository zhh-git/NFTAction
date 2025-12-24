// contracts/Proxies.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入 OpenZeppelin 的 ERC1967Proxy
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// 重新导出（仅用于让 Hardhat 编译该合约，无需修改逻辑）
contract MyERC1967Proxy is ERC1967Proxy {
    // 复用父类构造函数
    constructor(address implementation, bytes memory data) 
        ERC1967Proxy(implementation, data) 
    {}
}