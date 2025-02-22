// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;
interface ILayerZeroReceiver {
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) external;
}
