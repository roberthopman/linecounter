module Util
  module_function

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def present?(value)
    !blank?(value)
  end
end
