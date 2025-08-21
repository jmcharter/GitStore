import gleam/option.{type Option}

pub type ExpectResponseType {
  ExpectFile
  ExpectDir
}

pub fn expect_to_string(expect: ExpectResponseType) -> String {
  case expect {
    ExpectDir -> "directory"
    ExpectFile -> "file"
  }
}

pub type GitHubResponse {
  GitHubGetFileResponse(
    content: String,
    encoding: String,
    sha: String,
    size: Int,
  )
  GitHubGetDirResponse(List(DirListing))
  GitHubCreateFileResponse(content: FileInfo, commit: CommitInfo)
  GitHubUpdateFileResponse(content: FileInfo, commit: CommitInfo)
  GitHubDeleteFileResponse(content: Option(String), commit: CommitInfo)
}

pub type FileInfo {
  FileInfo(
    name: String,
    path: String,
    sha: String,
    size: Int,
    url: String,
    html_url: String,
    git_url: String,
    download_url: String,
    type_: String,
  )
}

pub type CommitInfo {
  CommitInfo(sha: String, url: String, html_url: String, message: String)
}

pub fn response_to_string(response: GitHubResponse) -> String {
  case response {
    GitHubGetFileResponse(_, _, _, _) -> "file"
    GitHubGetDirResponse(_) -> "dir"
    _ -> "other"
  }
}

pub type DirListing {
  DirListing(
    name: String,
    path: String,
    sha: String,
    size: Int,
    type_: String,
    // file or dir
    download_url: Option(String),
  )
}

/// The required fields to create a new file in a GitHub repo.
/// Message is the commit message
/// Content is the base64 encoded text content of the file
pub type GitHubFile {
  GitHubFileCreate(message: String, content: String)
  GitHubFileUpdate(message: String, content: String, sha: String)
  GitHubFileDelete(message: String, sha: String)
}
