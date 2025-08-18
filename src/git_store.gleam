import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/io
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

pub type GitHubFileResponse {
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

pub fn main() -> Nil {
  logging.configure()
  let owner = envoy.get("GITHUB_OWNER") |> result.unwrap("")
  let repo = envoy.get("GITHUB_REPO") |> result.unwrap("")
  let token = envoy.get("GITHUB_TOKEN") |> result.unwrap("")
  let config = GithubConfig(owner, repo, token, "https://api.github.com")
  let file = read_file(config, "README.md")
  io.println("Hello from git_store!")
}
