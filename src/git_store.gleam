import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
import gleam/json
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

pub fn repos_url(config: GitHubConfig) -> String {
  config.base_url <> "/repos"
}

pub fn read_file(
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

  request(config, http.Get, url)
}

fn request(config: GitHubConfig, method: http.Method, endpoint: String) {
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
    |> request.set_method(method)
    |> httpc.send()

  res
  |> result.map_error(fn(error) {
    logging.log(logging.Error, string.inspect(error))
    HTTPError(string.inspect(error))
  })
}

fn file_from_json(
  json_string: String,
) -> Result(GitHubResponse, json.DecodeError) {
  let file_decoder = {
    use content <- decode.field(
      "content",
      decode.then(decode.string, fn(item) {
        let decoded =
          item |> bit_array.base64_decode |> result.try(bit_array.to_string)
        case decoded {
          Ok(str) -> decode.success(str)
          Error(_) -> decode.failure("", "A base64 encoded String")
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

pub fn main() -> Nil {
  logging.configure()
  let owner = envoy.get("GITHUB_OWNER") |> result.unwrap("")
  let repo = envoy.get("GITHUB_REPO") |> result.unwrap("")
  let token = envoy.get("GITHUB_TOKEN") |> result.unwrap("")
  let base_url =
    envoy.get("GITHUB_BASE_URL") |> result.unwrap("https://api.github.com")
  let config = GithubConfig(owner, repo, token, base_url)
  let file = read_file(config, "README.md") |> result.unwrap(response.new(400))
  echo file_from_json(file.body)
  io.println("Hello from git_store!")
}
