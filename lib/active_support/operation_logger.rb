require "active_support/operation_logger/version"
require "active_support/notifications"
require "active_support/log_subscriber"

module ActiveSupport
  module OperationLogger
    # Provides methods that should probably be part of Ruby's stdlib
    module MethodHelper
      def self.public_owned_instance_methods(klass)
        klass.public_instance_methods.select do |m|
          klass.instance_method(m).owner == klass
        end
      end
    end

    # A generic factory responsible for creating modules that can be used to
    # decorate classes with ActiveSupport::Notifications
    module EventInstrumenterFactory
      # @param [Class] klass
      # @param [Array<Symbol>] methods
      # @param [Symbol] event_namespace
      # @return [Module] a module for prepending
      def self.instrumenter_for(klass, methods, event_namespace)
        Module.new do
          methods.each do |m|
            define_method m do |*args, &block|
              command_str = if args.size == 1 && args.first.is_a?(Array)
                              args.first.map(&:inspect).join(', ')
                            else
                              args.map(&:inspect).join(' ')
                            end
              ActiveSupport::Notifications.instrument("call.#{event_namespace}",
                                                      name: "#{event_namespace.to_s.classify} #{m}",
                                                      command: command_str) do
                super *args, &block
              end
            end
          end
        end
      end
    end

    # A generic factory responsible for creating classes that can be used to
    # create LogSubscribers that integrate with ActiveSupport::Notifications
    # and mirror the functionality of ActiveRecord::LogSubscriber
    module EventSubscriberFactory
      def self.subscriber_for(klass)
        Class.new(ActiveSupport::LogSubscriber) do
          def initialize
            super
            @odd = false
          end

          def odd?
            @odd = !@odd
          end

          def call(event)
            name = "#{event.payload[:name]} (#{event.duration.round(1)}ms)"
            command = event.payload[:command]
            if odd?
              name = color(name, ActiveSupport::LogSubscriber::CYAN, true)
              command = color(command, nil, true)
            else
              name = color(name, ActiveSupport::LogSubscriber::MAGENTA, true)
            end

            debug "  #{name}  #{command}"
          end
        end
      end
    end

    # Encapsulates the act of decorating classes with ActiveSupport::Notifications
    # instrumenters and ActiveSupport::LogSubscribers
    #
    # TODO: @jbodah 2016-04-30: just use one shared event subscriber
    def self.log_calls_on!(klass, only: nil, event_namespace: nil)
      methods = only || MethodHelper.public_owned_instance_methods(klass)
      event_namespace ||= klass.name.demodulize.underscore
      event_namespace = event_namespace.to_sym

      klass.prepend EventInstrumenterFactory.instrumenter_for(klass, methods, event_namespace)

      EventSubscriberFactory.subscriber_for(klass).attach_to(event_namespace)
    end
  end
end
