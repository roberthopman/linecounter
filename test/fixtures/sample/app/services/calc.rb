class Calc
  # rev: 2
  def initialize(items)
    @items = items
  end

  def total
    sum = 0
    @items.each do |item|
      next if item.nil?
      sum += item.price if item.price
      sum -= item.discount unless item.discount.zero?
    end
    sum
  end

  def classify(value)
    case value
    when 0 then :empty
    when 1..9 then :small
    else :large
    end
  end

  private

  def safe_divide(a, b)
    return 0 if b.zero?
    a / b
  rescue StandardError
    0
  end
end
