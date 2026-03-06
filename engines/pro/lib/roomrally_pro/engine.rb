module RoomrallyPro
  class Engine < ::Rails::Engine
    isolate_namespace RoomrallyPro

    # config.to_prepare runs after autoloading in development (each reload)
    # and once in production. This is the right hook for prepending onto
    # host app classes because those classes must be loaded first.
    config.to_prepare do
      PlanResolver.prepend(RoomrallyPro::PlanLimits) unless PlanResolver < RoomrallyPro::PlanLimits

      unless PlanResolver.singleton_class.ancestors.any? { |m| m.to_s.include?("RoomrallyPro") }
        PlanResolver.singleton_class.prepend(
          Module.new do
            def for(user)
              if user&.pro?
                new(:pro)
              else
                super
              end
            end
          end
        )
      end
    end
  end
end
