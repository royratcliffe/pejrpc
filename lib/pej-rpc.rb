require 'net/http'
require 'addressable/uri'
require 'openssl'
require 'base64'
require 'json'

require 'pej-rpc/exceptions'

module PejRPC
  
  # The RPC client-side object. Something on the client-side that you post requests to.
  class Client
    
    # Note that your URL needs a path component. That means you need a trailing slash if you have no path. Otherwise Ruby will raise an 'HTTP request path is empty' exception.
    def initialize(url)
      @address = Addressable::URI.parse(url)
    end
    
    # Parameters are optional. If none provided, the request object omits parameters entirely. Parameters can contain an array or a hash. You should never send a primitive as the +params+ argument.
    def post(method, params = nil)
      request_object = {:method => method.to_s, :jsonrpc => '2.0'}
      request_object.merge!(:params => params) if params
      
      # Send an HTTP POST request.
      response = Net::HTTP.start(@address.host, @address.port) do |http|
        http.post(@address.path, Base64.encode64(request_object.to_json))
      end
      
      # Handle the response. Response code 200 is the normal response.
      case response.code.to_i
      when 200...400
        
      else
        raise(ConnectionError.new(response))
      end
      
      response_object = JSON.parse(response.body)
      response_object
    end
    
  end
  
end
