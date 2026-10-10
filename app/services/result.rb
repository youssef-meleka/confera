Result = Data.define(:value, :error) do
  def self.success(value = nil) = new(value: value, error: nil)
  def self.failure(error)       = new(value: nil, error: error)

  def success? = error.nil?
  def failure? = !success?

  # Return the value, or raise the carried error (`save` vs `save!` convention)
  def value! = success? ? value : raise(error)
end