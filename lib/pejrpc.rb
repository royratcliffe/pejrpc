require 'net/http'
require 'addressable/uri'
require 'openssl'
require 'base64'
require 'json'

require 'pejrpc/exceptions'

module PejRPC
  class RSATranscoder
    attr_reader :rsa
    
    def initialize(pem)
      @rsa = OpenSSL::PKey::RSA.new(pem)
    end
    
    def encrypt(data)
      @rsa.send(@rsa.private? ? :private_encrypt : :public_encrypt, data)
    end
    
    def decrypt(data)
      @rsa.send(@rsa.private? ? :private_decrypt : :public_decrypt, data)
    end
    
    def object_to_body(object)
      Base64.encode64(encrypt(object.to_json))
    end
    
    def body_to_object(body)
      JSON.parse(decrypt(Base64.decode64(body)))
    end
  end
  
  class Server < RSATranscoder
    def initialize(pem)
      super(pem)
    end
    
    def handle(request)
      request_object = body_to_object(request.body.read)
      request_object
    end
  end
  
  # The RPC client-side object. Something on the client-side that you post requests to.
  class Client < RSATranscoder
    # Note that your URL needs a path component. That means you need a trailing slash if you have no path. Otherwise Ruby will raise an 'HTTP request path is empty' exception.
    def initialize(url, pem)
      @address = Addressable::URI.parse(url)
      super(pem)
    end
    
    # Parameters are optional. If none provided, the request object omits parameters entirely. Parameters can contain an array or a hash. You should never send a primitive as the +params+ argument.
    def post(method, params = nil)
      request_object = {:method => method.to_s, :jsonrpc => '2.0'}
      request_object.merge!(:params => params) if params
      
      # Send an HTTP POST request.
      response = Net::HTTP.start(@address.host, @address.port) do |http|
        http.post(@address.path, object_to_body(request_object))
      end
      
      # Handle the response. Response code 200 is the normal response.
      case response.code.to_i
      when 200...400
        
      else
        raise(ConnectionError.new(response))
      end
      
      response_object = body_to_object(response.body)
      response_object
    end
  end
end
