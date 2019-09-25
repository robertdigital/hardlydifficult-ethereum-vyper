/**
 * Tests the bigDiv math
 */
const BigMath = artifacts.require('BigMath');
const BigNumber = require('bignumber.js');

const MAX_DELTA_RATIO_FROM_EXPECTED = 0.0005; // 0.05%
const MAX_UINT256 = new BigNumber(
  '115792089237316195423570985008687907853269984665640564039457584007913129639935',
);
const MAX_BEFORE_SQUARE = new BigNumber(
  '340282366920938463463374607431768211456',
);
let maxError = new BigNumber(0);

const numbers = [
  new BigNumber('0'),
  new BigNumber('1'),
  new BigNumber('2'),
  new BigNumber('3'),
  new BigNumber('5'),
  new BigNumber('8'),
  new BigNumber('17'),
  new BigNumber('41'),
  new BigNumber('97'),
  new BigNumber('123456789123456789'),
  new BigNumber('849841365163516514614635436'),
  new BigNumber('8498413651635165146846416314635436'),
  new BigNumber('34028236692093842568444274447460650188'),
  new BigNumber('340282366920938425684442744474606501887'),
  new BigNumber('340282366920938425684442744474606501888'),
  // MAX_BEFORE_SQUARE.div('1000').dp(0).minus('1'),
  // MAX_BEFORE_SQUARE.div('1000').dp(0),
  // MAX_BEFORE_SQUARE.div('1000').dp(0).plus('1'),
  // MAX_BEFORE_SQUARE.div('10').dp(0).minus('1'),
  // MAX_BEFORE_SQUARE.div('10').dp(0),
  // MAX_BEFORE_SQUARE.div('10').dp(0).plus('1'),
  MAX_BEFORE_SQUARE.div('2').dp(0).minus('1'),
  MAX_BEFORE_SQUARE.div('2').dp(0),
  // MAX_BEFORE_SQUARE.div('2').dp(0).plus('1'),
  MAX_BEFORE_SQUARE.minus('10001'),
  MAX_BEFORE_SQUARE.minus('100'),
  MAX_BEFORE_SQUARE.minus('3'),
  MAX_BEFORE_SQUARE.minus('2'),
  MAX_BEFORE_SQUARE.minus('1'),
  MAX_BEFORE_SQUARE,
  MAX_BEFORE_SQUARE.plus('1'),
  MAX_BEFORE_SQUARE.plus('2'),
  // MAX_BEFORE_SQUARE.times('2').minus('1'),
  // MAX_BEFORE_SQUARE.times('2'),
  // MAX_BEFORE_SQUARE.times('2').plus('1'),
  // MAX_BEFORE_SQUARE.times('10').minus('1'),
  // MAX_BEFORE_SQUARE.times('10'),
  // MAX_BEFORE_SQUARE.times('10').plus('1'),
  // MAX_BEFORE_SQUARE.times('1000').minus('1'),
  // MAX_BEFORE_SQUARE.times('1000'),
  // MAX_BEFORE_SQUARE.times('1000').plus('1'),
  new BigNumber('99993402823669209384634633746074317682114579999'),
  new BigNumber('8888834028236692093846346337460743176821145788888'),
  new BigNumber('8888834028236692093846346337460743176821145799999'),
  new BigNumber('888883402823669209384634633746074317129816821145799999'),
  new BigNumber('20892373161954235709850086879078532699846623564056403945759935'),
  new BigNumber('20892373161954235709850086879078532699846656405640394575840079139935'),
  new BigNumber('2089237316195423570985008687907853269984665640564039457584007913129639935'),
  new BigNumber('2089237316195423570985008655555555555555555550564039457584007913129639935'),
  new BigNumber('113456789123456789123546781234567891234567891235467812345678912345678912354678'),
  MAX_UINT256.div('10000').dp(0).minus('1'),
  MAX_UINT256.div('10000').dp(0),
  MAX_UINT256.div('10000').dp(0).plus('1'),
  MAX_UINT256.div('10').dp(0).minus('1'),
  MAX_UINT256.div('10').dp(0),
  MAX_UINT256.div('10').dp(0).plus('1'),
  MAX_UINT256.div('2').dp(0).minus('1'),
  MAX_UINT256.div('2').dp(0),
  MAX_UINT256.div('2').dp(0).plus('1'),
  MAX_UINT256.minus('2'),
  MAX_UINT256.minus('1'),
  MAX_UINT256,
];

