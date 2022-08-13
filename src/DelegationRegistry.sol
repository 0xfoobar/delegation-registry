// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/** 
* @title An immutable registry contract to be deployed as a standalone primitive
* @author foobar
* @dev New project launches can read previous cold wallet -> hot wallet delegations from here and integrate those permissions into their flow
*/

contract DelegationRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The global mapping and single source of truth for delegations
    mapping(bytes32 => bool) public delegations;  

    /// @notice A secondary mapping to return onchain enumerability of wallet-level delegations
    mapping(address => EnumerableSet.AddressSet) internal delegationsForAll;

    /// @notice A secondary mapping to return onchain enumerability of contract-level delegations
    mapping(address => mapping(address => EnumerableSet.AddressSet)) internal delegationsForContract;

    /// @notice A secondary mapping to return onchain enumerability of token-level delegations
    mapping(address => mapping(address => mapping(uint256 => EnumerableSet.AddressSet))) internal delegationsForToken;

    /// @notice Emitted when a user delegates their entire wallet
    event DelegateForAll(address vault, address delegate, bool value);
    
    /// @notice Emitted when a user delegates a specific contract
    event DelegateForContract(address vault, address delegate, address contract_, bool value);

    /// @notice Emitted when a user delegates a specific token
    event DelegateForToken(address vault, address delegate, address contract_, uint256 tokenId, bool value);

    /** -----------  WRITE ----------- */

    /** 
    * @notice Allow the delegate to act on your behalf for all NFT contracts
    * @param delegate The hotwallet to act on your behalf
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForAll(address delegate, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender));
        delegations[delegateHash] = value;
        _setDelegationEnumeration(delegationsForAll[msg.sender], delegate, value);
        emit DelegateForAll(msg.sender, delegate, value);
    }

    /** 
    * @notice Allow the delegate to act on your behalf for a specific NFT contract
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForContract(address delegate, address contract_, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_));
        delegations[delegateHash] = value;
        _setDelegationEnumeration(delegationsForContract[msg.sender][contract_], delegate, value);
        emit DelegateForContract(msg.sender, delegate, contract_, value);
    }

    /** 
    * @notice Allow the delegate to act on your behalf for a specific token, supports 721 and 1155
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param tokenId The token id for the token you're delegating
    * @param value Whether to enable or disable delegation for this address, true for setting and false for revoking
    */
    function delegateForToken(address delegate, address contract_, uint256 tokenId, bool value) external {
        bytes32 delegateHash = keccak256(abi.encode(delegate, msg.sender, contract_, tokenId));
        delegations[delegateHash] = value;
        _setDelegationEnumeration(delegationsForToken[msg.sender][contract_][tokenId], delegate, value);
        emit DelegateForToken(msg.sender, delegate, contract_, tokenId, value);
    }

    function _setDelegationEnumeration(EnumerableSet.AddressSet storage set, address key, bool value) internal {
        if (value) {
            set.add(key);
        } else {
            set.remove(key);
        }
    }

    /** -----------  READ ----------- */

    /**
    * @notice Returns an array of wallet-level delegations for a given vault
    * @param vault The cold wallet who issued the delegation
    * @return addresses Array of wallet-level delegations for a given vault
    */
    function getDelegationsForAll(address vault) external view returns (address[] memory) {
        return delegationsForAll[vault].values();
    }

    /**
    * @notice Returns an array of contract-level delegations for a given vault and contract
    * @param vault The cold wallet who issued the delegation
    * @param contract_ The address for the contract you're delegating
    * @return addresses Array of contract-level delegations for a given vault and contract
    */
    function getDelegationsForContract(address vault, address contract_) external view returns (address[] memory) {
        return delegationsForContract[vault][contract_].values();
    }

    /**
    * @notice Returns an array of contract-level delegations for a given vault's token
    * @param vault The cold wallet who issued the delegation
    * @param contract_ The address for the contract holding the token
    * @param tokenId The token id for the token you're delegating
    * @return addresses Array of contract-level delegations for a given vault's token
    */
    function getDelegationsForToken(address vault, address contract_, uint256 tokenId) external view returns (address[] memory) {
        return delegationsForToken[vault][contract_][tokenId].values();
    }

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for all NFTs
    * @param delegate The hotwallet to act on your behalf
    * @param vault The cold wallet who issued the delegation
    */
    function checkDelegateForAll(address delegate, address vault) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault));
        return delegations[delegateHash];
    }

    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an NFT contract
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param vault The cold wallet who issued the delegation
    */ 
    function checkDelegateForContract(address delegate, address vault, address contract_) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_));
        return delegations[delegateHash] ? true : checkDelegateForAll(delegate, vault);
    }
    
    /** 
    * @notice Returns true if the address is delegated to act on your behalf for an specific NFT
    * @param delegate The hotwallet to act on your behalf
    * @param contract_ The address for the contract you're delegating
    * @param tokenId The token id for the token you're delegating
    * @param vault The cold wallet who issued the delegation
    */
    function checkDelegateForToken(address delegate, address vault, address contract_, uint256 tokenId) public view returns (bool) {
        bytes32 delegateHash = keccak256(abi.encode(delegate, vault, contract_, tokenId));
        return delegations[delegateHash] ? true : checkDelegateForContract(delegate, vault, contract_);
    }
}
