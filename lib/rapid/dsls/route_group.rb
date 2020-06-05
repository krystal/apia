# frozen_string_literal: true

module Rapid
  module DSLs
    class RouteGroup

      def initialize(route_set, group)
        @route_set = route_set
        @group = group
      end

      def route(path, **options)
        @route_set.dsl.route(path, controller: options[:controller] || @group.default_controller, group: @group, **options)
      end

      def group(id, &block)
        group = Rapid::RouteGroup.new("#{@group.id}.#{id}", @group)
        dsl = Rapid::DSLs::RouteGroup.new(@route_set, group)
        dsl.instance_eval(&block)
        @group.groups << group
      end

      Route::REQUEST_METHODS.each do |method_name|
        define_method method_name do |path, **options|
          route(path, request_method: method_name, **options)
        end
      end

      def name(name)
        @group.name = name
      end

      def description(description)
        @group.description = description
      end

      def controller(controller)
        @group.default_controller = controller
      end

    end
  end
end
