# frozen_string_literal: true

require "rspec/core/memoized_helpers"

module RSpec
  module Core
    module MemoizedHelpers
      private

      def query_logger(name:, type:)
        return yield unless ENV["PROFILE"]&.to_i&.positive?

        queries = []

        ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          event = ActiveSupport::Notifications::Event.new(*args).payload
          next if event[:name].in?([nil, "SCHEMA"])

          queries << {
            rspec_name: name,
            rspec_type: type,
            event_name: event[:name],
            sql: event[:sql],
            binds: event[:binds].map(&:value),
            factory: caller.any? { |call| call.match?(/factory_bot/) }
          }
        end

        yield
      ensure
        if queries&.any?
          # TODO: make a config option to be able to determine which types to profile. For now we only profile the subjects
          queries.reject! { |e| e.fetch(:factory) || e.fetch(:rspec_type) == :let }

          queries.group_by { |query| query.fetch(:rspec_name) }.each do |rspec_name, events|
            rspec_type = events.first.fetch(:rspec_type)

            puts "#{rspec_type}(:#{rspec_name}) -> query count: #{events.size}"

            next unless ENV["PROFILE"].to_i > 1

            events.group_by { |event| event.fetch(:sql) }.each do |sql, sqls|
              puts "- (#{sqls.size}): '#{sqls.first.fetch(:event_name)}' -> #{sql} [#{sqls.first.fetch(:binds)}]"
            end
          end
        end
      end

      module ClassMethods
        def let(name, type = :let, &block)
          # We have to pass the block directly to `define_method` to
          # allow it to use method constructs like `super` and `return`.
          raise "#let or #subject called without a block" if block.nil?

          if :initialize == name
            raise(
              "#let or #subject called with a reserved name #initialize"
            )
          end
          our_module = MemoizedHelpers.module_for(self)

          # If we have a module clash in our helper module
          # then we need to remove it to prevent a warning.
          #
          # Note we do not check ancestor modules (see: `instance_methods(false)`)
          # as we can override them.
          our_module.__send__(:remove_method, name) if our_module.instance_methods(false).include?(name)
          our_module.__send__(:define_method, name, &block)

          # If we have a module clash in the example module
          # then we need to remove it to prevent a warning.
          #
          # Note we do not check ancestor modules (see: `instance_methods(false)`)
          # as we can override them.
          remove_method(name) if instance_methods(false).include?(name)

          # Apply the memoization. The method has been defined in an ancestor
          # module so we can use `super` here to get the value.
          if block.arity == 1
            define_method(name) { __memoized.fetch_or_store(name) { super(RSpec.current_example, &nil) } }
          else
            define_method(name) do
              __memoized.fetch_or_store(name) do
                query_logger(type: type, name: name) { super(&nil) }
              end
            end
          end
        end

        # Since the subject becomes a regular `let` after this there is no way to tell which is the subject and
        # which is just a regular let. (For RSpec it does not matter, renaming all subjects to lets will work just fine)
        def subject(name = nil, &block)
          if name
            let(name, :subject, &block)
            alias_method :subject, name

            self::NamedSubjectPreventSuper.__send__(:define_method, name) do
              raise NotImplementedError, "`super` in named subjects is not supported"
            end
          else
            let(:subject, :subject, &block)
          end
        end
      end
    end
  end
end
