// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;
import "../interfaces/IStargateFeeLibrary.sol";
import "../Pool.sol";
import "../Factory.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
contract StargateFeeLibraryV01 is IStargateFeeLibrary, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public constant BP_DENOMINATOR = 10000;
    constructor(address _factory) {
        require(_factory != address(0x0), "FeeLibrary: Factory cannot be 0x0");
        factory = Factory(_factory);
    }
    Factory public factory;
    uint256 public lpFeeBP;
    uint256 public protocolFeeBP;
    uint256 public eqFeeBP;
    uint256 public eqRewardBP;
    event FeesUpdated(uint256 lpFeeBP, uint256 protocolFeeBP);
    function getFees(uint256, uint256, uint16, address, uint256 _amountSD) external view override returns (Pool.SwapObj memory s) {
        s.protocolFee = _amountSD.mul(protocolFeeBP).div(BP_DENOMINATOR);
        s.lpFee = _amountSD.mul(lpFeeBP).div(BP_DENOMINATOR);
        s.eqFee = _amountSD.mul(eqFeeBP).div(BP_DENOMINATOR);
        s.eqReward = _amountSD.mul(eqRewardBP).div(BP_DENOMINATOR);
        return s;
    }
    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }
    function setFees(uint256 _lpFeeBP, uint256 _protocolFeeBP, uint256 _eqFeeBP, uint256 _eqRewardBP) external onlyOwner {
        require(_lpFeeBP.add(_protocolFeeBP).add(_eqFeeBP).add(_eqRewardBP) <= BP_DENOMINATOR, "FeeLibrary: sum fees > 100%");
        require(eqRewardBP <= eqFeeBP, "FeeLibrary: eq fee param incorrect");
        lpFeeBP = _lpFeeBP;
        protocolFeeBP = _protocolFeeBP;
        eqFeeBP = _eqFeeBP;
        eqRewardBP = _eqRewardBP;
        emit FeesUpdated(lpFeeBP, protocolFeeBP);
    }
}
