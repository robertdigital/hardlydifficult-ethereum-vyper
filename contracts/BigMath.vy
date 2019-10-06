# @title Reduces the size of terms before multiplication, to avoid an overflow, and then
# restores the proper size after division.  
# @notice This effectively allows us to overflow values in the numerator and/or denominator 
# of a fraction, so long as the end result does not overflow as well.
# @dev Each individual numerator or denominator term is reduced if large so that multiplication 
# is safe from overflow.  Then we perform the division using the reduced terms.  Finally the
# result is increased to restore the original scale of terms.

MAX_UINT: constant(uint256) = 2**256 - 1
# @notice The max possible value

MAX_BEFORE_SQUARE: constant(uint256) = 340282366920938463463374607431768211455
# @notice When multiplying 2 terms, the max value is 2^128-1
# @dev 340282366920938463463374607431768211456 is 1 too large for squaring

MAX_ERROR: constant(uint256) = 10000
MAX_ERROR_BEFORE_DIV: constant(uint256) = MAX_ERROR * 10

@private
@constant
def _bigDiv2x1(
  _numA: uint256,
  _numB: uint256,
  _den: uint256
) -> uint256:
  """
  @notice Multiply the numerators, scaling them down if there is potential for overflow, and then
  scale them back up after division.
  @param _numA the first numerator term
  @param _numB the second numerator term
  @param _den the denominator
  @param _roundUp if true, the math may round the final value up from the exact expected value
  @return the approximate value of _numA * _numB / _den
  @dev this will overflow if the final value is > MAX_UINT (and may overflow if ~MAX_UINT)
  rounding applies but should be close to the expected value
  if the expected value is small, a rounding error or 1 may be a large percent error
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
  # smallest possible factor gives best results
  # seems to work well up till ~2^128 and then rounding errors occur
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
  value: uint256 = self._bigDiv2x1(_numA, _numB, _den)
  if(_roundUp):
    # round down has a max error of 0.01%, add that to the result
    # for a round up error of <= 0.01%
    if(value > 0):
      temp: uint256 = value - 1
      temp /= MAX_ERROR
      temp += 1
      if(MAX_UINT - value <= temp):
        value = MAX_UINT
      else:
        value += temp
    else:
      value = 1
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
  @notice Multiply the numerators, scaling them down if there is potential for overflow.
  Multiply the denominators, scaling them down if there is potential for overflow.
  Then compute the fraction and scale the final value back up or down as appropriate.
  @param _numA the first numerator term
  @param _numB the second numerator term
  @param _denA the first denominator term
  @param _denB the second denominator term
  @return the approximate value of _numA * _numB / (_denA * _denB)
  @dev rounds down by default. Comments from bigDiv2x1 apply here as well.
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

  # TODO this could overflow... hmm
  # maybe div with max uint and use that to determine the remainder as the factor
  factor = denMin
  factor /= MAX_BEFORE_SQUARE + 1
  temp = denMax
  temp /= MAX_BEFORE_SQUARE + 1
  if(MAX_UINT / factor >= temp):
    factor *= temp
    return self._bigDiv2x1(numMax / factor, numMin, MAX_UINT)
    
  return 42 # TODO
  # factor = denMin - 1
  # factor /= numMax
  # factor += 1
  # factor *= MAX_ERROR
  # temp = denMin - 1
  # temp /= factor
  # temp += 1
  # value = numMax / temp
  # temp = denMax
  # if(MAX_UINT / temp >= factor):
  #   temp *= factor
  #   return self._bigDiv2x1(value, numMin, temp)
  # else:
  #   value = self._bigDiv2x1(value, numMin, temp)
  #   value *= factor
  #   return value
  # formula: (a/(c/f)) * (b/(d/f))
  # factor: d / sqrt(MAX)
  # factor = denMin - 1
  # factor /= MAX_BEFORE_SQUARE
  # factor += 1

  # temp = denMax - 1
  # temp /= factor
  # temp += 1
  # value = numMax / temp
  # temp = denMin - 1
  # temp /= factor
  # temp += 1
  # temp = numMin / temp
  # value *= temp
  # return value
