import git_store/errors
import git_store/github_config
import gleeunit/should

pub fn new_test() {
  let config = github_config.new("owner", "repo", "token")

  config.owner |> should.equal("owner")
  config.repo |> should.equal("repo")
  config.token |> should.equal("token")
  config.base_url |> should.equal("https://api.github.com")
}

pub fn new_enterprise_test() {
  let config =
    github_config.new_enterprise(
      "owner",
      "repo",
      "token",
      "https://github.company.com/api/v3",
    )

  config.owner |> should.equal("owner")
  config.repo |> should.equal("repo")
  config.token |> should.equal("token")
  config.base_url |> should.equal("https://github.company.com/api/v3")
}

pub fn empty_test() {
  let config = github_config.empty()

  config.owner |> should.equal("")
  config.repo |> should.equal("")
  config.token |> should.equal("")
  config.base_url |> should.equal("")
}

pub fn get_owner_test() {
  let config = github_config.new("test-owner", "test-repo", "test-token")
  github_config.get_owner(config) |> should.equal("test-owner")
}

pub fn get_repo_test() {
  let config = github_config.new("test-owner", "test-repo", "test-token")
  github_config.get_repo(config) |> should.equal("test-repo")
}

pub fn get_base_url_test() {
  let config = github_config.new("test-owner", "test-repo", "test-token")
  github_config.get_base_url(config) |> should.equal("https://api.github.com")
}
