# frozen_string_literal: true

require 'dry-struct'
require 'securerandom'
require 'json'

module EventStoreClient
  class Event < Dry::Struct
    attr_reader :id

    attribute :type, Types::Strict::String
    attribute :title, Types::Strict::String.optional.default(nil)
    attribute :data, Types::Strict::String.default('{}')
    attribute :metadata, Types::Strict::String.default('{}')

    private

    def initialize(**args)
      @id = SecureRandom.uuid
      hash_meta = JSON.parse(args[:metadata] || '{}')
      hash_meta['created_at'] ||= Time.now
      args[:metadata] = JSON.generate(hash_meta)
      super(args)
    end
  end
end
