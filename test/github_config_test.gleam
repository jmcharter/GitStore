import git_store
import gleeunit/should

pub fn new_config_test() {
  let config = git_store.new_config("owner", "repo", "token")

  config.owner |> should.equal("owner")
  config.repo |> should.equal("repo")
  config.token |> should.equal("token")
  config.base_url |> should.equal("https://api.github.com")
}

pub fn new_enterprise_config_test() {
  let config =
    git_store.new_enterprise_config(
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

pub fn empty_config_test() {
  let config = git_store.empty_config()

  config.owner |> should.equal("")
  config.repo |> should.equal("")
  config.token |> should.equal("")
  config.base_url |> should.equal("")
}
