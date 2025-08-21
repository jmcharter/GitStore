import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import logging

import git_store/internal/decoders
import git_store/internal/errors
import git_store/internal/types.{
  type ExpectResponseType, type GitHubFile, type GitHubResponse,
  expect_to_string, response_to_string,
}
import git_store/internal/utils

const create_prefix = "add: "

const delete_prefix = "delete: "

const update_prefix = "update: "

// Configuration types and functions
pub type GitHubConfig {
  GitHubConfig(owner: String, repo: String, token: String, base_url: String)
}

/// Create a new GitHubConfig with default GitHub.com API base URL
pub fn new_config(owner: String, repo: String, token: String) -> GitHubConfig {
  GitHubConfig(owner, repo, token, "https://api.github.com")
}

/// Create a new GitHubConfig for GitHub Enterprise with custom base URL
pub fn new_enterprise_config(
  owner: String,
  repo: String,
  token: String,
  base_url: String,
) -> GitHubConfig {
  GitHubConfig(owner, repo, token, base_url)
}

/// Create an empty GitHubConfig (for testing or manual construction)
pub fn empty_config() -> GitHubConfig {
  GitHubConfig("", "", "", "")
}

/// Create a URL for creating, updating and deleting content on a GitHub repository
fn contents_url(config: GitHubConfig, path: String) -> String {
  utils.build_path(config.base_url, [
    "repos",
    config.owner,
    config.repo,
    "contents",
  ])
  <> "/"
  <> path
}

/// Get a file object from a GitHub repository at the given path
/// Path should be a '/' separated String, e.g:
/// 'foo/bar/baz'
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#get-repository-content
pub fn get_file(
  config: GitHubConfig,
  path: String,
) -> Result(GitHubResponse, errors.GitStoreError) {
  get_file_or_directory(config, path, types.ExpectFile)
}

fn get_file_or_directory(
  config: GitHubConfig,
  path: String,
  expect: ExpectResponseType,
) -> Result(GitHubResponse, errors.GitStoreError) {
  let url = contents_url(config, path)
  use res <- result.try(send_request(config, http.Get, url, None))
  let body =
    res.body
    |> response_from_json
  use response <- result.try(
    body
    |> result.map_error(fn(err) { errors.ParsingError(err |> string.inspect) }),
  )
  case expect, response {
    types.ExpectFile, types.GitHubGetFileResponse(_, _, _, _) -> Ok(response)
    types.ExpectDir, types.GitHubGetDirResponse(_) -> Ok(response)
    _, _ ->
      Error(errors.ParsingError(
        "Expected: "
        <> expect |> expect_to_string
        <> ", Got: "
        <> response |> response_to_string,
      ))
  }
}

/// Create a file from a file object on a GitHub repository at the given path
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#create-or-update-file-contents
pub fn create_file(
  config: GitHubConfig,
  filename: String,
  content: String,
) -> Result(GitHubResponse, errors.GitStoreError) {
  let url = contents_url(config, filename)
  let content = content |> utils.encode_content
  let file = types.GitHubFileCreate(create_prefix <> filename, content:)
  use res <- result.try(send_request(
    config,
    http.Put,
    url,
    Some(file |> file_to_json),
  ))

  case res.status {
    201 -> {
      logging.log(logging.Info, "Successfully written file: " <> filename)
      decoders.create_file_response_decoder()
      |> json.parse(res.body, using: _)
      |> result.map_error(fn(err) { errors.ParsingError(err |> string.inspect) })
    }
    422 ->
      Error(
        errors.ParsingError("File already exists. Use update instead.")
        |> errors.log_error,
      )
    _ -> Error(errors.GitHubError |> errors.log_error)
  }
}

