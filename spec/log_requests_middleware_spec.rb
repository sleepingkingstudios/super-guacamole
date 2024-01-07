# frozen_string_literal: true

require 'stringio'

require 'json'
require 'rack'

require 'log_requests_middleware'

# Defining a Log class for the purposes of testing.
class Log
  def self.create!(**); end
end

class MockApplication
  # @param responses [Array<Array>] the configured responses for the
  #   application.
  def initialize(*responses)
    @responses = responses
  end

  # Removes and returns the next configured response.
  #
  # @return [Array] the next configured response.
  #
  # @raise RuntimeError if there are no remaining configured responses.
  def call(_)
    raise RuntimeError, 'no configured responses' if @responses.empty?

    @responses.shift
  end
end

RSpec.describe LogRequestsMiddleware do
  subject(:middleware) { described_class.new(app) }

  let(:status) { 200 }
  let(:headers) { {} }
  let(:body) { [''] }
  let(:app) { MockApplication.new([status, headers, body]) }

  describe '#call' do
    let(:env) do
      # @see https://github.com/rack/rack/blob/main/SPEC.rdoc
      {
        'REQUEST_METHOD' => 'GET',
        'rack.errors' => StringIO.new,
        'rack.hijack?' => false,
        'rack.input' => StringIO.new,
        'rack.url_scheme' => 'http'
      }
    end

    before(:example) { allow(Log).to receive(:create!) }

    describe 'with an invalid request body' do
      let(:request_body) { 'Greetings, programs!' }
      let(:env) { super().merge('rack.input' => StringIO.new(request_body)) }

      it 'does not raise an exception' do
        pending 'Identified issue in provided code'

        expect { middleware.call(env) }.not_to raise_error JSON::ParserError
      end
    end

    describe 'with a valid request body' do
      let(:request_body) do
        JSON.generate({ 'message' => 'Greetings, programs!' })
      end
      let(:env) { super().merge('rack.input' => StringIO.new(request_body)) }

      it { expect { middleware.call(env) }.not_to raise_error }

      it 'creates a log entry' do
        middleware.call(env)

        # This unit test should validate the parameters passed to Log.create!,
        # but these assertions are boilerplate and omitted for purposes of time.
        expect(Log).to have_received(:create!)
      end
    end

    describe 'with an empty response body' do
      let(:body) { [] }

      it 'does not raise an exception' do
        pending 'Identified issue in provided code'

        expect { middleware.call(env) }.not_to raise_error NoMethodError
      end
    end

    describe 'with an invalid response body' do
      let(:body) { ['Greetings, programs!'] }

      it 'does not raise an exception' do
        pending 'Identified issue in provided code'

        expect { middleware.call(env) }.not_to raise_error JSON::ParserError
      end
    end

    describe 'with a valid response body' do
      let(:response_body) do
        JSON.generate({ 'message' => 'Greetings, programs!' })
      end
      let(:body) { [response_body] }

      it { expect { middleware.call(env) }.not_to raise_error }

      it 'creates a log entry' do
        middleware.call(env)

        # This unit test should validate the parameters passed to Log.create!,
        # but these assertions are boilerplate and omitted for purposes of time.
        expect(Log).to have_received(:create!)
      end
    end
  end
end
