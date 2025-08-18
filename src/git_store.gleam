import gleam/io

pub type GithubConfig {
  GithubConfig(owner: String, repo: String, token: String)
}

pub fn main() -> Nil {
  io.println("Hello from git_store!")
}
