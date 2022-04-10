pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IWBNB.sol";

contract Fold is IFlashLoanReceiver {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private immutable provider;
    ILendingPool private immutable pool;
    IWBNB public immutable wbnb;
    address public immutable valBnb;
    address public immutable debtBnb;

    constructor(address _provider, address _pool, address _wbnb, address _valBnb, address _debtBnb) {
        provider = _provider;
        pool = ILendingPool(_pool);
        wbnb = IWBNB(_wbnb);
        valBnb = _valBnb;
        debtBnb = _debtBnb;
    }

    receive() external payable {
        require(msg.sender == address(wbnb));
    }

    function _approve(address _token) internal {
        IERC20 token = IERC20(_token);
        if (token.allowance(address(this), address(pool)) == 0) {
            token.approve(address(pool), uint256(-1));
        }
    }

    function _fold(address _token, uint256 _depositAmount, uint256 _loanAmount) internal {
        require(_loanAmount > 0);
        _approve(_token);

        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _loanAmount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 2;
        pool.flashLoan(address(this), tokens, amounts, modes, msg.sender, abi.encode(msg.sender, _depositAmount.add(_loanAmount), uint256(0)), 0xF01D);
    }

    function fold(address _token, uint256 _depositAmount, uint256 _loanAmount) external {
        if (_depositAmount > 0) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _depositAmount);
        }
        _fold(_token, _depositAmount, _loanAmount);
    }

    function fold_bnb(uint256 _loanAmount) external payable {
        if (msg.value > 0) {
            wbnb.deposit{value: msg.value}();
        }
        _fold(address(wbnb), msg.value, _loanAmount);
    }

    function _unfold(address _token, address _valToken, address _debtToken, uint256 flag) internal {
        uint256 debt = IERC20(_debtToken).balanceOf(msg.sender);
        require(debt > 0);
        _approve(_token);

        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = debt;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        pool.flashLoan(address(this), tokens, amounts, modes, msg.sender, abi.encode(msg.sender, uint256(_valToken), flag), 0xF01E);
    }

    function unfold(address _token, address _valToken, address _debtToken) external {
        _unfold(_token, _valToken, _debtToken, 1);
    }

    function unfold_bnb() external {
        _unfold(address(wbnb), valBnb, debtBnb, 2);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(pool));
        require(assets.length == 1);
        require(initiator == address(this));
        address token = assets[0];
        uint256 loanAmount = amounts[0];
        (address sender, uint256 data, uint256 flag) = abi.decode(params, (address, uint256, uint256));
        if (flag == 0) {
            pool.deposit(token, data, sender, 0xF01D);
        }
        else {
            IERC20 valToken = IERC20(address(data));
            pool.repay(token, loanAmount, 2, sender);
            uint256 amount = valToken.balanceOf(sender);
            valToken.safeTransferFrom(sender, address(this), amount);
            pool.withdraw(token, amount, address(this));
            amount = amount.sub(loanAmount).sub(premiums[0]);
            if (flag == 1) {
                IERC20(token).safeTransfer(sender, amount);
            }
            else {
                wbnb.withdraw(amount);
                (bool success, ) = sender.call{value: amount}("");
                require(success);
            }
        }
        return true;
    }

    function ADDRESSES_PROVIDER() external override view returns (address) {
        return provider;
    }

    function LENDING_POOL() external override view returns (address) {
        return address(pool);
    }
}
