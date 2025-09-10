# frozen_string_literal: true

require_relative "client/version"
require "net/https"
require "net/http/post/multipart"

require "json"
require "uri"

module Dify
  module Client
    class DifyClient
      attr_accessor  :read_timeout

      def initialize(api_key, base_url = "https://api.dify.ai/v1")
        @api_key = api_key
        @base_url = base_url
        @read_timeout = 60
      end

      def message_feedback(message_id, rating, user)
        data = {
          rating: rating,
          user: user
        }
        _send_request("POST", "/messages/#{message_id}/feedbacks", data)
      end

      def get_application_parameters(user)
        params = { user: user }
        _send_request("GET", "/parameters", nil, params)
      end

      def update_api_key(new_key)
        @api_key = new_key
      end

      def upload(io_obj, user, filename = "localfile", _mine_type = "text/plain")
        uri = URI.parse("#{@base_url}/files/upload")

        request = Net::HTTP::Post::Multipart.new(uri.path, {
                                                   "file" => UploadIO.new(io_obj, "text/plain", filename),
                                                   "user" => user
                                                 })

        request["Authorization"] = "Bearer #{@api_key}"
        request["User-Agent"] = "Ruby-Dify-Uploader"

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        http.request(request)
      end

      def upload_file(file_path, user, filename = "localfile", mine_type = "text/plain")
        fileio = File.new(file_path)
        upload(fileio, user, filename, mine_type)
      end

      private

      def _send_request(method, endpoint, data = nil, params = nil, _stream: false)
        uri = URI.parse("#{@base_url}#{endpoint}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = @read_timeout

        headers = {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        }

        if method == "GET"
          uri.query = URI.encode_www_form(params) if params
          request = Net::HTTP::Get.new(uri.request_uri, headers)
        elsif method == "POST"
          request = Net::HTTP::Post.new(uri.request_uri, headers)
          request.body = data.to_json
        end

        http.request(request)
      end
    end

    class CompletionClient < DifyClient
      def create_completion_message(inputs, query, response_mode, user)
        data = {
          inputs: inputs,
          query: query,
          response_mode: response_mode,
          user: user
        }
        _send_request("POST", "/completion-messages", data, nil, _stream: response_mode == "streaming")
      end
    end

    class WorkflowClient < DifyClient
      def run_workflow(inputs, user, response_mode = "blocking", trace_id = nil)
        data = {
          inputs: inputs,
          user: user,
          response_mode: response_mode
        }

        data[:trace_id] = trace_id if trace_id

        _send_request("POST", "/workflows/run", data, nil, _stream: response_mode == "streaming")
      end

      def get_workflow(workflow_id)
        _send_request("GET", "/workflows/run/#{workflow_id}", nil, nil)
      end
    end

    class ChatClient < DifyClient
      def create_chat_message(inputs, query, user, response_mode = "blocking", conversation_id = nil)
        data = {
          inputs: inputs,
          query: query,
          user: user,
          response_mode: response_mode
        }
        data[:conversation_id] = conversation_id if conversation_id

        _send_request("POST", "/chat-messages", data, nil, _stream: response_mode == "streaming")
      end

      def get_conversation_messages(user, conversation_id = nil, first_id = nil, limit = nil)
        params = { user: user }
        params[:conversation_id] = conversation_id if conversation_id
        params[:first_id] = first_id if first_id
        params[:limit] = limit if limit

        _send_request("GET", "/messages", nil, params)
      end

      def get_conversations(user, last_id = nil, limit = nil, pinned = nil)
        params = { user: user, last_id: last_id, limit: limit, pinned: pinned }
        _send_request("GET", "/conversations", nil, params)
      end

      def rename_conversation(conversation_id, name, user)
        data = { name: name, user: user }
        _send_request("POST", "/conversations/#{conversation_id}/name", data)
      end
    end
  end
end
