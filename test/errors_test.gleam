import git_store/errors
import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleeunit/should

pub fn log_error_parsing_error_test() {
  let error = errors.ParsingError("Test parsing error")
  let result = errors.log_error(error)

  result |> should.equal(error)
}

pub fn log_error_http_error_test() {
  let error = errors.HTTPError("Test HTTP error")
  let result = errors.log_error(error)

  result |> should.equal(error)
}

pub fn log_error_no_file_found_test() {
  let error = errors.NoFileFound("test.txt")
  let result = errors.log_error(error)

  result |> should.equal(error)
}

pub fn log_error_github_error_test() {
  let error = errors.GitHubError
  let result = errors.log_error(error)

  result |> should.equal(error)
}

pub fn log_json_error_test() {
  // Create a decode error by trying to parse invalid JSON
  let decode_result = json.parse("invalid json", using: decode.string)
  case decode_result {
    Error(decode_error) -> {
      let result = errors.log_json_error(decode_error)
      case result {
        errors.ParsingError(_msg) -> should.be_true(True)
        _ -> should.fail()
      }
    }
    Ok(_) -> should.fail()
  }
}

pub fn log_http_error_test() {
  let response = response.Response(status: 404, headers: [], body: "Not Found")

  let result = errors.log_http_error(response, "Test operation")
  result |> should.equal(errors.GitHubError)
}
