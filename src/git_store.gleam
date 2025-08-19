import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

import envoy
import logging

import git_store/utils

pub type GitStoreError {
  ParsingError(String)
  HTTPError(String)
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
  GitHubFile(message: String, content: String)
}

pub fn repos_url(config: GitHubConfig) -> String {
  config.base_url <> "/repos"
}

/// Get a file object from a GitHub repository at the given path
/// Path should be a '/' separated String, e.g:
/// 'foo/bar/baz'
pub fn get_file(
  config: GitHubConfig,
  path: String,
) -> Result(response.Response(String), GitStoreError) {
  let url =
    utils.build_path(config.base_url, [
      "repos",
      config.owner,
      config.repo,
      "contents",
    ])
    <> "/"
    <> path

  request(config, http.Get, url, None)
}

fn request(
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

fn file_to_json(file: GitHubFile) -> String {
  json.object([
    #("message", json.string(file.message)),
    #("content", json.string(file.content)),
  ])
  |> json.to_string
}

fn create_file(config: GitHubConfig, filename: String, content: String) {
  let url =
    utils.build_path(config.base_url, [
      "repos",
      config.owner,
      config.repo,
      "contents",
    ])
    <> "/"
    <> filename
  let content =
    content
    |> bit_array.from_string
    |> bit_array.base64_encode(True)
  let file = GitHubFile("add: " <> filename, content:)
  let res = request(config, http.Put, url, Some(file |> file_to_json))
  logging.log(logging.Debug, "Writing file: " <> string.inspect(res))
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
  io.println("Hello from git_store!")
}
