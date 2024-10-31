pragma solidity ^0.8.26;

interface IBalancerV2WeightedPool {
    function getVault() external view returns (address);

    function getInvariant() external view returns (uint256);

    function getNormalizedWeights() external view returns (uint256[] memory);

    function getPoolId() external view returns (bytes32);

    function totalSupply() external view returns (uint256);

    function getActualSupply() external view returns (uint256);
}