Result = Data.define(:value, :error) do
  def self.success(value = nil) = new(value: value, error: nil)
  def self.failure(code, message) = new(value: nil, error: { code: code, message: message })

  def success? = error.nil?
  def failure? = !success?
end