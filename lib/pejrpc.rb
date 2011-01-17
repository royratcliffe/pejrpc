# standard library dependencies
require 'net/http'
require 'openssl'
require 'base64'

# external gem dependencies
require 'addressable/uri'
require 'json'

require 'pejrpc/exceptions'

module PejRPC
  # Handles the enciphering and deciphering, encapsulating three essential
  # pieces of information: the key, the initialisation vector and the cipher
  # text itself.
  #
  # You can use the CipherText class as follows.
  #
  # cipher_text = PejRPC::CipherText.new
  # cipher_text.encipher('hello')
  # p cipher_text.key
  # p cipher_text.iv
  # p cipher_text.text
  # p cipher_text.decipher
  #
  # Note, enciphering first sets up the key, initialisation vector and
  # enciphered text. If not already assigned, the key and initialisation vector
  # derive randomly from the cipher algorithm.
  class CipherText
    attr_accessor :key, :iv, :text
    
    def new_cipher
      OpenSSL::Cipher::Cipher.new('aes-256-cbc')
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
  
  # Wraps a public or private RSA key.
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
    # public key from the private. Key the private key secret.
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
    
    def object_from_request(request)
      JSON.parse(text_from_body_and_header(request.body.read, request.headers))
    end
    
    def object_from_response(response)
      JSON.parse(text_from_body_and_header(response.body, response.header))
    end
    
    def body_and_header_from_object(object)
      body_and_header_from_text(object.to_json)
    end
  end
  
  class Server
    attr_reader :key
    
    def initialize(pem)
      @key = Key.new(pem)
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
