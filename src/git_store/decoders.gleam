import gleam/bit_array
import gleam/dynamic/decode
import gleam/result
import gleam/string

import logging

import git_store/types.{
  type CommitInfo, type DirListing, type FileInfo, type GitHubResponse,
}

pub fn create_file_response_decoder() -> decode.Decoder(GitHubResponse) {
  use content <- decode.field("content", file_info_decoder())
  use commit <- decode.field("commit", commit_info_decoder())
  decode.success(types.GitHubCreateFileResponse(content:, commit:))
}

fn file_info_decoder() -> decode.Decoder(FileInfo) {
  use name <- decode.field("name", decode.string)
  use path <- decode.field("path", decode.string)
  use sha <- decode.field("sha", decode.string)
  use size <- decode.field("size", decode.int)
  use url <- decode.field("url", decode.string)
  use html_url <- decode.field("html_url", decode.string)
  use git_url <- decode.field("git_url", decode.string)
  use download_url <- decode.field("download_url", decode.string)
  use type_ <- decode.field("type", decode.string)
  decode.success(types.FileInfo(
    name:,
    path:,
    sha:,
    size:,
    url:,
    html_url:,
    git_url:,
    download_url:,
    type_:,
  ))
}

pub fn commit_info_decoder() -> decode.Decoder(CommitInfo) {
  use sha <- decode.field("sha", decode.string)
  use url <- decode.field("url", decode.string)
  use html_url <- decode.field("html_url", decode.string)
  use message <- decode.field("message", decode.string)
  decode.success(types.CommitInfo(sha:, url:, html_url:, message:))
}

pub fn dir_listing_decoder() -> decode.Decoder(DirListing) {
  use name <- decode.field("name", decode.string)
  use path <- decode.field("path", decode.string)
  use sha <- decode.field("sha", decode.string)
  use size <- decode.field("size", decode.int)
  use type_ <- decode.field("type", decode.string)
  use download_url <- decode.field(
    "download_url",
    decode.optional(decode.string),
  )
  decode.success(types.DirListing(
    name:,
    path:,
    sha:,
    size:,
    type_:,
    download_url:,
  ))
}

pub fn file_decoder() -> decode.Decoder(GitHubResponse) {
  use content <- decode.field(
    "content",
    decode.then(decode.string, fn(item) {
      let decoded =
        item
        |> string.replace("\n", "")
        |> bit_array.base64_decode
        |> result.try(bit_array.to_string)
      case decoded {
        Ok(str) -> decode.success(str)
        Error(_) -> {
          logging.log(
            logging.Error,
            "Failed to decode expected base64 string: " <> item,
          )
          decode.failure("", "A base64 encoded String")
        }
      }
    }),
  )
  use encoding <- decode.field("encoding", decode.string)
  use sha <- decode.field("sha", decode.string)
  use size <- decode.field("size", decode.int)
  decode.success(types.GitHubGetFileResponse(content:, encoding:, sha:, size:))
}
