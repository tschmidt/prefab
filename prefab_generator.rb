class PrefabGenerator < Rails::Generator::Base
  
  attr_accessor :name, :attributes, :controller_actions
  
  def initialize(runtime_args, runtime_options = {})
    super
    usage if @args.empty?
    
    @name = @args.first
    @controller_actions = Array.new
    @attributes = Array.new
    
    @args[1..-1].each do |arg|
      if arg == '!'
        options[:invert] = true
      elsif arg.include? ':'
        @attributes << Rails::Generator::GeneratedAttribute.new(*arg.split(':'))
      else
        @controller_actions << arg
        @controller_actions << 'create' if arg == 'new'
        @controller_actions << 'update' if arg == 'edit'
      end
    end
    
    @controller_actions.uniq!
    @attributes.uniq!
    
    if options[:invert] || @controller_actions.empty?
      @controller_actions = all_actions - @controller_actions
    end
    
    if @attributes.empty?
      options[:skip_model] = true # default to skipping model if no attributes passed
      if model_exists?
        model_columns_for_attributes.each do |column|
          @attributes << Rails::Generator::GeneratedAttribute.new(column.name.to_s, column.type.to_s)
        end
      else
        @attributes << Rails::Generators::GeneratedAttribute.new('name', 'string')
      end
    end
  end
  
  def manifest
    record do |m|
      unless options[:skip_model]
        m.directory "app/models"
        m.template "model.rb", "app/models/#{singular_name}.rb"
        unless options[:skip_migration]
          m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_#{plural_name}"
        end
        
        # Create the tests for the new model
        m.directory "test/unit"
        m.template "tests/#{test_framework}/model.rb", "test/unit/#{singular_name}_test.rb"
        m.directory "test/fixtures"
        m.template "fixtures.yml", "test/fixtures/#{plural_name}.yml"
      end
      
      unless options[:skip_controller]
        m.directory "app/controllers"
        m.template "controller.rb", "app/controllers/#{plural_name}_controller.rb"
        
        m.directory "app/views/#{plural_name}"
        controller_actions.each do |action|
          if File.exist? source_path("views/#{view_language}/#{action}.html.#{view_language}")
            m.template "views/#{view_language}/#{action}.html.#{view_language}", "app/views/#{plural_name}/#{action}.html.#{view_language}"
          end
        end
        
        m.template "views/#{view_language}/_model.html.#{view_language}", "app/views/#{plural_name}/_#{singular_name}.html.#{view_language}"
        
        if form_partial?
          m.template "views/#{view_language}/_form.html.#{view_language}", "app/views/#{plural_name}/_form.html.#{view_language}"
        end
        
        m.route_resources plural_name
      end
    end
  end
  
  def form_partial?
    actions?(:new, :edit)
  end
  
  def all_actions
    %w(index show new create edit update destroy)
  end
  
  def action?(name)
    controller_actions.include?(name.to_s)
  end
  
  def actions?(*names)
    names.all? {|name| action?(name.to_s)}
  end
  
  def singular_name
    name.underscore
  end
  
  def plural_name
    name.underscore.pluralize
  end
  
  def class_name
    name.camelize
  end
  
  def plural_class_name
    plural_name.camelize
  end
  
  def controller_methods(dir_name)
    controller_actions.map do |action|
      read_template("#{dir_name}/#{action}.rb")
    end.join("\n\n").strip
  end
  
  def render_form
    if form_partial?
      if options[:haml]
        "= render :partial => 'form'"
      else
        "<%= render :partial => 'form' %>"
      end
    else
      read_template("views/#{view_language}/_form.html.#{view_language}")
    end
  end
  
  def item_path(suffix = 'path')
    if action?(:show)
      "@#{singular_name}"
    else
      "#{plural_name}_#{suffix}"
    end
  end
  
  def item_path_for_spec(suffix = 'path')
    if action?(:show)
      "#{singular_name}_#{suffix}(assigns[:#{singular_name}])"
    else
      "#{plural_name}_#{suffix}"
    end
  end
  
  def item_path_for_test(suffix = 'path')
    if action?(:show)
      "#{singular_name}_#{suffix}(assigns(:#{singular_name}))"
    else
      "#{plural_name}_#{suffix}"
    end
  end
  
  def model_columns_for_attributes
    class_name.constantize.columns.reject do |column|
      column.name.to_s =~ /^(id|created_at|updated_at)$/
    end
  end
  
  protected
  
    def view_language
      options[:haml] ? 'haml' : 'erb'
    end
    
    def test_framework
      options[:test_framework] ||= default_test_framework
    end
    
    def default_test_framework
      File.exist?(destination_path("spec")) ? :rspec : :testunit
    end
    
    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-model", "Don't generate a model or migration file.") { |v| options[:skip_model] = v }
      opt.on("--skip-migration", "Don't generate a migration file for the model.") { |v| options[:skip_migration] = v }
      opt.on("--skip-timestamps", "Don't add timestamps to the migration file.") { |v| options[:skip_timestamps] = v }
      opt.on("--skip-controller", "Don't generate the controller or views for the model.") { |v| options[:skip_controller] = v }
      opt.on("--invert", "Generate all controller actions except these mentioned.") { |v| options[:invert] = v }
      opt.on("--haml", "Generate HAML views instead of ERB.") { |v| options[:haml] = v }
      opt.on("--testunit", "Use test/unit for test files.") { options[:test_framework] = :testunit }
      opt.on("--shoulda", "Use Shoulda for test files.") { options[:test_framework] = :shoulda  }
    end
    
    def model_exists?
      File.exist?(destination_path("app/models/#{singular_name}.rb"))
    end
    
    def read_template(relative_path)
      ERB.new(File.read(source_path(relative_path)), nil, '-').result(binding)
    end
    
    def banner
      <<-EOS
Creates a controller and optional model given the name, actions, and attributes.

USAGE: #{$0} #{spec.name} ModelName [controller_actions and model:attributes] [options]
EOS
    end
end