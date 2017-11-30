#!/usr/bin/env ruby

require 'sensu-plugin/check/cli'
require 'httparty'
require 'json'

class StorageGridHealth < Sensu::Plugin::Check::CLI
  option :hostname,
         short: '-h HOSTNAME',
         long: '--hostname HOSTNAME',
         description: 'Base URL to StorageGRID',
         required: true

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'StorageGRID username (default: root)',
         required: false,
         default: 'root'

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'StorageGRID password',
         required: true

  option :verify_ssl_off,
         short: '-i',
         long: '--insecure',
         description: 'Do not check validity of SSL cert',
         required: false,
         boolean: true,
         default: false

  def post_request(api_endpoint, headers, body, response_code = 200)
    r = HTTParty.post("#{config[:hostname]}#{api_endpoint}",
                      verify: !config[:verify_ssl_off],
                      headers: headers,
                      body: body.to_json)
    raise HTTParty::Error if r.response.code.to_i != response_code.to_i
    r.parsed_response
  end

  def get_request(api_endpoint, headers, response_code = 200)
    r = HTTParty.get("#{config[:hostname]}#{api_endpoint}",
                     verify: !config[:verify_ssl_off],
                     headers: headers)
    raise HTTParty::Error if r.response.code.to_i != response_code.to_i
    r.parsed_response
  end

  def run
    headers = { 'Content-Type' => 'application/json',
                'Accept' => 'application/json' }
    auth_body = { 'username' => config[:username],
                  'password' => config[:password] }
    auth_req = post_request('/api/v2/authorize', headers, auth_body)
    headers['Authorization'] = "Bearer #{auth_req['data']}"

    health_req = get_request('/api/v2/grid/health', headers)
    health_alarms = health_req['data']['alarms']
    health_nodes = health_req['data']['nodes']

    if health_alarms['critical'].to_i > 0 ||
       health_alarms['major'].to_i > 0 ||
       health_nodes['administratively-down'].to_i > 0 ||
       health_nodes['unknown'].to_i > 0
      critical
    elsif health_alarms['minor'].to_i > 0
      warning
    else
      ok
    end
  end
end
