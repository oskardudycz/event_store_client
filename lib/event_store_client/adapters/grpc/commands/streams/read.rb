# frozen_string_literal: true

require 'grpc'
require 'event_store_client/adapters/grpc/generated/projections_pb.rb'
require 'event_store_client/adapters/grpc/generated/projections_services_pb.rb'

require 'event_store_client/configuration'
require 'event_store_client/adapters/grpc/commands/command'

module EventStoreClient
  module GRPC
    module Commands
      module Streams
        class Read < Command
          include Configuration

          use_request EventStore::Client::Streams::ReadReq
          use_service EventStore::Client::Streams::Streams::Stub

          StreamNotFound = Class.new(StandardError)

          def call(name, options: {})
            direction =
              EventStoreClient::ReadDirection.new(options[:direction] || 'forwards').to_sym
            opts = {
              stream: {
                stream_identifier: {
                  streamName: name
                }
              },
              read_direction: direction,
              resolve_links: options[:resolve_links] || true,
              count: options[:count] || config.per_page,
              uuid_option: {
                string: {}
              },
              no_filter: {}
            }
            options[:start] ||= 0
            if options[:start].zero?
              opts[:stream][:start] = {}
            else
              opts[:stream][:revision] = options[:start]
            end

            events = service.read(request.new(options: opts)).map do |res|
              raise StreamNotFound if res.stream_not_found

              deserialize_event(res.event.event)
            end
            Success(events)
          rescue StreamNotFound
            Failure(:not_found)
          end

          private

          def deserialize_event(entry)
            data = (entry.data.nil? || entry.data.empty?) ? '{}' : entry.data

            event = EventStoreClient::Event.new(
              id: entry.id.string,
              title: "#{entry.stream_revision}@#{entry.stream_identifier.streamName}",
              type: entry.metadata['type'],
              data: data,
              metadata: (entry.metadata.to_h || {}).to_json
            )

            config.mapper.deserialize(event)
          end
        end
      end
    end
  end
end