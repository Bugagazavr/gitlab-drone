require 'rubygems'
require 'bundler'
Bundler.require

require './app.rb'

use ExceptionHandling
map "/auth" do
  run Auth
end

map "/repo" do
  run Repo
end

map "/perm" do
  run Perm
end
