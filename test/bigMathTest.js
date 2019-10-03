/**
 * Tests the bigDiv math
 */
const BigMath = artifacts.require('BigMath');
const BigNumber = require('bignumber.js');

const MAX_DELTA_RATIO_FROM_EXPECTED = 0.0001; // Goal was 0.01% accurate or better
const MAX_UINT256 = new BigNumber(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
);
const MAX_UINT192 = new BigNumber(
  '6277101735386680763835789423207666416102355444464034512895',
);
const MAX_UINT128 = new BigNumber(
  '340282366920938463463374607431768211455',
);
const MAX_UINT64 = new BigNumber(
  '18446744073709551615',
);
const MAX_UINT32 = new BigNumber(
  '4294967295',
);

const numbers = [
  new BigNumber('0'),
  new BigNumber('1'),
  new BigNumber('2'),
  new BigNumber('3'),
  new BigNumber('97'),
  MAX_UINT32.div('1009').dp(0),
  MAX_UINT32.div('10').dp(0),
  MAX_UINT32.div('2').dp(0).minus('1'),
  MAX_UINT32.div('2').dp(0),
  MAX_UINT32.div('2').dp(0).plus('1'),
  MAX_UINT32.minus('1'),
  MAX_UINT32,
  MAX_UINT32.plus('1'),
  MAX_UINT32.times('2').minus('1'),
  MAX_UINT32.times('2'),
  MAX_UINT32.times('2').plus('1'),
  MAX_UINT32.times('10'),
  MAX_UINT32.times('1009'),
  MAX_UINT64.div('1009').dp(0),
  MAX_UINT64.div('10').dp(0),
  MAX_UINT64.div('2').dp(0).minus('1'),
  MAX_UINT64.div('2').dp(0),
  MAX_UINT64.div('2').dp(0).plus('1'),
  MAX_UINT64.minus('1'),
  MAX_UINT64,
  MAX_UINT64.plus('1'),
  MAX_UINT64.times('2').minus('1'),
  MAX_UINT64.times('2'),
  MAX_UINT64.times('2').plus('1'),
  MAX_UINT64.times('10'),
  MAX_UINT64.times('1009'),
  new BigNumber('123456789123456789'),
  new BigNumber('849841365163516514614635436'),
  new BigNumber('8498413651635165146846416314635436'),
  new BigNumber('34028236692093842568444274447460650188'),
  MAX_UINT128.div('1009').dp(0),
  MAX_UINT128.div('10').dp(0),
  MAX_UINT128.div('2').dp(0).minus('1'),
  MAX_UINT128.div('2').dp(0),
  MAX_UINT128.div('2').dp(0).plus('1'),
  MAX_UINT128.minus('2'),
  MAX_UINT128.minus('1'),
  MAX_UINT128,
  MAX_UINT128.plus('1'),
  MAX_UINT128.plus('2'),
  MAX_UINT128.plus('3'),
  MAX_UINT128.times('2').minus('1'),
  MAX_UINT128.times('2'),
  MAX_UINT128.times('2').plus('1'),
  MAX_UINT128.times('10'),
  MAX_UINT128.times('1009'),
  new BigNumber('99993402823669209384634633746074317682114579999'),
  new BigNumber('8888834028236692093846346337460743176821145799999'),
  new BigNumber('20892373161954235709850086879078532699846623564056403945759935'),
  new BigNumber('2089237316195423570985008687907853269984665640564039457584007913129639935'),
  MAX_UINT192.div('1009').dp(0),
  MAX_UINT192.div('10').dp(0),
  MAX_UINT192.div('2').dp(0).minus('1'),
  MAX_UINT192.div('2').dp(0),
  MAX_UINT192.div('2').dp(0).plus('1'),
  MAX_UINT192.minus('1'),
  MAX_UINT192,
  MAX_UINT192.plus('1'),
  MAX_UINT192.times('2').minus('1'),
  MAX_UINT192.times('2'),
  MAX_UINT192.times('2').plus('1'),
  MAX_UINT192.times('10'),
  MAX_UINT192.times('1009'),
  MAX_UINT256.div('1009').dp(0),
  MAX_UINT256.div('10').dp(0),
  MAX_UINT256.div('2').dp(0).minus('1'),
  MAX_UINT256.div('2').dp(0),
  MAX_UINT256.div('2').dp(0).plus('1'),
  MAX_UINT256.minus('2'),
  MAX_UINT256.minus('1'),
  MAX_UINT256,
];

