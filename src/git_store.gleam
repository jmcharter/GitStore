import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import envoy
import logging

import git_store/utils

const create_prefix = "add: "

const delete_prefix = "delete: "

pub type GitStoreError {
  ParsingError(String)
  HTTPError(String)
  NoFileFound(String)
  GitHubError
}

pub type GitHubConfig {
  GithubConfig(owner: String, repo: String, token: String, base_url: String)
}

pub type GitHubResponse {
  GitHubFileResponse(content: String, encoding: String, sha: String, size: Int)
}

/// The required fields to create a new file in a GitHub repo.
/// Message is the commit message
/// Content is the base64 encoded text content of the file
pub type GitHubFile {
  GitHubFileCreate(message: String, content: String)
  GitHubFileDelete(message: String, sha: String)
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
) -> Result(response.Response(String), GitStoreError) {
  let url = contents_url(config, path)
  send_request(config, http.Get, url, None)
}

/// Create a file from a file object on a GitHub repository at the given path
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#create-or-update-file-contents
pub fn create_file(
  config: GitHubConfig,
  filename: String,
  content: String,
) -> Result(response.Response(String), GitStoreError) {
  let url = contents_url(config, filename)
  let content = content |> utils.encode_content
  let file = GitHubFileCreate(create_prefix <> filename, content:)
  let res = send_request(config, http.Put, url, Some(file |> file_to_json))
  logging.log(logging.Debug, "Writing file: " <> string.inspect(res))
  res
}

/// Get a file object from a GitHub repositiory and, if it exists, delete it
/// https://docs.github.com/en/rest/repos/contents?apiVersion=2022-11-28#delete-a-file
pub fn delete_file(
  config: GitHubConfig,
  filename: String,
) -> Result(response.Response(String), GitStoreError) {
  let url = contents_url(config, filename)
  use original <- result.try(
    get_file(config, filename)
    |> result.map_error(fn(_) { NoFileFound(filename) }),
  )
  use original_file <- result.try(
    file_from_json(original.body)
    |> result.map_error(fn(err) { ParsingError(err |> string.inspect) }),
  )
  let file = GitHubFileDelete(delete_prefix <> filename, sha: original_file.sha)
  let res = send_request(config, http.Delete, url, Some(file |> file_to_json))
  logging.log(logging.Debug, "Deleting file: " <> string.inspect(res))
  res
}

/// Create a JSON string from a GitHubFile
fn file_to_json(file: GitHubFile) -> String {
  let base_fields = [#("message", json.string(file.message))]
  let other_field = case file {
    GitHubFileCreate(_msg, content) -> {
      [#("content", json.string(content))]
    }
    GitHubFileDelete(_msg, sha) -> [#("sha", json.string(sha))]
  }
  list.append(base_fields, other_field)
  |> json.object
  |> json.to_string
}

/// Parse the JSON data from file.body, converting the base64 encoded content
/// into a String
fn file_from_json(
  json_string: String,
) -> Result(GitHubResponse, json.DecodeError) {
  logging.log(logging.Debug, json_string)
  let file_decoder = {
    use content <- decode.field(
      "content",
      decode.then(decode.string, fn(item) {
        let decoded =
          item
          |> string.replace("\n", "")
          |> bit_array.base64_decode
          |> result.try(bit_array.to_string)
        case decoded {
          Ok(str) -> decode.success(str)
          Error(_) -> {
            logging.log(
              logging.Error,
              "Failed to decode expected base64 string: " <> item,
            )
            decode.failure("", "A base64 encoded String")
          }
        }
      }),
    )
    use encoding <- decode.field("encoding", decode.string)
    use sha <- decode.field("sha", decode.string)
    use size <- decode.field("size", decode.int)
    decode.success(GitHubFileResponse(content:, encoding:, sha:, size:))
  }
  json.parse(json_string, using: file_decoder)
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
      logging.log(logging.Error, "Unable to parse URL")
      ParsingError("Unable to parse URL: " <> endpoint)
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
    HTTPError(string.inspect(error))
  })
}

pub fn main() -> Nil {
  logging.configure()
  logging.set_level(logging.Debug)
  let owner = envoy.get("GITHUB_OWNER") |> result.unwrap("")
  let repo = envoy.get("GITHUB_REPO") |> result.unwrap("")
  let token = envoy.get("GITHUB_TOKEN") |> result.unwrap("")
  let base_url =
    envoy.get("GITHUB_BASE_URL") |> result.unwrap("https://api.github.com")
  let config = GithubConfig(owner, repo, token, base_url)
  logging.log(logging.Debug, config |> string.inspect)
  let file = get_file(config, "README.md") |> result.unwrap(response.new(400))
  echo file_from_json(file.body)
  let new_file = create_file(config, "test", "foo bar baz")
  let file = get_file(config, "test") |> result.unwrap(response.new(400))
  echo file_from_json(file.body)
  echo delete_file(config, "test")

  io.println("Hello from git_store!")
}
