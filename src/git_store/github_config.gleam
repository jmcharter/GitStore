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

pub fn get_owner(config: GitHubConfig) -> String {
  config.owner
}

pub fn get_repo(config: GitHubConfig) -> String {
  config.repo
}

pub fn get_base_url(config: GitHubConfig) -> String {
  config.base_url
}
