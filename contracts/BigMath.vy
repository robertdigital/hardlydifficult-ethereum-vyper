# @title Reduces the size of terms before multiplication, to avoid an overflow, and then
# restores the proper size after division.  
# @notice This effectively allows us to overflow values in the numerator and/or denominator 
# of a fraction, so long as the end result does not overflow as well.

MAX_UINT: constant(uint256) = 2**256 - 1
# @notice The max possible value

MAX_BEFORE_SQUARE: constant(uint256) = 2**128 - 1
# @notice When multiplying 2 terms <= this value the result won't overflow

MAX_ERROR: constant(uint256) = 10000
# @notice Representing up to 0.01% error

MAX_ERROR_BEFORE_DIV: constant(uint256) = MAX_ERROR * 10
# @notice A larger error threshold to use when multiple rounding errors may apply

@private
@constant
def _bigDiv2x1(
  _numA: uint256,
  _numB: uint256,
  _den: uint256
) -> uint256:
  """
  @notice Returns the approx result of `a * b / d` so long as the result is <= MAX_UINT
  @param _numA the first numerator term
  @param _numB the second numerator term
  @param _den the denominator
  @return the approx result with up to off by 1 + 0.01% error
  """
  if(_numA == 0 or _numB == 0):
    # would div by 0 or underflow if we don't special case 0
    return 0

  value: uint256

  if(MAX_UINT / _numA >= _numB):
    # a*b does not overflow, return exact math
    value = _numA * _numB
    value /= _den
    return value

  # Sort numerators
  numMax: uint256
  numMin: uint256
  if(_numA > _numB):
    numMax = _numA
    numMin = _numB
  else:
    numMax = _numB
    numMin = _numA

  value = numMax / _den
  if(value > MAX_ERROR):
    # _den is small enough to be 0.01% accurate or better w/o a factor
    value *= numMin
    return value

  factor: uint256
  temp: uint256

  # formula = ((a / f) * b) / (d / f)
  # factor >= a / sqrt(MAX) * b / sqrt(MAX)
  factor = numMin - 1
  factor /= MAX_BEFORE_SQUARE
  factor += 1
  temp = numMax - 1
  temp /= MAX_BEFORE_SQUARE
  temp += 1

  if(MAX_UINT / factor >= temp):
    factor *= temp

    value = numMax / factor
    if(factor <= MAX_BEFORE_SQUARE or value > MAX_ERROR_BEFORE_DIV):
      value *= numMin
      temp = _den - 1
      temp /= factor
      temp += 1
      value /= temp
      return value

  # formula = a / (d / f) * b / f
  # factor <= MAX / a * (d / b)
  factor = MAX_UINT / numMax
  temp = _den / numMin
  factor *= temp
  if(factor > 0):
    temp = _den - 1
    temp /= factor
    temp += 1
    value = numMax / temp
    if((factor <= MAX_BEFORE_SQUARE and factor > MAX_ERROR) or value > MAX_ERROR_BEFORE_DIV):
      value *= numMin
      value /= factor
      return value

  # formula: (a / (d / f)) * (b / f)
  # factor: b / sqrt(MAX)
  factor = numMin - 1
  factor /= MAX_BEFORE_SQUARE
  factor += 1
  value = numMin / factor
  temp = _den - 1
  temp /= factor
  temp += 1
  temp = numMax / temp
  value *= temp
  return value

@public
@constant
def bigDiv2x1(
  _numA: uint256,
  _numB: uint256,
  _den: uint256,
  _roundUp: bool
) -> uint256:
  """
  @notice Returns the approx result of `a * b / d` so long as the result is <= MAX_UINT
  @param _numA the first numerator term
  @param _numB the second numerator term
  @param _den the denominator
  @param _roundUp if true, the math may round the final value up from the exact expected value
  @return the approx result with up to off by 1 + 0.01% error
  @dev _roundUp is implemented by first rounding down and then adding the max error to the result
  """
  # first get the rounded down result
  value: uint256 = self._bigDiv2x1(_numA, _numB, _den)

  if(_roundUp):
    if(value == 0):
      # when the value rounds down to 0, assume up to an off by 1 error
      return 1

    # round down has a max error of 0.01%, add that to the result
    # for a round up error of <= 0.01%
    temp: uint256 = value - 1
    temp /= MAX_ERROR
    temp += 1
    if(MAX_UINT - value < temp):
      # value + error would overflow, return MAX
      return MAX_UINT

    value += temp

  return value

