import Foundation
import Anthropic

/// Canned JSON response bodies for use in unit tests.
///
/// - Important: A fixture is only as good as where it came from. The `skill*` bodies below are
///   copied verbatim from Anthropic's published `Response (200)` examples, with the page and the
///   date they were read. The older fixtures were hand-written from the API's shape as understood
///   at the time, and at least one type was wrong that way for six months with a green suite —
///   `Skill` decoded a `name` key the API has never returned. Treat an uncited fixture as a
///   statement about this SDK, not about the API, and re-derive it from the docs before trusting
///   it to prove a contract.
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

    /// The `Response (200)` bodies of <https://platform.claude.com/docs/en/api/models> (retrieved
    /// 2026-10-09), verbatim apart from whitespace. The values are the page's placeholders.
    public static let modelsList = Data("""
    {
      "data": [
        {
      "id": "claude-opus-5",
      "capabilities": {
        "batch": {"supported": true},
        "citations": {"supported": true},
        "code_execution": {"supported": true},
        "context_management": {
          "clear_thinking_20251015": {"supported": true},
          "clear_tool_uses_20250919": {"supported": true},
          "compact_20260112": {"supported": true},
          "supported": true
        },
        "effort": {
          "high": {"supported": true},
          "low": {"supported": true},
          "max": {"supported": true},
          "medium": {"supported": true},
          "supported": true,
          "xhigh": {"supported": true}
        },
        "image_input": {"supported": true},
        "pdf_input": {"supported": true},
        "server_tools": {
          "code_execution": {"supported": true},
          "supported": true,
          "web_search": {"supported": true}
        },
        "structured_outputs": {"supported": true},
        "thinking": {
          "supported": true,
          "types": {
            "adaptive": {"supported": true},
            "disabled": {"supported": true},
            "enabled": {"supported": true}
          }
        }
      },
      "created_at": "2026-07-24T00:00:00Z",
      "deprecated_at": "2019-12-27T18:11:19.117Z",
      "display_name": "Claude Opus 5",
      "lifecycle": "active",
      "line": "haiku",
      "max_input_tokens": 0,
      "max_tokens": 0,
      "retires_at": "2019-12-27T18:11:19.117Z",
      "type": "model"
    }
      ],
      "first_id": "first_id",
      "has_more": true,
      "last_id": "last_id"
    }
    """.utf8)

    /// The pre-2026-10 shape this package modelled before checking the page: no capabilities,
    /// lifecycle, line or token limits. Kept so those bodies stay decodable.
    public static let modelsListLegacy = Data("""
    {
      "data": [
        {"type": "model", "id": "claude-opus-4-5", "display_name": "Claude Opus 4.5", "created_at": "2025-01-01T00:00:00Z"},
        {"type": "model", "id": "claude-sonnet-4-5", "display_name": "Claude Sonnet 4.5", "created_at": "2025-01-01T00:00:00Z"}
      ],
      "has_more": false,
      "first_id": "claude-opus-4-5",
      "last_id": "claude-sonnet-4-5"
    }
    """.utf8)

    public static let singleModel = Data("""
    {
      "id": "claude-opus-5",
      "capabilities": {
        "batch": {"supported": true},
        "citations": {"supported": true},
        "code_execution": {"supported": true},
        "context_management": {
          "clear_thinking_20251015": {"supported": true},
          "clear_tool_uses_20250919": {"supported": true},
          "compact_20260112": {"supported": true},
          "supported": true
        },
        "effort": {
          "high": {"supported": true},
          "low": {"supported": true},
          "max": {"supported": true},
          "medium": {"supported": true},
          "supported": true,
          "xhigh": {"supported": true}
        },
        "image_input": {"supported": true},
        "pdf_input": {"supported": true},
        "server_tools": {
          "code_execution": {"supported": true},
          "supported": true,
          "web_search": {"supported": true}
        },
        "structured_outputs": {"supported": true},
        "thinking": {
          "supported": true,
          "types": {
            "adaptive": {"supported": true},
            "disabled": {"supported": true},
            "enabled": {"supported": true}
          }
        }
      },
      "created_at": "2026-07-24T00:00:00Z",
      "deprecated_at": "2019-12-27T18:11:19.117Z",
      "display_name": "Claude Opus 5",
      "lifecycle": "active",
      "line": "haiku",
      "max_input_tokens": 0,
      "max_tokens": 0,
      "retires_at": "2019-12-27T18:11:19.117Z",
      "type": "model"
    }
    """.utf8)

    // MARK: - Batches

    /// The `Response (200)` body of
    /// <https://platform.claude.com/docs/en/api/messages/batches/retrieve> (retrieved 2026-10-09).
    public static let messageBatch = Data("""
    {
      "id": "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF",
      "archived_at": "2024-08-20T18:37:24.100435Z",
      "cancel_initiated_at": "2024-08-20T18:37:24.100435Z",
      "created_at": "2024-08-20T18:37:24.100435Z",
      "ended_at": "2024-08-20T18:37:24.100435Z",
      "expires_at": "2024-08-20T18:37:24.100435Z",
      "processing_status": "in_progress",
      "request_counts": {
        "canceled": 10,
        "errored": 30,
        "expired": 10,
        "processing": 100,
        "succeeded": 50
      },
      "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_013Zva2CMHLNnXjNJJKqJ2EF/results",
      "type": "message_batch"
    }
    """.utf8)

    /// The `Response (200)` body of
    /// <https://platform.claude.com/docs/en/api/messages/batches/list> (retrieved 2026-10-09).
    public static let messageBatchList = Data("""
    {
      "data": [
        {
          "id": "msgbatch_013Zva2CMHLNnXjNJJKqJ2EF",
          "archived_at": "2024-08-20T18:37:24.100435Z",
          "cancel_initiated_at": "2024-08-20T18:37:24.100435Z",
          "created_at": "2024-08-20T18:37:24.100435Z",
          "ended_at": "2024-08-20T18:37:24.100435Z",
          "expires_at": "2024-08-20T18:37:24.100435Z",
          "processing_status": "in_progress",
          "request_counts": {
            "canceled": 10,
            "errored": 30,
            "expired": 10,
            "processing": 100,
            "succeeded": 50
          },
          "results_url": "https://api.anthropic.com/v1/messages/batches/msgbatch_013Zva2CMHLNnXjNJJKqJ2EF/results",
          "type": "message_batch"
        }
      ],
      "first_id": "first_id",
      "has_more": true,
      "last_id": "last_id"
    }
    """.utf8)

    // MARK: - Files

    /// The `Response (200)` body of
    /// <https://platform.claude.com/docs/en/api/files/retrieve_metadata> (retrieved 2026-10-09).
    public static let fileObject = Data("""
    {
      "id": "file_011CNha8iCJcU1wXNR6q4V8w",
      "created_at": "2025-04-15T18:37:24.100435Z",
      "filename": "document.pdf",
      "mime_type": "application/pdf",
      "size_bytes": 102400,
      "type": "file",
      "downloadable": false,
      "expires_at": "2025-05-15T18:37:24.100435Z"
    }
    """.utf8)

    /// A list envelope: `data` of `FileMetadata` plus `next_page`, per
    /// <https://platform.claude.com/docs/en/api/files/list> (retrieved 2026-10-09).
    public static let filesList = Data("""
    {
      "data": [
        {
          "id": "file_011CNha8iCJcU1wXNR6q4V8w",
          "created_at": "2025-04-15T18:37:24.100435Z",
          "filename": "document.pdf",
          "mime_type": "application/pdf",
          "size_bytes": 102400,
          "type": "file",
          "downloadable": false,
          "expires_at": "2025-05-15T18:37:24.100435Z"
        }
      ],
      "next_page": "page_MjAyNS0wNS0xNFQwMDowMDowMFo="
    }
    """.utf8)

    /// The `Response (200)` body of <https://platform.claude.com/docs/en/api/files/delete>
    /// (retrieved 2026-10-09).
    public static let fileDeleted = Data("""
    {
      "id": "file_011CNha8iCJcU1wXNR6q4V8w",
      "type": "file_deleted"
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

    // MARK: - Skills
    //
    // Copied verbatim from the `Response (200)` examples, retrieved 2026-09-22. The beta
    // (`skills-2025-10-02`) and GA documents describe the same object and the same envelope.

    /// <https://platform.claude.com/docs/en/api/skills/retrieve>
    public static let skillObject = Data("""
    {
      "id": "skill_01JAbcdefghijklmnopqrstuvw",
      "created_at": "2024-10-30T23:58:27.427722Z",
      "display_name": "display_name",
      "latest_version_id": "latest_version_id",
      "source": {
        "type": "custom"
      },
      "type": "skill",
      "updated_at": "2024-10-30T23:58:27.427722Z"
    }
    """.utf8)

    /// <https://platform.claude.com/docs/en/api/skills/list>
    public static let skillList = Data("""
    {
      "data": [
        {
          "id": "skill_01JAbcdefghijklmnopqrstuvw",
          "created_at": "2024-10-30T23:58:27.427722Z",
          "display_name": "display_name",
          "latest_version_id": "latest_version_id",
          "source": {
            "type": "custom"
          },
          "type": "skill",
          "updated_at": "2024-10-30T23:58:27.427722Z"
        }
      ],
      "next_page": "next_page"
    }
    """.utf8)

    /// <https://platform.claude.com/docs/en/api/skills/versions/retrieve>, retrieved 2026-10-09.
    public static let skillVersionObject = Data("""
    {
      "id": "id",
      "created_at": "2024-10-30T23:58:27.427722Z",
      "description": "description",
      "name": "name",
      "skill_id": "skill_01JAbcdefghijklmnopqrstuvw",
      "type": "skill_version"
    }
    """.utf8)

    /// <https://platform.claude.com/docs/en/api/skills/versions/list>, retrieved 2026-10-09.
    public static let skillVersionList = Data("""
    {
      "data": [
        {
          "id": "id",
          "created_at": "2024-10-30T23:58:27.427722Z",
          "description": "description",
          "name": "name",
          "skill_id": "skill_01JAbcdefghijklmnopqrstuvw",
          "type": "skill_version"
        }
      ],
      "next_page": "next_page"
    }
    """.utf8)

    /// <https://platform.claude.com/docs/en/api/skills/delete>
    public static let skillDeleted = Data("""
    {
      "id": "skill_01JAbcdefghijklmnopqrstuvw",
      "type": "skill_deleted"
    }
    """.utf8)
}
