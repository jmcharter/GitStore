import gleam/http/request
import gleam/option.{None, Some}

import gleeunit/should

import git_store/utils

pub fn build_path_test() {
  utils.build_path("https://api.github.com", ["repos", "owner", "repo"])
  |> should.equal("https://api.github.com/repos/owner/repo")
}

pub fn build_path_empty_segments_test() {
  utils.build_path("https://api.github.com", [])
  |> should.equal("https://api.github.com")
}

pub fn build_path_single_segment_test() {
  utils.build_path("https://api.github.com", ["repos"])
  |> should.equal("https://api.github.com/repos")
}

pub fn encode_content_test() {
  utils.encode_content("Hello, World!")
  |> should.equal("SGVsbG8sIFdvcmxkIQ==")
}

pub fn encode_content_empty_test() {
  utils.encode_content("")
  |> should.equal("")
}

pub fn set_json_with_body_test() {
  let req = request.new()
  let result = utils.set_json(req, Some("{\"test\": \"value\"}"))

  // This is more of a smoke test to ensure the function doesn't crash
  result |> should.not_equal(req)
}

pub fn set_json_without_body_test() {
  let req = request.new()
  let result = utils.set_json(req, None)

  // Should return the same request unchanged
  result |> should.equal(req)
}