/// Get a file object from a GitHub repositiory and, if it exists, replace the content with the given content
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#create-or-update-file-contents
pub fn update_file(
  config: GitHubConfig,
  filename: String,
  content: String,
) -> Result(GitHubResponse, errors.GitStoreError) {
  let url = contents_url(config, filename)
  use original <- result.try(
    get_file(config, filename)
    |> result.map_error(fn(_) { errors.NoFileFound(filename) }),
  )
  case original {
    types.GitHubGetFileResponse(_, _, sha, _) -> {
      let file =
        types.GitHubFileUpdate(
          update_prefix <> filename,
          content: content |> utils.encode_content,
          sha: sha,
        )
      use res <- result.try(send_request(
        config,
        http.Put,
        url,
        Some(file |> file_to_json),
      ))
      case res.status {
        200 -> {
          logging.log(logging.Info, "Successfully updated file: " <> filename)
          decoders.update_file_response_decoder()
          |> json.parse(res.body, using: _)
          |> result.map_error(errors.log_json_error)
        }
        _ -> Error(errors.log_http_error(res, "Update file"))
      }
    }
    _ -> Error(errors.ParsingError("Expected file") |> errors.log_error)
  }
}

/// Get a file object from a GitHub repositiory and, if it exists, delete it
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#delete-a-file
pub fn delete_file(
  config: GitHubConfig,
  filename: String,
) -> Result(GitHubResponse, errors.GitStoreError) {
  let url = contents_url(config, filename)
  use original <- result.try(
    get_file(config, filename)
    |> result.map_error(fn(_) { errors.NoFileFound(filename) }),
  )
  case original {
    types.GitHubGetFileResponse(_, _, sha, _) -> {
      let file = types.GitHubFileDelete(delete_prefix <> filename, sha: sha)
      use res <- result.try(send_request(
        config,
        http.Delete,
        url,
        Some(file |> file_to_json),
      ))
      case res.status {
        200 -> {
          logging.log(logging.Info, "Successfully deleted file: " <> filename)
          decoders.delete_file_response_decoder()
          |> json.parse(res.body, using: _)
          |> result.map_error(errors.log_json_error)
        }
        _ -> Error(errors.log_http_error(res, "Delete file"))
      }
    }
    _ -> Error(errors.ParsingError("Expected file") |> errors.log_error)
  }
}

/// Create a JSON string from a GitHubFile
fn file_to_json(file: GitHubFile) -> String {
  let base_fields = [#("message", json.string(file.message))]
  let other_fields = case file {
    types.GitHubFileCreate(_msg, content) -> {
      [#("content", json.string(content))]
    }
    types.GitHubFileDelete(_msg, sha) -> [#("sha", json.string(sha))]
    types.GitHubFileUpdate(_msg, content, sha) -> [
      #("content", json.string(content)),
      #("sha", json.string(sha)),
    ]
  }
  list.append(base_fields, other_fields)
  |> json.object
  |> json.to_string
}

/// Parse the JSON data from file.body, converting the base64 encoded content
/// into a String
fn response_from_json(
  json_string: String,
) -> Result(GitHubResponse, json.DecodeError) {
  case
    json.parse(json_string, using: decode.list(decoders.dir_listing_decoder()))
  {
    Ok(listings) -> Ok(types.GitHubGetDirResponse(listings))
    Error(_) -> json.parse(json_string, using: decoders.file_decoder())
  }
}

fn send_request(
  config: GitHubConfig,
  method: http.Method,
  endpoint: String,
  json_body: Option(String),
) {
  use req <- result.try(
    request.to(endpoint)
    |> result.map_error(fn(_) {
      errors.ParsingError("Unable to parse URL: " <> endpoint)
      |> errors.log_error
    }),
  )
  let res =
    req
    |> request.set_header("Authorization", "Bearer " <> config.token)
    |> request.set_header("Accept", "application/vnd.github+json")
    |> request.set_header("User-Agent", "GitStore-Gleam")
    |> utils.set_json(json_body)
    |> request.set_method(method)
    |> httpc.send()

  res
  |> result.map_error(fn(error) {
    logging.log(logging.Error, string.inspect(error))
    errors.HTTPError(string.inspect(error))
  })
}
