require 'sinatra'
require "sinatra/base"
require "sinatra/json"
require 'gitlab'
require 'json'
require 'active_support/all'

class ExceptionHandling
  def initialize(app)
    @app = app
  end
 
  def call(env)
    begin
      @app.call env
    rescue Gitlab::Error::MissingCredentials
      [401, {'Content-Type' => 'application/json'}, [{errors: ["please check your endpoint or/and token"]}.to_json]]
    rescue Gitlab::Error::Unauthorized
      [401, {'Content-Type' => 'application/json'}, [{errors: ["Unathorized"]}.to_json]]
    end
  end
end

class API < Sinatra::Base
  configure do
    set :dump_errors, false
    set :raise_errors, true
    set :show_exceptions, false
    
    use ExceptionHandling
  end
  
  before do
    request.body.rewind
    @body = JSON.parse(request.body.read)
  end
  
  before do
    @token = if @body['token']
      @body['token']
    elsif @body['user'] && @body['user']['token']
      @body['user']['token']
    else
      nil
    end
  end
  
  before do
    Gitlab.configure do |config|
      config.endpoint = "#{request.env['HTTP_X_DRONE_BASE']}/api/v3"
      config.private_token = @token
    end
  end
end

class Auth < API
  post '/' do
    current_user = Gitlab.user
    body = {
      login: current_user.username,
      email: current_user.email,
      name: current_user.name,
      token: @body['token'],
      secret: @body['secret']
    }
    json(body)
  end
end

class Repo < API
  post '/' do
    project = Gitlab.project("#{@body['owner']}%2F#{@body['repo']}")
    body = {
      name: project.name,
      owner: project.namespace.name,
      link: project.web_url,
      private: !project.public,
      clone: project.ssh_url_to_repo
    }
    json(body)
  end
end

class Perm < API
  def is_admin?(perms)
    if perms.project_access.present? && perms.project_access.access_level >= 40
      true
    elsif perms.group_access.present? && perms.group_access.access_level >= 40
      true
    else
      false
    end 
  end
  
  def is_write?(perms)
    if perms.project_access.present? && perms.project_access.access_level >= 30
      true
    elsif perms.group_access.present? && perms.group_access.access_level >= 30
      true
    else
      false
    end 
  end
  
  def is_read?(perms, public = false)
    if public
      true
    elsif perms.project_access.present? && perms.project_access.access_level >= 20
      true
    elsif perms.group_access.present? && perms.group_access.access_level >= 20
      true
    else
      false
    end 
  end
  
  post '/' do
    project = Gitlab.project("#{@body['owner']}%2F#{@body['repo']}")
    
    perms = project.permissions
    body = {
      login: @body['user']['login'],
      admin: is_admin?(perms),
      write: is_write?(perms),
      read: is_read?(perms, project.public)
    }
    json(body)
  end
end
