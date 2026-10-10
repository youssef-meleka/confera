class ApplicationController < ActionController::API
  # rescue_from handlers are matched from the BOTTOM up: the last one declared
  # that matches wins. Broadest first, most specific last.

  rescue_from StandardError do |exception|
    Rails.logger.error("#{exception.class}: #{exception.message}\n#{exception.backtrace&.first(15)&.join("\n")}")
    Rails.error.report(exception, handled: true)
    message = Rails.env.production? ? "Internal server error" : "#{exception.class}: #{exception.message}"
    render_error Confera::InternalError.new(message)
  end

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error Confera::BadRequest.new("Malformed request body")
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_error Confera::BadRequest.new(e.message)
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    render_error Confera::RecordNotFound.new("#{e.model || 'Record'} not found")
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render_error Confera::ValidationFailed.new(e.record)
  end

  # Never pass e.message through: it contains raw SQL and index names
  rescue_from ActiveRecord::RecordNotUnique do
    render_error Confera::Conflict.new("Record already exists")
  end

  rescue_from Confera::Error do |e|
    render_error e
  end

  # Target of the catch-all route, so unknown URLs get the same envelope
  def route_not_found
    raise Confera::RecordNotFound, "No route matches #{request.method} #{request.path}"
  end

  private

  def render_error(error)
    render json: {
      error: {
        code: error.code,
        message: error.message,
        details: error.details,
        request_id: request.request_id
      }.compact
    }, status: error.status
  end
end
