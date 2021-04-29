// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.6.12;

import "ds-test/test.sol";
import "dss-interfaces/Interfaces.sol";
import { Clipper } from "dss/clip.sol"; // TODO: remove when ETH-A clipper
                                        // becames available on mainnet
import { UniswapV2CalleeDai } from "../UniswapV2Callee.sol";

interface UniV2Router02Abstract {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint[] memory amounts);
}

interface WethAbstract is GemAbstract {
    function deposit() external payable;
}

contract Constants {

    // mainnet UniswapV2Router02 address
    address constant uniAddr = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 constant WAD = 1E18;
    bytes32 constant ilkName = "ETH-A";

    address wethAddr;
    address daiAddr;
    address vatAddr;
    address wethJoinAddr;
    address spotterAddr;
    address daiJoinAddr;
    address dogAddr;

    UniV2Router02Abstract uniRouter;
    WethAbstract weth;
    VatAbstract vat;
    DaiAbstract dai;
    GemJoinAbstract wethJoin;
    DogAbstract dog;

    Clipper clipper;
    UniswapV2CalleeDai callee;

    function setAddresses() private {
        ChainlogHelper helper = new ChainlogHelper();
        ChainlogAbstract chainLog = helper.ABSTRACT();
        wethAddr = chainLog.getAddress("ETH");
        vatAddr = chainLog.getAddress("MCD_VAT");
        daiAddr = chainLog.getAddress("MCD_DAI");
        wethJoinAddr = chainLog.getAddress("MCD_JOIN_ETH_A");
        spotterAddr = chainLog.getAddress("MCD_SPOT");
        daiJoinAddr = chainLog.getAddress("MCD_JOIN_DAI");
        dogAddr = chainLog.getAddress("MCD_DOG");
    }

    function setInterfaces() private {
        uniRouter = UniV2Router02Abstract(uniAddr);
        weth = WethAbstract(wethAddr);
        vat = VatAbstract(vatAddr);
        dai = DaiAbstract(daiAddr);
        wethJoin = GemJoinAbstract(wethJoinAddr);
        dog = DogAbstract(dogAddr);
    }

    function deployContracts() private {
        // TODO: change clipper to ETH-A mainnet deployment when available
        clipper = new Clipper(vatAddr, spotterAddr, address(dog), ilkName);
        callee = new UniswapV2CalleeDai(uniAddr, address(clipper), daiJoinAddr);
    }

    constructor () public {
        setAddresses();
        setInterfaces();
        deployContracts();
    }
}

contract Guy is Constants {

    constructor() public {
        weth.approve(uniAddr, type(uint256).max);
        vat.hope(msg.sender);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        uniRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }
}

contract SimulationTests is DSTest, Constants {

    Guy ali;
    address aliAddr;

    function setUp() public {
        ali = new Guy();
        aliAddr = address(ali);
    }

    function getWeth(uint256 value) private {
        weth.deposit{ value: value }();
        weth.transfer(aliAddr, value);
    }

    function testSwap() public {
        getWeth(2 * WAD);
        uint256 amountIn = 1 * WAD;
        uint256 amountOutMin = 1500 * WAD;
        address[] memory path = new address[](2);
        path[0] = wethAddr;
        path[1] = daiAddr;
        address to = aliAddr;
        uint256 deadline = block.timestamp;
        uint256 wethPre = weth.balanceOf(aliAddr);
        uint256 daiPre = dai.balanceOf(aliAddr);
        ali.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
        uint256 wethPost = weth.balanceOf(aliAddr);
        uint256 daiPost = dai.balanceOf(aliAddr);
        assertEq(wethPost, wethPre - amountIn);
        assertGe(daiPost, daiPre + amountOutMin);
    }

    function joinWeth(uint256 value) private {
        weth.deposit{ value: value }();
        weth.approve(wethJoinAddr, type(uint256).max);
        wethJoin.join(aliAddr, value);
    }

    function frobMax() private {
        uint256 ink = vat.gem(ilkName, aliAddr);
        (, uint256 rate, uint256 spot, ,) = vat.ilks(ilkName);
        uint256 art = ink * spot / rate;
        vat.frob(ilkName, aliAddr, aliAddr, aliAddr, int256(ink), int256(art));
    }

    function testFlash() public {
        joinWeth(20 * WAD);
        frobMax();
    }
}