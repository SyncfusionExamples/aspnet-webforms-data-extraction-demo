using Microsoft.Extensions.Options;
using OpenAI;
using OpenAI.Chat;
using System;
using System.ComponentModel.DataAnnotations;

namespace SmartDataExtractorSample
{
    // Owns the single OpenAIClient and exposes a ChatClient.
    public sealed class OpenAIClientFactory : IDisposable
    {
        private readonly OpenAIClient _client;
        private readonly string _model;
        private readonly Lazy<ChatClient> _chatClient;

        public OpenAIClientFactory(IOptions<OpenAIOptions> options)
        {
            if (options == null) throw new ArgumentNullException(nameof(options));
            var opts = options.Value;

            if (string.IsNullOrWhiteSpace(opts.ApiKey) ||
                string.IsNullOrWhiteSpace(opts.Model))
            {
                throw new InvalidOperationException(
                    "OpenAI configuration is missing. Set ApiKey and Model under the OpenAI section of appsettings.json.");
            }

            _model = opts.Model;
            _client = new OpenAIClient(opts.ApiKey);

            _chatClient = new Lazy<ChatClient>(
                () => _client.GetChatClient(_model));
        }

        /// <summary>
        /// Convenience constructor for WebForms / .ashx handlers where dependency
        /// injection is not available. Reads ApiKey + Model directly.
        /// </summary>
        public OpenAIClientFactory(string apiKey, string model)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new ArgumentException("OpenAI ApiKey is required.", nameof(apiKey));
            }
            if (string.IsNullOrWhiteSpace(model))
            {
                throw new ArgumentException("OpenAI Model is required.", nameof(model));
            }

            _model = model;
            _client = new OpenAIClient(apiKey);
            _chatClient = new Lazy<ChatClient>(() => _client.GetChatClient(_model));
        }

        public ChatClient ChatClient => _chatClient.Value;

        public void Dispose()
        {
            // No disposal currently required.
        }
    }

    public sealed class OpenAIOptions
    {
        public const string SectionName = "OpenAI";
        public string ApiKey { get; set; } = string.Empty;
        public string Model { get; set; } = string.Empty;
    }
}