import gleam/result

import envoy
import logging

import git_store/errors

pub type GitHubConfig {
  GitHubConfig(owner: String, repo: String, token: String, base_url: String)
}

/// Create a new GitHubConfig with default GitHub.com API base URL
pub fn new(owner: String, repo: String, token: String) -> GitHubConfig {
  GitHubConfig(owner, repo, token, "https://api.github.com")
}

/// Create a new GitHubConfig for GitHub Enterprise with custom base URL
pub fn new_enterprise(
  owner: String,
  repo: String,
  token: String,
  base_url: String,
) -> GitHubConfig {
  GitHubConfig(owner, repo, token, base_url)
}

/// Create an empty GitHubConfig (for testing or manual construction)
pub fn empty() -> GitHubConfig {
  GitHubConfig("", "", "", "")
}

/// Load GitHubConfig from environment variables
/// Expects: GITHUB_OWNER, GITHUB_REPO, GITHUB_TOKEN
/// Optional: GITHUB_BASE_URL (defaults to "https://api.github.com")
pub fn from_env() -> Result(GitHubConfig, errors.GitStoreError) {
  use owner <- result.try(
    envoy.get("GITHUB_OWNER")
    |> result.map_error(fn(_) {
      errors.ParsingError("Missing GITHUB_OWNER environment variable")
      |> errors.log_error
    }),
  )
  use repo <- result.try(
    envoy.get("GITHUB_REPO")
    |> result.map_error(fn(_) {
      errors.ParsingError("Missing GITHUB_REPO environment variable")
      |> errors.log_error
    }),
  )
  use token <- result.try(
    envoy.get("GITHUB_TOKEN")
    |> result.map_error(fn(_) {
      errors.ParsingError("Missing GITHUB_TOKEN environment variable")
      |> errors.log_error
    }),
  )

  let base_url =
    envoy.get("GITHUB_BASE_URL") |> result.unwrap("https://api.github.com")

  logging.log(
    logging.Info,
    "Successfully loaded GitHub config from environment variables",
  )
  Ok(GitHubConfig(owner, repo, token, base_url))
}

pub fn get_owner(config: GitHubConfig) -> String {
  config.owner
}

pub fn get_repo(config: GitHubConfig) -> String {
  config.repo
}

pub fn get_base_url(config: GitHubConfig) -> String {
  config.base_url
}
