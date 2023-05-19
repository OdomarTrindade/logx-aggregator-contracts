// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";

import "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IAggregator.sol";

import "./Storage.sol";
import "./ProxyBeacon.sol";
import "./ProxyConfig.sol";

contract ProxyFactory is Storage, ProxyBeacon, ProxyConfig, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct OpenPositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        address tokenIn;
        uint256 amountIn; // tokenIn.decimals
        uint256 minOut; // collateral.decimals
        uint256 borrow; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    struct ClosePositionArgs {
        uint256 exchangeId;
        address collateralToken;
        address assetToken;
        bool isLong;
        uint256 collateralUsd; // collateral.decimals
        uint256 sizeUsd; // 1e18
        uint96 priceUsd; // 1e18
        uint8 flags; // MARKET, TRIGGER
        bytes32 referralCode;
    }

    event SetReferralCode(bytes32 referralCode);

    function initialize(address weth_) external initializer {
        __Ownable_init();
        _weth = weth_;
    }

    function weth() external view returns (address) {
        return _weth;
    }

    // ======================== methods for contract management ========================
    function upgradeTo(uint256 exchangeId, address newImplementation_) external onlyOwner {
        _upgradeTo(exchangeId, newImplementation_);
    }

    function getImplementationAddress(uint256 exchangeId) external view returns(address){
        return _implementations[exchangeId];
    }

    function setExchangeLiquidityPool(uint256 exchangeId, address liquidityPool) external onlyOwner{
        _setExchangeLiquidityPool(exchangeId, liquidityPool);
    }

    function getExchangeLiquidityPool(uint256 exchangeId) external view returns(address){
        return _getExchangeLiquidityPool(exchangeId);
    }

    function getProxyExchangeId(address proxy) external view returns(uint256){
        return _proxyExchangeIds[proxy];
    }

    function getTradingProxy(bytes32 proxyId) external view returns(address){
        return _tradingProxies[proxyId];
    }

    // ======================== methods called by user ========================
    function createProxy(
        uint256 exchangeId,
        address collateralToken,
        address assetToken,
        bool isLong
    ) public returns (address) {
        //ToDo - verify collateral and asset IDs before we create a proxy
        address _liquidityPool = _getExchangeLiquidityPool(exchangeId);
        return
            _createBeaconProxy(
                exchangeId,
                _liquidityPool,
                msg.sender,
                assetToken,
                collateralToken,
                isLong
            );
    }

    function openPosition(OpenPositionArgs calldata args) external payable {
        bytes32 proxyId = _makeProxyId(args.exchangeId, msg.sender, args.collateralToken, args.assetToken, args.isLong);
        address proxy = _tradingProxies[proxyId];
        if (proxy == address(0)) {
            proxy = createProxy(args.exchangeId, args.collateralToken, args.assetToken, args.isLong);
        }
        if (args.tokenIn != _weth) {
            IERC20Upgradeable(args.tokenIn).safeTransferFrom(msg.sender, proxy, args.amountIn);
        } else {
            require(msg.value >= args.amountIn, "InsufficientAmountIn");
        }

        IAggregator(proxy).openPosition{ value: msg.value }(
            args.tokenIn,
            args.amountIn,
            args.minOut,
            args.borrow,
            args.sizeUsd,
            args.priceUsd,
            args.flags,
            args.referralCode
        );
    }

    function closePosition(ClosePositionArgs calldata args) external payable {
        address proxy = _mustGetProxy(args.exchangeId, msg.sender, args.collateralToken, args.assetToken, args.isLong);

        IAggregator(proxy).closePosition{ value: msg.value }(
            args.collateralUsd,
            args.sizeUsd,
            args.priceUsd,
            args.flags,
            args.referralCode
        );
    }

    function cancelOrders(
        uint256 exchangeId,
        address collateralToken,
        address assetToken,
        bool isLong,
        bytes32[] calldata keys
    ) external {
        IAggregator(_mustGetProxy(exchangeId, msg.sender, collateralToken, assetToken, isLong)).cancelOrders(keys);
    }

    // ======================== Utility methods ========================
    function _mustGetProxy(
        uint256 exchangeId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) internal view returns (address proxy) {
        bytes32 proxyId = _makeProxyId(exchangeId, account, collateralToken, assetToken, isLong);
        proxy = _tradingProxies[proxyId];
        require(proxy != address(0), "ProxyNotExist");
    }
}