import Foundation
import Anthropic

/// Canned JSON response bodies for use in unit tests.
///
/// All fixtures match the actual Anthropic API response shapes.
public enum MockResponses {
    // MARK: - Messages

    public static let singleMessage = Data("""
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "text",
          "text": "Hello! How can I help you today?"
        }
      ],
      "model": "claude-opus-4-5",
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 10,
        "output_tokens": 9
      }
    }
    """.utf8)

    public static let messageWithToolUse = Data("""
    {
      "id": "msg_01xtY5HkFZAJEaadPKXvHnfH",
      "type": "message",
      "role": "assistant",
      "content": [
        {
          "type": "tool_use",
          "id": "toolu_01A09q90qw90lq917835lq9",
          "name": "get_weather",
          "input": { "location": "San Francisco, CA" }
        }
      ],
      "model": "claude-opus-4-5",
      "stop_reason": "tool_use",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 68,
        "output_tokens": 14
      }
    }
    """.utf8)

    // MARK: - Token Count

    public static let tokenCount = Data("""
    {
      "input_tokens": 42
    }
    """.utf8)

    // MARK: - Models

    public static let modelsList = Data("""
    {
      "data": [
        {
          "type": "model",
          "id": "claude-opus-4-5",
          "display_name": "Claude Opus 4.5",
          "created_at": "2025-01-01T00:00:00Z"
        },
        {
          "type": "model",
          "id": "claude-sonnet-4-5",
          "display_name": "Claude Sonnet 4.5",
          "created_at": "2025-01-01T00:00:00Z"
        }
      ],
      "has_more": false,
      "first_id": "claude-opus-4-5",
      "last_id": "claude-sonnet-4-5"
    }
    """.utf8)

    public static let singleModel = Data("""
    {
      "type": "model",
      "id": "claude-opus-4-5",
      "display_name": "Claude Opus 4.5",
      "created_at": "2025-01-01T00:00:00Z"
    }
    """.utf8)

    // MARK: - Batches

    public static let messageBatch = Data("""
    {
      "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "type": "message_batch",
      "processing_status": "in_progress",
      "request_counts": {
        "processing": 100,
        "succeeded": 0,
        "errored": 0,
        "canceled": 0,
        "expired": 0
      },
      "ended_at": null,
      "created_at": "2024-09-24T18:37:24.100435Z",
      "expires_at": "2024-09-25T18:37:24.100435Z",
      "cancel_initiated_at": null,
      "results_url": null
    }
    """.utf8)

    public static let messageBatchList = Data("""
    {
      "data": [
        {
          "id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
          "type": "message_batch",
          "processing_status": "ended",
          "request_counts": {
            "processing": 0,
            "succeeded": 50,
            "errored": 0,
            "canceled": 0,
            "expired": 0
          },
          "ended_at": "2024-09-24T19:37:24.100435Z",
          "created_at": "2024-09-24T18:37:24.100435Z",
          "expires_at": "2024-09-25T18:37:24.100435Z",
          "cancel_initiated_at": null,
          "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d/results"
        }
      ],
      "has_more": false,
      "first_id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d",
      "last_id": "msgbatch_01HkcTjaV5uDC8jWR4ZsDV8d"
    }
    """.utf8)

    // MARK: - Files

    public static let fileObject = Data("""
    {
      "id": "file_011CNmFNMT7RRHzqSCnmPwH7",
      "type": "file",
      "filename": "annual_report.pdf",
      "size": 4096,
      "created_at": 1714041600,
      "purpose": "assistants"
    }
    """.utf8)

    public static let filesList = Data("""
    {
      "data": [
        {
          "id": "file_011CNmFNMT7RRHzqSCnmPwH7",
          "type": "file",
          "filename": "annual_report.pdf",
          "size": 4096,
          "created_at": 1714041600,
          "purpose": "assistants"
        }
      ],
      "has_more": false,
      "first_id": "file_011CNmFNMT7RRHzqSCnmPwH7",
      "last_id": "file_011CNmFNMT7RRHzqSCnmPwH7"
    }
    """.utf8)

    public static let fileDeleted = Data("""
    {
      "id": "file_011CNmFNMT7RRHzqSCnmPwH7",
      "type": "file_deleted",
      "deleted": true
    }
    """.utf8)

    // MARK: - Admin

