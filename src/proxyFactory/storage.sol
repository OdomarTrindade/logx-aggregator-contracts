// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract Storage is Initializable{
    //mapping exchangeID to its implementation address
    mapping(uint256 => address) internal _implementations;
    //mapping proxy addresses to their exchangeIds
    mapping(address => uint256) internal _proxyExchangeIds;
    //mapping proxy IDs to their addresses
    mapping(bytes32 => address) internal _tradingProxies;
    //mapping user address to proxies owned by the user
    mapping(address => address[]) internal _ownedProxies;
    //mapping exchangeID to its implementation address
    mapping(uint256 => address) internal _exchangeLiquidityPool;

    //record weth address
    address internal _weth;

    //address for logX referral manager
    address internal _referralManager;
}