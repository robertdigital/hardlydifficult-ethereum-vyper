# @title Reduces the size of terms before multiplication, to avoid an overflow, and then
# restores the proper size after division.  
# @notice This effectively allows us to overflow values in the numerator and/or denominator 
# of a fraction, so long as the end result does not overflow as well.

MAX_UINT: constant(uint256) = 2**256 - 1
# @notice The max possible value

MAX_BEFORE_SQUARE: constant(uint256) = 2**128 - 1
# @notice When multiplying 2 terms <= this value the result won't overflow

MAX_ERROR: constant(uint256) = 100000000
# @notice The max error target is off by 1 plus up to 0.000001% error for 2x1 and that `* 2` for 2x2

MAX_ERROR_BEFORE_DIV: constant(uint256) = MAX_ERROR * 2
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
  @return the approx result with up to off by 1 + MAX_ERROR, rounding down if needed
  """
  if(_numA == 0 or _numB == 0):
    # would div by 0 or underflow if we don't special case 0
    return 0

  value: uint256 = 0

  if(MAX_UINT / _numA >= _numB):
    # a*b does not overflow, return exact math
    value = _numA * _numB
    value /= _den
    return value

  # Sort numerators
  numMax: uint256 = _numB
  numMin: uint256 = _numA
  if(_numA > _numB):
    numMax = _numA
    numMin = _numB

  value = numMax / _den
  if(value > MAX_ERROR):
    # _den is small enough to be MAX_ERROR or better w/o a factor
    value *= numMin
    return value

  # formula = ((a / f) * b) / (d / f)
  # factor >= a / sqrt(MAX) * (b / sqrt(MAX))
  factor: uint256 = numMin - 1
  factor /= MAX_BEFORE_SQUARE
  factor += 1
  temp: uint256 = numMax - 1
  temp /= MAX_BEFORE_SQUARE
  temp += 1
  if(MAX_UINT / factor >= temp):
    factor *= temp
    value = numMax / factor
    if(value > MAX_ERROR_BEFORE_DIV):
      value *= numMin
      temp = _den - 1
      temp /= factor
      temp += 1
      value /= temp
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
  @return the approx result with up to off by 1 + MAX_ERROR, rounding down if needed
  @dev _roundUp is implemented by first rounding down and then adding the max error to the result
  """
  # first get the rounded down result
  value: uint256 = self._bigDiv2x1(_numA, _numB, _den)

  if(_roundUp):
    if(value == 0):
      # when the value rounds down to 0, assume up to an off by 1 error
      return 1

    # round down has a max error of MAX_ERROR, add that to the result
    # for a round up error of <= MAX_ERROR
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
  @return the approx result with up to off by 2 + MAX_ERROR*10 error, rounding down if needed
  @dev this uses bigDiv2x1 and adds additional rounding error so the max error of this formula is larger
  """
  if(MAX_UINT / _denA >= _denB):
    # denA*denB does not overflow, use bigDiv2x1 instead
    return self._bigDiv2x1(_numA, _numB, _denA * _denB)

  if(_numA == 0 or _numB == 0):
    # would div by 0 or underflow if we don't special case 0
    return 0

  # Sort denominators
  denMax: uint256 = _denB
  denMin: uint256 = _denA
  if(_denA > _denB):
    denMax = _denA
    denMin = _denB

  value: uint256 = 0

  if(MAX_UINT / _numA >= _numB):
    # a*b does not overflow, use `a / d / c`
    value = _numA * _numB
    value /= denMin
    value /= denMax
    return value

  # `ab / cd` where both `ab` and `cd` would overflow

  # Sort numerators
  numMax: uint256 = _numB
  numMin: uint256 = _numA
  if(_numA > _numB):
    numMax = _numA
    numMin = _numB

  # formula = (a/d) * b / c
  temp: uint256 = numMax / denMin
  if(temp > MAX_ERROR_BEFORE_DIV):
    return self._bigDiv2x1(temp, numMin, denMax)

  # formula: ((a/f) * b) / d then either * f / c or / c * f
  # factor >= a / sqrt(MAX) * (b / sqrt(MAX))
  factor: uint256 = numMin - 1
  factor /= MAX_BEFORE_SQUARE
  factor += 1
  temp = numMax - 1
  temp /= MAX_BEFORE_SQUARE
  temp += 1
  if(MAX_UINT / factor >= temp):
    factor *= temp

    value = numMax / factor
    if(value > MAX_ERROR_BEFORE_DIV):
      value *= numMin
      value /= denMin
      if(value > 0):
        if(MAX_UINT / value >= factor):
          value *= factor
          value /= denMax
          return value

  # formula: (a/f) * b / ((c*d)/f)
  # factor >= c / sqrt(MAX) * (d / sqrt(MAX))
  factor = denMin
  factor /= MAX_BEFORE_SQUARE
  temp = denMax
  # + 1 here prevents overflow of factor*temp
  temp /= MAX_BEFORE_SQUARE + 1
  factor *= temp
  return self._bigDiv2x1(numMax / factor, numMin, MAX_UINT)
