import git_store/decoders
import git_store/types
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should

pub fn file_decoder_test() {
  let json_string =
    "{
    \"content\": \"SGVsbG8sIFdvcmxkIQ==\",
    \"encoding\": \"base64\",
    \"sha\": \"abc123\",
    \"size\": 13
  }"

  let result = json.parse(json_string, using: decoders.file_decoder())

  case result {
    Ok(response) -> {
      case response {
        types.GitHubGetFileResponse(content, encoding, sha, size) -> {
          content |> should.equal("Hello, World!")
          encoding |> should.equal("base64")
          sha |> should.equal("abc123")
          size |> should.equal(13)
        }
        _ -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn dir_listing_decoder_test() {
  let json_string =
    "{
    \"name\": \"test.txt\",
    \"path\": \"dir/test.txt\",
    \"sha\": \"abc123\",
    \"size\": 100,
    \"type\": \"file\",
    \"download_url\": \"https://example.com/download\"
  }"

  let result = json.parse(json_string, using: decoders.dir_listing_decoder())

  case result {
    Ok(listing) -> {
      listing.name |> should.equal("test.txt")
      listing.path |> should.equal("dir/test.txt")
      listing.sha |> should.equal("abc123")
      listing.size |> should.equal(100)
      listing.type_ |> should.equal("file")
      listing.download_url |> should.equal(Some("https://example.com/download"))
    }
    Error(_) -> should.fail()
  }
}

pub fn dir_listing_decoder_null_download_url_test() {
  let json_string =
    "{
    \"name\": \"subdir\",
    \"path\": \"dir/subdir\",
    \"sha\": \"def456\",
    \"size\": 0,
    \"type\": \"dir\",
    \"download_url\": null
  }"

  let result = json.parse(json_string, using: decoders.dir_listing_decoder())

  case result {
    Ok(listing) -> {
      listing.name |> should.equal("subdir")
      listing.type_ |> should.equal("dir")
      listing.download_url |> should.equal(None)
    }
    Error(_) -> should.fail()
  }
}
