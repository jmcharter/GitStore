# GitStore

[![Package Version](https://img.shields.io/hexpm/v/git_store)](https://hex.pm/packages/git_store)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/git_store/)

A Gleam library for using GitHub repositories as backend storage. GitStore provides a simple API to create, read, update, and delete files in GitHub repositories through the GitHub REST API.

## Features

📁 **File Operations**: Create, read, update, and delete files in GitHub repositories

## Installation

```sh
gleam add git_store@1
```

## Configuration

Set the following environment variables:

```sh
export GITHUB_OWNER="your-username"
export GITHUB_REPO="your-repository"
export GITHUB_TOKEN="your-github-token"
export GITHUB_BASE_URL="https://api.github.com"  # Optional, defaults to GitHub.com
```

For GitHub Enterprise, set `GITHUB_BASE_URL` to your enterprise instance API URL.

## Usage

```gleam
import git_store
import git_store/github_config.{GitHubConfig}
import git_store/errors
import envoy

pub fn main() -> Nil {
  // Load configuration from environment
  let assert Ok(owner) = envoy.get("GITHUB_OWNER")
  let assert Ok(repo) = envoy.get("GITHUB_REPO") 
  let assert Ok(token) = envoy.get("GITHUB_TOKEN")
  let base_url = envoy.get("GITHUB_BASE_URL") |> result.unwrap("https://api.github.com")
  
  let config = GitHubConfig(owner, repo, token, base_url)

  // Create a new file
  case git_store.create_file(config, "hello.txt", "Hello, World!") {
    Ok(_) -> io.println("File created successfully")
    Error(err) -> io.println("Error: " <> string.inspect(err))
  }

  // Read a file
  case git_store.get_file(config, "hello.txt") {
    Ok(response) -> {
      case response {
        types.GitHubGetFileResponse(content, _, _, _) -> 
          io.println("File content: " <> content)
        _ -> io.println("Unexpected response")
      }
    }
    Error(err) -> io.println("Error: " <> string.inspect(err))
  }

  // Update a file
  case git_store.update_file(config, "hello.txt", "Hello, Updated World!") {
    Ok(_) -> io.println("File updated successfully")
    Error(err) -> io.println("Error: " <> string.inspect(err))
  }

  // Delete a file
  case git_store.delete_file(config, "hello.txt") {
    Ok(_) -> io.println("File deleted successfully")
    Error(err) -> io.println("Error: " <> string.inspect(err))
  }
}
```

## API Reference

### Core Functions

- `get_file(config, path)` - Retrieve a file from the repository
- `create_file(config, filename, content)` - Create a new file
- `update_file(config, filename, content)` - Update an existing file  
- `delete_file(config, filename)` - Delete a file

### Configuration

```gleam
GitHubConfig(
  owner: String,    // Repository owner/organization
  repo: String,     // Repository name
  token: String,    // GitHub personal access token
  base_url: String  // GitHub API base URL
)
```

### Error Types

- `ParsingError(String)` - JSON parsing or response format errors
- `HTTPError(String)` - HTTP request failures
- `NoFileFound(String)` - File not found in repository
- `GitHubError` - General GitHub API errors

## Commit Message Format

GitStore automatically generates commit messages with operation prefixes:
- `add: filename` - For file creation
- `update: filename` - For file updates  
- `delete: filename` - For file deletion

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Documentation

Further documentation can be found at <https://hexdocs.pm/git_store>.
