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

DIGITS_UINT: constant(uint256) = 10 ** 18
# @notice Represents 1 full token (with 18 decimals)

DIGITS_DECIMAL: constant(decimal) = convert(DIGITS_UINT, decimal)
# @notice Represents 1 full token (with 18 decimals)

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
  
  if(_den <= MAX_BEFORE_SQUARE): # _den is small enough we don't need to factor
    return numMax / _den * numMin

  factor:uint256

  factor = _den / MAX_BEFORE_SQUARE # round up seems to make no difference

  if(numMax >= _den):
    factor = min(factor, MAX_UINT/numMax)
  
  if(numMax/numMin < _den/numMax):
    factor = max(factor, (MAX_UINT - 1)/numMax + 1) # Round down overflows

  factor = max(2**32 - 1, factor)
  
  # scale down the den 
  den: uint256 = (_den - 1) / factor + 1

  # take the larger value and the scaled down den to minimize rounding
  value: uint256 = numMax / den

  if((MAX_UINT - 1) / value + 1 > numMin):
    return value * numMin / factor
  
  if(value >= numMin):
    return value / factor * numMin

  # then use the smaller value and the factor to scale back up
  value *= numMin / factor
  
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

@public
@constant
def sqrtOfTokensSupplySquared(
  _tokenValue: uint256,
  _supply: uint256
) -> uint256:
  """
  @notice Calculates sqrt((_tokenValue + _supply^2)/10^18)*10^18
  """
  tokenValue: uint256 = _tokenValue

  # Math: max supply^2 given the hard-cap is 1e56 leaving room for the max tokenValue (equal to the FAIR hard-cap)
  tokenValue += _supply * _supply

  # Math: Truncates last 18 digits from tokenValue here
  tokenValue /= DIGITS_UINT

  # Math: Truncates another 8 digits from tokenValue (losing 26 digits in total)
  # This will cause small values to round to 0 tokens for the payment (the payment is still accepted)
  # Math: Max supported tokenValue is 1.7e+56. If supply is at the hard-cap tokenValue would be 1e38, leaving room
  # for a _currencyValue up to 1.7e33 (or 1.7e15 after decimals)

  temp: uint256 = tokenValue / DIGITS_UINT
  decimalValue: decimal = convert(tokenValue - temp * DIGITS_UINT, decimal)
  decimalValue /= DIGITS_DECIMAL
  decimalValue += convert(temp, decimal)

  decimalValue = sqrt(decimalValue)

  # Unshift results
  # Math: decimalValue has a max value of 2^127 - 1 which after sqrt can always be multiplied
  # here without overflow
  decimalValue *= DIGITS_DECIMAL

  tokenValue = convert(decimalValue, uint256)

  return tokenValue