@public
@constant
def bigDiv2x2(
  _numA: uint256,
  _numB: uint256,
  _denA: uint256,
  _denB: uint256
) -> uint256:
  """
  @notice Returns the approx result of `a * b / (c * d)` so long as the result is <= MAX_UINT
  @param _numA the first numerator term
  @param _numB the second numerator term
  @param _denA the first denominator term
  @param _denB the second denominator term
  @return the approx result with up to off by 2 + 0.1% error
  @dev this uses bigDiv2x1 and adds additional rounding error so the max error of this formula is larger
  """
  if((MAX_UINT - 1) / _denA + 1 > _denB):
    # denA*denB does not overflow, use bigDiv2x1 instead
    return self._bigDiv2x1(_numA, _numB, _denA * _denB)

  if(_numA == 0 or _numB == 0):
    # would div by 0 or underflow if we don't special case 0
    return 0

  # Sort denominators
  denMax: uint256
  denMin: uint256
  if(_denA > _denB):
    denMax = _denA
    denMin = _denB
  else:
    denMax = _denB
    denMin = _denA

  value: uint256

  if(MAX_UINT / _numA >= _numB):
    # a*b does not overflow, use `a / d / c`
    value = _numA * _numB
    value /= denMin
    value /= denMax
    return value

  # `ab / cd` where both `ab` and `cd` would overflow

  # Sort numerators
  numMax: uint256
  numMin: uint256
  if(_numA > _numB):
    numMax = _numA
    numMin = _numB
  else:
    numMax = _numB
    numMin = _numA

  temp: uint256

  # formula = (a/d)*b/c
  temp = numMax / denMin
  if(temp > MAX_ERROR_BEFORE_DIV):
    return self._bigDiv2x1(temp, numMin, denMax)

  # formula: ((a/c) * b) / d or (a/c) * (b/d)
  value = numMax / denMax
  if(value > MAX_ERROR):
    # denMax is small enough to be 0.01% accurate or better w/o a factor
    if(MAX_UINT / value >= numMin):
      # multiply first won't overflow and limits rounding
      value *= numMin
      value /= denMin
      return value
    temp = numMin / denMin
    if(temp > MAX_ERROR):
      # denMin is small enough to be 0.01% accurate or better w/o a factor
      value *= temp
      return value

  factor: uint256

  # formula: ((a/f) * b) / d then either * f / c or / c * f
  # factor >= a / sqrt(MAX) * b / sqrt(MAX)
  factor = numMin - 1
  factor /= MAX_BEFORE_SQUARE
  factor += 1
  temp = numMax - 1
  temp /= MAX_BEFORE_SQUARE
  temp += 1
  if(MAX_UINT / factor >= temp):
    factor *= temp

    value = numMax / factor
    if(factor <= MAX_BEFORE_SQUARE or value > MAX_ERROR_BEFORE_DIV):
      value *= numMin
      value /= denMin
      if(value > 0):
        if(MAX_UINT / value >= factor):
          value *= factor
          value /= denMax
        else: # TODO remove this path?
          value /= denMax
          value *= factor
      return value

  # formula: (a/f) * b / ((c*d)/f)
  # factor >= c / sqrt(MAX) * d / sqrt(MAX)
  factor = denMin
  factor /= MAX_BEFORE_SQUARE + 1
  temp = denMax
  temp /= MAX_BEFORE_SQUARE + 1
  factor *= temp
  return self._bigDiv2x1(numMax / factor, numMin, MAX_UINT)
