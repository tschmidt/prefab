require 'test_helper'
 
class <%= plural_class_name %>ControllerTest < ActionController::TestCase
  <%= controller_methods 'tests/testunit/actions' %>
end