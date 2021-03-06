# frozen_string_literal: true

module EventStoreClient
  module StoreAdapter
    class InMemory
      Response = Struct.new(:body, :status) do
        def success?
          status == 200
        end
      end

      attr_reader :event_store

      def append_to_stream(stream_name, events, expected_version: nil) # rubocop:disable Lint/UnusedMethodArgument,Metrics/LineLength
        event_store[stream_name] = [] unless event_store.key?(stream_name)

        [events].flatten.each do |event|
          event_store[stream_name].unshift(
            'eventId' => event.id,
            'data' => event.data,
            'eventType' => event.type,
            'metaData' => event.metadata,
            'positionEventNumber' => event_store[stream_name].length
          )
        end
      end

      def read(stream_name, direction: 'forward', start: 0, resolve_links: nil)
        response =
          if direction == 'forward'
            read_stream_forward(stream_name, start: start)
          else
            read_stream_backward(stream_name, start: start)
          end

        res = Response.new(response.to_json, 200)

        return [] if res.body.nil? || res.body.empty?
        JSON.parse(res.body)['entries'].map do |entry|
          deserialize_event(entry)
        end.reverse
      end

      def read_all_from_stream(stream_name, direction: 'forward', start: 0, resolve_links: true)
        response =
          if direction == 'forward'
            read_stream_forward(stream_name, start: start)
          else
            read_stream_backward(stream_name, start: start)
          end
        res = Response.new(response.to_json, 200)

        return [] if res.body.nil? || res.body.empty?
          JSON.parse(res.body)['entries'].map do |entry|
            deserialize_event(entry)
          end.reverse
      end

      def subscribe_to_stream(stream_name, subscription_name, **)
        # TODO: implement method body
      end

      def consume_feed(
        stream_name,
        subscription_name,
        **
      )
        # TODO: implement method body
      end

      def delete_stream(stream_name, hard_delete: false) # rubocop:disable Lint/UnusedMethodArgument
        event_store.delete(stream_name)
      end

      def link_to(stream_name, events, **)
        append_to_stream(stream_name, events)
        events
      end

      def ack(url)
        # TODO: implement method body
      end

      def join_streams(name, streams); end

      private

      attr_reader :per_page, :mapper

      def initialize(mapper:, per_page: 20)
        @per_page = per_page
        @mapper = mapper
        @event_store = {}
      end

      def read_stream_backward(stream_name, start: 0)
        response = {
          'entries' => [],
          'links' => []
        }
        return response unless event_store.key?(stream_name)

        start = start == 'head' ? event_store[stream_name].length - 1 : start
        last_index = start - per_page
        response['entries'] = event_store[stream_name].select do |event|
          event['positionEventNumber'] > last_index &&
            event['positionEventNumber'] <= start
        end
        response['links'] = links(stream_name, last_index, 'next', response['entries'], per_page)

        response
      end

      def read_stream_forward(stream_name, start: 0)
        response = {
          'entries' => [],
          'links' => []
        }

        return response unless event_store.key?(stream_name)

        last_index = start + per_page
        response['entries'] = event_store[stream_name].select do |event|
          event['positionEventNumber'] < last_index &&
            event['positionEventNumber'] >= start
        end
        response['links'] =
          links(stream_name, last_index, 'previous', response['entries'], per_page)

        response
      end

      def links(stream_name, batch_size, direction, entries, count)
        if entries.empty? || batch_size.negative?
          []
        else
          [{
            'uri' =>
              "/streams/#{stream_name}/#{batch_size}/#{direction}/#{count}",
            'relation' => direction
          }]
        end
      end

      private

      def deserialize_event(entry)
        event = EventStoreClient::Event.new(
          id: entry['eventId'],
          title: entry['title'],
          type: entry['eventType'],
          data: entry['data'] || '{}',
          metadata: entry['isMetaData'] ? entry['metaData'] : '{}'
        )

        mapper.deserialize(event)
      end
    end
  end
end
