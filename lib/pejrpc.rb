# standard library dependencies
require 'net/http'
require 'openssl'
require 'base64'

# external gem dependencies
require 'addressable/uri'
require 'json'

require 'pejrpc/exceptions'

module PejRPC
  # Handles enciphering and deciphering, encapsulating three essential pieces of
  # information: the key, the initialisation vector and the cipher text itself.
  #
  # You can use the CipherText class as follows.
  #
  #   cipher_text = PejRPC::CipherText.new
  #   cipher_text.encipher('hello')
  #   p cipher_text.key
  #   p cipher_text.iv
  #   p cipher_text.text
  #
  # Note, enciphering first sets up the key, initialisation vector and
  # enciphered text. If not already assigned, the key and initialisation vector
  # derive randomly from the cipher algorithm.
  #
  # You can use the key and initialisation vector subsequently to decipher the original text.
  #
  #   p cipher_text.decipher
  #
  class CipherText
    attr_accessor :key, :iv, :text
    
    def new_cipher
      OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    end
    
    def encipher(text)
      cipher = new_cipher
      cipher.encrypt
      
      @key ||= cipher.random_key
      @iv ||= cipher.random_iv
      
      cipher.key = @key
      cipher.iv = @iv
      
      @text = cipher.update(text)
      @text << cipher.final
      @text
    end
    
    def decipher
      cipher = new_cipher
      cipher.decrypt
      
      cipher.key = @key
      cipher.iv = @iv
      
      text = cipher.update(@text)
      text << cipher.final
      text
    end
  end
  
  # Wraps a public or private RSA key. The key encrypts and decrypts
  # information, doing so either privately or publicly depending on the
  # underlying key: privately for private keys, publicly for public keys.
  class Key
    attr_reader :rsa
    
    def initialize(pem)
      @rsa = OpenSSL::PKey::RSA.new(pem)
    end
    
    def private?
      @rsa.private?
    end
    
    # Answers the encryption method, either private or public. Which one depends
    # on the RSA key. If a private key, encrypt_method answers the name of the
    # private encryption method, public otherwise. Note, you can generate the
    # public key from the private. Keep the private key secret.
    def encrypt_method
      private? ? :private_encrypt : :public_encrypt
    end
    
    def decrypt_method
      private? ? :private_decrypt : :public_decrypt
    end
    
    def encrypt(text)
      @rsa.send(encrypt_method, text)
    end
    
    def decrypt(data)
      @rsa.send(decrypt_method, data)
    end
    
    # Converts the given +data+ to a string representing the data exactly. Use
    # the pack(string) method to reverse the encoding. The encoding makes some
    # assumptions about the size of the data. It assumes units of 32-bit blocks.
    def unpack(data)
      data.unpack('N*').collect { |n| n.to_s(36) }.join(':')
    end
    
    def pack(string)
      string.split(':').collect { |s| s.to_i(36) }.pack('N*')
    end
    
    # body, header <-- text
    def body_and_header_from_text(text)
      cipher_text = CipherText.new
      cipher_text.encipher(text)
      return Base64::encode64(cipher_text.text), {'key' => unpack(encrypt(cipher_text.key)), 'iv' => unpack(encrypt(cipher_text.iv))}
    end
    
    # text <-- body, header
    def text_from_body_and_header(body, header)
      cipher_text = CipherText.new
      cipher_text.key = decrypt(pack(header['key']))
      cipher_text.iv = decrypt(pack(header['iv']))
      cipher_text.text = Base64::decode64(body)
      cipher_text.decipher
    end
    
    # Answers a request object given a Rails request.
    def object_from_request(request)
      # Why send request.body.read? The request body is a StringIO instance, not
      # String instance.
      JSON.parse(text_from_body_and_header(request.body.read, request.headers))
    end
    
    # Answers a response object given a Rails response.
    def object_from_response(response)
      JSON.parse(text_from_body_and_header(response.body, response.header))
    end
    
    def body_and_header_from_object(object)
      body_and_header_from_text(object.to_json)
    end
  end
  
  class Server
    attr_accessor :delegate
    attr_reader :key
    
    def initialize(delegate, pem)
      @delegate = delegate
      @key = Key.new(pem)
    end
    
    # In Rails, do something like this:
    #
    #   def post
    #     server = PejRPC::Server.new(self, File.read(Rails.root.join('config', 'private.pem')))
    #     body, headers = server.handle(request)
    #   
    #     response.headers.merge!(headers)
    #     render :text => body
    #   end
    #
    # This is a +post+ action tied to a POST request via the Rails router. It
    # starts a new server and asks it to handle the request. The server extracts
    # the request object from the given request. That includes headers as well
    # as the request body. It then delegates the request and prepares the
    # response body and headers. After handling, merge the headers with the
    # response headers and render the body as text within the response.
    def handle(request)
      request_object = @key.object_from_request(request)
      response_object = delegate.send(request_object['method'], request_object['params'])
      @key.body_and_header_from_object(response_object)
    end
  end
  
  # The RPC client-side object. Something on the client-side that you post
  # requests to.
  class Client
    attr_reader :key
    
    # Note that your URL needs a path component. That means you need a trailing
    # slash if you have no path. Otherwise Ruby will raise an 'HTTP request path
    # is empty' exception.
    def initialize(url, pem)
      @address = Addressable::URI.parse(url)
      @key = Key.new(pem)
    end
    
    # Parameters are optional. If none provided, the request object omits
    # parameters entirely. Parameters can contain an array or a hash. You should
    # never send a primitive as the +params+ argument.
    def post(method, params = nil)
      request_object = {:method => method.to_s, :jsonrpc => '2.0'}
      request_object.merge!(:params => params) if params
      
      # Send an HTTP POST request.
      response = Net::HTTP.start(@address.host, @address.port) do |http|
        body, header = @key.body_and_header_from_object(request_object)
        http.post(@address.path, body, header)
      end
      
      # Handle the response. Response code 200 is the normal response.
      case response.code.to_i
      when 200...400
        
      else
        raise ConnectionError, response
      end
      
      response_object = @key.object_from_response(response)
      response_object
    end
  end
end
