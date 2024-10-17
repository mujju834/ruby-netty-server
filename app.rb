# app.rb
require 'sinatra'
require 'net/http'
require 'uri'
require 'dotenv'
require 'json'

# Load environment variables from .env (if available)
if File.exist?('.env')
  Dotenv.load
  puts ".env file loaded successfully"
else
  puts ".env file not found, using system environment variables."
end

API_GATEWAY_URL = ENV['API_GATEWAY_URL']
SERVER_PORT = ENV['PORT'] || '3999'

puts "API_GATEWAY_URL: #{API_GATEWAY_URL}"
puts "SERVER_PORT: #{SERVER_PORT}"

# Helper method to set CORS headers
def set_cors_headers(response)
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS, PUT, DELETE'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Range'
end

# Helper method to copy headers (excluding CORS headers to avoid duplication)
def copy_headers(source_headers, target_headers)
  source_headers.each do |key, value|
    next if ['Access-Control-Allow-Origin', 'Access-Control-Allow-Methods', 'Access-Control-Allow-Headers'].include?(key)
    target_headers[key] = value
  end
end

# Route to handle requests
before do
  set_cors_headers(response) # Set CORS headers for all responses
end

# Root endpoint with a custom response
get '/' do
  content_type 'text/plain'
  status 200
  'Netty server deployed by Mujahid in Ruby'
end

# Handle CORS preflight requests
options '*' do
  200
end

post '/api/upload' do
    if params[:file]
      filename = params[:file][:filename]
      temp_file = params[:file][:tempfile]
  
      # Save uploaded file
      file_path = "./uploads/#{filename}"
      File.open(file_path, 'wb') { |f| f.write(temp_file.read) }
  
      status 201
      { message: 'File uploaded successfully', path: file_path }.to_json
    else
      status 400
      { message: 'No file uploaded' }.to_json
    end
  end
  

# Proxy all other requests to the API gateway
['get', 'post', 'put', 'delete'].each do |method|
  send(method, '/*') do
    uri = URI.join(API_GATEWAY_URL, request.path_info)
    forwarded_request = Net::HTTP.const_get(method.capitalize).new(uri)

    # Copy request headers
    copy_headers(request.env.select { |k, _| k.start_with?('HTTP_') }, forwarded_request)

    # Send the request to the API Gateway
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    response = http.request(forwarded_request)

    # Set headers and response body
    copy_headers(response.each_header.to_h, headers)
    status response.code.to_i
    body response.body
  end
end

# Start the server
set :port, SERVER_PORT
set :bind, '0.0.0.0'
puts "Starting server on http://localhost:#{SERVER_PORT}"