// Checks that the difference is no greater than max(1, 0.05% of expectation)
const checkBounds = (expectedBN, resultBN, roundUp) => {
  const diff = expectedBN.minus(resultBN);

  const maxDiff = new BigNumber(MAX_DELTA_RATIO_FROM_EXPECTED).times(
    expectedBN,
  );
  // console.log('maxDiff', maxDiff.toFixed())

  const maxDiffInt = maxDiff.plus(new BigNumber('1')).dp(0); // // Adds 1 and rounds down, so allows a diff of 1 if expected diff is <1
  // console.log('maxDiffInt', maxDiffInt.toFixed())

  const maxDiffBN = new BigNumber(maxDiffInt.toFixed());
  // console.log('maxDiffBN', maxDiffBN.toFixed())

  // let diffDesc = '(unknown delta)';
  let minVal; let
    maxVal;
  if (!expectedBN.eq(new BigNumber(0))) {
    const diffPct = new BigNumber(diff.toFixed()).div(expectedBN.toFixed());
    if (expectedBN.gt('1000000') && diffPct.gt(maxError)) {
      maxError = diffPct;
    }
    // diffDesc = `(delta=${diffPct
    //   .times(100)
    //   // .toPrecision(5)
    //   .toFixed()}%)`;
  }

  if (roundUp) {
    minVal = expectedBN;
    maxVal = expectedBN.plus(maxDiffBN);
  } else {
    minVal = expectedBN.minus(maxDiffBN);
    maxVal = expectedBN;
  }

  // console.log(`Expecting ${resultBN} to be between ${minVal.toFixed()} and ${maxVal.toFixed()}`)
  if (maxVal.gt(MAX_UINT256)) {
    console.log('WARNING: expected value range exceeds MAX_UINT256');
  }

  assert(resultBN.gte(minVal), `${resultBN.toFixed()} is not >= ${minVal.toFixed()}`);
  assert(resultBN.lte(maxVal));
};

contract('bigDiv', () => {
  let contract;

  before(async () => {
    // Update to test new, BigMath contract
    contract = await BigMath.new();
  });

  after(async () => {
    console.log(maxError.toFixed());
  });

  const check2x1 = async (numA, numB, den, roundUp) => {
    const contractRes = new BigNumber(await contract.bigDiv2x1(
      numA.toFixed(),
      numB.toFixed(),
      den.toFixed(),
      roundUp,
    ));

    let bnRes = new BigNumber(numA).times(new BigNumber(numB)).div(new BigNumber(den));
    bnRes = bnRes.dp(0, roundUp ? BigNumber.ROUND_UP : BigNumber.ROUND_DOWN);

    checkBounds(bnRes, contractRes, roundUp);
    // expect(contractRes, `(${numA} * ${numB}) / ${den}) failed`).to.be.bignumber.equal(bnRes);
    return contractRes;
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
  //   return contractRes;
  // };

  for (let a = 0; a < numbers.length; a++) {
    for (let b = a; b < numbers.length; b++) {
      // todo start at 0
      for (let d = 0; d < numbers.length; d++) {
        const numA = numbers[a];
        const numB = numbers[b];
        const den = numbers[d];
        if (den.toFixed() !== '0') {
          const bnRes = new BigNumber(numA).times(new BigNumber(numB)).div(new BigNumber(den));

          if (bnRes.lte(MAX_UINT256)) {
            // TODO this is temp for faster testing
            if (new BigNumber(numA).times(numB).gte(MAX_UINT256)) {
              //  Only run test if the result fits into a uint256
              it(`bigDiv2x1         ${numA} * ${numB} / ${den}`, async () => {
                await check2x1(numA, numB, den, false);
              });
              // it(`bigDiv2x1 ROUNDUP ${numA} * ${numB} / ${den}`, async () => {
              //   await check2x1(numA, numB, den, true);
              // });
            }
          }
        }
      }
    }
  }
});
