import gleam/bit_array
import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn build_path(base: String, segments: List(String)) -> String {
  segments
  |> list.fold(base, fn(path, segment) { path <> "/" <> segment })
}

/// Set the JSON content type header and JSON body if json_body is not None
pub fn set_json(req: request.Request(String), json_body: Option(String)) {
  case json_body {
    Some(body) ->
      req
      |> request.set_header("Content-Type", "application/json")
      |> request.set_body(body)

    None -> req
  }
}

/// Encode string to Base64
pub fn encode_content(content: String) -> String {
  content
  |> bit_array.from_string
  |> bit_array.base64_encode(True)
}
