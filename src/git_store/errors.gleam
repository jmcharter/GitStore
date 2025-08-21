import gleam/http/response
import gleam/int
import gleam/json
import gleam/string
import logging

pub type GitStoreError {
  ParsingError(String)
  HTTPError(String)
  NoFileFound(String)
  GitHubError
}

/// Log and return an error
pub fn log_error(error: GitStoreError) -> GitStoreError {
  let error_msg = case error {
    ParsingError(msg) -> "Parsing Error: " <> msg
    HTTPError(msg) -> "HTTP Error: " <> msg
    NoFileFound(filename) -> "File Not Found: " <> filename
    GitHubError -> "GitHub API Error"
  }
  logging.log(logging.Error, error_msg)
  error
}

/// Helper for logging and converting JSON decode errors
pub fn log_json_error(err: json.DecodeError) -> GitStoreError {
  let error = ParsingError(err |> string.inspect)
  log_error(error)
}

/// Helper for logging HTTP responses that aren't successful
pub fn log_http_error(
  res: response.Response(String),
  operation: String,
) -> GitStoreError {
  let error_msg =
    operation
    <> " failed with status "
    <> int.to_string(res.status)
    <> ": "
    <> res.body
  logging.log(logging.Error, error_msg)
  GitHubError
}
