pub type GitHubConfig {
  GitHubConfig(owner: String, repo: String, token: String, base_url: String)
}

pub fn new() {
  GitHubConfig("", "", "", "")
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
