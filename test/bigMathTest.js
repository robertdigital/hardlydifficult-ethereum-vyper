/**
 * Tests the bigDiv math
 */
const chai = require("chai");
const { expect } = chai;
const { BN, expectRevert } = require("openzeppelin-test-helpers");
const BigMath = artifacts.require("BigMath");
const Big = require("big.js");
const MAX_DELTA_RATIO_FROM_EXPECTED = 0.0005; // 0.05%
Big.DP = 200;
Big.PE = 200;
const MAX_UINT256 = new BN(
  "115792089237316195423570985008687907853269984665640564039457584007913129639935"
);
let maxError = new BN(0);

const numbers = [
  //'0',
  // "1",
  // "2",
  // "5",
  // "8",
  // "17",
  "123456789123456789",
  "8498413651635165146846416314635436",
  "34028236692093842568444274447460650188",
  "340282366920938425684442744474606501887",
  "340282366920938425684442744474606501888",
  "340282366920938463463374607431768211454",
  "340282366920938463463374607431768211455",
  "340282366920938463463374607431768211456", // MAX_BEFORE_SQUARE
  "340282366920938463463374607431768211457",
  "340282366920938463463374607431768211458",
  "99993402823669209384634633746074317682114579999",
  "8888834028236692093846346337460743176821145788888",
  "8888834028236692093846346337460743176821145799999",
  "20892373161954235709850086879078532699846656405640394575840079139935",
  "2089237316195423570985008687907853269984665640564039457584007913129639935",
  "2089237316195423570985008655555555555555555550564039457584007913129639935",
  "113456789123456789123546781234567891234567891235467812345678912345678912354678",
  "115792089237316195423570985008687907853269984665640564039457584007913129639934",
  "115792089237316195423570985008687907853269984665640564039457584007913129639935" // MAX_UINT256
];

// Checks that the difference is no greater than max(1, 0.05% of expectation)
const checkBounds = (expectedBN, resultBN, roundUp, testDesc) => {
  const diff = expectedBN.sub(resultBN);

  const maxDiff = new Big(MAX_DELTA_RATIO_FROM_EXPECTED).mul(
    new Big(expectedBN.toString())
  );
  // console.log('maxDiff', maxDiff.toString())

  const maxDiffInt = maxDiff.add(new Big("1")).round(0, 0); // // Adds 1 and rounds down, so allows a diff of 1 if expected diff is <1
  // console.log('maxDiffInt', maxDiffInt.toString())

  const maxDiffBN = new BN(maxDiffInt.toString());
  // console.log('maxDiffBN', maxDiffBN.toString())

  let diffDesc = "(unknown delta)";
  let minVal, maxVal;
  if (!expectedBN.eq(new BN(0))) {
    const diffPct = Big(diff.toString()).div(Big(expectedBN.toString()));
    if (diffPct.gt(maxError)) {
      maxError = diffPct;
    }
    diffDesc = `(delta=${diffPct
      .mul(100)
      .toPrecision(5)
      .toString()}%)`;
  }

  if (roundUp) {
    minVal = expectedBN;
    maxVal = expectedBN.add(maxDiffBN);
  } else {
    minVal = expectedBN.sub(maxDiffBN);
    maxVal = expectedBN;
  }

  // console.log(`Expecting ${resultBN} to be between ${minVal.toString()} and ${maxVal.toString()}`)
  if (maxVal.gt(MAX_UINT256)) {
    console.log("WARNING: expected value range exceeds MAX_UINT256");
  }

  expect(resultBN, `value too low ${diffDesc}`).to.be.bignumber.at.least(
    minVal
  );
  expect(resultBN, `value too high ${diffDesc}`).to.be.bignumber.at.most(
    maxVal
  );
};

contract("bigDiv", accounts => {
  let contract;

  before(async () => {
    // Update to test new, BigMath contract
    contract = await BigMath.new();
  });

  after(async () => {
    console.log(maxError.toString());
  });

  it("check", async () => {
     
    await check2x1(
      "99993402823669209384634633746074317682114579999",
      "99993402823669209384634633746074317682114579999",
      "113456789123456789123546781234567891234567891235467812345678912345678912354678",
      false
    );
  });

  const check2x1 = async (numA, numB, den, roundUp) => {
    const contractRes = await contract.bigDiv2x1(
      numA,
      numB,
      den,
      roundUp
    );

    const bnRes = new BN(numA).mul(new BN(numB)).div(new BN(den));

    checkBounds(bnRes, contractRes, roundUp);
    // expect(contractRes, `(${numA} * ${numB}) / ${den}) failed`).to.be.bignumber.equal(bnRes);
    return contractRes;
  };

  const check2x2 = async (numA, numB, den1, den2, roundUp) => {
    const contractRes = await contract.bigDiv2x2(
      numA,
      numB,
      den1,
      den2,
      roundUp
    );

    const bnRes = new BN(numA)
      .mul(new BN(numB))
      .div(new BN(den1).mul(new BN(den2)));

    checkBounds(bnRes, contractRes, roundUp);
    // expect(contractRes, `(${numA} * ${numB}) / (${den1} * ${den2})) failed`).to.be.bignumber.equal(bnRes);
    return contractRes;
  };

  for (let a = 0; a < numbers.length; a++) {
    for (let b = a; b < numbers.length; b++) {
      // todo start at 0
      for (let d = 0; d < numbers.length; d++) {
        const numA = numbers[a];
        const numB = numbers[b];
        const den = numbers[d];
        const bnRes = new BN(numA).mul(new BN(numB)).div(new BN(den));

        if (bnRes.lte(MAX_UINT256)) {
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
});
