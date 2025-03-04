import { ethers, network } from 'hardhat'
import { randomBytes } from 'crypto'
import { expect } from 'chai'
import { boolean } from 'hardhat/internal/core/params/argumentTypes'

export const randomAddress = () => {
    const id = randomBytes(32).toString('hex')
    const privateKey = '0x' + id
    const wallet = new ethers.Wallet(privateKey)
    return wallet.address
}

export const sleepTo = async (timestamp: bigint) => {
    await network.provider.send('evm_setNextBlockTimestamp', [Number(timestamp)])
    await network.provider.send('evm_mine')
}

export const sleep = async (seconds: bigint) => {
    await network.provider.send('evm_increaseTime', [Number(seconds)])
    await network.provider.send('evm_mine')
}

export function sqrt(value: bigint) {
    if (value < 0n) {
        throw 'square root of negative numbers is not supported'
    }

    if (value < 2n) {
        return value;
    }

    function newtonIteration(n: bigint, x0: bigint) {
        const x1 = ((n / x0) + x0) >> 1n;
        if (x0 === x1 || x0 === (x1 - 1n)) {
            return x0;
        }
        return newtonIteration(n, x1);
    }

    return newtonIteration(value, 1n);
}

export const toPrice = (sqrtPriceX96: bigint) => {
    // sqrtPriceX96 = sqrt(price) * 2^96
    // price = (sqrtPriceX96 / 2^96)^2
    const Q96 = 2n**96n
    return {
        price: sqrtPriceX96 ** 2n / Q96**2n,
        invertedPrice:  Q96**2n / sqrtPriceX96 ** 2n
    }
}

export const epsEqual = (
    a: bigint,
    b: bigint,
    eps: bigint = 1n,
    decimals: bigint = 10n**3n,
    zeroThresh = 10n
) => {
    if (a === b) return true

    let res: boolean = false
    if (a === 0n) res = b <= zeroThresh
    if (b === 0n) res = a <= zeroThresh
    // |a - b| / a < eps <==> a ~ b
    if (a * b !== 0n) res = abs(a - b) * decimals / a < eps

    if (!res) console.log(`A = ${a}, B = ${b}`)
    return res
}

export const abs = (a: bigint) => {
    return a > 0n ? a : -a
}

export const epsEqualNumber = (
    a: number,
    b: number,
    eps: number = 1,
    decimals: number = 10 ** 4
) => {
    if (a === b) return true

    let res: boolean = false
    if (a === 0) res = b < eps
    if (b === 0) res = a < eps
    // |a - b| / a < eps <==> a ~ b
    if (a * b !== 0) res = Math.abs(a - b) / a < eps

    if (!res) console.log(`A = ${Number(a)}, B = ${Number(b)}`)
    return res
}

export const balanceOf = async (address: string) => {
    return await ethers.provider.getBalance(address)
}

export const ADDRESSES = {
    uniV3Factory: '0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7',
    uniV3PositionManager: '0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613',
    btcb: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
    usdt: '0x55d398326f99059fF775485246999027B3197955',
    uniV2Router: '0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24',
}