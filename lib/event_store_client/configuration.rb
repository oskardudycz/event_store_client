# frozen_string_literal: true

require 'dry-configurable'

module EventStoreClient
  extend Dry::Configurable

  # Supported adapters: %i[api in_memory]
  #
  setting :adapter, :api

  setting :error_handler
  setting :eventstore_url, 'http://localhost:2113' do |value|
    value.is_a?(URI) ? value : URI(value)
  end

  setting :eventstore_user, 'admin'
  setting :eventstore_password, 'changeit'

  setting :db_port, 2113

  setting :per_page, 20
  setting :pid_path, 'tmp/poll.pid'

  setting :service_name, 'default'

  setting :mapper, Mapper::Default.new

  def self.configure
    yield(config) if block_given?
  end

  def self.adapter
    case config.adapter
    when :api
      StoreAdapter::Api::Client.new(
        config.eventstore_url,
        per_page: config.per_page,
        mapper: config.mapper,
        connection_options: {}
      )
    else
      StoreAdapter::InMemory.new(
        mapper: config.mapper, per_page: config.per_page
      )
    end
  end
end