    public static let workspace = Data("""
    {
      "id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ",
      "type": "workspace",
      "name": "My Workspace",
      "created_at": "2024-09-24T18:37:24.100435Z",
      "archived_at": null,
      "display_color": "#6C5BB9"
    }
    """.utf8)

    public static let workspaceList = Data("""
    {
      "data": [
        {
          "id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ",
          "type": "workspace",
          "name": "My Workspace",
          "created_at": "2024-09-24T18:37:24.100435Z",
          "archived_at": null,
          "display_color": "#6C5BB9"
        }
      ],
      "has_more": false,
      "first_id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ",
      "last_id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ"
    }
    """.utf8)

    public static let apiKey = Data("""
    {
      "id": "apikey_01Rj2N8SVvo6B5p8hqjjXqM4",
      "type": "api_key",
      "name": "My API Key",
      "status": "active",
      "created_at": "2024-09-24T18:37:24.100435Z",
      "last_used_at": "2024-09-25T18:37:24.100435Z",
      "workspace_id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ",
      "created_by": {
        "id": "user_01WCz1FkmYMm4gnmykNKvp7Y",
        "type": "user"
      }
    }
    """.utf8)

    public static let apiKeyList = Data("""
    {
      "data": [
        {
          "id": "apikey_01Rj2N8SVvo6B5p8hqjjXqM4",
          "type": "api_key",
          "name": "My API Key",
          "status": "active",
          "created_at": "2024-09-24T18:37:24.100435Z",
          "last_used_at": null,
          "workspace_id": "wrkspc_01JwQvzr7rXLA5AGx3HKfFUJ",
          "created_by": {
            "id": "user_01WCz1FkmYMm4gnmykNKvp7Y",
            "type": "user"
          }
        }
      ],
      "has_more": false,
      "first_id": "apikey_01Rj2N8SVvo6B5p8hqjjXqM4",
      "last_id": "apikey_01Rj2N8SVvo6B5p8hqjjXqM4"
    }
    """.utf8)

    public static let member = Data("""
    {
      "user_id": "user_01WCz1FkmYMm4gnmykNKvp7Y",
      "type": "user",
      "organization_role": "user",
      "email": "user@example.com",
      "name": "Jane Smith",
      "added_at": "2024-01-01T00:00:00Z"
    }
    """.utf8)

    public static let memberList = Data("""
    {
      "data": [
        {
          "user_id": "user_01WCz1FkmYMm4gnmykNKvp7Y",
          "type": "user",
          "organization_role": "user",
          "email": "user@example.com",
          "name": "Jane Smith",
          "added_at": "2024-01-01T00:00:00Z"
        }
      ],
      "has_more": false,
      "first_id": "user_01WCz1FkmYMm4gnmykNKvp7Y",
      "last_id": "user_01WCz1FkmYMm4gnmykNKvp7Y"
    }
    """.utf8)

    public static let invite = Data("""
    {
      "id": "invite_01J2qFhxxWVBDFMEcMFKNHha",
      "type": "invite",
      "email": "newuser@example.com",
      "role": "user",
      "status": "pending",
      "invited_at": "2024-01-01T00:00:00Z",
      "expires_at": "2024-02-01T00:00:00Z"
    }
    """.utf8)

    public static let inviteList = Data("""
    {
      "data": [
        {
          "id": "invite_01J2qFhxxWVBDFMEcMFKNHha",
          "type": "invite",
          "email": "newuser@example.com",
          "role": "user",
          "status": "pending",
          "invited_at": "2024-01-01T00:00:00Z",
          "expires_at": "2024-02-01T00:00:00Z"
        }
      ],
      "has_more": false,
      "first_id": "invite_01J2qFhxxWVBDFMEcMFKNHha",
      "last_id": "invite_01J2qFhxxWVBDFMEcMFKNHha"
    }
    """.utf8)

    // MARK: - Errors

    public static let invalidRequestError = Data("""
    {
      "type": "error",
      "error": {
        "type": "invalid_request_error",
        "message": "max_tokens: field required"
      }
    }
    """.utf8)

    public static let authError = Data("""
    {
      "type": "error",
      "error": {
        "type": "authentication_error",
        "message": "invalid x-api-key"
      }
    }
    """.utf8)

    public static let rateLimitError = Data("""
    {
      "type": "error",
      "error": {
        "type": "rate_limit_error",
        "message": "Number of request tokens has exceeded your per-minute rate limit."
      }
    }
    """.utf8)
}
