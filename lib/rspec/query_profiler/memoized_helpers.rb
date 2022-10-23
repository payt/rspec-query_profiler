# frozen_string_literal: true

module RSpec
  # TODO: Move this condition to an prepend statement like in example.rb
  if QueryProfiler::PROFILE_LEVEL.positive?
    module Core
      module MemoizedHelpers
        private

        def query_logger(type:, &block)
          return yield unless type == :subject || query_logger_within_subject?

          RSpec.current_example.instance_variable_set(:@query_logger_within_subject, true)
          ActiveSupport::Notifications.subscribed(
            query_logger_callback(type: type),
            "sql.active_record",
            &block
          )
        end

        def query_logger_within_subject?
          RSpec.current_example.instance_variable_get(:@query_logger_within_subject)
        end

        def query_logger_callback(type:)
          lambda do |*args|
            query_details = args[4]
            next if query_details.fetch(:name).in?(QueryProfiler::IGNORED_QUERIES)

            RSpec.current_example.instance_variable_get(:@query_logger) << {
              type: type,
              name: query_details.fetch(:name),
              sql: query_details.fetch(:sql),
              binds: query_details.fetch(:type_casted_binds)
            }
          end
        end

        module ClassMethods
          ### QUERY_PROFILER START: add `type` argument to distinguise between :subject and :let ###
          def let(name, type = :let, &block)
            ### QUERY_PROFILER END ###
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
                  ### QUERY_PROFILER START: wrap the subject and let blocks to be able to count their queries ###
                  query_logger(type: type) { super(&nil) }
                  ### QUERY_PROFILER END ###
                end
              end
            end
          end

          # Since the subject becomes a regular `let` after this there is no way to tell which is the subject and
          # which is just a regular let. (For RSpec it does not matter, renaming all subjects to lets will work just fine)
          def subject(name = nil, &block)
            if name
              ### QUERY_PROFILER START ###
              let(name, :subject, &block)
              ### QUERY_PROFILER END ###
              alias_method :subject, name

              self::NamedSubjectPreventSuper.__send__(:define_method, name) do
                raise NotImplementedError, "`super` in named subjects is not supported"
              end
            else
              ### QUERY_PROFILER START ###
              let(:subject, :subject, &block)
              ### QUERY_PROFILER END ###
            end
          end
        end
      end
    end
  end
end
