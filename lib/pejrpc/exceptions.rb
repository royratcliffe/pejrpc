module PejRPC
  class ConnectionError < StandardError # :nodoc:
    attr_reader :response
    
    def initialize(response)
      @response = response
    end
    
    def to_s
      message = "Failed."
      message << " Response code #{response.code}." if response.respond_to?(:code)
      message << " #{response.message.strip}." if response.respond_to?(:message)
      message
    end
  end
end
