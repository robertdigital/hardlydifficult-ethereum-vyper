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

@private
@constant
def _bigDiv2x1(
  _numA: uint256,
  _numB: uint256,
  _den: uint256,
  _roundUp: bool # TODO
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
    # would underflow if we don't special case 0
    return 0

  value: uint256
  temp: uint256

  if(MAX_UINT / _numA >= _numB):
    # a*b does not overflow, return exact math
    value = _numA * _numB
    if(_roundUp):
      # (x - 1) / y + 1 == roundUp(x/y) using int math
      value -= 1
      value /= _den
      value += 1
    else:
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

  if(numMax / _den > 10000):
    # _den is small enough to be 0.01% accurate or better w/o a factor
    # this is required for values > 1000000000000 otherwise rounding errors occur
    if(_roundUp):
      value = numMax - 1
      value /= _den
      value += 1
    else:
      value = numMax / _den
    value *= numMin
    return value

  # formula = ((a / f) * b) / (d / f)
  # factor >= a / sqrt(MAX) * b / sqrt(MAX)
  factorMul: uint256 = numMin - 1
  factorMul /= MAX_BEFORE_SQUARE
  factorMul += 1
  temp = numMax - 1
  temp /= MAX_BEFORE_SQUARE
  temp += 1
  if(MAX_UINT / factorMul >= temp):
    factorMul *= temp
  else:
    factorMul = MAX_UINT

  if(factorMul <= MAX_BEFORE_SQUARE):
    value = numMax / factorMul
    value *= numMin
    temp = _den - 1
    temp /= factorMul
    temp += 1
    value /= temp
    return value

  # formula = a / (d / f) * (b / f)
  # factor >= MAX / a * (d / b)
  # then max with max(d, a) / sqrt(MAX) to help with rounding errors
  factorDiv: uint256 = MAX_UINT - 1
  factorDiv /= numMax
  factorDiv += 1
  temp = _den - 1
  temp /= numMin
  temp += 1
  if(MAX_UINT / factorDiv >= temp):
    factorDiv *= temp
  else:
    factorDiv = MAX_UINT

  # formula = a / (d / f) * b / f
  # factor = guess
  factor:uint256 = factorDiv
  if(numMax >= _den):
    factor = MAX_UINT # test: this if condition only ever ensured that factor is not used below
  elif(numMax/numMin >= _den/numMax): # TODO > or >=? Round up has no impact it seems
    factor = MAX_UINT # test: this if condition only ever ensured that factor is not used below
  factor = max(2**64, factor) # this also works with a wide range of values

  # guess to help with rounding errors
  factorDiv = max(factorDiv, max(_den, numMax) / MAX_BEFORE_SQUARE)
  
  temp = (_den - 1) / factor + 1
  value = numMax / temp

  if(factor < factorDiv and MAX_UINT / value >= numMin): # value * numMin won't overflow
    # formula: a / (d / f) * b / f
    if(_roundUp):
      temp = _den / factor
      value = numMax - 1
      value /= temp
      value += 1
      value *= numMin
      value -= 1
      value /= factor
      value += 1
    else:
      temp = _den - 1
      temp /= factor
      temp += 1
      value = numMax / temp
      value *= numMin
      value /= factor
    return value

  # formula: (a / (d / f)) * (b / f)
  if(_roundUp):
    value = numMin - 1
    value /= factorDiv
    value += 1
    temp = _den / factorDiv
    temp = (numMax - 1) / temp
    temp += 1
  else:
    value = numMin / factorDiv
    temp = _den - 1
    temp /= factorDiv
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
  _roundUp: bool # TODO
) -> uint256:
  return self._bigDiv2x1(_numA, _numB, _den, _roundUp)

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
    return self._bigDiv2x1(_numA, _numB, _denA * _denB, False)

  if(_numA == 0 or _numB == 0):
    return 0

  # Find max value
  value: uint256 = _numA
  if(_numB > value):
    value = _numB
  if(_denA > value):
    value = _denA
  if(_denB > value):
    value = _denB
  
  # Use max to determine factor to use
  factor: uint256 = value / MAX_BEFORE_SQUARE 
  if(factor == 0 or factor >= MAX_BEFORE_SQUARE / 2):
    factor += 1
  
  count: int128 = 0
  
  # Numerator
  if(_numA >= MAX_BEFORE_SQUARE):
    value = _numA / factor
    count += 1
  else:
    value = _numA
  if(_numB >= MAX_BEFORE_SQUARE):
    value *= _numB / factor
    count += 1
  else:
    value *= _numB

  # Denominator
  den: uint256
  if(_denA >= MAX_BEFORE_SQUARE):
    den = (_denA - 1) / factor + 1
    count -= 1
  else:
    den = _denA
  if(_denB >= MAX_BEFORE_SQUARE):
    den *= (_denB - 1) / factor + 1
    count -= 1
  else:
    den *= _denB
  
  # Faction
  value /= den

  # Scale back up/down
  if(count == 1):
    value *= factor
  elif(count == 2):
    value *= factor * factor
  elif(count == -1):
    value /= factor
  elif(count == -2):
    value /= factor * factor

  return value
