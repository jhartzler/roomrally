module RoomrallyPro
  class Engine < ::Rails::Engine
    # Isolate engine namespace to avoid class conflicts with host app.
    # This means engine classes are accessed as RoomrallyPro::ClassName.
    isolate_namespace RoomrallyPro

    # config.to_prepare runs after autoloading in development (each reload)
    # and once in production. This is the right hook for prepending onto
    # host app classes because those classes must be loaded first.
    config.to_prepare do
      # Load the pro plan limits decoration
      load RoomrallyPro::Engine.root.join("config/initializers/plan_resolver.rb")
    end
  end
end
