# frozen_string_literal: true

module RSpec
  module QueryProfiler
    module Example
      def run(example_group_instance, reporter)
        @example_group_instance = example_group_instance
        @reporter = reporter
        ### QUERY_PROFILER START: add some instance variables ###
        @query_logger = []
        @query_logger_within_subject = false
        ### QUERY_PROFILER END ###
        RSpec.configuration.configure_example(self, hooks)
        RSpec.current_example = self

        start(reporter)
        Core::Pending.mark_pending!(self, pending) if pending?

        begin
          if skipped?
            Core::Pending.mark_pending! self, skip
          elsif !RSpec.configuration.dry_run?
            ### QUERY_PROFILER START: wrap the entire example run in a block to log all its queries ###
            with_query_logger do
              ### QUERY_PROFILER END ###
              with_around_and_singleton_context_hooks do
                run_before_example

                @example_group_instance.instance_exec(self, &@example_block)

                if pending?
                  Core::Pending.mark_fixed! self

                  raise Core::Pending::PendingExampleFixedError,
                        "Expected example to fail since it is pending, but it passed.",
                        [location]
                end
              rescue Core::Pending::SkipDeclaredInExample => _e
              # The "=> _" is normally useless but on JRuby it is a workaround
              # for a bug that prevents us from getting backtraces:
              # https://github.com/jruby/jruby/issues/4467
              #
              # no-op, required metadata has already been set by the `skip`
              # method.
              rescue AllExceptionsExcludingDangerousOnesOnRubiesThatAllowIt => e
                set_exception(e)
              ensure
                run_after_example
              end
            end
          end
        rescue Support::AllExceptionsExceptOnesWeMustNotRescue => e
          set_exception(e)
        ensure
          @example_group_instance = nil # if you love something... let it go
        end

        finish(reporter)
      ensure
        execution_result.ensure_timing_set(clock)
        RSpec.current_example = nil
      end

      def record_finished(status, reporter)
        execution_result.record_finished(status, clock.now)
        reporter.example_finished(self)
        query_logger_report
      end

      private

      def with_query_logger(&block)
        ActiveSupport::Notifications.subscribed(
          query_logger_callback,
          "sql.active_record",
          &block
        )
      end

      def query_logger_callback(type: nil)
        lambda do |*args|
          query_details = args[4]
          next if query_details.fetch(:name).in?(IGNORED_QUERIES)

          RSpec.current_example.instance_variable_get(:@query_logger) << {
            type: type,
            name: query_details.fetch(:name),
            sql: query_details.fetch(:sql),
            binds: query_details.fetch(:type_casted_binds)
          }
        end
      end

      def query_logger_report
        return unless @query_logger&.any?

        all, within_subject = @query_logger.partition { |log| log.fetch(:type).nil? }
        subjects, lets = within_subject.partition { |log| log.fetch(:type) == :subject }
        lets.uniq.each { |let| subjects.reject! { |subject| subject.slice(:sql, :binds) == let.slice(:sql, :binds) } }
        subjects.each { |subject| all.reject! { |a| a.slice(:sql, :binds) == subject.slice(:sql, :binds) } }

        puts "app: #{subjects.size}, test: #{all.size}"
        return unless PROFILE_LEVEL > 1

        puts "app: #{subjects.size}"
        subjects.each do |query|
          puts "  \e[36m#{query.fetch(:name)} \e[34m#{query.fetch(:sql)}\e[0m #{query.fetch(:binds)}"
        end
        puts "\n" if subjects.any? && all.any?
        return unless PROFILE_LEVEL > 2

        puts "test: #{all.size}"
        all.each do |query|
          puts "  \e[36m#{query.fetch(:name)} \e[34m#{query.fetch(:sql)}\e[0m #{query.fetch(:binds)}"
        end
      end
    end
  end

  module Core
    class Example
      prepend QueryProfiler::Example if QueryProfiler::PROFILE_LEVEL.positive?
    end
  end
end
