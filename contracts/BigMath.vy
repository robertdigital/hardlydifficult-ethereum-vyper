# @title Reduces the size of terms before multiplication, to avoid an overflow, and then
# restores the proper size after division.  
# @notice This effectively allows us to overflow values in the numerator and/or denominator 
# of a fraction, so long as the end result does not overflow as well.
# @dev Each individual numerator or denominator term is reduced if large so that multiplication 
# is safe from overflow.  Then we perform the division using the reduced terms.  Finally the
# result is increased to restore the original scale of terms.

MAX_UINT: constant(uint256) = 2**256 - 1
# @notice The max possible value

MAX_BEFORE_SQUARE: constant(uint256) = 340282366920938463463374607431768211456
# @notice When multiplying 2 terms, the max value is sqrt(2^256-1) 
# @dev 340282366920938463463374607431768211456 is 1 too large for squaring

@public
@constant
def bigDiv2x1(
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
  if(_numA == 0 or _numB == 0): # would underflow if we don't special case 0
    return 0
  if((MAX_UINT - 1) / _numA + 1 > _numB): # a*b does not overflow, return exact math
    if(_roundUp):
      return (_numA * _numB - 1) / _den + 1
    else:
      return _numA * _numB / _den
  
  # Sort numerators
  numMax: uint256
  numMin: uint256
  if(_numA > _numB):
    numMax = _numA
    numMin = _numB
  else:
    numMax = _numB
    numMin = _numA

  if(numMax / _den > 1000000000000):
    # _den is small enough to be 0.0000000001% accurate or better w/o a factor
    # TODO increase before launch to 0.01%, just testing with lower values
    return numMax / _den * numMin

  # formula = a / (d / f) * (b / f)
  # factor = MAX / a * (d / b) - then max with max(d, a) / sqrt(MAX)
  factorDiv: uint256 = (MAX_UINT - 1) / numMax + 1
  if((MAX_UINT - 1) / factorDiv + 1 > (_den - 1) / numMin + 1):
    factorDiv *= (_den - 1) / numMin + 1
  else:
    factorDiv = MAX_UINT

  # formula = a / (d / f) * b / f
  # factor = guess
  factor:uint256 = factorDiv
  if(numMax >= _den):
    factor = (MAX_UINT - 1)/numMax + 1
  elif(numMax/numMin >= _den/numMax): # TODO > or >=? Round up has no impact it seems
    factor /= 2
  factor = max(2**64, factor) 

  # guess
  factorDiv = max(factorDiv, max(_den, numMax) / MAX_BEFORE_SQUARE)

  # formula = a / f * (b / (d / f))
  # factor = a / sqrt(MAX) * b / sqrt(MAX)
  factorMul: uint256 = ((numMin - 1) / (MAX_BEFORE_SQUARE-1)+1)
  if((MAX_UINT - 1) / factorMul + 1 > ((numMax - 1) / (MAX_BEFORE_SQUARE-1)+1)):
    factorMul *= ((numMax - 1) / (MAX_BEFORE_SQUARE-1)+1)
  else:
    factorMul = MAX_UINT

  if(factorMul < 2**64 or factorMul <= max(factorDiv, factor)):
    return numMax / factorMul * numMin / ((_den - 1) / factorMul + 1)
  
  den: uint256 = (_den - 1) / factor + 1
  value: uint256 = numMax / den

  if(factor < factorDiv and (MAX_UINT - 1) / value + 1 > numMin): # value * numMin won't overflow
    return value * numMin / factor
  return numMin / factorDiv * (numMax / ((_den - 1) / factorDiv + 1))

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
  if(_numA == 0 or _numB == 0):
    return 0
  if(MAX_UINT / _numA > _numB and MAX_UINT / _denA > _denB):
    return _numA * _numB / (_denA * _denB)

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