const getValue = (expectedBN, roundUp) => {
  const maxDiff = new BigNumber(MAX_DELTA_RATIO_FROM_EXPECTED).times(
    expectedBN,
  );

  const maxDiffInt = maxDiff.plus(new BigNumber('1')).dp(0); // // Adds 1 and rounds down, so allows a diff of 1 if expected diff is <1

  const maxDiffBN = new BigNumber(maxDiffInt.toFixed());

  let minVal;
  let maxVal;

  if (roundUp) {
    minVal = expectedBN;
    maxVal = expectedBN.plus(maxDiffBN);
  } else {
    minVal = expectedBN.minus(maxDiffBN);
    maxVal = expectedBN;
  }

  return [minVal, maxVal];
};

// Checks that the difference is no greater than max(1, MAX_DELTA of expectation)
const checkBounds = (expectedBN, resultBN, roundUp) => {
  const [minVal, maxVal] = getValue(expectedBN, roundUp);

  if (maxVal.gt(MAX_UINT256)) {
    console.log('WARNING: expected value range exceeds MAX_UINT256');
  }

  assert(resultBN.gte(minVal), `${resultBN.toFixed()} is not >= ${minVal.toFixed()} (and <= ${maxVal.toFixed()})`);
  assert(resultBN.lte(maxVal), `${resultBN.toFixed()} is not <= ${maxVal.toFixed()} (and >= ${minVal.toFixed()})`);
};

contract('bigDiv', () => {
  let contract;

  before(async () => {
    contract = await BigMath.new();
  });

  const check2x1 = async (numA, numB, den, roundUp) => {
    let bnRes = new BigNumber(numA).times(new BigNumber(numB)).div(new BigNumber(den));
    bnRes = bnRes.dp(0, roundUp ? BigNumber.ROUND_UP : BigNumber.ROUND_DOWN);

    const [, maxVal] = getValue(bnRes, roundUp);
    if (maxVal.gt(MAX_UINT256)) {
      return; // skip test as the result may overflow when in expected range
    }

    const contractRes = new BigNumber(await contract.bigDiv2x1(
      numA.toFixed(),
      numB.toFixed(),
      den.toFixed(),
      roundUp,
    ));

    checkBounds(bnRes, contractRes, roundUp);
  };

  // const check2x2 = async (numA, numB, den1, den2, roundUp) => {
  //   const contractRes = new BigNumber(await contract.bigDiv2x2(
  //     numA.toFixed(),
  //     numB.toFixed(),
  //     den1.toFixed(),
  //     den2.toFixed(),
  //     roundUp,
  //   ));

  //   const bnRes = new BigNumber(numA)
  //     .times(new BigNumber(numB))
  //     .div(new BigNumber(den1).times(new BigNumber(den2)));

  //   checkBounds(bnRes, contractRes, roundUp);
  //   // expect(contractRes, `(${numA} * ${numB}) / (${den1} * ${den2})) failed`)
  //       .to.be.bignumber.equal(bnRes);
  // };

  for (let a = numbers.length - 1; a >= 0; a--) {
    for (let b = a; b < numbers.length; b++) {
      for (let d = 0; d < numbers.length; d++) {
        const numA = numbers[a];
        const numB = numbers[b];
        const den = numbers[d];
        if (den.toFixed() !== '0') {
          const bnRes = new BigNumber(numA).times(new BigNumber(numB)).div(new BigNumber(den));

          if (bnRes.lte(MAX_UINT256)) {
            if (new BigNumber(numA).times(numB).plus(100).gte(MAX_UINT256)) {
              it(`bigDiv2x1         ${numA.toFixed()} * ${numB.toFixed()} / ${den.toFixed()} ~= ${bnRes.toExponential(2)}`, async () => {
                await check2x1(numA, numB, den, false);
              });
              it(`bigDiv2x1 ROUNDUP ${numA.toFixed()} * ${numB.toFixed()} / ${den.toFixed()} ~= ${bnRes.toExponential(2)}`, async () => {
                await check2x1(numA, numB, den, true);
              });
            }
          }
        }
      }
    }
  }
});
