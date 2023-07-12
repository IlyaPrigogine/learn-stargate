// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
contract OmnichainFungibleToken is ERC20, Ownable, ILayerZeroReceiver, ILayerZeroUserApplicationConfig {
    ILayerZeroEndpoint immutable public endpoint;
    mapping(uint16 => bytes) public dstContractLookup;
    bool public paused;
    bool public isMain;
    event Paused(bool isPaused);
    event SendToChain(uint16 srcChainId, bytes toAddress, uint256 qty, uint64 nonce);
    event ReceiveFromChain(uint16 srcChainId, address toAddress, uint256 qty, uint64 nonce);
    constructor(string memory _name, string memory _symbol, address _endpoint, uint16 _mainChainId, uint256 _initialSupplyOnMainEndpoint) ERC20(_name, _symbol) {
        if (ILayerZeroEndpoint(_endpoint).getChainId() == _mainChainId) {
            _mint(msg.sender, _initialSupplyOnMainEndpoint);
            isMain = true;
        }
        endpoint = ILayerZeroEndpoint(_endpoint);
    }
    function pauseSendTokens(bool _pause) external onlyOwner {
        paused = _pause;
        emit Paused(_pause);
    }
    function setDestination(uint16 _dstChainId, bytes calldata _destinationContractAddress) public onlyOwner {
        dstContractLookup[_dstChainId] = _destinationContractAddress;
    }
    function chainId() external view returns (uint16){
        return endpoint.getChainId();
    }
    function sendTokens(uint16 _dstChainId, bytes calldata _to, uint256 _qty, address _zroPaymentAddress, bytes calldata _adapterParam) public payable {
        require(!paused, "OFT: sendTokens() is currently paused");
        if (isMain) {
            _transfer(msg.sender, address(this), _qty);
        } else {
            _burn(msg.sender, _qty);
        }
        bytes memory payload = abi.encode(_to, _qty);
        endpoint.send{value: msg.value}(
            _dstChainId,
            dstContractLookup[_dstChainId],
            payload,
            msg.sender,
            _zroPaymentAddress,
            _adapterParam
        );
        uint64 nonce = endpoint.getOutboundNonce(_dstChainId, address(this));
        emit SendToChain(_dstChainId, _to, _qty, nonce);
    }
    function lzReceive(uint16 _srcChainId, bytes memory _fromAddress, uint64 _nonce, bytes memory _payload) external override {
        require(msg.sender == address(endpoint)); // lzReceive must only be called by the endpoint
        require(
            _fromAddress.length == dstContractLookup[_srcChainId].length && keccak256(_fromAddress) == keccak256(dstContractLookup[_srcChainId]),
            "OFT: invalid source sending contract"
        );
        (bytes memory _to, uint256 _qty) = abi.decode(_payload, (bytes, uint256));
        address toAddress;
        assembly { toAddress := mload(add(_to, 20)) }
        if (toAddress == address(0x0)) toAddress == address(0xdEaD);
        if (isMain) {
            _transfer(address(this), toAddress, _qty);
        } else {
            _mint(toAddress, _qty);
        }
        emit ReceiveFromChain(_srcChainId, toAddress, _qty, _nonce);
    }
    function estimateSendTokensFee(uint16 _dstChainId, bytes calldata _toAddress, bool _useZro, bytes calldata _txParameters) external view returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(_toAddress, 1);
        return endpoint.estimateFees(_dstChainId, address(this), payload, _useZro, _txParameters);
    }
    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config) external override onlyOwner {
        endpoint.setConfig(_version, _chainId, _configType, _config);
    }
    function setSendVersion(uint16 _version) external override onlyOwner {
        endpoint.setSendVersion(_version);
    }
    function setReceiveVersion(uint16 _version) external override onlyOwner {
        endpoint.setReceiveVersion(_version);
    }
    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        endpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }
    function renounceOwnership() public override onlyOwner {}
}
