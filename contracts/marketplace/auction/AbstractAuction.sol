pragma solidity ^0.5.2;

import "@axie/contract-library/contracts/token/erc20/IERC20.sol";
import "@axie/contract-library/contracts/lifecycle/Pausable.sol";
import "@axie/contract-library/contracts/ownership/Withdrawable.sol";
import "../../chain/common/Registry.sol";
import "../exchange/IExchange.sol";
import "./clock/IClockAuction.sol";
import "./offer/IOfferAuction.sol";


contract AbstractAuction is Pausable, Withdrawable {
  string public constant EXCHANGE = "EXCHANGE";
  string public constant CLOCK_AUCTION = "CLOCK_AUCTION";
  string public constant OFFER_AUCTION = "OFFER_AUCTION";

  Registry public registry;
  // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
  // Values 0-10,000 map to 0%-100%.
  uint256 public ownerCut;

  constructor(Registry _registry, uint256 _ownerCut) public {
    require(_ownerCut <= 10000);
    ownerCut = _ownerCut;
    registry = _registry;
  }

  function updateRegistry(Registry _registry) external onlyAdmin {
    registry = _registry;
  }

  function setOwnerCut(uint256 _newOwnerCut) external onlyAdmin {
    require(_newOwnerCut <= 10000);
    ownerCut = _newOwnerCut;
  }

  function _getExchangeContract() internal view returns (IExchange _exchangeContract) {
    _exchangeContract = IExchange(registry.getContract(EXCHANGE));
  }

  function _getClockContract() internal view returns (IClockAuction _clockAuctionContract) {
    _clockAuctionContract = IClockAuction(registry.getContract(CLOCK_AUCTION));
  }

  function _getOfferContract() internal view returns (IOfferAuction _offerAuctionContract) {
    _offerAuctionContract = IOfferAuction(registry.getContract(OFFER_AUCTION));
  }
}
