# Leaving the linting errors aside, the first issue is that there is no
# frozen_string_literal directive. Each time #call is evaluated, it allocates a
# new copy of the "HTTP_AUTHORIZATION", 'swagger' and 'favicon.ico' strings.
#
# There is a missing dependency on the JSON gem, for which there is no require
# statement.
#
# There is a missing dependency on a Log class, for which there is no require
# statement (and is not defined).

# The class has no documentation, nor do any of the methods.
class LogRequestsMiddleware
  # No documentation. From context, it looks like this class is intended to be
  # Rack middleware, and by implication app is a Rack application. There is no
  # handling here if an invalid object is passed in.
  def initialize(app)
    @app = app
  end

  # No documentation.
  def call(env)
    # The requirements for a Rack environment can be found here:
    # https://github.com/rack/rack/blob/main/SPEC.rdoc
    # However, there is no validation for the passed in environment.
    status, headers, response = @app.call(env)
    request = Rack::Request.new(env)
    request_body = request.body.read
    # The first potential issue is handling empty responses. For example, a HEAD
    # request could return [200, {}, []] from #call. See Rack::Head#call.
    # However, when we call #log_request_and_response!, we are passing in the
    # *first* item in the returned response, which can potentially be nil. This
    # will raise an exception.
    #
    # Also important to note is that we are passing the value of
    # env["HTTP_AUTHORIZATION"] to our logger. This means that user
    # authorization tokens or other sensitive values are being printed to our
    # logs. This is very bad security practice; if we need to log any headers,
    # we should be explicitly excluding the HTTP_AUTHORIZATION header.
    log_request_and_response!(request: request_body, headers: env["HTTP_AUTHORIZATION"], url: request.path, response: response.first)


    [status, headers, response]
  end

  # From context, this should be a private method.
  #
  # No documentation.
  def log_request_and_response!(request:, headers:, url:, response:)
    return if ['swagger', 'favicon.ico'].include?(url)
    # We need to handle the case when a non-empty request body is passed in that
    # is not valid JSON. The body could be malformed or not in a JSON format.
    # Ideally our middleware should not be tied to a specific request format,
    # but assuming that JSON is the only format we need to handle, we should
    # probably define a wrapper method to safely parse the string and either
    # return the parsed value or nil if the string is not valid. At a minimum,
    # we should be catching JSON::ParserError at the bottom of this method.
    request = JSON.parse(request) unless request.empty?
    # Per above, calling #log_request_and_response! when the response body is
    # empty will pass in nil as the value of response, which will then fail when
    # response.empty? is called (with a NoMethodError). We need an explicit
    # check here for the nil case.
    #
    # Likewise, we need to handle the case where the response is not nil or
    # empty but not a valid JSON representation.
    response = JSON.parse(response) unless response.empty?
    Log.create!(
      request: request,
      headers: headers,
      url: url,
      response: response
    )
  end
end
