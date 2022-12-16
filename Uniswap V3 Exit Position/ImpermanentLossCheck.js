const axios = require('axios');
const { ethers } = require('ethers');
const subgraphURL = process.env.subgraphURL;
const alchemyURL = process.env.alchemyURL;
const provider = new ethers.providers.JsonRpcProvider(alchemyURL);
const { abi: ArdaUniContractABI } = require('./contracts/ABIS/ArdaUniContract.json');
const { abi: OracleLibraryABI } = require('./contracts/ABIS/OracleLibrary.json');

require('dotenv').config()

const accounts = await provider.send("eth_requestAccounts", []); 
const walletAddress = accounts[0];
const signer = provider.getSigner(walletAddress);

const contractAddress = "";
const libraryAddress = "";
const usdtAddress = "0xdac17f958d2ee523a2206206994597c13d831ec7"; // hard-coded address for this example. 
const ethUsdtPool = "0x11b815efb8f581194ae79006d24e0d814b7697f6"; // we can also call IUniswapFactory Contract to get pool info
const wbtcUsdtPool = "0x9db9e0e53058c89e5b94e29621a205198648425b"; // for respective token0/usdt & token1/usdt pool tick.

const tickBase = 1.0001;
const time = 30000; //30s

positionQuery = `  
{
    position(id: 4) {
      token0 {
        id
        symbol
        decimals
      }
      token1 {
        id
        symbol
        decimals
      }
      tickLower {
        tickIdx
      }
      tickUpper {
        tickIdx
      }
      id
      owner
      depositedToken0
      depositedToken1
      pool {
        id
        feeTier
      }
    }
  }
`

poolQuery = `
{
    position(id: 4) {
      liquidity      
      pool{
        sqrtPrice
        tick
      }
  }
}
`
const interval = (timeInMs) => 
new Promise((resolve) => setTimeout(resolve, timeInMs));

function tickToPrice(tick) {
    return tickBase ** tick;
}

async function main() { 
    const posResult = await axios.post(subgraphURL, {query: positionQuery });
    const depAmount0 = posResult.data.data.position.depositedToken0;
    const depAmount1 = posResult.data.data.position.depositedToken1;
    const decimals0 = posResult.data.data.position.token0.decimals;
    const decimals1 = posResult.data.data.position.token1.decimals;
    const upTick = posResult.data.data.position.tickUpper.tickIdx;
    const lowTick = posResult.data.data.position.tickLower.tickIdx;
    const NFTid = posResult.data.data.position.id;
    const owner = posResult.data.data.position.owner;
    const token0Address = posResult.data.data.position.token0.id;
    const token1Address = posResult.data.data.position.token1.id;

    while (true) {
        const poolResult = await axios.post(subgraphURL, {query: poolQuery});
        const liquidity = poolResult.data.data.position.liquidity;
        const sqrtPrice = poolResult.data.data.position.pool.sqrtPrice / (2 ** 96);
        const currentTick = poolResult.data.data.position.pool.tick; 
        const sa = tickToPrice(lowTick / 2);
        const sb = tickToPrice(upTick / 2);
        
        if(upTick <= currentTick) {
            const liqAmount0 = 0;
            const liqAmount1 = liquidity * (sb - sa); 
        } else if (lowTick < currentTick && currentTick < upTick) {
            const liqAmount0 = liquidity * (sb - sqrtPrice) / (sqrtPrice * sb);
            const liqAmount1 = liquidity * (sqrtPrice - sa);
        } else {
            const liqAmount0 = liquidity * (sb - sa) / (sa * sb);
            const liqAmount1 = 0;
        }

        const adjustedAmt0 = liqAmount0 / (10 ** decimals0);
        const adjustedAmt1 = liqAmount1 / (10 ** decimals1);

        const oracleLib = new ethers.Contract(libraryAddress, OracleLibraryABI, provider);
        const pool0Tick = oracleLib.consult(wbtcUsdtPool, 30);
        const pool1Tick = oracleLib.consult(ethUsdtPool, 30);
        const price0 = oracleLib.getQuoteAtTick(pool0Tick, 1, token0Address, usdtAddress);
        const price1 = oracleLib.getQuoteAtTick(pool1Tick, 1, token1Address, usdtAddress);

        const hodlValue = (depAmount0 * price0) + (depAmount1 * price1);
        const totalLiquidity = adjustedAmt0 * price0 + adjustedAmt1 * price1;
        const iL = (hodlValue - totalLiquidity) / hodlValue;

        if(iL > 0.50) {
            const exitContract = new ethers.Contract(contractAddress, ArdaUniContractABI, signer);
            await exitContract.exitPosition(NFTid, owner);
        } else {
            await interval(time);
        }
    }
}

main();
